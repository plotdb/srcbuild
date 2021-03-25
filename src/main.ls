require! <[fs ./i18n ./watch ./ext/pug ./ext/stylus ./ext/lsc ./ext/bundle ./ext/base]>

module.exports = do
  base: base
  i18n: i18n
  lsp: (opt = {}) ->
    base = opt.base or 'web'
    adapters = [
      new lsc({base} <<< opt{logger,i18n} <<< (opt.lsc or {}))
      new stylus({base} <<< opt{logger,i18n}  <<< (opt.stylus or {}))
      new pug({base} <<< opt{logger,i18n} <<< (opt.pug or {}))
      new bundle({base} <<< opt{logger,i18n}  <<< (opt.bundle or {}))
    ].map -> it.get-adapter!
    watcher = new watch({adapters} <<< opt{logger, i18n, ignored})
