require! <[path uglify-js uglifycss @loadingio/debounce.js]>
require! <[./base ../aux]>
fs = require "fs-extra"

spec = (o = {}) ->
  @mgr = o.manager
  @log = o.log
  @o = JSON.parse JSON.stringify o{name,type,codesrc,specsrc,deps,src}
  @ <<< @o{type, name}
  # source option for building ( which generates codesrc with `get-path` )
  @src = (if Array.isArray(o.src) => o.src else [o.src]).filter(->it)
  @codesrc = new Set(@o.codesrc or [])
  @specsrc = new Set(@o.specsrc or [])
  @deps = new Set(@o.deps or [])
  @

spec.prototype = Object.create(Object.prototype) <<< do
  to-object: ->
    {} <<< {
      codesrc: Array.from(@codesrc)
      specsrc: Array.from(@specsrc)
      deps: Array.from(@deps)
      src: Array.from(@src)
    } <<< @{type, name}
  cache-fn: -> @mgr.get-cache-name @
  sync-cache: ->
    fn = @cache-fn!
    fs.ensure-dir path.dirname(fn)
      .then ~>
        fs.write-file fn, JSON.stringify(@to-object!)
        @log.info "bundle dependency written to #fn"

specmgr = (o = {}) ->
  @log = o.log
  @cachedir = o.cachedir
  @evthdr = {}
  @_ = {}
  # codesrc, specsrc, depsare hashes for with files that should be watched in this builder.
  #  - codesrc for set of files that are used to generate bundle files (their updates trigger rebuild)
  #  - specsrc for set of files that use (and thus define) bundles. (their updates change bundle spec)
  #  - deps for set of files depended by some spec. this stores additional dependencies except files in codesrc.
  # the object stored in thes hashes are Set object containing the spec key linked with these files.
  @codesrc = {}
  @specsrc = {}
  @deps = {}
  # keep track of keys of spec been updated. batch write back cache by specmgr to reduce file access.
  @_dirty = new Set!
  @

specmgr.prototype = Object.create(Object.prototype) <<< do
  on: (n, cb) -> (if Array.isArray(n) => n else [n]).map (n) ~> @evthdr.[][n].push cb
  fire: (n, ...v) -> for cb in (@evthdr[n] or []) => cb.apply @, v
  key: (o = {}) -> if typeof(o) == \object => "#{o.type}/#{o.name}" else o
  get-cache-name: (spec) -> path.join(@cachedir, spec.type, "#{spec.name}.dep")

  # we should write back deps and rebuild if dirty and is not delete (spec still exists)
  set-dirty: (o = {}) ->
    @_dirty.add @key(o)
    @clear-dirty!
  clear-dirty: debounce 1000, ->
    specs = Array.from(@_dirty)
      .map (k) ~> @get k
      .filter -> it
    @fire \build-by-spec, specs
    specs.map (s) -> s.sync-cache!
    @_dirty.clear!
  add: (o={}, opt = {}) ->
    k = @key o
    if @_[k] and !opt.force => return that
    @_[k] = s = new spec({log: @log, manager: @} <<< o)
    s.codesrc.for-each (n) ~> @link codesrc: n, spec: s
    s.specsrc.for-each (n) ~> @link specsrc: n, spec: s
    s.deps.for-each (n) ~> @link deps: n, spec: s
    if !opt.init => @set-dirty s
    s
  set: (o = {}, opt = {}) -> @add o, ({force: true} <<< opt)
  has-code: (f) -> !!@codesrc[f] or !!@deps[f]
  touch-code: (files) ->
    files = if Array.isArray(files) => files else [files]
    keys = new Set!
    files.map (f) ~>
      if typeof(f) == \object => f = f.file
      if @codesrc[f] => Array.from(@codesrc[f]).for-each (k) ~> keys.add k
      if @deps[f] => Array.from(@deps[f]).for-each (k) ~> keys.add k
    @fire \build-by-spec, Array.from(keys).map((k) ~> @get k)

  update: (o = {}) ->
    k = @key o
    dirty = false
    if !(s = @_[k]) =>
      @add o
      return true
    if Array.from(s.codesrc).join(',') != (o.codesrc or []).join(',') => dirty = true
    if s.src.join(',') != (o.src or []).join(',') => dirty = true
    s.src = (if Array.isArray(o.src) => o.src else [o.src]).filter(->it)
    s.codesrc = new Set(o.codesrc or [])
    s.deps = new Set(o.deps or [])
    (if Array.isArray(o.specsrc) => o.specsrc else [o.specsrc]).for-each (n) ->
      if !s.specsrc.has n => dirty := true
      s.specsrc.add n

    s.codesrc.for-each (n) ~> @link codesrc: n, spec: s
    s.specsrc.for-each (n) ~> @link specsrc: n, spec: s
    s.deps.for-each (n) ~> @link deps: n, spec: s

    if dirty => @set-dirty s
    return dirty

  get: (o={}) -> @_[@key o]
  delete: (o = {}) ->
    s = @_[@key o]
    s.codesrc.for-each (n) ~> @unlink codesrc: n, spec: s
    s.specsrc.for-each (n) ~> @unlink specsrc: n, spec: s
    s.deps.for-each (n) ~> @unlink deps: n, spec: s
    @set-dirty o

  link: (o = {}) ->
    f = if o.codesrc => \codesrc else if o.specsrc => \specsrc else \deps
    s = if @[f][o[f]] => that else @[f][o[f]] = new Set!
    if !s => return
    s.add(@key o.spec)

  unlink: (o = {}) ->
    f = if o.codesrc => \codesrc else if o.specsrc => \specsrc else \deps
    if !(s = @[f][o[f]]) => return
    s.remove @key o.spec
    if s.size => return
    delete @[f][o[f]]

  del-specsrc: (n) ->
    if !(s = @specsrc[n]) => return
    s.for-each (k) ~>
      if !(spec = @get k) => return
      spec.unlink specsrc: n
      # spec deletion trigger a cache writeback,
      # but should not trigger bundle rebuild. how to identify this?
      @set-dirty k
    delete @specsrc[n]

