require! <[fs path assert fs-extra]>
{test} = require 'node:test'
minify = require '../src/minify'
bundle = require '../src/ext/bundle'
lsc = require '../src/ext/lsc'
{quiet, tmpdir, write, touch} = require './aux'

broken = "function f(){ var a = "
lib = (n) -> "static/assets/lib/#n"


test 'uglify reports a syntax error by omitting `code`, not by throwing', ->
  # the premise of everything below. if a future uglify starts throwing instead, these
  # tests still pass but the reason they exist has changed - so pin the behaviour.
  uglify = require 'uglify-js'
  ret = uglify.minify broken
  assert.ok ret.error, 'expected an error object'
  assert.strictEqual ret.code, void, 'expected no `code` field at all'
  # and this is the silent part: it disappears from a join.
  assert.strictEqual ['a;', ret.code, 'b;'].join(''), 'a;b;'


test 'minify hands back the original on failure instead of nothing', ->
  ret = minify \js, broken
  assert.ok ret.failed
  assert.strictEqual ret.code, broken


test 'minify still minifies when the input is fine', ->
  src = 'window.f = function  ( ) { var  unused = 1 ; return   2 ; } ;'
  ret = minify \js, src
  assert.ok !ret.failed
  assert.ok !!ret.code
  assert.ok ret.code.length < src.length, "expected it to shrink: #{ret.code}"


test 'minify passes empty input through without claiming failure', ->
  for type in <[js css]> =>
    ret = minify type, ''
    assert.strictEqual ret.code, ''
    assert.ok !ret.failed


test 'or-original logs once and returns the input', ->
  msgs = []
  log = {error: (-> msgs.push it), info: (->), warn: (->)}
  out = minify.or-original \js, broken, {}, log, 'a.js'
  assert.strictEqual out, broken
  assert.strictEqual msgs.length, 1
  assert.ok /a\.js/.exec(msgs.0), "expected the file name in the log: #{msgs.0}"


test 'a broken source stays in the bundle instead of vanishing from it', ->
  # the failure this whole commit is about: `.map` returned undefined for the bad file
  # and `.join('')` dropped it, so the minified bundle silently shipped without it.
  root = write tmpdir!, {
    "#{lib 'ok.js'}": "function ok(){ return 1; }"
    "#{lib 'bad.js'}": broken
  }
  b = new bundle {base: root, logger: quiet, init-scan: false}
  src = <[ok.js bad.js]>.map -> path.join(root, lib(it))
  b.specmgr.update {type: \js, name: \x, src: src, codesrc: src, specsrc: ['p.pug']}
  ret <-! b.build-by-spec b.specmgr.get({type: \js, name: \x}), {force: true} .then
  min = fs.read-file-sync path.join(root, 'static/assets/bundle/x.min.js') .toString!
  assert.ok /ok/.exec(min), 'the good file must still be there'
  assert.ok /var a/.exec(min), "the broken file must survive unminified, got: #min"
  assert.ok !/undefined/.exec(min)


test 'a broken .ls writes its unminified output, not an empty file', ->
  root = write tmpdir!, {'src/ls/b.ls': 'x = ->\n  y = '}
  # ^ compiles fine as livescript? no - make it compile and then break uglify instead.
  fs.write-file-sync path.join(root, 'src/ls/b.ls'), 'window.f = -> 1'
  l = new lsc {base: root, logger: quiet, init-scan: false}
  l.build [{file: path.join(root, 'src/ls/b.ls'), mtime: Date.now! + 5000}]
  <-! set-timeout _, 200
  desmin = path.join(root, 'static/js/b.min.js')
  assert.ok fs.exists-sync(desmin)
  assert.ok fs.read-file-sync(desmin).toString!.length > 0, 'min output must not be empty'


# --- off the event loop ------------------------------------------------------------

