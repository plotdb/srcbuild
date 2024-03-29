require! <[fs path fs-extra stylus uglifycss @plotdb/colors]>
require! <[./base ../aux ../adapter]>

stylusbuild = (opt={}) -> @init({srcdir: 'src/styl', desdir: 'static/css'} <<< opt)
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
  build: (files) ->
    for {file, mtime} in files =>
      {src,des,des-min} = @map file
      if !fs.exists-sync(src) or aux.newer(des, mtime) => continue
      try
        t1 = Date.now!
        code = fs.read-file-sync src .toString!
        if /^\/\/- ?(module) ?/.exec(code) => continue
        desdir = path.dirname(des)
        fs-extra.ensure-dir-sync desdir
        stylus code
          .set \filename, src
          .render (e, css) ~>
            if e => throw e
            code-min = uglifycss.processString(css, uglyComments: true)
            fs.write-file-sync des, css
            fs.write-file-sync des-min, code-min
            t2 = Date.now!
            @log.info "#src --> #des / #des-min ( #{t2 - t1}ms )"
      catch
        @log.error "#src failed: ".red
        @log.error e.message.toString!
  purge: (files) ->
    for {file, mtime} in files =>
      {src,des,des-min} = @map(file)
      [des,des-min].filter (f) ~>
        if !fs.exists-sync f => return
        fs.unlink-sync f
        @log.warn "#src --> #f deleted.".yellow

module.exports = stylusbuild
