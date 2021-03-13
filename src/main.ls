require! <[fs ./watch ./ext/pug ./ext/stylus ./ext/lsc ./ext/base]>

module.exports = do
  base: base
  lsp: (opt = {}) ->
    base = opt.base or 'web'
    adapters = [
      new lsc {base}
      new stylus {base}
      new pug {base}
    ].map -> it.get-adapter!
    watcher = new watch {adapters}
