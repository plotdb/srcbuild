require! <[fs path fs-extra anymatch ./aux]>

adapter = (opt={}) ->
  @opt = opt
  @base = opt.base or '.'
  @log = opt.logger or aux.logger
  @init-scan = if opt.init-scan? => opt.init-scan else true
  @ignored = opt.ignored or opt.{}watcher.ignored or []
  @depends = {on: {}, by: {}}
  # files whose `get-dependencies` threw. their edges are unknown ( or stale ), so we
  # retry them on every change event until the analysis succeeds. see `change`.
  @failed = new Set!

  if opt.get-dependencies => @get-dependencies = that
  if opt.is-supported => @is-supported = that
  if opt.build => @build = that
  if opt.purge => @purge = that
  if opt.resolve => @resolve = that
  @

adapter.prototype = Object.create(Object.prototype) <<< do
  get-dependencies: -> []
  is-supported: (file) -> return false
  purge: (files) -> # files: [{file, mtime}, ... ]
  build: (files) -> # files: [{file, mtime}, ... ]
  resolve: (file) -> return null
  log-dependencies: (file) ->
    try list = (@get-dependencies(file) or []).map path.normalize catch e
      # don't touch dependency since we can't get the correct one. keeping the previous
      # edges is the best guess we have; the real error surfaces when `build` runs.
      throw new Error(e.message) <<< {name: 'lderror', id: 999, cause: e}
    Array.from(@depends.by[file] or []).map (f) ~> if @depends.on[f] => @depends.on[f].delete file
    setby = @depends.by[file] = new Set!
    list.map (f) ~>
      seton = if @depends.on[f] => that else (@depends.on[f] = new Set!)
      seton.add file
      setby.add f

  unlink: (files) ->
    ret = files
      .filter ~> @is-supported it
      .map -> {file: it, mtime: 0}
    ret.map ~> @failed.delete it.file
    @purge ret

  # the newest mtime among `file` and everything it (transitively) depends on. `memo`
  # is shared across a batch so a module included by 200 pages is stat'ed once.
  dep-mtime: (file, memo = {}) ->
    recurse = (f) ~>
      if memo[f]? => return that
      memo[f] = 0 # placed before recursing: this is what stops a dependency cycle
      if !fs.exists-sync(f) => return memo[f] = 0
      try
        stat = fs.stat-sync(f)
      catch e # file exists, but stat-sync fails - it may be a symlink pointing to a non-existed file.
        return memo[f] = 0
      return memo[f] = Math.max.apply Math,
        [+stat.mtime] ++ Array.from(@depends.by[f] or []).map((n) -> recurse n)
    recurse file

  change: (files, opt = {}) ->
    # walking the reverse graph and computing mtimes used to be the same loop, which
    # made it enumerate *paths* rather than visit *nodes*: a dependency cycle spun
    # forever, and a fan-in/fan-out graph ( version.pug -> base.pug -> every page, each
    # page also including shared modules ) grew the queue multiplicatively.
    # they are separated now: reachability first, then one memoised mtime pass.
    affected-files = new Set!
    queued = new Set!
    queue = []
    push = (f) -> if !queued.has(f) => queued.add f; queue.push f
    files = (if Array.isArray(files) => files else [files])
    files.map push
    # retry whatever failed to analyse before. a pug file that includes a broken .ls
    # records no edges at all, so fixing the .ls would otherwise trigger nothing and the
    # page stays stale until someone touches it by hand.
    Array.from(@failed).map push
    now = Date.now!
    while queue.length
      file = queue.pop!
      if !fs.exists-sync file => continue
      if @is-supported file =>
        analysed = true
        try @log-dependencies file catch e
          if !(e.name == \lderror and e.id == 999) => throw e
          analysed = false
        # note we do NOT skip the file when analysis failed: it still gets built, so the
        # builder reports the actual error instead of a vague "analyse failed", and its
        # dependents are still walked ( `depends.on` describes who depends on *this*
        # file, and is unaffected by our failure to read this file's own dependencies ).
        if analysed =>
          if @failed.has file =>
            @failed.delete file
            @log.info "#file analysed successfully. dependency recovered.".green
        else if !@failed.has file =>
          @failed.add file
          @log.error "analyse #file failed. will retry on next change.".red
      affected-files.add file
      if opt.non-recursive => continue
      Array.from(@depends.on[file] or []).map push
    memo = {}
    ret = Array.from(affected-files)
      .filter ~> @is-supported it
      .map ~> {file: it, mtime: (if opt.force => now else @dep-mtime(it, memo))}
    Promise.resolve(if ret.length => @build ret else null)

  dirty-check: (files) ->
    memo = {}
    @build files.map((file) ~> {file, mtime: @dep-mtime(file, memo)})

  init: ->
    if !@init-scan => return Promise.resolve!
    init-builds = []
    recurse = (root) ~>
      if !fs.exists-sync(root) => return
      files = fs.readdir-sync root
        .filter ~> !anymatch((@ignored or []), it)
        .map -> path.normalize("#root/#it")
      for file in files =>
        try
          stat = fs.stat-sync(file)
        catch e # file exists, but stat-sync fails - it may be a symlink pointing to a non-existed file.
          continue
        if stat.is-directory!
          recurse file
          # a directory is never a build target. it used to fall through to the
          # `is-supported` test below, which an extension whitelist almost always
          # failed - but a whitelist-free builder ( `ext: '*'` ) says yes to every
          # directory it walks.
          continue
        if !@is-supported(file) => continue
        # this is a time consuming func call. consider ODB instead.
        # on error: simply ignore. builder will take care of it.
        try @log-dependencies file catch e
          if !(e.name == \lderror and e.id == 999) => throw e
          @failed.add file
          @log.error "analyse #file failed. will retry on next change.".red
        init-builds.push file
    t1 = Date.now!
    recurse @base
    #console.log("adopt recurse takes #{Date.now! - t1}ms ( #{@base} )")
    @dirty-check init-builds

module.exports = adapter
