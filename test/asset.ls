require! <[fs path assert]>
{test} = require 'node:test'
hashstore = require '../src/hashstore'
lsc = require '../src/ext/lsc'
stylus = require '../src/ext/stylus'
pugbuild = require '../src/ext/pug'
{quiet, tmpdir, write, touch} = require './aux'


test 'the hash goes before a trailing .min.<ext>', ->
  h = hashstore.hashed-name
  assert.equal h('vendor.min.js', 'abc'), 'vendor.abc.min.js'
  assert.equal h('vendor.js', 'abc'), 'vendor.abc.js'
  assert.equal h('index.min.css', 'abc'), 'index.abc.min.css'
  assert.equal h('a.b.min.js', 'abc'), 'a.b.abc.min.js'
  assert.equal h('index.html', 'abc'), 'index.abc.html'


test 'a compiled .ls gets a content-addressed twin', ->
  root = write tmpdir!, {'src/ls/site.ls': 'x = 1\n'}
  store = new hashstore {base: root, logger: quiet}
  b = new lsc {base: root, logger: quiet, init-scan: false, store: store}
  src = path.join(root, 'src/ls/site.ls')
  b.build [{file: src, mtime: +fs.stat-sync(src).mtime}]
    .then ->
      url = store.get '/js/site.min.js'
      assert.match url, /^\/js\/site\.[0-9a-f]{12}\.min\.js$/
      assert.ok fs.exists-sync(path.join(root, 'static', url))
      assert.ok store.get('/js/site.js'), 'the non-min output is hashed too'


test 'a compiled .styl gets a content-addressed twin', ->
  root = write tmpdir!, {'src/styl/index.styl': 'body\n  color red\n'}
  store = new hashstore {base: root, logger: quiet}
  b = new stylus {base: root, logger: quiet, init-scan: false, store: store}
  src = path.join(root, 'src/styl/index.styl')
  b.build [{file: src, mtime: +fs.stat-sync(src).mtime}]
  # stylus renders through a callback; give it a tick
  new Promise (res) -> setTimeout res, 300
    .then ->
      assert.match store.get('/css/index.min.css'), /^\/css\/index\.[0-9a-f]{12}\.min\.css$/


test 'a page that embeds a plain asset url is rebuilt when its hash moves', ->
  root = write tmpdir!, {
    'src/ls/site.ls': 'x = 1\n'
    # `+script` with a plain url goes through `asseturl`
    # `doctype` is what makes the builder inject lib.pug, where `+script` lives
    'src/pug/index.pug': 'doctype html\nhtml\n  body\n    +script(["/js/site.min.js"])\n'
  }
  store = new hashstore {base: root, logger: quiet}
  l = new lsc {base: root, logger: quiet, init-scan: false, store: store}
  p = new pugbuild {base: root, logger: quiet, init-scan: false, store: store}
  # the injected lib.pug is resolved against @base, so give the fixture one
  fs.mkdir-sync path.join(root, 'node_modules'), {recursive: true}
  fs.mkdir-sync path.join(root, 'node_modules/@plotdb/srcbuild/dist'), {recursive: true}
  fs.copy-file-sync path.join(__dirname, '../src/lib.pug'), path.join(root, 'node_modules/@plotdb/srcbuild/dist/lib.pug')
  fs.write-file-sync path.join(root, 'node_modules/@plotdb/srcbuild/package.json'), '{"name":"@plotdb/srcbuild","main":"dist/lib.pug"}'
  store.on \change, ({url}) -> p.invalidate-url url

  lssrc = path.join(root, 'src/ls/site.ls')
  pugsrc = path.join(root, 'src/pug/index.pug')
  html = -> fs.read-file-sync(path.join(root, 'static/index.html')).toString!
  srcof = -> (/<script[^>]*src="([^"]*)"/.exec(html!) or [])[1]

  Promise.resolve!
    .then -> l.build [{file: lssrc, mtime: +fs.stat-sync(lssrc).mtime}]
    .then -> p.adapter.change pugsrc
    .then ->
      u1 = srcof!
      assert.match u1, /^\/js\/site\.[0-9a-f]{12}\.min\.js$/, "got #u1"
      # the page has the hash baked in and site.ls is not in its pug dependency graph,
      # so only the store's change event can bring it back.
      fs.write-file-sync lssrc, 'x = 2\n'
      touch lssrc
      l.build [{file: lssrc, mtime: +fs.stat-sync(lssrc).mtime}] .then -> u1
    .then (u1) ->
      new Promise (res) -> setTimeout (-> res u1), 300
    .then (u1) ->
      assert.notEqual srcof!, u1, 'the page must follow the new hash'
      assert.match srcof!, /^\/js\/site\.[0-9a-f]{12}\.min\.js$/


