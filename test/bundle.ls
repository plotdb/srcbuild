require! <[fs path assert fs-extra]>
{test} = require 'node:test'
bundle = require '../src/ext/bundle'
{quiet, tmpdir, write, touch} = require './aux'

# a bundler over `root`, with `static/` as both src and des ( the defaults ).
mk = (root, cfg = null) ->
  new bundle {base: root, logger: quiet, init-scan: false, config: cfg}

lib = (n) -> "static/assets/lib/#n"
des = (root, n) -> path.join(root, 'static/assets/bundle', n)


test 'unlink actually removes a link ( Set has `delete`, not `remove` )', ->
  root = tmpdir!
  b = mk root
  b.specmgr.add {type: \js, name: \x, codesrc: ['a.js'], specsrc: ['p.pug']}, {init: true}
  s = b.specmgr.get {type: \js, name: \x}
  assert.ok b.specmgr.has-code 'a.js'
  # this used to throw TypeError: s.remove is not a function
  b.specmgr.unlink {codesrc: 'a.js', spec: s}
  assert.equal b.specmgr.has-code('a.js'), false


test 'update drops the links of sources the spec no longer uses', ->
  root = tmpdir!
  b = mk root
  key = {type: \js, name: \x}
  b.specmgr.update {} <<< key <<< {src: ['a.js', 'b.js'], codesrc: ['a.js', 'b.js'], specsrc: ['p.pug']}
  assert.ok b.specmgr.has-code 'b.js'
  b.specmgr.update {} <<< key <<< {src: ['a.js'], codesrc: ['a.js'], specsrc: ['p.pug']}
  assert.ok b.specmgr.has-code('a.js'), 'a.js is still bundled'
  # old behaviour: b.js kept triggering this bundle forever.
  assert.equal b.specmgr.has-code('b.js'), false, 'b.js must no longer trigger js/x'


test 'del-specsrc drops an orphaned spec and its .dep cache', ->
  root = tmpdir!
  b = mk root
  b.specmgr.update {type: \js, name: \x, src: ['a.js'], codesrc: ['a.js'], specsrc: ['p.pug']}
  s = b.specmgr.get {type: \js, name: \x}
  fn = s.cache-fn!
  fs-extra.ensure-dir-sync path.dirname(fn)
  fs.write-file-sync fn, JSON.stringify(s.to-object!)

  # this used to throw TypeError: spec.unlink is not a function
  b.del-specsrc 'p.pug'

  assert.equal b.specmgr.get({type: \js, name: \x}), void, 'spec must be gone'
  assert.equal b.specmgr.has-code('a.js'), false, 'its codesrc links must be gone'
  assert.equal fs.exists-sync(fn), false, '.dep must be deleted, or load-caches revives it'


test 'del-specsrc keeps a spec that another page still declares', ->
  root = tmpdir!
  b = mk root
  b.specmgr.update {type: \js, name: \x, src: ['a.js'], codesrc: ['a.js'], specsrc: ['p.pug']}
  b.specmgr.update {type: \js, name: \x, src: ['a.js'], codesrc: ['a.js'], specsrc: ['q.pug']}
  b.del-specsrc 'p.pug'
  assert.ok b.specmgr.get({type: \js, name: \x}), 'q.pug still declares it'
  assert.ok b.specmgr.has-code 'a.js'


test 'build-by-spec is a no-op when the output is already fresh', ->
  root = tmpdir!
  write root, {"#{lib 'a/main/index.min.js'}": 'AAA;', "#{lib 'b/main/index.min.js'}": 'BBB;'}
  b = mk root
  src = [lib('a/main/index.min.js'), lib('b/main/index.min.js')].map -> path.join(root, it)
  b.specmgr.update {type: \js, name: \v, src: src, codesrc: src, specsrc: ['p.pug']}
  spec = b.specmgr.get {type: \js, name: \v}
  out = des root, 'v.min.js'

  Promise.resolve!
    .then -> b.build-by-spec spec
    .then ->
      assert.ok fs.exists-sync(out)
      # old behaviour: every event rewrote the file unconditionally. that has to stop
      # before a bundle rebuild is ever allowed to trigger a page rebuild.
      b.build-by-spec spec
    .then (ret) ->
      assert.ok ret.skipped, 'unchanged sources must not rebuild the bundle'
      # a real source change must still get through
      fs.write-file-sync path.join(root, lib 'a/main/index.min.js'), 'CCC;'
      touch path.join(root, lib 'a/main/index.min.js')
      b.build-by-spec spec
    .then (ret) ->
      assert.equal ret.skipped, void, 'a newer source must rebuild'
      assert.match fs.read-file-sync(out).toString!, /CCC;/
      # and so must a change of the source *list*, which mtimes cannot see
      b.build-by-spec spec, {force: true}
    .then (ret) -> assert.equal ret.skipped, void, 'force must always rebuild'


test 'the .min filename is derived from the end of the path', ->
  root = tmpdir!
  # `three.js` in the middle of the path used to make the string replace produce
  # `three.min.js/main/index.js`, silently falling back to re-minifying the source.
  write root, {
    "#{lib 'three.js/main/index.js'}": 'var raw = 1;'
    "#{lib 'three.js/main/index.min.js'}": 'var min=1;'
  }
  b = mk root
  src = [path.join(root, lib 'three.js/main/index.min.js')]
  b.specmgr.update {type: \js, name: \t, src: src, codesrc: src, specsrc: ['p.pug']}
  b.build-by-spec b.specmgr.get({type: \js, name: \t})
    .then ->
      assert.equal fs.read-file-sync(des(root, 't.min.js')).toString!, 'var min=1;'
      assert.equal fs.read-file-sync(des(root, 't.js')).toString!, 'var raw = 1;'


test 'a bundle.json change does not swallow the rest of the batch', ->
  root = tmpdir!
  write root, {
    "#{lib 'a/main/index.min.js'}": 'AAA;'
    'bundle.json': JSON.stringify({js: {v: [lib 'a/main/index.min.js']}})
  }
  b = new bundle {
    base: root, logger: quiet, init-scan: false
    config-file: 'bundle.json', relative-path: true
  }
  touched = []
  b.specmgr.touch-code = (files, opt) -> touched := files.map -> it.file
  b.build [{file: path.join(root, 'bundle.json'), mtime: 1}, {file: path.join(root, lib 'a/main/index.min.js'), mtime: 1}]
  # old behaviour: `return @load-cfg!` dropped the source file silently.
  assert.deep-equal touched, [path.join(root, lib 'a/main/index.min.js')]


test 'a pending spec flush is not cancelled by another bundler', ->
  # `clear-dirty` used to be a prototype-level `debounce(...)`, whose timer lives in a
  # single closure. with `lsp {base: [web, alt]}` there is one bundler per base, so one
  # manager's pending flush was cancelled by the other's and never ran.
  [a, b] = [mk(tmpdir!), mk(tmpdir!)]
  a.specmgr.update {type: \js, name: \x, src: ['a.js'], codesrc: ['a.js'], specsrc: ['p.pug']}
  b.specmgr.update {type: \js, name: \y, src: ['b.js'], codesrc: ['b.js'], specsrc: ['q.pug']}
  new Promise (res) -> setTimeout res, 1600
    .then ->
      assert.equal a.specmgr._dirty.size, 0, "the first bundler's flush must still run"
      assert.equal b.specmgr._dirty.size, 0, "the second bundler's flush must run"



