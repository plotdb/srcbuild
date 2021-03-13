require! <[fs path fs-extra pug livescript stylus js-yaml marked]>
require! <[./base ../aux]>

pugbuild = (opt={}) ->
  @i18n = opt.i18n or null
  @intlbase = opt.intlbase or 'intl'
  @extapi = @get-extapi! # get-dependencies use this, so we should init it before @init
  @init({srcdir: 'src/pug', desdir: 'static'} <<< opt)
  @viewdir = path.normalize(path.join(@base, opt.viewdir or '.view'))
  @

pugbuild.prototype = Object.create(base.prototype) <<< do
  resolve: (fn,src,opt) ->
    if !/^@/.exec(fn) => return path.resolve(path.join(path.dirname(src), fn))
    try
      if /^@\//.exec(fn) =>
        return require.resolve(fn.replace /^@\//, "")
      else if /^@static\//.exec(fn) =>
        des = "/" + path.join(@srcdir.split('/').filter(->it).map(-> '..').join('/'), @desdir)
        return path.resolve(path.join(path.dirname(src), fn.replace(/^@static/,des)))
    catch e
      throw new Error("no such file or directory: #fn")

  get-extapi: ->
    ret = do
      plugins: [{resolve: (...args) ~> @resolve.apply @, args}]
      filters: do
        'lsc': (text, opt) -> return livescript.compile(text,{bare:true,header:false})
        'lson': (text, opt) -> return livescript.compile(text,{bare:true,header:false,json:true})
        'stylus': (text, opt) ->
           stylus(text)
             .set \filename, 'inline'
             .define 'index', (a,b) ->
               a = (a.string or a.val).split(' ')
               return new stylus.nodes.Unit(a.indexOf b.val)
             .render!
        'md': (text, opt) -> marked text
      md: marked
      yaml: -> js-yaml.safe-load fs.read-file-sync it
      yamls: (dir) ~>
        ret = fs.readdir-sync dir
          .map -> "#dir/#it"
          .filter -> /\.yaml$/.exec(it)
          .map ~>
            try
              js-yaml.safe-load(fs.read-file-sync it)
            catch e
              @log.error "[ERROR@#it]: ", e
        return ret

    if @i18n =>
      ret.i18n = ~> @i18n.t((it or '').trim!)
      ret.intlbase = (p = "") ~> if @i18n.language => path.join(@intlbase, opt.i18n.language,p) else p
      ret.{}filters.i18n = (t, o) -> @i18n.t((t or '').trim!)

    return ret

  get-dependencies: (file) ->
    code = fs.read-file-sync file
    ret = pug.compileClientWithDependenciesTracked(
      code,
      {basedir: path.join(path.dirname file), filename: file} <<< @extapi
    )
    root = path.resolve('.') + '/'
    return (ret.dependencies or []).map ~> it.replace(root, '')

  is-supported: (file) -> /\.pug$/.exec(file) and file.startsWith(@srcdir)

  map: (file) ->
    src: file
    desh: file.replace(@srcdir, @desdir).replace(/.pug$/, '.html')
    desv: file.replace(@srcdir, @viewdir).replace(/.pug/, '.js')

  build: (files) ->
    _ = (lng = '') ~>
      intl = if lng => path.join(@intlbase,lng) else ''
      p = if @i18n and @i18n.changeLanguage =>
        @i18n.changeLanguage(if lng => that else @i18n.{}options.fallbackLng)
      else Promise.resolve!
      p.then ~>
        for {file, mtime} in files =>
          {src, desh, desv} = @map file
          if !fs.exists-sync(src) or aux.newer(desv, mtime) => continue
          code = fs.read-file-sync src .toString!
          try
            t1 = Date.now!
            if /^\/\/- ?module ?/.exec(code) => continue
            desvdir = path.dirname(desv)
            fs-extra.ensure-dir-sync desvdir
            ret = pug.compileClient code, {filename: src, basedir: @srcdir} <<< @extapi
            ret = """ (function() { #ret; module.exports = template; })() """
            fs.write-file-sync desv, ret
            t2 = Date.now!
            @log.info "build: #src --> #desv ( #{t2 - t1}ms )"
            if !(/^\/\/- ?view ?/.exec(code)) =>
              desdir = path.dirname(desh)
              fs-extra.ensure-dir-sync desdir
              fs.write-file-sync(
                desh, pug.render code, {filename: src, basedir: @srcdir} <<< @extapi
              )
              t2 = Date.now!
              @log.info "build: #src --> #desh ( #{t2 - t1}ms )"
          catch
            @log.error "build #src failed: "
            @log.error e.message.toString!


    lngs = ([''] ++ (if @i18n => @i18n.{}options.lng or [] else []))
    consume = (i = 0) ->
      if i >= lngs.length => return
      _(lngs[i]).then -> consume(i + 1)
    consume!
  purge: (files) ->
    for {file,mtime} in files =>
      {src,desh,desv} = @map file
      [desh,desv].filter (f) ~>
        if !fs.exists-sync f => return
        fs.unlink-sync f
        @log.warn "#src --> #f deleted."


module.exports = pugbuild
