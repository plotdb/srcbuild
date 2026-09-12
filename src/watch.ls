require! <[fs path fs-extra chokidar @plotdb/colors @loadingio/debounce.js ./aux]>

watch = (opt={}) ->
  @opt = opt
  @buf = {}
  @adapters = opt.adapters or []
  @chokidar-cfg = {persistent: true, ignored: aux.ignored(opt.ignored), ignoreInitial: true}
  @_root = if opt.root => (if Array.isArray(opt.root) => opt.root else [opt.root]) else <[.]>
  # symlinks we have re-added, so that we do it once each. see `relink` in `init`.
  @links = new Set!
  @log = opt.logger or aux.logger
  @init!
  @

watch.prototype = Object.create(Object.prototype) <<< do
  add-adapter: (b) -> if Array.isArray(b) => @adapters ++= b else @adapters.push b
  init: ->
    # chokidar's fsevents backend installs a watcher only in `initWatch`, which it skips
    # for anything discovered at runtime. a plain directory is covered by the parent's
    # recursive stream anyway; a symlink is not, so a module linked in after boot
    # ( `fedep`, on `npm install` ) goes silent. re-adding it does call `initWatch`.
    # both events have to ask: `fedep` replaces a link with `remove` + `symlink`, and
    # depending on how fsevents coalesces that pair chokidar reports it either as
    # `addDir` or as `change` followed by `unlink`. listening to `addDir` alone leaves
    # the second shape unrepaired, and it is about half of them.
    #
    # once per link, though. `add` on a path that already has a watcher appends another
    # listener rather than replacing the one there, and these events arrive in bursts -
    # a single `fedep` run re-announces every link several times. left unguarded that
    # piles up duplicate listeners on the same directory for the rest of the session.
    # `unlinkDir` is when the link ( or what it points at ) actually went away, and the
    # only point at which a fresh `add` is the right answer again.
    relink = (p) ~>
      if @links.has p => return
      try
        if !fs.lstat-sync(p).is-symbolic-link! => return
      catch e # gone again already; the event for the link that replaces it will follow.
        return
      @links.add p
      @watcher.add p
    @watcher = chokidar.watch @_root, @chokidar-cfg
      .on \add, (~> @add path.normalize it)
      .on \change, (~> relink it; @change path.normalize it)
      .on \unlink, (~> @unlink path.normalize it)
      .on \addDir, relink
      .on \unlinkDir, (~> @links.delete it)
    @log.info "watching #{@_root.join(' ')} for file change".cyan
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
