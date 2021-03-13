require! <[fs path fs-extra livescript uglify-js]>
require! <[./base ../aux ../adapter]>


lscbuild = (opt={}) -> @init({srcdir: 'src/ls', desdir: 'static/js'} <<< opt)
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
    for {file, mtime} in files =>
      {src, des, des-min} = @map(file)
      if !fs.exists-sync(src) or aux.newer(des, mtime) => continue
      try
        t1 = Date.now!
        code = fs.read-file-sync src .toString!
        desdir = path.dirname(des)
        fs-extra.ensure-dir-sync desdir
        code = livescript.compile(fs.read-file-sync(src)toString!,{bare: true, header: false})
        code-min = uglify-js.minify(code).code
        fs.write-file-sync des, code
        fs.write-file-sync des-min, code-min
        t2 = Date.now!
        @log.info "build: #src --> #des / #des-min ( #{t2 - t1}ms )"
      catch
        @log.error "build #src failed: "
        @log.error e.message.toString!
  purge: (files) ->
    for {file, mtime} in files =>
      {src,des,des-min} = @map(file)
      [des,des-min].filter (f) ~>
        if !fs.exists-sync f => return
        fs.unlink-sync f
        @log.warn "purge: #src --> #f deleted."

module.exports = lscbuild
