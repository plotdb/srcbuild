require! <[fs path assert fs-extra]>
{test} = require 'node:test'
bundle = require '../src/ext/bundle'
pugbuild = require '../src/ext/pug'
hashstore = require '../src/hashstore'
{quiet, tmpdir, write, touch} = require './aux'

lib = (n) -> "static/assets/lib/#n"
bundledir = (root) -> path.join(root, 'static/assets/bundle')

# a bundler with one js spec built from `contents` ( name -> code, under static/assets/lib ).
setup = (contents, opt = {}) ->
  root = write tmpdir!, contents
  store = new hashstore {base: root, logger: quiet} <<< opt
  b = new bundle {base: root, logger: quiet, init-scan: false, store: store}
  src = [k for k of contents].map -> path.join(root, it)
  b.specmgr.update {type: \js, name: \vendor, src: src, codesrc: src, specsrc: ['p.pug']}
  return {root, b, store, spec: b.specmgr.get({type: \js, name: \vendor}), src}


test 'a built bundle gets a content-addressed copy and a manifest entry', ->
  {root, b, spec} = setup {"#{lib 'a/main/index.min.js'}": 'AAA;'}
  assert.equal b.manifest-url({type: \js, name: \vendor}), null, 'nothing to point at yet'
  b.build-by-spec spec
    .then ->
      url = b.manifest-url {type: \js, name: \vendor}
      assert.match url, /^\/assets\/bundle\/vendor\.[0-9a-f]{12}\.min\.js$/
      assert.ok fs.exists-sync(path.join(root, 'static', url)), 'the hashed file exists'
      # the plain name has to stay: already deployed html points at it, and it is the
      # fallback for a page rendered before the bundle was built.
      assert.ok fs.exists-sync(path.join(bundledir(root), 'vendor.min.js'))
      # min and non-min are hashed separately
      raw = b.manifest-url {type: \js, name: \vendor, min: false}
      assert.match raw, /^\/assets\/bundle\/vendor\.[0-9a-f]{12}\.js$/
      assert.notEqual raw, url


test 'the url follows the content, and only the content', ->
  {root, b, store, spec, src} = setup {"#{lib 'a/main/index.min.js'}": 'AAA;'}
  seen = []
  store.on \change, (e) -> if /vendor\.[0-9a-f]{12}\.min\.js/.exec(e.hashed) => seen.push e
  Promise.resolve!
    .then -> b.build-by-spec spec
    .then ->
      u1 = b.manifest-url {type: \js, name: \vendor}
      assert.equal seen.length, 1, 'first build announces its url'
      assert.equal seen.0.url, '/assets/bundle/vendor.min.js', 'announced by its plain url'
      # a rebuild with identical content must be silent, otherwise
      # page -> bundle -> page never settles.
      touch src.0
      b.build-by-spec spec, {force: true} .then -> u1
    .then (u1) ->
      assert.equal b.manifest-url({type: \js, name: \vendor}), u1, 'same content, same url'
      assert.equal seen.length, 1, 'no url-change for an identical rebuild'
      fs.write-file-sync src.0, 'BBB;'
      b.build-by-spec spec, {force: true} .then -> u1
    .then (u1) ->
      assert.notEqual b.manifest-url({type: \js, name: \vendor}), u1, 'new content, new url'
      assert.equal seen.length, 2


test 'old generations are reaped once they are both surplus and old', ->
  # keep-days 0 makes every previous generation immediately eligible, so this exercises
  # the count limit on its own.
  {root, b, spec, src} = setup {"#{lib 'a/main/index.min.js'}": 'v0;'}, {keep: 2, keep-days: 0}
  urls = []
  step = (i) ->
    fs.write-file-sync src.0, "v#i;"
    b.build-by-spec spec, {force: true}
      .then -> urls.push b.manifest-url({type: \js, name: \vendor})
  Promise.resolve!
    .then -> step 1 .then -> step 2 .then -> step 3
    .then ->
      hashed = fs.readdir-sync(bundledir root).filter -> /^vendor\.[0-9a-f]{12}\./.exec it
      # 2 generations x ( min + non-min )
      assert.equal hashed.length, 4, "kept: #{hashed.join ' '}"
      # the page that was rendered one build ago still resolves ...
      assert.ok fs.exists-sync(path.join(root, 'static', urls[* - 2]))
      assert.ok fs.exists-sync(path.join(root, 'static', urls[* - 1]))
      # ... but the one before that is gone.
      assert.equal fs.exists-sync(path.join(root, 'static', urls.0)), false


