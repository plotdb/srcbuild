require! <[fs ./i18n ./watch ./ext/pug ./ext/stylus ./ext/lsc ./ext/base]>

module.exports = do
  base: base
  i18n: i18n
  lsp: (opt = {}) ->
    base = opt.base or 'web'
    adapters = [
      new lsc({base} <<< opt)
      new stylus({base} <<< opt)
      new pug({base} <<< opt)
    ].map -> it.get-adapter!
    watcher = new watch({adapters} <<< opt)
