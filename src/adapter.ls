require! <[fs path fs-extra pug ./aux]>

adapter = (opt={}) ->
  @opt = opt
  @base = opt.base or '.'
  @log = opt.logger or aux.logger
  @depends = {on: {}, by: {}}

  if opt.get-dependencies => @get-dependencies = that
  if opt.is-supported => @is-supported = that
  if opt.build => @build = that
  if opt.purge => @purge = that
  if opt.resolve => @resolve = that
  @

adapter.prototype = Object.create(Object.prototype) <<< do
  get-dependencies: -> []
  is-supported: (file) -> return false
  purge: (files) -> # files: [{file, mtime}, ... ]
  build: (files) -> # files: [{file, mtime}, ... ]
  resolve: (file) -> return null
  log-dependencies: (file) ->
    try list = (@get-dependencies(file) or []).map path.normalize catch e
      @log.error "analyse #file failed: ".red
      @log.error e.message.toString!
      throw new Error! <<< {name: 'lderror', id: 999}
      return # dont touch dependency since we can't get the correct one.
    Array.from(@depends.by[file] or []).map (f) ~> if @depends.on[f] => @depends.on[f].delete file
    setby = @depends.by[file] = new Set!
    list.map (f) ~>
      seton = if @depends.on[f] => that else (@depends.on[f] = new Set!)
      seton.add file
      setby.add f

  unlink: (files) ->
    ret = files
      .filter ~> @is-supported it
      .map -> {file: it, mtime: 0}
    @purge ret

  change: (files, opt = {}) ->
    affected-files = new Set!
    mtimes = {}
    queue = (if Array.isArray(files) => files else [files]).map(->it) # array clone
    ret = []
    now = Date.now!
    while queue.length
      file = queue.pop!
      if !fs.exists-sync file => continue
      if @is-supported file =>
        try @log-dependencies file catch e
          if e.name == \lderror and e.id == 999 => continue
      affected-files.add file
      mtime = if opt.force => now else if fs.exists-sync(file) => fs.stat-sync(file).mtime else now
      if !mtimes[file] or mtimes[file] < mtime => mtimes[file] = mtime
      if opt.non-recursive => continue
      Array.from(@depends.on[file] or [])
        .map (f) ->
          if !mtimes[f] or mtimes[f] < mtimes[file] => mtimes[f] = mtimes[file]
          queue.push f
    ret = Array.from(affected-files)
      .filter ~> @is-supported it
      .map ~> {file: it, mtime: mtimes[it]}
    Promise.resolve(if ret.length => @build ret else null)

  dirty-check: (files) ->
    mtimes = {}
    recurse = (file) ~>
      if mtimes[file] => return that
      if !fs.exists-sync(file) => return 0
      return mtimes[file] = Math.max.apply( Math,
        [+fs.stat-sync(file).mtime] ++ Array.from(@depends.by[file] or []).map((f) -> recurse f)
      )
    @build files.map((file) -> {file, mtime: recurse(file)})

  init: ->
    init-builds = []
    recurse = (root) ~>
      if !fs.exists-sync(root) => return
      files = fs.readdir-sync root .map -> path.normalize("#root/#it")
      for file in files =>
        if fs.stat-sync file .is-directory! => recurse file
        if !@is-supported(file) => continue
        # on error: simply ignore. builder will take care of it.
        try @log-dependencies file catch e
          if e.name == \lderror and e.id == 999 => continue
        init-builds.push file
    recurse @base
    @dirty-check init-builds

module.exports = adapter
