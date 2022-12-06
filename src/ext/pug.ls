require! <[fs path fs-extra pug livescript uglify-js uglifycss stylus js-yaml marked crypto @plotdb/colors]>
require! <[./base ../aux]>

cwd = process.cwd!

pugbuild = (opt={}) ->
  @i18n = opt.i18n or null
  @intlbase = opt.intlbase or 'intl'
  @filters = opt.filters or {}
  @extapi = @get-extapi! # get-dependencies use this, so we should init it before @init
  @bundler = opt.bundler
  @init({srcdir: 'src/pug', desdir: 'static'} <<< opt)
  @viewdir = path.normalize(path.join(@base, opt.viewdir or '.view'))
  @_no-view = opt.no-view or false
  @

pugbuild.prototype = Object.create(base.prototype) <<< do
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
    ret = do
      plugins: [{
        resolve: (...args) ~> @pug-resolve.apply @, args
        postParse: (dom, opt) ->
          if !(dom.nodes.0 and dom.nodes.0.type == \Doctype) => return dom
          dom.nodes.splice 1, 0 {
            type: \Include, block: { type: 'Block', nodes: [] }
            file: {type: \FileReference, filename: opt.filename, path: '@/@plotdb/srcbuild/dist/lib.pug'}
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
            @bundler.add-spec spec
            des = @bundler.des-path spec
            if o.type == \css
              ret += """<link rel="stylesheet" type="text/css" href="#{des.des-min}"/>"""
            else if o.type == \js
              ret += """<script type="text/javascript" src="#{des.des-min}"></script>"""
            else if o.type == \block
              # TODO
              ret += """<link rel="block" href="/assets/bundle/#{des.des-min}">"""
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
          if !fs.exists-sync(src) or aux.newer((if @_no-view => desh else desv), mtime) => continue
          code = fs.read-file-sync src .toString!
          try
            t1 = Date.now!
            if /^\/\/- ?module ?/.exec(code) => continue
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

    lngs = ([''] ++ (if @i18n => @i18n.{}options.lng or [] else []))
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
          [desh,desv].filter (f) ~>
            if !fs.exists-sync f => return
            fs.unlink-sync f
            @log.warn "#src --> #f deleted.".yellow

    lngs = ([''] ++ (if @i18n => @i18n.{}options.lng or [] else []))
    consume = (i = 0) ->
      if i >= lngs.length => return Promise.resolve!
      _(lngs[i]).then -> consume(i + 1)
    consume!


module.exports = pugbuild
