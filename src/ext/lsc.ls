require! <[fs path fs-extra livescript uglify-js colors]>
require! <[./base ../aux ../adapter]>


lscbuild = (opt={}) -> @init({srcdir: 'src/ls', desdir: 'static/js'} <<< opt)
lscbuild.prototype = Object.create(base.prototype) <<< do
  get-dependencies: (file) -> return []
  is-supported: (file) -> /\.ls$/.exec(file) and file.startsWith(@srcdir)
  build: (files) ->
    for {file, mtime} in files =>
      src = file
      des = src.replace(@srcdir, @desdir).replace(/\.ls$/, '.js')
      des-min = src.replace(@srcdir, @desdir).replace(/\.ls$/, '.min.js')
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
        @log.info "#src --> #des / #des-min ( #{t2 - t1}ms )"
      catch
        @log.error "build #src failed: ".red
        @log.error e.message.toString!.red

module.exports = lscbuild
