require! <[fs path assert]>
{test} = require 'node:test'
pugbuild = require '../src/ext/pug'
{quiet, tmpdir, write, touch} = require './aux'

# note: fixtures avoid `doctype`, which makes the builder inject srcbuild's own lib.pug
# and would need a resolvable @plotdb/srcbuild inside the fixture tree.
mk = (root) -> new pugbuild {base: root, logger: quiet, init-scan: false}


test 'a missing static html is regenerated even when the precompiled view is fresh', ->
  root = write tmpdir!, {'src/pug/index.pug': 'p hello\n'}
  b = mk root
  src = path.join(root, 'src/pug/index.pug')
  {desh, desv} = b.map src, ''

  Promise.resolve!
    .then -> b.build [{file: src, mtime: +fs.stat-sync(src).mtime}]
    .then ->
      assert.ok fs.exists-sync(desv), 'view js built'
      assert.ok fs.exists-sync(desh), 'static html built'
      # someone wiped static/ but .view/ survived. the old guard only looked at desv,
      # so the page was never regenerated.
      fs.unlink-sync desh
      b.build [{file: src, mtime: +fs.stat-sync(src).mtime}]
    .then ->
      assert.ok fs.exists-sync(desh), 'static html must come back'


test 'a `//- view` page is not held back by its missing static html', ->
  root = write tmpdir!, {'src/pug/v.pug': '//- view\np hi\n'}
  b = mk root
  src = path.join(root, 'src/pug/v.pug')
  {desh, desv} = b.map src, ''
  Promise.resolve!
    .then -> b.build [{file: src, mtime: +fs.stat-sync(src).mtime}]
    .then ->
      assert.ok fs.exists-sync(desv)
      assert.equal fs.exists-sync(desh), false, 'a view-only page produces no html'
