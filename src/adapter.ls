require! <[fs path fs-extra anymatch ./aux]>

adapter = (opt={}) ->
  @opt = opt
  @base = opt.base or '.'
  @log = opt.logger or aux.logger
  @ignored = opt.{}watcher.ignored or []
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
      try
        stat = fs.stat-sync(file)
      catch e # file exists, but stat-sync fails - it may be a symlink pointing to a non-existed file.
        return 0
      return mtimes[file] = Math.max.apply( Math,
        [+stat.mtime] ++ Array.from(@depends.by[file] or []).map((f) -> recurse f)
      )
    @build files.map((file) -> {file, mtime: recurse(file)})

  init: ->
    init-builds = []
    recurse = (root) ~>
      if !fs.exists-sync(root) => return
      len1 = fs.readdir-sync(root).length
      len2 = fs.readdir-sync(root).filter(~>!anymatch((@ignored or []), it)).length
      files = fs.readdir-sync root
        .filter ~> !anymatch((@ignored or []), it)
        .map -> path.normalize("#root/#it")
      for file in files =>
        try
          stat = fs.stat-sync(file)
        catch e # file exists, but stat-sync fails - it may be a symlink pointing to a non-existed file.
          continue
        if stat.is-directory! => recurse file
        if !@is-supported(file) => continue
        # this is a time consuming func call. consider ODB instead.
        # on error: simply ignore. builder will take care of it.
        try @log-dependencies file catch e
          if e.name == \lderror and e.id == 999 => continue
        init-builds.push file
    t1 = Date.now!
    recurse @base
    #console.log("adopt recurse takes #{Date.now! - t1}ms ( #{@base} )")
    @dirty-check init-builds

module.exports = adapter
