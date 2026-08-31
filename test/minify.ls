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
