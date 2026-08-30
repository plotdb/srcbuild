require! <[fs path fs-extra pug livescript uglify-js uglifycss stylus js-yaml marked crypto @plotdb/colors]>
require! <[./base ../aux ./bundle ../hashstore]>

cwd = process.cwd!

# the lib.pug injected into every doctype'd page, as pug resolves it ( see `pug-resolve`
# and the `postParse` plugin below ).
libpug = '@/@plotdb/srcbuild/dist/lib.pug'

pugbuild = (opt={}) ->
  @i18n = opt.i18n or null
  @intlbase = opt.intlbase or 'intl'
  @filters = opt.filters or {}
  @locals = opt.locals or {}
  @extapi = @get-extapi! # get-dependencies use this, so we should init it before @init
  @bundler = opt.bundler
  @store = opt.store or null
  # url -> the pug files that embedded it, when there is no store to persist it in
  # ( the express view engine ). the store is the authority whenever one is wired in:
  # these refs are only recorded while a page is actually rendered, so keeping them in
  # memory alone leaves them empty after a warm start - which is exactly when the first
  # edit needs them.
  @urlrefs = {}
  @init({srcdir: 'src/pug', desdir: 'static'} <<< opt)
  @viewdir = path.normalize(path.join(@base, opt.viewdir or '.view'))
  @_no-view = opt.no-view or false
  @_build-intl = if opt.build-intl? => opt.build-intl else true
  @check-libpug!
  @