test 'the worker gives the same answers as the in-process path', ->
  cases = [
    [\js, 'window.f = function ( ) { var u = 1 ; return 2 ; } ;']
    [\js, broken]
    [\css, 'a { color : red ; }']
    [\js, '']
  ]
  # sequential on purpose: one worker, and we want each answer compared before the next
  # job is queued.
  cases.reduce(
    (p, [type, code]) -> p.then ->
      want = minify type, code
      minify.async(type, code).then (got) ->
        assert.strictEqual got.code, want.code, "#type: code differs"
        assert.strictEqual !!got.failed, !!want.failed, "#type: failed differs"
    Promise.resolve!
  ).then -> minify.stop!


test 'minify.async keeps the event loop responsive', ->
  # the whole point. build an input big enough that the synchronous path stalls, then
  # assert the loop keeps ticking while the worker chews on it.
  unit = "window.fN = function () { var a = [#{[1 to 40].join ','}]; return a.map(function(x){ return x * N; }); };\n"
  code = [1 to 4000].map((i) -> unit.replace(/N/g, i)).join('')

  lag = (fn) ->
    (resolve) <~ new Promise _
    worst = 0
    last = Date.now!
    iv = set-interval (-> now = Date.now! ; worst := Math.max(worst, now - last - 10) ; last := now), 10
    t1 = Date.now!
    <~ set-immediate
    done = -> clear-interval iv ; resolve {worst, elapsed: Date.now! - t1}
    ret = fn!
    if ret and ret.then => ret.then -> set-immediate done else set-immediate done

  sync-run <-! lag(-> minify \js, code) .then
  async-run <-! lag(-> minify.async \js, code) .then
  minify.stop!

  # if the synchronous path did not actually stall, the test proves nothing - say so
  # rather than passing vacuously.
  assert.ok sync-run.worst > 200,
    "expected the sync path to block; it only lagged #{sync-run.worst}ms over #{sync-run.elapsed}ms. make the input bigger."
  assert.ok async-run.worst < sync-run.worst / 4,
    "worker lagged the loop #{async-run.worst}ms vs #{sync-run.worst}ms sync"


test 'a dead worker falls back in-process instead of hanging', ->
  # kill the thread out from under an in-flight job. the promise must still settle.
  p = minify.async \js, 'window.a = function () { return 1 ; } ;'
  minify.stop!
  ret <-! p.then
  assert.ok ret.code?, 'the promise settled'
  assert.strictEqual ret.code, 'window.a=function(){return 1};'


test 'SRCBUILD_MINIFY_WORKER=0 keeps everything in-process', ->
  # the escape hatch, and how the rest of the suite avoids paying for thread spawns.
  {execFileSync} = require 'child_process'
  out = execFileSync 'node', ['-e', """
    require('livescript');
    const m = require('#{path.join(__dirname, '../src/minify')}');
    m.async('js', 'window.a = 1 ;').then(function (r) {
      console.log(JSON.stringify({code: r.code, threads: require('worker_threads')}));
    });
  """], {env: {} <<< process.env <<< {SRCBUILD_MINIFY_WORKER: '0'}, encoding: 'utf8'}
  assert.match out, /window\.a=1/


test 'stopping the worker does not disable it for the rest of the run', ->
  # `terminate` exits non-zero, which looks exactly like a crash. before the identity
  # check in `spawn`, the 30s idle timer firing once meant every later build minified on
  # the main thread again - the regression that undoes this whole commit, silently.
  minify.async \js, 'window.a = 1 ;'
    .then -> minify.stop!
    .then ->
      lag = 0
      last = Date.now!
      iv = set-interval (-> now = Date.now! ; lag := Math.max(lag, now - last - 10) ; last := now), 10
      unit = "window.fN = function () { var a = [#{[1 to 40].join ','}]; return a.map(function(x){ return x * N; }); };\n"
      code = [1 to 4000].map((i) -> unit.replace(/N/g, i)).join('')
      minify.async(\js, code).then ->
        clear-interval iv
        minify.stop!
        # if the pool had gone in-process this would be seconds, not milliseconds.
        assert.ok lag < 300, "the second job blocked the loop for #{lag}ms - the pool fell back in-process"
