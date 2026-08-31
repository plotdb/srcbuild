require! <[path crypto @loadingio/debounce.js ../minify]>
require! <[./base ../aux ../hashstore]>
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
  # `debounce` keeps its timer in a closure, so a debounced method defined on the
  # prototype is shared by every instance: with more than one base ( `lsp {base: [...]}` )
  # one manager's pending flush is cancelled by another's and then never runs, and its
  # spec changes are silently dropped. bind it per instance instead.
  @clear-dirty = debounce 1000, ~> @flush-dirty!
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
  flush-dirty: ->
    specs = Array.from(@_dirty)
      .map (k) ~> @get k
      .filter -> it
    # `force`: the spec *definition* changed ( source list added / removed / reordered ),
    # so the output is stale even when every remaining source file is older than it.
    @fire \build-by-spec, specs, {force: true}
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
  touch-code: (files, opt = {}) ->
    files = if Array.isArray(files) => files else [files]
    keys = new Set!
    files.map (f) ~>
      if typeof(f) == \object => f = f.file
      if @codesrc[f] => Array.from(@codesrc[f]).for-each (k) ~> keys.add k
      if @deps[f] => Array.from(@deps[f]).for-each (k) ~> keys.add k
    @fire \build-by-spec, Array.from(keys).map((k) ~> @get k).filter(-> it), opt

  update: (o = {}) ->
    k = @key o
    dirty = false
    if !(s = @_[k]) =>
      @add o
      return true
    if Array.from(s.codesrc).join(',') != (o.codesrc or []).join(',') => dirty = true
    if s.src.join(',') != (o.src or []).join(',') => dirty = true
    s.src = (if Array.isArray(o.src) => o.src else [o.src]).filter(->it)
    # drop the links of sources this spec no longer uses. without this the reverse index
    # only ever grows: a file that was bundled once keeps triggering that bundle forever.
    for f in <[codesrc deps]> =>
      next = new Set(o[f] or [])
      s[f].for-each (n) ~>
        if next.has(n) => return
        u = {spec: s}
        u[f] = n
        @unlink u
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

  # replace a spec's extra dependencies without marking it dirty. block dependencies
  # are resolved by the block manager and change whenever a block's html changes, so
  # they have to be re-linked after a build - but re-linking must not itself schedule
  # another build, or every block bundle would rebuild forever.
  set-deps: (spec, list) ->
    next = new Set(list or [])
    if Array.from(spec.deps).sort!join(',') == Array.from(next).sort!join(',') => return false
    spec.deps.for-each (n) ~> if !next.has(n) => @unlink deps: n, spec: spec
    spec.deps = next
    next.for-each (n) ~> @link deps: n, spec: spec
    spec.sync-cache!
    @log.info "bundle #{@key spec} dependencies updated ( #{next.size} )"
    return true

  get: (o={}) -> @_[@key o]
  delete: (o = {}) ->
    k = @key o
    if !(s = @_[k]) => return
    s.codesrc.for-each (n) ~> @unlink codesrc: n, spec: s
    s.specsrc.for-each (n) ~> @unlink specsrc: n, spec: s
    s.deps.for-each (n) ~> @unlink deps: n, spec: s
    delete @_[k]
    # the spec is gone, so `clear-dirty` would drop it silently and leave the `.dep`
    # behind - which `load-caches` would happily resurrect on the next start.
    @_dirty.delete k
    fn = @get-cache-name s
    if fs.exists-sync fn => fs.unlink-sync fn
    @log.info "bundle spec #k removed. #fn deleted."
    # the built output and the manifest entry outlive the spec otherwise: nothing else
    # knows those files belong to a bundle nobody declares any more.
    @fire \delete, s

  link: (o = {}) ->
    f = if o.codesrc => \codesrc else if o.specsrc => \specsrc else \deps
    s = if @[f][o[f]] => that else @[f][o[f]] = new Set!
    if !s => return
    s.add(@key o.spec)

  unlink: (o = {}) ->
    f = if o.codesrc => \codesrc else if o.specsrc => \specsrc else \deps
    if !(s = @[f][o[f]]) => return
    s.delete @key o.spec
    if s.size => return
    delete @[f][o[f]]

  del-specsrc: (n) ->
    if !(s = @specsrc[n]) => return
    # `unlink` mutates @specsrc[n], so iterate over a copy.
    Array.from(s).for-each (k) ~>
      if !(spec = @get k) => return
      spec.specsrc.delete n
      @unlink specsrc: n, spec: spec
      # nobody declares this bundle any more - it is garbage, not just dirty.
      if !spec.specsrc.size => return @delete k
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
  # content-addressed copies live in a store shared with the other builders of this
  # base, so `/js/site.min.js` and `/assets/bundle/vendor.min.js` are looked up the
  # same way. optional: without one, only the plain names are written.
  @store = o.store or null
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
  # the content-addressed url of a built bundle, or null when it hasn't been built yet
  # ( cold start ). callers fall back to the unhashed name in that case.
  manifest-url: ({type, name, min = true}) ->
    if !@store => return null
    {des, des-min} = @des-path {name, type}
    return @store.get @store.url-of(if min => des-min else des)

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
    @specmgr.on \build-by-spec, (specs, opt = {}) ~>
      specs.for-each (spec) ~> @build-by-spec spec, opt
    @specmgr.on \delete, (spec) ~> @purge-outputs spec

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

  del-specsrc: (n) -> @specmgr.del-specsrc n
  add-spec: (opts = []) ->
    opts = (if Array.isArray(opts) => opts else [opts]).filter(->it)
    opts.map (o) ~>
      if o.type == \block =>
        @mgr.bundle blocks: (o.[]src ++ o.[]codesrc)
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

  # a spec nobody declares any more. drop its outputs and its store entries, or both
  # accumulate for the lifetime of the project.
  purge-outputs: ({name, type}) ->
    {des, des-min} = @des-path {name, type}
    [des, des-min].map (f) ~>
      if @store => @store.drop f
      if !fs.exists-sync f => return
      @log.info "bundle #f removed with its spec."
      fs.remove-sync f

  get-dependencies: (file) -> return []
  is-supported: (file) -> return @specmgr.has-code file
  # a source file was deleted. its mtime tells us nothing, so the guard in
  # `build-by-spec` cannot see that the bundle is now stale - rebuild unconditionally.
  purge: (files) -> @build files, {force: true}
  build: (files, opt) ->
    opt = if typeof(opt) == \boolean => {force: opt} else (opt or {})
    # a change on the config file and on a bundled source can arrive in the same batch.
    # returning early here used to drop the latter silently.
    [cfgs, rest] = [[], []]
    files.map (f) ~> (if f.file == @cfgfn => cfgs else rest).push f
    if cfgs.length => @load-cfg!
    if rest.length => @specmgr.touch-code rest, opt

  des-path: ({name, type}) -> return build.des-path {desdir: @desdir, name, type}

  build-by-spec: (spec, opt = {}) ->
    <~ Promise.resolve!then _
    if !spec => return
    {name,type} = spec
    t1 = Date.now!
    srcs = Array.from spec.codesrc
    # `deps` are the extra files a spec is rebuilt for ( block bundling resolves them
    # from the registry ). they are not read here, but they do decide freshness.
    watched = srcs ++ Array.from(spec.deps)
    {desdir, des, des-min} = @des-path {name, type}
    ext = if type == \block => \html else type
    # every other builder skips when the output is newer than its sources; this one used
    # to rebuild and rewrite unconditionally on every event. that is required to be a
    # no-op before the output can ever feed back into a page rebuild ( content hashing ),
    # otherwise page -> bundle -> page is an infinite loop.
    # `opt.force` covers the case the mtimes cannot see: the source *list* changed.
    if !opt.force and aux.newer(des, watched) and aux.newer(des-min, watched) =>
      # the outputs survived but the manifest did not: adopt them rather than falling
      # back to the plain url forever.
      if @store => [des, des-min].map ~> @store.ensure it
      return {type, name, skipped: true}
    fs.ensure-dir desdir
      .then ~>
        if type == \block =>
          if !@mgr or !@mgr.bundle =>
            throw new Error("block bundling requires manager of @plotdb/block provided via bundler option.")
          @mgr.bundle blocks: spec.src
            .then (ret) ~>
              # the manager just told us what this bundle actually depends on. that set
              # moves whenever a block's html gains or drops a dependency, and until now
              # it was only ever captured at `add-spec` time - so a newly added
              # dependency was invisible to the watcher until the declaring pug file
              # happened to be re-analysed.
              if ret.deps =>
                deps = ret.deps
                @specmgr.set-deps spec, ((deps.js or []) ++ (deps.css or []) ++ (deps.block or [])).map (f) ~> @get-path f
              code = ret.code or ret
              {code, code-min: code}
        else
          # `String.replace` with a string argument replaces the *first* occurrence, so
          # `three.js/main/index.js` used to derive `three.min.js/main/index.js`. anchor
          # it at the end of the path instead.
          [re, re-min] = [new RegExp("\\.min\\.#{ext}$"), new RegExp("\\.#{ext}$")]
          ps = srcs.map (f) ->
            f = f.replace re, ".#ext"
            f-min = f.replace re-min, ".min.#ext"
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
              # off the main thread: this is where the seconds are. see minify.ls.
              # sources that ship their own `.min` twin never reach the worker.
              mins = ret.map (o) ~>
                if o.code-min => return Promise.resolve o.code-min
                if !o.code => return Promise.resolve ""
                # on failure this resolves to `o.code` unchanged, so the file stays in
                # the bundle. it used to be `undefined`, which `.join` drops silently -
                # one bad source file and the bundle shipped without it.
                minify.async-or-original type, o.code, {}, @log, o.name
              Promise.all(mins).then (minified) -> {code: normal, code-min: minified.join('')}

      .then ({code, code-min}) ~>
        Promise.all [fs.write-file(des, code), fs.write-file(des-min, code-min)]
          .then ~>
            # the store announces the url change; pug listens and re-renders the pages
            # that embedded it. bundles are in no page's pug dependency graph, so
            # nothing else could notice.
            if !@store => return {}
            {code: @store.put(des, code), min: @store.put(des-min, code-min)}
      .then (out) ~>
        elapsed = Date.now! - t1
        @log.info "bundle #des ( #{fs.stat-sync(des).size} bytes / #{elapsed}ms )"
        @log.info "bundle #des-min ( #{fs.stat-sync(des-min).size} bytes / #{elapsed}ms )"
        {type, name, elapsed} <<< out
      .catch (e) ~>
        @log.error "#des failed: ".red
        @log.error {err: e}, e.message.toString!

build.des-path = ({desdir, name, type}) ->
  _desdir = path.join(desdir, \assets, \bundle)
  ext = if type == \block => \html else type
  des = path.join(_desdir, "#name.#ext")
  des-min = path.join(_desdir, "#name.min.#ext")
  # we may have subfolders in name
  desdir = path.dirname(des)
  return {desdir, des, des-min}

module.exports = build
