require! <[fs path assert fs-extra]>
{test} = require 'node:test'
srcbuild = require '../src/main'
{quiet, tmpdir, write} = require './aux'


test 'watcher.ready resolves only after the first build has written its outputs', ->
  # the point of the signal: a host that listens before this settles is serving requests
  # during the heaviest build of the process's life. `@listen!` then `@watch` is what
  # servebase and its derived projects do today, which is why they see database
  # connection timeouts in the first few seconds and nowhere else.
  root = write tmpdir!, {
    'src/ls/a.ls': 'window.a = -> 1'
    'src/ls/b.ls': 'window.b = -> 2'
    'src/styl/c.styl': 'body\n  color red\n'
  }
  w = srcbuild.lsp {base: root, logger: quiet}
  assert.ok (w.ready and w.ready.then), 'lsp exposes a ready promise'
  <-! w.ready.then
  for f in <[static/js/a.js static/js/a.min.js static/js/b.min.js static/css/c.min.css]> =>
    assert.ok fs.exists-sync(path.join(root, f)), "#f should exist once ready resolved"
  w.watcher.close!


test 'ready does not reject when a source is broken', ->
  # one bad file must not stop a host that awaits this from starting.
  root = write tmpdir!, {
    'src/ls/ok.ls': 'window.ok = -> 1'
    'src/ls/bad.ls': 'window.bad = ->\n    (((\n'
  }
  w = srcbuild.lsp {base: root, logger: quiet}
  <-! w.ready.then
  assert.ok fs.exists-sync(path.join(root, 'static/js/ok.min.js')), 'the good file still built'
  w.watcher.close!
