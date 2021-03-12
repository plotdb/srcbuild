require! <[fs path fs-extra chokidar ./aux]>

srcwatch = (opt={}) ->
  @opt = opt
  @builders = opt.builders
  @chokidar-cfg = {persistent: true, ignored: [], ignoreInitial: true}
  @log = opt.logger or aux.logger
  @init!
  @

srcwatch.prototype = Object.create(Object.prototype) <<< do
  init: ->
    @watcher = chokidar.watch <[.]>, @chokidar-cfg
      .on \add, (~> @add path.normalize it)
      .on \change, (~> @change path.normalize it)
      .on \unlink, (~> @unlink path.normalize it)
    @log.info "watching src for file change"

  add: (file) -> @builders.map -> it.change file
  change: (file) -> @builders.map -> it.change file
  unlink: (file) -> @builders.map -> it.unlink file

module.exports = srcwatch