test 'a surplus generation is still kept while it is young', ->
  # the real risk is how long a browser tab can stay open, not how many times we have
  # rebuilt since. a generation past `keep` but younger than `keep-days` must survive.
  {root, b, spec, src} = setup {"#{lib 'a/main/index.min.js'}": 'v0;'}, {keep: 1, keep-days: 30}
  urls = []
  step = (i) ->
    fs.write-file-sync src.0, "v#i;"
    b.build-by-spec spec, {force: true}
      .then -> urls.push b.manifest-url({type: \js, name: \vendor})
  Promise.resolve!
    .then -> step 1 .then -> step 2 .then -> step 3
    .then ->
      urls.map (u) ->
        assert.ok fs.exists-sync(path.join(root, 'static', u)), "#u must still resolve"


test 'the manifest survives a restart', ->
  {root, b, spec} = setup {"#{lib 'a/main/index.min.js'}": 'AAA;'}
  b.build-by-spec spec
    .then ->
      url = b.manifest-url {type: \js, name: \vendor}
      # the debounced write has to land before another process can read it
      new Promise (res) -> setTimeout res, 500
        .then ->
          s2 = new hashstore {base: root, logger: quiet}
          b2 = new bundle {base: root, logger: quiet, init-scan: false, store: s2}
          assert.equal b2.manifest-url({type: \js, name: \vendor}), url


test 'the bundle filter emits the hashed url once it is known', ->
  root = write tmpdir!, {"#{lib 'a/main/index.min.js'}": 'AAA;'}
  store = new hashstore {base: root, logger: quiet}
  b = new bundle {base: root, logger: quiet, init-scan: false, store: store}
  p = new pugbuild {base: root, logger: quiet, init-scan: false, bundler: b, store: store}
  render = ->
    pug = require 'pug'
    pug.render(
      """
      div
        :bundle(options=[{type: "js", name: "vendor", files: ["#{path.join root, lib 'a/main/index.min.js'}"]}])
      """
      {filename: path.join(root, 'src/pug/x.pug'), doctype: \html} <<< p.get-extapi!
    )

  # before anything is built there is no hash to use: the plain name, which nginx has
  # to serve as no-cache.
  assert.match render!, /src="\/assets\/bundle\/vendor\.min\.js"/
  b.build-by-spec b.specmgr.get({type: \js, name: \vendor})
    .then -> assert.match render!, /src="\/assets\/bundle\/vendor\.[0-9a-f]{12}\.min\.js"/


test 'a pug builder with no bundler reads the manifest off disk', ->
  # this is the express view engine: it constructs its own pug builder, and the
  # bundles may well have been produced by a different process.
  root = write tmpdir!, {"#{lib 'a/main/index.min.js'}": 'AAA;'}
  store = new hashstore {base: root, logger: quiet}
  b = new bundle {base: root, logger: quiet, init-scan: false, store: store}
  b.specmgr.update do
    {type: \js, name: \vendor, specsrc: ['p.pug']}
      <<< {src: [path.join root, lib 'a/main/index.min.js'], codesrc: [path.join root, lib 'a/main/index.min.js']}
  viewside = new pugbuild {base: root, logger: quiet, init-scan: false}
  assert.equal viewside.bundle-url({type: \js, name: \vendor}), null

  b.build-by-spec b.specmgr.get({type: \js, name: \vendor})
    .then -> new Promise (res) -> setTimeout res, 500
    .then ->
      assert.equal viewside.bundle-url({type: \js, name: \vendor}),
        b.manifest-url({type: \js, name: \vendor})


