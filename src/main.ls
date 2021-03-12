require! <[fs ./watch ./ext/pug ./ext/stylus ./ext/lsc]>

module.exports = (opt = {}) ->
  base = opt.base or 'web'
  adapters = [
    new pug {base}
    new stylus {base}
    new lsc {base}
  ].map -> it.get-adapter!
  watcher = new watch {adapters}
