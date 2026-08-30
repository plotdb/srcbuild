require! <[path assert]>
{test} = require 'node:test'
adapter = require '../src/adapter'
{quiet, tmpdir, write} = require './aux'

# build an adapter over a fixed dependency map. `deps[f]` is what `f` depends on;
# the adapter turns that into the reverse edges it walks ( `depends.on` ).
mk = (root, deps, opt = {}) ->
  built = []
  analysed = []
  supported = opt.supported or (-> true)
  a = new adapter {
    base: root
    logger: quiet
    init-scan: false
    is-supported: (f) -> supported f
    get-dependencies: (f) ->
      analysed.push f
      if opt.broken and opt.broken.has(path.basename f) => throw new Error("boom")
      (deps[path.basename f] or []).map -> path.join(root, it)
    build: (files) -> built.push files.map(-> path.basename it.file).sort!
  }
  # stand in for `init`: register every known file so the graph exists up front.
  if opt.no-init != true =>
    for n of deps => try a.log-dependencies path.join(root, n)
  analysed.length = 0
  return {a, built, analysed}


test 'change: a dependency cycle terminates instead of spinning forever', ->
  root = write tmpdir!, {'a.pug': 'a', 'b.pug': 'b'}
  # a includes b, b includes a. `depends.on` therefore has a <-> b.
  {a, built} = mk root, {'a.pug': ['b.pug'], 'b.pug': ['a.pug']}
  ret = a.change path.join(root, 'a.pug')
  ret.then ->
    assert.deep-equal built, [['a.pug', 'b.pug']]


test 'change: visits nodes, not paths', ->
  # root <- m1..m4 <- p1..p20 . every page includes every module, every module
  # includes root. old code enumerated all root->m->p paths: 1 + 4 + 4*20 = 85 pops.
  mods = [1 to 4].map -> "m#it.pug"
  pages = [1 to 20].map -> "p#it.pug"
  files = {'root.pug': 'r'}
  deps = {}
  mods.map (m) -> files[m] = 'm'; deps[m] = ['root.pug']
  pages.map (p) -> files[p] = 'p'; deps[p] = mods
  root = write tmpdir!, files
  {a, analysed} = mk root, deps
  ret = a.change path.join(root, 'root.pug')
  ret.then ->
    # each reachable node is analysed exactly once. the old loop walked every distinct
    # root -> module -> page path: 1 + 4 + 4*20 = 85.
    assert.equal analysed.length, 1 + mods.length + pages.length,
      "each node once, got #{analysed.length}"
    assert.equal (new Set(analysed)).size, analysed.length, 'no node analysed twice'


test 'change: a file that fails to analyse is still built and retried later', ->
  # the reported failure: index.pug includes a broken index.ls . pug's dependency
  # tracking runs the filters, so the *pug* analysis is what throws.
  root = write tmpdir!, {'index.pug': 'p', 'index.ls': 'l', 'other.pug': 'o'}
  broken = new Set(['index.pug'])
  {a, built} = mk root, {'index.pug': ['index.ls']}, {
    broken, no-init: true, supported: (f) -> !!/\.pug$/.exec(f)
  }

  Promise.resolve!
    .then -> a.change path.join(root, 'index.pug')
    .then ->
      # old behaviour: `continue` dropped it entirely and nothing was built.
      assert.deep-equal built, [['index.pug']], 'broken file must still reach the builder'
      assert.ok a.failed.has(path.join(root, 'index.pug'))
      assert.equal (a.depends.on[path.join(root, 'index.ls')] or new Set!).size, 0
      built.length = 0
    .then ->
      # index.ls is fixed. the edge was never recorded, so without the retry list
      # this change event finds nothing to do - the page stays stale forever.
      broken.delete 'index.pug'
      a.change path.join(root, 'index.ls')
    .then ->
      assert.deep-equal built, [['index.pug']], 'retry must pick the page back up'
      assert.equal a.failed.size, 0
      assert.ok a.depends.on[path.join(root, 'index.ls')].has(path.join(root, 'index.pug'))
      built.length = 0
    .then ->
      # and from now on it behaves like any other tracked dependency.
      a.change path.join(root, 'index.ls')
    .then ->
      assert.deep-equal built, [['index.pug']]


test 'change: analysis failure keeps the previously known edges', ->
  root = write tmpdir!, {'a.pug': 'a', 'b.pug': 'b'}
  broken = new Set!
  {a, built} = mk root, {'a.pug': ['b.pug']}, {broken, no-init: true}
  Promise.resolve!
    .then -> a.change path.join(root, 'a.pug')
    .then ->
      built.length = 0
      broken.add 'a.pug'
      a.change path.join(root, 'a.pug')
    .then ->
      built.length = 0
      # b.pug -> a.pug edge must survive the failed re-analysis of a.pug
      a.change path.join(root, 'b.pug')
    .then ->
      assert.deep-equal built, [['a.pug', 'b.pug']]