test 'a wiped manifest is re-adopted from the surviving outputs', ->
  root = write tmpdir!, {'src/ls/site.ls': 'x = 1\n'}
  store = new hashstore {base: root, logger: quiet}
  b = new lsc {base: root, logger: quiet, init-scan: false, store: store}
  src = path.join(root, 'src/ls/site.ls')
  b.build [{file: src, mtime: +fs.stat-sync(src).mtime}]
    .then ->
      url = store.get '/js/site.min.js'
      # a fresh store with no manifest, but the outputs are still newer than the source
      # so nothing would rebuild - it must adopt them instead of falling back forever.
      fs.rm-sync path.join(root, '.bundle-dep'), {recursive: true, force: true}
      s2 = new hashstore {base: root, logger: quiet}
      b2 = new lsc {base: root, logger: quiet, init-scan: false, store: s2}
      b2.build [{file: src, mtime: +fs.stat-sync(src).mtime}] .then -> url
    .then (url) ->
      s3 = new hashstore {base: root, logger: quiet}
      assert.equal s3.get('/js/site.min.js'), url


test 'query mode addresses content without writing extra files', ->
  root = write tmpdir!, {'src/ls/site.ls': 'x = 1\n'}
  store = new hashstore {base: root, logger: quiet, mode: \query}
  b = new lsc {base: root, logger: quiet, init-scan: false, store: store}
  src = path.join(root, 'src/ls/site.ls')
  before = null
  b.build [{file: src, mtime: +fs.stat-sync(src).mtime}]
    .then ->
      url = store.get '/js/site.min.js'
      assert.match url, /^\/js\/site\.min\.js\?v=[0-9a-f]{12}$/
      # nothing accumulates: the plain file is the only file
      before := fs.readdir-sync(path.join(root, 'static/js')).sort!
      assert.deep-equal before, ['site.js', 'site.min.js']
      fs.write-file-sync src, 'x = 2\n'
      touch src
      b.build [{file: src, mtime: +fs.stat-sync(src).mtime}] .then -> url
    .then (url) ->
      assert.notEqual store.get('/js/site.min.js'), url, 'the query follows the content'
      assert.deep-equal fs.readdir-sync(path.join(root, 'static/js')).sort!, before,
        'still no extra files after a rebuild'


test 'hashing is opt in', ->
  root = write tmpdir!, {'src/ls/site.ls': 'x = 1\n'}
  b = new lsc {base: root, logger: quiet, init-scan: false}   # no store
  src = path.join(root, 'src/ls/site.ls')
  b.build [{file: src, mtime: +fs.stat-sync(src).mtime}]
    .then ->
      assert.deep-equal fs.readdir-sync(path.join(root, 'static/js')).sort!,
        ['site.js', 'site.min.js']
      assert.equal fs.exists-sync(path.join(root, '.bundle-dep')), false,
        'no manifest is written when hashing is off'


test 'the plain name is always current, whatever the mode', ->
  # this is what the nginx fallback and any already-deployed html land on.
  <[filename query]>.map (mode) ->
    root = write tmpdir!, {'src/ls/site.ls': 'x = 1\n'}
    store = new hashstore {base: root, logger: quiet, mode: mode}
    b = new lsc {base: root, logger: quiet, init-scan: false, store: store}
    src = path.join(root, 'src/ls/site.ls')
    b.build [{file: src, mtime: +fs.stat-sync(src).mtime}]
      .then ->
        fs.write-file-sync src, 'zzz = 9\n'
        touch src
        b.build [{file: src, mtime: +fs.stat-sync(src).mtime}]
      .then ->
        plain = fs.read-file-sync(path.join(root, 'static/js/site.min.js')).toString!
        assert.match plain, /zzz/, "#mode: plain name must hold the latest build"
  |> (ps) -> Promise.all ps


