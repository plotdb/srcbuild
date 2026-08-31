require! <[uglify-js uglifycss @plotdb/colors]>

# one place for every minifier call in this package.
#
# the reason it exists: `uglify-js.minify` does not throw on a syntax error, it returns
# `{error}` - with no `code` field at all. every call site used to read `.code` off that
# and get `undefined`, then either `or ''` it into an empty output file or `.join('')`
# it into a bundle, where `undefined` simply vanishes. a source file with a typo would
# disappear from the minified build with no log, no throw, and a perfectly fine
# unminified twin sitting next to it.
#
# so: never silently produce nothing. on failure hand back the input unchanged and say
# what happened. an unminified asset is bigger, not broken.

# {code, error, failed}. `code` is always a string worth writing:
# the minified form when it worked, the input when it did not.
minify = (type, code, opt = {}) ->
  if !code => return {code: '', failed: false}
  if type == \js =>
    ret = try
      uglify-js.minify code, opt
    catch e
      {error: e}
    # `ret.code` can legitimately be '' ( minifying whitespace-only input ), so test
    # `error` rather than the truthiness of `code`.
    if ret.error => return {code, error: ret.error, failed: true}
    return {code: (ret.code or ''), failed: false}
  else if type == \css =>
    try
      return {code: uglifycss.processString(code, uglyComments: true), failed: false}
    catch e
      return {code, error: e, failed: true}
  # not a type we minify: pass through.
  return {code, failed: false}

# the shape a caller usually wants: log on failure, always get a string back.
minify.or-original = (type, code, opt, log, what) ->
  ret = minify type, code, opt
  if ret.failed and log =>
    log.error "minify #type failed#{if what => " ( #what )" else ''}: #{ret.error?.message or ret.error}. left unminified.".red
  return ret.code

# ---------------------------------------------------------------------------------
# off the event loop.
#
# uglify is pure synchronous CPU work, and the process running it is usually also
# serving http. measured on a 0.94MB bundle: 2677ms of minify blocked the event loop
# for 1769ms in a single stall - long enough that a cold `pg.Pool` connect
# ( connectionTimeoutMillis 2000 ) expires while the handshake's callbacks cannot run.
# the request then fails with a database error that has nothing to do with the
# database. see servebase context/servebase/tasks/todo/20260830-srcbuild-minify-blocks-event-loop.md
#
# the same bundle through a worker: 3283ms wall, of which 9ms was moving the strings
# across, and the loop's worst tick was 13ms. so it costs ~20% more total time - a
# worker has its own heap and warms its own jit - and buys back the whole stall.
#
# note the cost is not a smooth function of size: 800KB of the same corpus took 88ms
# and 960KB took 2319ms, because one construct in that last chunk is pathological for
# uglify. that rules out "only send big inputs to the worker" - you cannot tell from
# the input which one will be expensive. everything the builders minify goes across.
#
# pug filters are the exception, and they stay synchronous: pug's filter interface has
# no async form. they minify inline `include:lsc` snippets, which are small.

worker-threads = try require 'worker_threads' catch e then null
idle-timeout = 30000

pool =
  worker: null
  jobs: {}
  seq: 0
  timer: null
  # once a worker has failed to start or died on us, stop trying: fall back to
  # in-process for the rest of the run rather than paying the spawn cost per call.
  disabled: !worker-threads or process.env.SRCBUILD_MINIFY_WORKER == '0'

  spawn: ->
    if @worker => return @worker
    path = require 'path'
    try
      @worker = new worker-threads.Worker path.join(__dirname, 'minify-worker.js')
    catch e
      @disabled = true
      return null
    w = @worker
    # never hold the process open. a build in flight is not a reason to keep node alive;
    # whoever asked for the build is holding their own handle.
    w.unref!
    # `@worker == w` is the difference between "it died" and "we killed it". `terminate`
    # exits non-zero, so without this check the idle timer below - or an explicit
    # `stop!` - would look like a crash and disable the pool for the rest of the run.
    # both of those set `@worker = null` first, so the identity test is the signal.
    w.on \message, (msg) ~> @settle msg
    w.on \error, (e) ~> if @worker == w => @die e
    w.on \exit, (code) ~> if @worker == w and code != 0 => @die new Error("minify worker exited with #code")
    return w

  settle: (msg) ->
    job = @jobs[msg.id]
    if !job => return
    delete @jobs[msg.id]
    job.resolve {code: msg.code, failed: msg.failed, error: msg.error}
    @arm-idle!

  # whatever happens to the thread, every outstanding promise has to settle. redo those
  # jobs in-process: slow, but a caller left hanging stalls the whole build.
  drain: ->
    jobs = @jobs
    @jobs = {}
    for id, job of jobs => job.resolve minify(job.type, job.code, job.opt)

  kill: ->
    if @timer => clear-timeout @timer
    @timer = null
    w = @worker
    @worker = null
    ret = if w => w.terminate! else Promise.resolve!
    @drain!
    return ret

  # the worker is gone on its own. same cleanup, plus: stop trying. paying a spawn per
  # call for something that has already failed once is worse than staying in-process.
  die: (e) ->
    @disabled = true
    @kill!

  arm-idle: ->
    if @timer => clear-timeout @timer
    @timer = null
    if @worker and !Object.keys(@jobs).length =>
      @timer = set-timeout (~>
        @timer = null
        if @worker and !Object.keys(@jobs).length =>
          w = @worker
          @worker = null
          try w.terminate!
      ), idle-timeout
      # the idle timer must not keep the process alive either.
      if @timer.unref => @timer.unref!

  run: (type, code, opt) ->
    if @disabled or !code => return Promise.resolve minify(type, code, opt)
    if !@spawn! => return Promise.resolve minify(type, code, opt)
    id = ++@seq
    p = new Promise (resolve) ~>
      @jobs[id] = {resolve, type, code, opt}
    if @timer => clear-timeout @timer ; @timer = null
    @worker.post-message {id, type, code, opt}
    return p

# same contract as `minify`, resolved rather than returned.
minify.async = (type, code, opt = {}) -> pool.run type, code, (opt or {})

# same contract as `or-original`, resolved rather than returned.
minify.async-or-original = (type, code, opt, log, what) ->
  pool.run type, code, (opt or {})
    .then (ret) ->
      if ret.failed and log =>
        log.error "minify #type failed#{if what => " ( #what )" else ''}: #{ret.error?.message or ret.error}. left unminified.".red
      return ret.code

# so a host can shut the thread down deliberately ( tests, one-shot cli builds ). the
# next call spawns a fresh one - unlike `die`, this is not a failure.
minify.stop = -> pool.kill!

module.exports = minify
