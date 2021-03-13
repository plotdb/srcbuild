require! <[fs path fs-extra chokidar @loadingio/debounce.js ./aux]>

watch = (opt={}) ->
  @opt = opt
  @buf = {}
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
    @change-debounced = debounce ~> 
      files = Array.from(@buf.change)
      @buf.change = null
      @adapters.map -> it.change files
    @unlink-debounced = debounce ~>
      files = Array.from(@buf.unlink)
      @buf.unlink = null
      @adapters.map -> it.unlink files

  add: (file) -> @adapters.map -> it.change file
  change: (file) ->
    if !@buf.change => @buf.change = new Set!
    @buf.change.add file
    @change-debounced!
  unlink: (file) ->
    if !@buf.unlink => @buf.unlink = new Set!
    @buf.unlink.add file
    @unlink-debounced!

module.exports = watch
