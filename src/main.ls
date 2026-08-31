require! <[fs ./i18n ./watch ./hashstore ./ext/pug ./ext/stylus ./ext/lsc ./ext/bundle ./ext/asset ./ext/base]>

module.exports = do
  base: base
  i18n: i18n
  hashstore: hashstore
  lsp: (opt = {}) ->
    base = opt.base or 'web'
    base = if Array.isArray(base) => base else [base]
    adapters = []
    stores = []
    bundlers = []
    # `.map` and not `for`: each base needs its own scope, since the store handler
    # below closes over that base's pug builder.
    base.map (b) ->
      # opt in: `hash: {enabled: true}`. it changes the url of every generated asset in
      # every page, and it is only worth anything once the edge serves the addressed
      # form with a long max-age - so a project turns it on when it has done that
      # ( see `cachecheck` in servebase, or the README ).
      # one store per base, shared by every builder of that base, so a bundle and a
      # plain `/js/site.min.js` are looked up through the same manifest.
      store = if (opt.hash or {}).enabled => new hashstore({base: b} <<< opt{logger} <<< opt.hash) else null
      if store => stores.push store
      bundler = new bundle({base: b, store} <<< opt{logger,i18n,ignored}  <<< (opt.bundle or {}))
      pugbuilder = new pug({base: b, bundler, store} <<< opt{logger,i18n,ignored} <<< (opt.pug or {}))
      # a built file whose content hash moved invalidates every page that baked its url
      # in. built assets are in no page's pug dependency graph, so nothing else can
      # notice. the store only announces a real hash change, so page -> asset -> page
      # settles in one pass instead of looping.
      if store => store.on \change, ({url}) -> pugbuilder.invalidate-url url
      bundlers.push bundler
      adapters.push bundler.get-adapter!
      adapters ++= [
        new lsc({base: b, store} <<< opt{logger,i18n,ignored} <<< (opt.lsc or {}))
        new stylus({base: b, store} <<< opt{logger,i18n,ignored}  <<< (opt.stylus or {}))
        pugbuilder
        new asset({base: b} <<< opt{logger,i18n,ignored} <<< (opt.asset or {}))
      ].map -> it.get-adapter!
    watcher = new watch({adapters} <<< opt{logger, i18n, ignored})
    # exposed so a host can hand the same store to its express view engine instead of
    # letting the view engine re-read the manifest from disk.
    watcher.stores = stores
    # resolves when every adapter's initial scan has finished building.
    #
    # a host that starts listening before this settles serves requests while the first
    # build is still running - which is exactly when the build is heaviest, and, before
    # minify moved to a worker, when it was blocking the loop outright. that is now a
    # choice the host can make rather than one it cannot see: `await srcbuild.ready`.
    #
    # it never rejects. a build that fails has already logged; refusing to start the
    # server over one bad source file would be worse than serving the rest.
    watcher.ready = Promise.all(adapters.map -> it.ready or Promise.resolve!)
      .then -> Promise.all bundlers.map -> it.idle!
      .then -> void
    watcher
