require! <[fs path fs-extra pug ./aux]>

srcbuild = (opt={}) ->
  @opt = opt
  @base = opt.base or '.'
  @log = opt.logger or aux.logger
  @dependencies = {}

  if opt.get-dependencies => @get-dependencies = that
  if opt.is-supported => @is-supported = that
  if opt.build => @build = that
  @

srcbuild.prototype = Object.create(Object.prototype) <<< do
  get-dependencies: -> []
  is-supported: (file) -> return false
  unlink: ->
  # files: [{file, mtime}, ... ]
  build: (files) ->
  log-dependencies: (file) ->
    try
      list = (@get-dependencies(file) or []).map path.normalize
    catch e
      list = []
    list.map (f) ~>
      set = if @dependencies[f] => that else (@dependencies[f] = new Set!)
      set.add file
  change: (file) ->
    files = []
    if !fs.exists-sync file => return
    mtime = +fs.stat-sync(file).mtime
    if @is-supported(file) =>
      files.push {file, mtime}
      @log-dependencies file
    if @dependencies[file] =>
      files ++= Array.from(@dependencies[file]).map -> {file:it, mtime}
    @build files
  init: ->
    recurse = (root) ~>
      if !fs.exists-sync(root) => return
      files = fs.readdir-sync root .map -> path.normalize("#root/#it")
      for file in files =>
        if fs.stat-sync file .is-directory! => recurse file
        if @is-supported file => @log-dependencies(file)
    recurse @base

module.exports = srcbuild
