require! <[fs path stream fs-extra livescript uglify-js @plotdb/colors]>
require! <[./base ../aux ../adapter]>

glslify = null
browserify = null

lscbuild = (opt={}) ->
  @ <<< opt{use-glslify}
  if @use-glslify and !glslify =>
    glslify := require "glslify"
    browserify := require "browserify"
  @init({srcdir: 'src/ls', desdir: 'static/js'} <<< opt)

lscbuild.prototype = Object.create(base.prototype) <<< do
  get-dependencies: (file) -> return []
  is-supported: (file) -> /\.ls$/.exec(file) and file.startsWith(@srcdir)
  resolve: (file) ->
    re = new RegExp("^#{@desdir}/(.+?)(\.min)?\.js")
    ret = re.exec(file)
    if ret => return path.join(@srcdir, "#{ret.1}.ls")
    return null
  map: (file) ->
    src: file
    des: file.replace(@srcdir, @desdir).replace(/\.ls$/, '.js')
    des-min: file.replace(@srcdir, @desdir).replace(/\.ls$/, '.min.js')
  build: (files) ->
    Promise.all files.map ({file, mtime}) ~>
      {src, des, des-min} = @map(file)
      t1 = Date.now!
      Promise.resolve!
        .then ~>
          if !fs.exists-sync(src) or aux.newer(des, mtime) => return Promise.resolve!
          code = fs.read-file-sync src .toString!
          desdir = path.dirname(des)
          fs-extra.ensure-dir-sync desdir
          code = livescript.compile(fs.read-file-sync(src)toString!,{bare: true, header: false})
          if !@use-glslify => return Promise.resolve code

          (res, rej) <~ new Promise _
          s = new stream.Readable!
          s.push code
          s.push null
          # module lookup from src file directory.
          bobj = browserify s, {basedir: path.dirname(src)}
          bobj.transform \glslify
          bobj.bundle (e, b) -> if e => return rej e else res b

        .then (code) ~>
          if !code => return
          code-min = uglify-js.minify(code).code or ''
          fs.write-file-sync des, code
          fs.write-file-sync des-min, code-min
          t2 = Date.now!
          @log.info "#src --> #des / #des-min ( #{t2 - t1}ms )"

        .catch (e) ~>
          @log.error "#src failed: ".red
          @log.error e.message.toString!

  purge: (files) ->
    for {file, mtime} in files =>
      {src,des,des-min} = @map(file)
      [des,des-min].filter (f) ~>
        if !fs.exists-sync f => return
        fs.unlink-sync f
        @log.warn "#src --> #f deleted.".yellow

module.exports = lscbuild
