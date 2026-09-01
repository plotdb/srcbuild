require! <[fs path assert fs-extra]>
{test} = require 'node:test'
srcbuild = require '../src/main'
asset = require '../src/ext/asset'
{quiet, tmpdir, write} = require './aux'

raw = (root, opt = {}) ->
  new asset {base: root, logger: quiet, srcdir: 'src/raw', desdir: 'static', ext: '*'} <<< opt

des = (root, ...p) -> path.join.apply path, [root, 'static'] ++ p
src = (root, ...p) -> path.join.apply path, [root, 'src/raw'] ++ p
build1 = (b, f) -> b.build [{file: f, mtime: +fs.stat-sync(f).mtime}]


test 'a raw tree lands in the document root verbatim, whatever the extension', ->
  # the whole point of dropping the whitelist: nobody has to remember to add `.ico`,
  # `.txt`, `.webmanifest`, `.woff2` ... to a list before the file will ship.
  files = <[favicon.ico robots.txt site.webmanifest assets/img/a.png assets/custom/b.svg]>
  root = write tmpdir!, {["src/raw/#f", "#f\n"] for f in files}
  b = raw root
  <-! b.adapter.ready.then
  for f in files =>
    assert.ok fs.exists-sync(des(root, f)), "#f should have been copied"
    assert.equal fs.read-file-sync(des(root, f)).toString!, "#f\n", "#f must be byte-identical"


test 'the extension whitelist still works, and is still the default', ->
  # the old mode is what every existing project is configured for. `src/pug/**.png ->
  # static/**` in servebase, `src/assets -> static/assets` by default here.
  root = write tmpdir!, {'src/assets/a.png': 'PNG', 'src/assets/a.txt': 'TXT'}
  b = new asset {base: root, logger: quiet}
  <-! b.adapter.ready.then
  assert.ok fs.exists-sync(path.join(root, 'static/assets/a.png')), 'a whitelisted ext is copied'
  assert.equal fs.exists-sync(path.join(root, 'static/assets/a.txt')), false,
    'a non-whitelisted ext is not'


test 'junk never reaches the document root', ->
  # `ext: '*'` says yes to everything, so the ignore list is the only thing standing
  # between a mac and a deployed .DS_Store.
  root = write tmpdir!, {
    'src/raw/.DS_Store': 'junk'
    'src/raw/Thumbs.db': 'junk'
    'src/raw/notes.txt~': 'junk'
    'src/raw/keep.txt': 'keep'
  }
  b = raw root
  <-! b.adapter.ready.then
  assert.ok fs.exists-sync(des(root, 'keep.txt')), 'a real file still ships'
  for f in <[.DS_Store Thumbs.db notes.txt~]> =>
    assert.equal fs.exists-sync(des(root, f)), false, "#f must not be copied"


test 'a whitelist-free builder does not claim outputs it has no source for', ->
  # `watch.demand` takes the first adapter whose `resolve` answers. this builder's
  # desdir is the entire document root, so answering for everything would hijack every
  # pug page and every compiled .ls, and send them to a src/raw path that is not there.
  root = write tmpdir!, {'src/raw/favicon.ico': 'ICO'}
  b = raw root, {init-scan: false}
  assert.equal b.resolve(des(root, 'favicon.ico')), src(root, 'favicon.ico'),
    'it does claim what it owns'
  assert.equal b.resolve(des(root, 'index.html')), null, "pug's page is not its business"
  assert.equal b.resolve(des(root, 'js/site.min.js')), null, "nor is lsc's output"


test 'directories are not build targets', ->
  # with a whitelist a directory almost never matched, so the initial scan got away with
  # falling through to `is-supported` after recursing into it. `ext: '*'` says yes to
  # every directory, which would hand `copy-sync` a whole subtree and bypass the
  # per-file freshness check.
  root = write tmpdir!, {'src/raw/img/a.png': 'PNG'}
  fs-extra.ensure-dir-sync src(root, 'empty')
  b = raw root
  <-! b.adapter.ready.then
  assert.ok fs.exists-sync(des(root, 'img/a.png')), 'files under a directory still ship'
  assert.equal fs.exists-sync(des(root, 'empty')), false,
    'an empty directory is not an output'


test 'deleting sources purges their copies, all of them', ->
  # a directory removal arrives as one batch. the first entry already gone used to
  # abandon the rest of the batch, leaving the others deployed forever.
  root = write tmpdir!, {'src/raw/a.txt': 'A', 'src/raw/b.txt': 'B'}
  b = raw root, {init-scan: false}
  for f in <[a.txt b.txt]> => build1 b, src(root, f)
  assert.ok fs.exists-sync(des(root, 'b.txt'))
  # a.txt's copy is already gone - a half-finished earlier purge, a manual rm, anything.
  fs.unlink-sync des(root, 'a.txt')
  fs.unlink-sync src(root, 'a.txt')
  fs.unlink-sync src(root, 'b.txt')
  b.adapter.unlink [src(root, 'a.txt'), src(root, 'b.txt')]
  assert.equal fs.exists-sync(des(root, 'b.txt')), false,
    'the rest of the batch must still be purged'


test 'overriding `asset` does not take `raw` down with it', ->
  # this is why raw is its own option and not another entry in `asset`. servebase points
  # `asset` at src/pug, and every derived project inherits that override - if raw were a
  # default entry in the same list, all of them would silently lose it.
  root = write tmpdir!, {
    'src/pug/logo.png': 'PNG'
    'src/raw/robots.txt': 'User-agent: *\n'
  }
  w = srcbuild.lsp {base: root, logger: quiet, asset: {srcdir: 'src/pug', desdir: 'static'}}
  <-! w.ready.then
  w.watcher.close!
  assert.ok fs.exists-sync(path.join(root, 'static/logo.png')), 'the override still applies'
  assert.ok fs.exists-sync(path.join(root, 'static/robots.txt')), 'and raw survives it'


test 'raw can be turned off', ->
  root = write tmpdir!, {'src/raw/robots.txt': 'x'}
  w = srcbuild.lsp {base: root, logger: quiet, raw: false}
  <-! w.ready.then
  w.watcher.close!
  assert.equal fs.exists-sync(path.join(root, 'static/robots.txt')), false


test 'raw is wired up by default, with no configuration at all', ->
  root = write tmpdir!, {'src/raw/favicon.ico': 'ICO', 'src/raw/assets/img/a.png': 'PNG'}
  w = srcbuild.lsp {base: root, logger: quiet}
  <-! w.ready.then
  w.watcher.close!
  assert.ok fs.exists-sync(path.join(root, 'static/favicon.ico'))
  assert.ok fs.exists-sync(path.join(root, 'static/assets/img/a.png'))