test 'deleting the last page that declares a bundle removes its output too', ->
  {root, b, spec} = setup {"#{lib 'a/main/index.min.js'}": 'AAA;'}
  b.build-by-spec spec
    .then ->
      url = b.manifest-url {type: \js, name: \vendor}
      files = fs.readdir-sync bundledir root
      assert.ok files.length > 0
      b.del-specsrc 'p.pug'
      new Promise (res) -> setTimeout res, 500
        .then -> url
    .then (url) ->
      assert.equal b.manifest-url({type: \js, name: \vendor}), null, 'manifest entry gone'
      assert.deep-equal fs.readdir-sync(bundledir root), [], 'no orphan files left'
      # and the manifest on disk agrees, so a restart does not resurrect it
      m = JSON.parse fs.read-file-sync(path.join(root, '.bundle-dep/manifest.json')).toString!
      assert.equal m['js/vendor'], void


test 'deleting the last page that declares a bundle removes its output too', ->
  {root, b, spec} = setup {"#{lib 'a/main/index.min.js'}": 'AAA;'}
  b.build-by-spec spec
    .then ->
      url = b.manifest-url {type: \js, name: \vendor}
      files = fs.readdir-sync bundledir root
      assert.ok files.length > 0
      b.del-specsrc 'p.pug'
      new Promise (res) -> setTimeout res, 500
        .then -> url
    .then (url) ->
      assert.equal b.manifest-url({type: \js, name: \vendor}), null, 'manifest entry gone'
      assert.deep-equal fs.readdir-sync(bundledir root), [], 'no orphan files left'
      # and the manifest on disk agrees, so a restart does not resurrect it
      m = JSON.parse fs.read-file-sync(path.join(root, '.bundle-dep/manifest.json')).toString!
      assert.equal m['js/vendor'], void


test 'block dependencies are re-resolved on every build', ->
  root = write tmpdir!, {'static/block/a/main/index.html': '<div>a</div>'}
  store = new hashstore {base: root, logger: quiet}
  # a stand-in block manager whose dependency answer changes over time, the way a real
  # one does when a block's html gains a dependency.
  deps = {js: [], css: [], block: []}
  mgr = {
    get-url: (d) -> path.join(root, "static/block/#{d.name}/#{d.version or \main}/#{d.path or 'index.html'}")
    bundle: -> Promise.resolve {code: '<div>a</div>', deps: deps}
  }
  b = new bundle {base: root, logger: quiet, init-scan: false, store: store, manager: mgr}
  b.specmgr.update do
    {type: \block, name: \page, specsrc: ['p.pug']}
      <<< {src: [{name: 'a'}], codesrc: [mgr.get-url({name: 'a'})], deps: []}
  spec = b.specmgr.get {type: \block, name: \page}
  newdep = mgr.get-url {name: 'b'}

  b.build-by-spec spec, {force: true}
    .then ->
      assert.equal b.specmgr.has-code(newdep), false
      # block a now depends on block b
      deps.block = [{name: 'b'}]
      b.build-by-spec spec, {force: true}
    .then ->
      # without the re-resolve, editing block b would not rebuild this bundle until the
      # pug file declaring it happened to be analysed again.
      assert.ok b.specmgr.has-code(newdep), 'the new dependency must now trigger a rebuild'
      assert.ok spec.deps.has(newdep)
      # `sync-cache` writes asynchronously
      new Promise (res) -> setTimeout res, 300
    .then ->
      # persisted, so a restart does not lose it
      cached = JSON.parse fs.read-file-sync(spec.cache-fn!).toString!
      assert.ok newdep in cached.deps
      # dropping it again unlinks it
      deps.block = []
      b.build-by-spec spec, {force: true}
    .then -> assert.equal b.specmgr.has-code(newdep), false