test 'the page index survives a restart that rebuilds nothing', ->
  # refs are only recorded while a page renders. a warm start renders nothing, so a
  # memory-only index is empty exactly when the first edit after a restart needs it -
  # the hash moves, and no page is rebuilt to follow it.
  root = write tmpdir!, {
    'src/ls/site.ls': 'x = 1\n'
    'src/pug/index.pug': 'doctype html\nhtml\n  body\n    +script(["/js/site.min.js"])\n'
  }
  fs.mkdir-sync path.join(root, 'node_modules/@plotdb/srcbuild/dist'), {recursive: true}
  fs.copy-file-sync path.join(__dirname, '../src/lib.pug'), path.join(root, 'node_modules/@plotdb/srcbuild/dist/lib.pug')
  fs.write-file-sync path.join(root, 'node_modules/@plotdb/srcbuild/package.json'), '{"name":"@plotdb/srcbuild","main":"dist/lib.pug"}'

  lssrc = path.join(root, 'src/ls/site.ls')
  pugsrc = path.join(root, 'src/pug/index.pug')
  srcof = -> (/<script[^>]*src="([^"]*)"/.exec(fs.read-file-sync(path.join(root, 'static/index.html')).toString!) or [])[1]

  s1 = new hashstore {base: root, logger: quiet}
  l1 = new lsc {base: root, logger: quiet, init-scan: false, store: s1}
  p1 = new pugbuild {base: root, logger: quiet, init-scan: false, store: s1}

  Promise.resolve!
    .then -> l1.build [{file: lssrc, mtime: +fs.stat-sync(lssrc).mtime}]
    .then -> p1.adapter.change pugsrc
    .then ->
      assert.match srcof!, /^\/js\/site\.[0-9a-f]{12}\.min\.js$/
      new Promise (res) -> setImmediate res      # the deferred ref flush
    .then ->
      assert.deep-equal (new hashstore {base: root, logger: quiet}).refs-of('/js/site.min.js'),
        [pugsrc], 'the index must be on disk, not only in memory'
      # restart: fresh instances, nothing to rebuild, so nothing renders.
      s2 = new hashstore {base: root, logger: quiet}
      l2 = new lsc {base: root, logger: quiet, init-scan: false, store: s2}
      p2 = new pugbuild {base: root, logger: quiet, init-scan: false, store: s2}
      s2.on \change, ({url}) -> p2.invalidate-url url
      u1 = srcof!
      fs.write-file-sync lssrc, 'x = 2\n'
      touch lssrc
      l2.build [{file: lssrc, mtime: +fs.stat-sync(lssrc).mtime}] .then -> u1
    .then (u1) -> new Promise (res) -> setTimeout (-> res u1), 300
    .then (u1) ->
      assert.notEqual srcof!, u1, 'the page must follow the new hash after a warm start'
      assert.match srcof!, /^\/js\/site\.[0-9a-f]{12}\.min\.js$/


# a fixture frontend root with its own node_modules/@plotdb/srcbuild/dist/lib.pug,
# which is how pug resolves the file it injects into every doctype'd page.
mkroot = (libpug) ->
  root = write tmpdir!, {
    'src/ls/site.ls': 'x = 1\n'
    'src/pug/index.pug': 'doctype html\nhtml\n  body\n    +script(["/js/site.min.js"])\n'
  }
  d = path.join(root, 'node_modules/@plotdb/srcbuild/dist')
  fs.mkdir-sync d, {recursive: true}
  fs.write-file-sync path.join(root, 'node_modules/@plotdb/srcbuild/package.json'),
    '{"name":"@plotdb/srcbuild","version":"0.0.1","main":"dist/lib.pug"}'
  fs.write-file-sync path.join(d, 'lib.pug'), libpug
  return root


test 'the shipped lib.pug reaches the page ( asseturl is actually called )', ->
  # this is the regression this file exists for: `asseturl` lives in lib.pug, which is
  # injected by path. if the injection breaks, or the mixin stops calling it, every page
  # keeps building and content addressing is simply absent - with no error anywhere.
  root = mkroot fs.read-file-sync(path.join(__dirname, '../src/lib.pug')).toString!
  store = new hashstore {base: root, logger: quiet}
  l = new lsc {base: root, logger: quiet, init-scan: false, store: store}
  p = new pugbuild {base: root, logger: quiet, init-scan: false, store: store}
  seen = []
  orig = p.extapi.asseturl
  p.extapi.asseturl = (url, src) -> seen.push url; orig url, src

  src = path.join(root, 'src/ls/site.ls')
  Promise.resolve!
    .then -> l.build [{file: src, mtime: +fs.stat-sync(src).mtime}]
    .then -> p.build [{file: path.join(root, 'src/pug/index.pug'), mtime: Date.now!}]
    .then ->
      assert.ok ('/js/site.min.js' in seen), "asseturl was never called: #{JSON.stringify seen}"
      html = fs.read-file-sync(path.join(root, 'static/index.html')).toString!
      assert.match html, /src="\/js\/site\.[0-9a-f]{12}\.min\.js"/, 'and its result reached the html'


test 'a stale lib.pug in the frontend root is reported', ->
  # exactly the failure this check exists for: an old srcbuild under <base>/node_modules
  # shadows the running one, so the injected lib.pug has no `asseturl` at all.
  warned = []
  logger = {info: (->), error: (->), warn: (...a) -> warned.push a.join(' ')}
  root = mkroot '//- module\nmixin script(os,cfg)\n  each o in os\n    script(src=o)\n'
  new pugbuild {base: root, logger: logger, init-scan: false}
  assert.ok warned.length, 'a differing lib.pug must be reported'
  assert.match warned.join('\n'), /injected lib\.pug is not the one shipped/
  assert.match warned.join('\n'), /node_modules\/@plotdb\/srcbuild\/dist\/lib\.pug/, 'names the injected copy'


test 'an identical lib.pug is silent', ->
  warned = []
  logger = {info: (->), error: (->), warn: (...a) -> warned.push a.join(' ')}
  root = mkroot fs.read-file-sync(path.join(__dirname, '../src/lib.pug')).toString!
  new pugbuild {base: root, logger: logger, init-scan: false}
  assert.deep-equal warned, [], 'no warning when the copies agree'
