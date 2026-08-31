require! <[fs path fs-extra stylus @plotdb/colors ../minify]>
require! <[./base ../aux ../adapter]>

stylusbuild = (opt={}) ->
  @ <<< opt{store}
  @init({srcdir: 'src/styl', desdir: 'static/css'} <<< opt)
stylusbuild.prototype = Object.create(base.prototype) <<< do
  get-dependencies: (file) ->
    code = fs.read-file-sync file .toString!
    ret = code
      .split \\n
      .map -> /\s*(@import)\s+(.+)$/.exec(it)
      .filter -> it
      .map -> it.2.replace(/'/g, '').replace(/(\.styl)?$/, '.styl')
      .map ~> path.join(@srcdir,it)
    root = path.resolve('.') + '/'
    return (ret or []).map ~> it.replace(root, '')
  is-supported: (file) -> /\.styl$/.exec(file) and file.startsWith(@srcdir)

  resolve: (file) ->
    re = new RegExp("^#{@desdir}/(.+?)(\.min)?\.css")
    ret = re.exec(file)
    if ret => return path.join(@srcdir, "#{ret.1}.styl")
    return null

  map: (file) ->
    src: file
    des: file.replace(@srcdir, @desdir).replace(/\.styl$/, '.css')
    des-min: file.replace(@srcdir, @desdir).replace(/\.styl$/, '.min.css')
  # returns a promise now: uglifycss runs on a worker thread ( see minify.ls ), so the
  # write cannot happen in the same tick as the render. that also makes this builder
  # report when it is actually done, which `adapter.change` passes up to `watcher.ready`.
  build: (files) ->
    Promise.all files.map ({file, mtime}) ~> @build-one file, mtime

  build-one: (file, mtime) ->
    {src,des,des-min} = @map file
    if !fs.exists-sync(src) or aux.newer(des, mtime) =>
      # up to date. adopt the outputs if the manifest was wiped from under them.
      if @store => [des, des-min].map ~> @store.ensure it
      return Promise.resolve!
    t1 = Date.now!
    Promise.resolve!
      .then ~>
        code = fs.read-file-sync src .toString!
        if /^\/\/- ?(module) ?/.exec(code) => return null
        fs-extra.ensure-dir-sync path.dirname(des)
        # stylus' `render` callback is synchronous, but throwing out of it only unwinds
        # into stylus. wrap it so the error reaches our `.catch`.
        (res, rej) <~ new Promise _
        stylus code
          .set \filename, src
          .render (e, css) -> if e => rej e else res css
      .then (css) ~>
        if css == null => return
        minify.async-or-original \css, css, {}, @log, src .then (code-min) ~>
          fs.write-file-sync des, css
          fs.write-file-sync des-min, code-min
          if @store =>
            @store.put des, css
            @store.put des-min, code-min
          @log.info "#src --> #des / #des-min ( #{Date.now! - t1}ms )"
      .catch (e) ~>
        @log.error "#src failed: ".red
        @log.error e.message.toString!
  purge: (files) ->
    for {file, mtime} in files =>
      {src,des,des-min} = @map(file)
      [des,des-min].filter (f) ~>
        if @store => @store.drop f
        if !fs.exists-sync f => return
        fs.unlink-sync f
        @log.warn "#src --> #f deleted.".yellow

module.exports = stylusbuild
