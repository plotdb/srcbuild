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
  @

adapter.prototype = Object.create(Object.prototype) <<< do
  get-dependencies: -> []
  is-supported: (file) -> return false
  purge: (files) -> # files: [{file, mtime}, ... ]
  build: (files) -> # files: [{file, mtime}, ... ]
  log-dependencies: (file) ->
    try
      list = (@get-dependencies(file) or []).map path.normalize
    catch e
      list = []
    Array.from(@depends.by[file] or []).map (f) ~> if @depends.on[f] => @depends.on[f].delete file
    setby = @depends.by[file] = new Set!
    list.map (f) ~>
      seton = if @depends.on[f] => that else (@depends.on[f] = new Set!)
      seton.add file
      setby.add f
  unlink: (files) -> @purge files.map(-> {file: it, mtime: 0})
  change: (files) ->
    affected-files = new Set!
    mtimes = {}
    queue = (if Array.isArray(files) => files else [files]).map(->it) # array clone
    ret = []
    while queue.length
      affected-files.add(file = queue.pop!)
      if !fs.exists-sync file => continue
      if @is-supported file => @log-dependencies file
      mtime = fs.stat-sync(file).mtime
      if !mtimes[file] or mtimes[file] < mtime => mtimes[file] = mtime
      Array.from(@depends.on[file] or [])
        .map (f) ->
          if !mtimes[f] or mtimes[f] < mtimes[file] => mtimes[f] = mtimes[file]
          queue.push f
    ret = Array.from(affected-files)
      .filter ~> @is-supported it
      .map ~> {file: it, mtime: mtimes[it]}
    if ret.length => @build ret

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
        @log-dependencies(file)
        init-builds.push file
    recurse @base
    @dirty-check init-builds

module.exports = adapter
