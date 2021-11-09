require! <[fs path fs-extra pug livescript uglify-js uglifycss stylus js-yaml marked colors]>
require! <[./base ../aux]>

pugbuild = (opt={}) ->
  @i18n = opt.i18n or null
  @intlbase = opt.intlbase or 'intl'
  @extapi = @get-extapi! # get-dependencies use this, so we should init it before @init
  @init({srcdir: 'src/pug', desdir: 'static'} <<< opt)
  @viewdir = path.normalize(path.join(@base, opt.viewdir or '.view'))
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
      plugins: [{resolve: (...args) ~> @pug-resolve.apply @, args}]
      filters: do
        'lsc': (text, opt) ->
          code = livescript.compile(text,{bare:true,header:false})
          # we may need an option to turn off uglify-js but for now we will enable it by default.
          code-min = uglify-js.minify(code).code or ''
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
        'md': (text, opt) -> marked text
      json: -> JSON.parse(fs.read-file-sync it)
      md: marked
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

    if @i18n =>
      ret.i18n = ~> @i18n.t((it or '').trim!)
      ret.i18n.language = ~> @i18n.language
      ret.i18n.intlbase = (p = "") ~> if @i18n.language => path.join(@intlbase, @i18n.language,p) else p
      # deprecated. use i18n.intlbase instead.
      ret.intlbase = (p = "") ~> if @i18n.language => path.join(@intlbase, @i18n.language,p) else p
      ret.{}filters.i18n = (t, o) ~> @i18n.t((t or '').trim!)

    return ret

  get-dependencies: (file) ->
    code = fs.read-file-sync file
    ret = pug.compileClientWithDependenciesTracked(
      code,
      {basedir: path.resolve(@srcdir), filename: file, doctype: \html} <<< @extapi
    )
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
    src: file
    desh: file.replace(@srcdir, path.join(@desdir, intl)).replace(/.pug$/, '.html')
    desv: file.replace(@srcdir, path.join(@viewdir, intl)).replace(/.pug/, '.js')

  build: (files) ->
    _ = (lng = '') ~>
      intl = if lng => path.join(@intlbase,lng) else ''
      p = if @i18n and @i18n.changeLanguage =>
        @i18n.changeLanguage(if lng => that else @i18n.{}options.fallbackLng)
      else Promise.resolve!
      p.then ~>
        for {file, mtime} in files =>
          {src, desh, desv} = @map file, intl
          if !fs.exists-sync(src) or aux.newer(desv, mtime) => continue
          code = fs.read-file-sync src .toString!
          try
            t1 = Date.now!
            if /^\/\/- ?module ?/.exec(code) => continue
            desvdir = path.dirname(desv)
            fs-extra.ensure-dir-sync desvdir
            ret = pug.compileClient code, {filename: src, basedir: path.resolve(@srcdir), doctype: \html} <<< @extapi
            ret = """ (function() { #ret; module.exports = template; })() """
            fs.write-file-sync desv, ret
            t2 = Date.now!
            @log.info "#src --> #desv ( #{t2 - t1}ms )"
            if !(/^\/\/- ?view ?/.exec(code)) =>
              desdir = path.dirname(desh)
              fs-extra.ensure-dir-sync desdir
              fs.write-file-sync(
                desh, pug.render code, {filename: src, basedir: path.resolve(@srcdir), doctype: \html} <<< @extapi
              )
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