pugbuild.prototype = Object.create(base.prototype) <<< do
  # `lib.pug` is injected by path, resolved from the *frontend root* - so whichever copy
  # of srcbuild lands in `<base>/node_modules` wins, no matter which one is running.
  # a stale copy there is silent: pages build, nothing errors, and any feature that
  # lives in lib.pug ( `asseturl`, `bundleurl`, `hashfile` ) is simply absent.
  # so say so, once, with both paths.
  check-libpug: ->
    mine = path.join(__dirname, '..', 'lib.pug')
    try
      theirs = require.resolve libpug.replace(/^@\//, ''), {paths: [@base]}
    catch e
      return @log.warn "cannot resolve #libpug from #{@base}: #{e.message}".yellow
    if !fs.exists-sync(mine) or path.resolve(mine) == path.resolve(theirs) => return
    try
      if fs.read-file-sync(mine).toString! == fs.read-file-sync(theirs).toString! => return
    catch e
      return
    ver = (p) -> try require(path.join(path.dirname(p), '..', 'package.json')).version catch e then '?'
    @log.warn "the injected lib.pug is not the one shipped with this srcbuild.".yellow
    @log.warn "  running : #mine ( #{ver mine} )".yellow
    @log.warn "  injected: #theirs ( #{ver theirs} )".yellow
    @log.warn "  it is resolved from the frontend root, so that copy wins.".yellow

  # remember that `src` embedded `url`, so a later hash change can find it again.
  ref-url: (url, src) ->
    if !(url and src) => return
    if (store = @get-store!) => return store.add-ref url, src
    (if @urlrefs[url] => that else @urlrefs[url] = new Set!).add src

  refs-of: (url) ->
    if (store = @get-store!) => return store.refs-of url
    return Array.from(@urlrefs[url] or [])

  # a built file's content hash moved. re-render whatever embedded its url. only fired
  # when the hash actually changed, so page -> asset -> page settles in one pass.
  # the count is logged even when it is zero: a silently empty index is what made the
  # memory-only version of this look like it was working.
  invalidate-url: (url) ->
    files = @refs-of(url).filter -> fs.exists-sync it
    @log.info "#{path.join(@desdir, url)} changed --> #{files.length} page(s) embed it"
    if !files.length => return Promise.resolve!
    @adapter.change files, {force: true}

  # `store` may be a function: a host that builds its express view engine before
  # `lsp` has run can hand us a getter instead of an instance.
  get-store: -> if typeof(@store) == \function => @store! else @store

  # the content-addressed url for a plain one, or null if it was never built.
  asset-url: (url) ->
    if (store = @get-store!) => return store.get url
    return @load-manifest![url] or null

  bundle-url: ({type, name, min = true}) ->
    des = bundle.des-path {desdir: @desdir, name, type}
    return @asset-url @url-of(if min => des.des-min else des.des)

  url-of: (file) -> '/' + path.relative(@desdir, path.normalize file).split(path.sep).join('/')

  # no store wired in ( the express view engine builds its own pug builder, and the
  # assets may even be produced by another process ), so read the manifest off disk.
  # keyed on mtime, so a render costs a stat and not a parse.
  load-manifest: ->
    fn = hashstore.manifest-path @base
    try
      mtime = +fs.stat-sync(fn).mtime
    catch e
      return @_manifest = {}
    if @_manifest and @_manifest-mtime == mtime => return @_manifest
    try
      raw = JSON.parse(fs.read-file-sync(fn).toString!)
      @_manifest = {[k, (v or {}).url] for k, v of raw}
      @_manifest-mtime = mtime
    catch e
      @log.error "parse error of hash manifest #fn".red
      @_manifest = {}
    return @_manifest

  pug-resolve: (fn,src,opt) ->
    try
      if /^@\//.exec(fn) => return require.resolve(fn.replace(/^@\//, ""), {paths: [@base]})
      else if /^@static\//.exec(fn) => return path.resolve(fn.replace(/^@static/,@desdir))
      else if /^@/.exec(fn) => throw new Error('path starting with `@` is reserved. please use other pathname.')
      else if /^\//.exec(fn) => return path.resolve(path.join(opt.basedir, fn))
      else return path.resolve(path.join(path.dirname(src), fn))
    catch e
      throw new Error("error when looking up #fn: #{e.toString!}")

  get-extapi: ->
    ret = {} <<< (@locals or {}) <<< do
      plugins: [{
        resolve: (...args) ~> @pug-resolve.apply @, args
        postParse: (dom, opt) ->
          if !(dom.nodes.0 and dom.nodes.0.type == \Doctype) => return dom
          dom.nodes.splice 1, 0 {
            type: \Include, block: { type: 'Block', nodes: [] }
            file: {type: \FileReference, filename: opt.filename, path: libpug}
          }
          return dom
      }]
      filters: (@filters or {}) <<< do
        'bundle': (text, _opt) ~>
          # we keep bundling in complie time so it will be
          #  - fast, since we won't trigger bundling each time a view is rendered.
          #  - safe, since it's impossible to change the files to bundle and load.
          opts = if Array.isArray(_opt.options) => _opt.options else [_opt.options]
          opts = opts.filter(->it and it.type in <[js css block]>)
          ret = ""
          opts.for-each (o) ~>
            list = o.files
            list.for-each (d) -> if !d.type => d.type = o.type
            # sorting makes the md5 hashing stable, but order in js/css is important
            # so we onlt sort block bundling here.
            if o.type == \block and !(o.sort? or o.sort) =>
              list.sort (a,b) ->
                for n in <[ns name version path]> =>
                  [c,d] = [a[n] or '', b[n] or '']
                  if c < d => return -1 else if c > d => return 1
                return 0
            if o.name => name = o.name
            else
              # add `type` so we never have to worry if bundle names collides between different types
              # TODO how to avoid the still possible hash collision?
              str = "#{o.type}:" + list.join(';')
              name = crypto.createHash \md5 .update str .digest \hex
              # 2 level hierarchy
              name = path.join(name.substring(0,4), name.substring(4))
            spec = {name: name, type: o.type, src: list, specsrc: _opt.filename}
            if @bundler =>
              @bundler.add-spec spec
              des = @bundler.des-path spec
            else
              # TODO the actual bundler may have different desdir. use this anyway for now.
              des = bundle.des-path {desdir: @desdir} <<< spec
            # prefer the content-addressed url so the page can be cached hard. it is
            # null until the bundle has actually been built ( cold start ); the plain
            # name is the fallback, and the rebuild triggered by `url-change` replaces
            # it once the hash is known.
            plain = "/#{path.relative(@desdir, des.des-min)}"
            @ref-url plain, _opt.filename
            url = @bundle-url({type: o.type, name}) or plain
            if o.type == \css
              ret += """<link rel="stylesheet" type="text/css" href="#url"/>"""
            else if o.type == \js
              ret += """<script type="text/javascript" src="#url"></script>"""
            else if o.type == \block
              ret += """<link rel="block" href="#url">"""

          return ret
        'lsc': (text, opt) ->
          code = livescript.compile(text,{bare:true,header:false})
          # we may need an option to turn off uglify-js but for now we will enable it by default.
          # we disable `compress` since we may somehow postprocess code in function ( such as in `@plotdb/block` )
          # yet some code we need may be treated as unused and  removed by compress option
          code-min = uglify-js.minify(code,{compress:false}).code or ''
          return code-min
        'lson': (text, opt) -> return livescript.compile(text,{bare:true,header:false,json:true})
        'stylus': (text, opt) ->
          code = stylus(text)
            .set \filename, 'inline'
            .define 'index', (a,b) ->
              a = (a.string or a.val).split(' ')
              return new stylus.nodes.Unit(a.indexOf b.val)
            .render!
          code-min = uglifycss.processString(code, uglyComments: true)
        'md': (text, opt) -> marked.parse text
      json: -> JSON.parse(fs.read-file-sync it)
      md: marked.parse
      yaml: -> js-yaml.load fs.read-file-sync it
      yamls: (dir) ~>
        ret = fs.readdir-sync dir
          .map -> "#dir/#it"
          .filter -> /\.yaml$/.exec(it)
          .map ~>
            try
              js-yaml.load(fs.read-file-sync it)
            catch e
              @log.error "[ERROR@#it]: ", e
        return ret
      md5: (str) -> crypto.createHash \md5 .update str .digest \hex
      # the content-addressed url of a bundle, or null if it isn't built yet. the same
      # helper serves both modes: static bakes the value in ( and gets re-rendered when
      # the hash moves ), the view engine looks it up on every render.
      bundleurl: ({type, name, min = true, src}) ~>
        # `des-min` is a livescript identifier, so the key on the returned object is
        # `desMin` - it cannot be reached with a string index.
        d = bundle.des-path {desdir: @desdir, name, type}
        @ref-url @url-of(if min => d.des-min else d.des), src
        @bundle-url {type, name, min}
      # the same lookup for a plain built file - `/js/site.min.js`, `/css/index.min.css`.
      # returns the url unchanged when there is no hashed twin, so callers can use it
      # unconditionally.
      asseturl: (url, src) ~>
        if !url or /^(https?:)?\/\//.exec(url) => return url
        @ref-url url, src
        return @asset-url(url) or url
      hashfile: ({type, name, files, src}) ~>
        if !@bundler => return
        files = files.map (file) ~>
          if /^https?:/.exec(file.url or file) =>
            return file.url or file
          if file.url or typeof(file) == \string =>
            return path.join(@desdir, file.url or file)
          if typeof(file) == \object => return {type} <<< file
          return file
        spec = {type, name, src: files, specsrc: [src]}
        @bundler.add-spec spec

    if @i18n =>
      ret.i18n = ~> @i18n.t((it or '').trim!)
      ret.i18n.language = ~> @i18n.language
      ret.i18n.intlbase = (p = "", lng = "") ~>
        if !(lng = lng or @i18n.language) => return p
        path.join(\/, @intlbase, lng, p)
      # deprecated. use i18n.intlbase instead.
      ret.intlbase = (p = "", lng = "") ~>
        if !(lng = lng or @i18n.language) => return p
        path.join(\/, @intlbase, lng, p)
      ret.{}filters.i18n = (t, o) ~> @i18n.t((t or '').trim!)

    return ret

  get-dependencies: (file) ->
    code = fs.read-file-sync file
    opt = {
      basedir: path.resolve(@srcdir)
      filename: file
      doctype: \html
      compileDebug: false
    } <<< @extapi
    ret = pug.compileClientWithDependenciesTracked(code, opt)
    root = path.resolve('.') + '/'
    return (ret.dependencies or []).map ~> it.replace(root, '')

  is-supported: (file) -> /\.pug$/.exec(file) and file.startsWith(@srcdir)

  resolve: (file) ->
    res = [
      "^#{@desdir}/#{@intlbase}/[^/]+/(.+)\.html$"
      "^#{@viewdir}/#{@intlbase}/[^/]+/(.+)\.js$"
      "^#{@desdir}/(.+)\.html$"
      "^#{@viewdir}/(.+)\.js$"
    ].map -> new RegExp it
    for re in res =>
      ret = re.exec(file)
      if ret => return path.join(@srcdir, "#{ret.1}.pug")
    return null

  map: (file, intl) ->
    # this may be inaccurate but will work most of the time.
    # TODO try a better approach
    if ~file.indexOf(@srcdir) =>
      src: file
      desh: file.replace(@srcdir, path.join(@desdir, intl)).replace(/.pug$/, '.html')
      desv: file.replace(@srcdir, path.join(@viewdir, intl)).replace(/.pug/, '.js')
    else # out of src dir - put under .@root
      alt = path.resolve(path.join('/', path.relative('.', file)))
      src: file
      desh: path.join(cwd, @desdir, \.@root, intl, alt).replace(/.pug$/, '.html')
      desv: path.join(cwd, @viewdir, \.@root, intl, alt).replace(/.pug$/, '.js')

  build: (files) ->
    _ = (lng = '') ~>
      intl = if lng => path.join(@intlbase,lng) else ''
      p = if @i18n and @i18n.changeLanguage =>
        @i18n.changeLanguage(if lng => that else @i18n.{}options.fallbackLng)
      else Promise.resolve!
      p.then ~>
        for {file, mtime} in files =>
          {src, desh, desv} = @map file, intl
          if !fs.exists-sync(src) => continue
          code = fs.read-file-sync src .toString!
          if /^\/\/- ?module ?/.exec(code) => continue
          # which outputs this file is supposed to produce. the guard used to look at
          # `desv` only, so a deleted / stale `desh` was never regenerated as long as the
          # precompiled view happened to be fresh.
          outs = []
          if !@_no-view => outs.push desv
          if !(/^\/\/- ?view ?/.exec(code)) => outs.push desh
          if outs.length and outs.filter(-> aux.newer(it, mtime)).length == outs.length => continue
          try
            t1 = Date.now!
            if !@_no-view =>
              desvdir = path.dirname(desv)
              fs-extra.ensure-dir-sync desvdir

              opt = {
                filename: src
                basedir: path.resolve(@srcdir)
                doctype: \html
                compileDebug: false
              } <<< @extapi

              ret = pug.compileClient(code, opt)
              ret = """ (function() { #ret; module.exports = template; })() """
              fs.write-file-sync desv, ret
              t2 = Date.now!
              @log.info "#src --> #desv ( #{t2 - t1}ms )"
            if !(/^\/\/- ?view ?/.exec(code)) =>
              desdir = path.dirname(desh)
              fs-extra.ensure-dir-sync desdir

              opt = {
                filename: src
                basedir: path.resolve(@srcdir)
                doctype: \html
                compileDebug: false
              } <<< @extapi

              fs.write-file-sync( desh, pug.render(code, opt) )
              t2 = Date.now!
              @log.info "#src --> #desh ( #{t2 - t1}ms )"
          catch e
            @log.error "#src failed: ".red
            @log.error e.message.toString!

    lngs = ([''] ++ (if @i18n and @_build-intl => @i18n.{}options.lng or [] else []))
    consume = (i = 0) ->
      if i >= lngs.length => return Promise.resolve!
      _(lngs[i]).then -> consume(i + 1)
    consume!

  purge: (files) ->
    _ = (lng = '') ~>
      intl = if lng => path.join(@intlbase,lng) else ''
      p = if @i18n and @i18n.changeLanguage =>
        @i18n.changeLanguage(if lng => that else @i18n.{}options.fallbackLng)
      else Promise.resolve!
      p.then ~>
        for {file,mtime} in files =>
          {src,desh,desv} = @map file, intl
          # this pug file declared bundles ( via the `bundle` filter / `hashfile` ).
          # nobody else knows they are orphaned now.
          if @bundler => @bundler.del-specsrc src
          if (store = @get-store!) => store.drop-ref src
          [desh,desv].filter (f) ~>
            if !fs.exists-sync f => return
            fs.unlink-sync f
            @log.warn "#src --> #f deleted.".yellow

    lngs = ([''] ++ (if @i18n and @_build-intl => @i18n.{}options.lng or [] else []))
    consume = (i = 0) ->
      if i >= lngs.length => return Promise.resolve!
      _(lngs[i]).then -> consume(i + 1)
    consume!


module.exports = pugbuild
