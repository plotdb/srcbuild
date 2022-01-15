require! <[fs path fs-extra chokidar @plotdb/colors @loadingio/debounce.js ./aux]>

watch = (opt={}) ->
  @opt = opt
  @buf = {}
  @adapters = opt.adapters or []
  @chokidar-cfg = {persistent: true, ignored: opt.ignored or ['.git'], ignoreInitial: true}
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
    @log.info "watching src for file change".cyan
    @change-debounced = debounce ~> 
      files = Array.from(@buf.change)
      @buf.change = null
      @adapters.map -> it.change files
    @unlink-debounced = debounce ~>
      files = Array.from(@buf.unlink)
      @buf.unlink = null
      @adapters.map -> it.unlink files

  demand: (files) ->
    files = (if Array.isArray(files) => files else [files])
      .map (f) ~>
        for adapter in @adapters => if adapter.resolve(f) => return that
        return null
      .filter -> it
    Promise.all(@adapters.map -> it.change files, {force: true, non-recursive: true})

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
