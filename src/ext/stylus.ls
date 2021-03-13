require! <[fs path fs-extra stylus uglifycss]>
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
      .map -> it
    root = path.resolve('.') + '/'
    return (ret or []).map ~> it.replace(root, '')
  is-supported: (file) -> /\.styl$/.exec(file) and file.startsWith(@srcdir)
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
            @log.info "build: #src --> #des / #des-min ( #{t2 - t1}ms )"
      catch
        @log.error "build #src failed: "
        @log.error e.message.toString!
  unlink: (files) ->
    for {file, mtime} in files =>
      {src,des,des-min} = @map(file)
      [des,des-min].filter (f) ->
        if !fs.exists-sync f => return
        fs.unlink-sync f
        @log.warn "#src --> #f deleted."

module.exports = stylusbuild
