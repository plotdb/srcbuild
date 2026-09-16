require! <[fs path assert fs-extra]>
{test} = require 'node:test'
pugbuild = require '../src/ext/pug'
{quiet, tmpdir, write} = require './aux'

# fake an installed @plotdb/srcbuild. `npm` keeps lib.pug under dist/; `fedep publish -g`
# copies dist/ into the package root, so a github install has it one level up.
install = (root, layout) ->
  pkg = path.join(root, 'node_modules/@plotdb/srcbuild')
  dir = if layout == \flat => pkg else path.join(pkg, 'dist')
  fs-extra.ensure-dir-sync dir
  fs-extra.copy-sync path.join(__dirname, '../src/lib.pug'), path.join(dir, 'lib.pug')
  fs.write-file-sync path.join(pkg, 'package.json'),
    JSON.stringify {name: '@plotdb/srcbuild', version: '0.0.0', main: 'main.js'}
  return root

# unlike the fixtures in pug.ls this one needs a doctype: that is what makes the
# builder inject lib.pug at all.
# `+script` comes from lib.pug: if it was not injected, pug fails on an unknown mixin
# rather than quietly rendering an empty page.
fixture = 'doctype html\nhtml: body\n  +script(["/a.js"])\n'

page = (layout) ->
  root = install (write tmpdir!, {'src/pug/index.pug': fixture}), layout
  b = new pugbuild {base: root, logger: quiet, init-scan: false}
  src = path.join(root, 'src/pug/index.pug')
  b.build [{file: src, mtime: +fs.stat-sync(src).mtime}]
    .then -> b.map src, ''
    .then ({desh}) -> if fs.exists-sync(desh) => fs.read-file-sync(desh).toString! else null

test 'a doctype page builds against an npm-shaped install', ->
  page \npm .then (html) -> assert.ok html?, 'page must build'

test 'a doctype page builds when dist/ was flattened into the package root', ->
  # `fedep publish -g` produces this layout. before lib.pug was looked up both ways,
  # every doctype'd page failed to build against it - which is to say all of them.
  page \flat .then (html) -> assert.ok html?, 'page must build against a flattened install'

test 'lib.pug is actually injected, not merely resolvable', ->
  # the mixin resolving is the proof; the tag it emits is what we can assert on.
  page \flat .then (html) -> assert.ok ~html.index-of('/a.js'), "lib.pug must be injected: #html"
