require! <[fs path fs-extra uglify-js uglifycss colors]>
require! <[./base ../aux ../adapter]>


bundlebuild = (opt={}) ->
  @config = opt.config or {css: {}, js: {}}
  @config-file = opt.config-file or null #'bundle.json'
  @prepare-config!
  @init({srcdir: 'static', desdir: 'static'} <<< opt)

bundlebuild.prototype = Object.create(base.prototype) <<< do
  prepare-config: ->
    if @config-file and fs.exists-sync(@config-file) =>
      @config = JSON.parse fs.read-file-sync(@config-file).toString!
    @file-list = new Set!
    @file-map = {}
    for type of @config => for name,list of @config[type] => for f in list =>
      @file-list.add f
      @file-map[f] = {type, name}
    @file-list.add @config-file

  get-dependencies: (file) -> return if file == @config-file => [] else [@config-file]
  is-supported: (file) -> return @file-list.has(file)
  resolve: (file) ->
    re = new RegExp("^#{@desdir}/(css|js)/pack/(.+?)(\.min)?\.(css|js)")
    if !(ret = re.exec file) => return null
    return (@config[ret.1][ret.2] or []).0
  build: (files) ->
    if files.filter(~> it.file == @config-file).length =>
      @prepare-config!
      files = Array.from(@file-list)
      files.splice files.indexOf(@config-file), 1
      return @build files
    dirty = {}
    for file in files =>
      if !(ret = @file-map[file.file]) => continue
      dirty{}[ret.type][ret.name] = true
    ps = []
    for type of dirty => for name of dirty[type] =>
      desdir = path.join(@desdir, type, 'pack')
      des = path.join(desdir, "#name.#type")
      if aux.newer des, ((@config[type][name] or []) ++ [@config-file]) => continue
      ps.push @build-by-name({type, name})
    Promise.all ps


  build-by-name: ({name, type}) ->
    <~ Promise.resolve!then _
    t1 = Date.now!
    srcs = @config[type][name]
    desdir = path.join(@desdir, type, 'pack')
    des = path.join(desdir, "#name.#type")
    des-min = path.join(desdir, "#name.min.#type")
    Promise.resolve!
      .then -> new Promise (res, rej) -> fs-extra.ensure-dir desdir, -> res!
      .then ->
        Promise.all [
          Promise.all(srcs.map((f) -> new Promise (res, rej) ->
            fs.read-file(f, (e,b) -> if e => rej e else res {name: f, code: b.toString!}))),
          Promise.all(srcs.map((f) -> new Promise (res, rej) ->
            fm = f.replace /\.(js|css)$/, '.min.$1'
            (e,b) <- fs.read-file fm, _
            if e => fs.read-file f,((e, b) -> if e => rej e else res {name: fm, code: b.toString!})
            else res {name: f, code: b.toString!}
          ))
        ]
      .then (ret) ->
        normal = ret.0.map(->it.code).join('')
        minified = ret.1
          .map ({name,code}) ->
            return if /\.min\./.exec(name) => code
            else if type == \js => uglify-js.minify(code).code
            else if type == \css => uglifycss.processString(code, uglyComments: true)
            else code
          .join('')
        Promise.all [
          new Promise (res, rej) -> fs.write-file des, normal, (e, b) -> res b
          new Promise (res, rej) -> fs.write-file des-min, minified, (e, b) -> res b
        ]
      .then ~>
        ret = do
          type: type, name: name
          elapsed: Date.now! - t1
          size: fs.stat-sync(des).size
          size-min: fs.stat-sync(des-min).size
        {size,size-min,elapsed} = ret
        @log.info "bundle: static/#type/pack/#name.#type ( #size bytes / #{elapsed}ms )"
        @log.info "bundle: static/#type/pack/#name.min.#type ( #size-min bytes / #{elapsed}ms )"
        ret

  purge: (files) -> @build files

module.exports = bundlebuild