build = (o={}) ->
  opt = {srcdir: 'static', desdir: 'static'} <<< o
  @init-vars opt
  @mgr = if typeof(o.manager) == \function => o.manager({base: @base}) else o.manager
  # this is the optional bundle specs provided directly through constructor
  @defcfg = o.config or null
  # this is the directory storing dependency metadata cache
  @cachedir = path.join(o.base or '.', '.bundle-dep')
  # this file keeps optional bundle specs expliticly defines by developer.
  @cfgfn = if o.config-file => path.join(o.base or '.', o.config-file) else null
  # this helps us converting files in cfgfn to the correct path
  # since cfgfn may locate in any dir,
  # the directory relation between cfgfn and the code source files is kinda undefined
  # so we use reldir to explicitly define it.
  @reldir = if typeof(o.relative-path) == \string => o.relative-path
  else if (!(o.relative-path?) or o.relative-path) and @cfgfn => path.dirname(@cfgfn)
  else process.cwd!
  @log = o.logger or aux.logger
  @reload!
  @init-adapter opt
  @

build.prototype = Object.create(base.prototype) <<< do
  get-path: (f) ->
    if typeof(f) == \string => return f
    if @mgr => return @mgr.get-url(f)
    version = f.version or \main
    p = if f.path => f.path
    else if f.type == \css => \index.min.css
    else if f.type == \block => \index.html
    else 'index.min.js'
    # path are defined in frontend context. thus, it will be sth like "/js/site.js" etc
    # related to @desdir (e.g., `static` )
    return path.join(@desdir, "assets/lib/#{f.name}/#version/#p")

  reload: ->
    @reset!
    @load-caches!
    @load-cfg init: true

  reset: ->
    # specmgr manages lifecycle of specs
    @specmgr = new specmgr cachedir: @cachedir, log: @log
    @specmgr.on \build-by-spec, (specs) ~>
      specs.for-each (spec) ~> @build-by-spec spec

  load-cfg: (opt = {}) ->
    cfgs = if opt.init => [['',@defcfg]] else []
    if (@cfgfn and fs.exists-sync(@cfgfn)) =>
      try
        cfg = JSON.parse fs.read-file-sync(@cfgfn).toString!
      catch e
        @log.error "parse error of config file #{@cfgfn}".red
        cfg = {}
      cfgs.push [@cfgfn, cfg]
    for [fn,cfg] in cfgs =>
      for type of cfg =>
        for name, list of cfg[type] =>
          # this should be the only place we need to join `reldir` with a file name.
          codesrc = list.map (n) ~>
            if typeof(n) == \string => return path.join(@reldir, n)
            if !n.type => n.type = type
            @get-path n
          # add fn in `deps` to ensure it's supported and trigger building when updated
          # so we can call load-cfg when file update.
          @specmgr.update { type, name, src: list, codesrc: codesrc, deps: [fn], specsrc: [fn] }

  load-caches: ->
    if !fs.exists-sync(@cachedir) => return
    traverse = (dir) ->
      files = fs.readdir-sync dir .map (n) -> path.join(dir, n)
      ret = []
      for file in files =>
        if fs.stat-sync(file).is-directory! => ret ++= traverse(file)
        if /\.dep$/.exec(file) => ret.push file
      return ret
    files = traverse @cachedir
    files.for-each (n) ~>
      try
        json = JSON.parse(fs.read-file-sync n .toString!)
      catch e
        console.log e
        @log.error "parse error of cache file #n".red
      @specmgr.set json, {init: true}

  del-specsrc: (n) -> specmgr.del-specsrc n
  add-spec: (opts = []) ->
    opts = (if Array.isArray(opts) => opts else [opts]).filter(->it)
    opts.map (o) ~>
      if o.type == \block =>
        @mgr.bundle blocks: o.[]codesrc
          .then (r) ~>
            if !(r and r.deps) => @log.warn "block bundle requires block > 4.8.0 to work properly"
            deps = r.deps or {js: [], css: [], block: []}
            deps = (deps.js ++ deps.css ++ deps.block).map (f) ~> @get-path f
            codesrc = o.[]src.map (f) ~> @get-path f
            specsrc = if Array.isArray(o.specsrc) => o.specsrc else [o.specsrc]
            @specmgr.update({} <<< o{name,type,src} <<< {codesrc, specsrc, deps})
      else
        codesrc = o.[]src.map (f) ~> @get-path f
        specsrc = (if Array.isArray(o.specsrc) => o.specsrc else [o.specsrc]).filter(->it)
        deps = (if Array.isArray(o.deps) => o.deps else [o.deps]).filter(->it)
        @specmgr.update({} <<< o{name,type,src} <<< {codesrc, specsrc, deps})

  get-dependencies: (file) -> return []
  is-supported: (file) -> return @specmgr.has-code file
  purge: (files) -> @build files
  build: (files, opt) ->
    force = if typeof(opt) == \boolean => opt else false
    if !opt? => opt = {}
    if files.filter(~> it.file == @cfgfn).length => return @load-cfg!
    @specmgr.touch-code files

  des-path: ({name, type}) ->
    _desdir = path.join(@desdir, \assets, \bundle)
    ext = if type == \block => \html else type
    des = path.join(_desdir, "#name.#ext")
    des-min = path.join(_desdir, "#name.min.#ext")
    # we may have subfolders in name
    desdir = path.dirname(des)
    return {desdir, des, des-min}

  build-by-spec: (spec) ->
    <~ Promise.resolve!then _
    {name,type} = spec
    t1 = Date.now!
    srcs = Array.from spec.codesrc
    {desdir, des, des-min} = @des-path {name, type}
    ext = if type == \block => \html else type
    fs.ensure-dir desdir
      .then ~>
        if type == \block =>
          if !@mgr or !@mgr.bundle =>
            throw new Error("block bundling requires manager of @plotdb/block provided via bundler option.")
          @mgr.bundle blocks: spec.src
            .then (ret) ->
              code = ret.code or ret
              Promise.all [
                fs.write-file(des, code)
                fs.write-file(des-min, code)
              ]
        else
          ps = srcs.map (f) ->
            f = f.replace "\.min.#ext", ".#ext"
            f-min = f.replace "\.#ext", ".min.#ext"
            fs.read-file f
              .catch -> return ""
              .then (b) ->
                fs.read-file f-min
                  .catch -> ""
                  .then (bm) ->
                    {name: f, code: b.toString!, code-min: bm.toString!}
          Promise.all ps
            .then (ret) ~>
              normal = ret.map(->it.code or it.code-min).join('')
              minified = ret
                .map (o) ~>
                  if o.code-min => return o.code-min
                  if !o.code => return ""
                  return if type == \js => uglify-js.minify(o.code).code
                  else if type == \css => uglifycss.processString(o.code, uglyComments: true)
                  else o.code
                .join('')
              Promise.all [
                fs.write-file(des, normal)
                fs.write-file(des-min, minified)
              ]

      .then ~>
        ret = do
          type: type, name: name
          elapsed: Date.now! - t1
          size: fs.stat-sync(des).size
          size-min: fs.stat-sync(des-min).size
        {size,size-min,elapsed} = ret
        @log.info "bundle #des ( #size bytes / #{elapsed}ms )"
        @log.info "bundle #des-min ( #size-min bytes / #{elapsed}ms )"
        ret
      .catch (e) ~>
        @log.error "#des failed: ".red
        @log.error {err: e}, e.message.toString!

module.exports = build
