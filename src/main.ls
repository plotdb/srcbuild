require! <[fs ./i18n ./watch ./ext/pug ./ext/stylus ./ext/lsc ./ext/bundle ./ext/base]>

module.exports = do
  base: base
  i18n: i18n
  lsp: (opt = {}) ->
    base = opt.base or 'web'
    base = if Array.isArray(base) => base else [base]
    adapters = []
    for b in base =>
      bundler = new bundle({base: b} <<< opt{logger,i18n,ignored}  <<< (opt.bundle or {}))
      adapters ++= [
        new lsc({base: b} <<< opt{logger,i18n,ignored} <<< (opt.lsc or {}))
        new stylus({base: b} <<< opt{logger,i18n,ignored}  <<< (opt.stylus or {}))
        new pug({base: b, bundler} <<< opt{logger,i18n,ignored} <<< (opt.pug or {}))
      ].map -> it.get-adapter!
    watcher = new watch({adapters} <<< opt{logger, i18n, ignored})
