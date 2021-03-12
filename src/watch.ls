require! <[fs path fs-extra chokidar ./aux]>

watch = (opt={}) ->
  @opt = opt
  @adapters = opt.adapters or []
  @chokidar-cfg = {persistent: true, ignored: [], ignoreInitial: true}
  @log = opt.logger or aux.logger
  @init!
  @

watch.prototype = Object.create(Object.prototype) <<< do
  add-adapter: (b) -> if Array.isArray(b) => @adapters ++= b else @adapters.push b
  init: ->
    @watcher = chokidar.watch <[.]>, @chokidar-cfg
      .on \add, (~> @add path.normalize it)
      .on \change, (~> @change path.normalize it)
      .on \unlink, (~> @unlink path.normalize it)
    @log.info "watching src for file change"

  add: (file) -> @adapters.map -> it.change file
  change: (file) -> @adapters.map -> it.change file
  unlink: (file) -> @adapters.map -> it.unlink file

  /*change = (file) -> 
    change-list.push file
    change-debounced!
  change-debounced = ~>
    @adapters.map -> it.change change-list
  */
module.exports = watch
