require! <[fs path fs-extra livescript uglify-js]>
require! <[../aux ../srcbuild]>

lscbuild = (opt={}) ->
  @opt = opt
  @log = opt.logger or aux.logger
  @base = opt.base or '.'
  @srcdir = path.normalize(path.join(@base, opt.srcdir or 'src/ls'))
  @desdir = path.normalize(path.join(@base, opt.desdir or 'static/js'))
  @builder = new srcbuild do
    base: @srcdir
    get-dependencies: (file) ~> return []
    is-supported: (file) ~> /\.ls$/.exec(file) and file.startsWith(@srcdir)
    build: (files) ~> @build files
  @builder.init!
  @

lscbuild.prototype = Object.create(Object.prototype) <<< do
  get-builder: -> @builder
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
        @log.info "[BUILD] #src --> #des / #des-min ( #{t2 - t1}ms )"
      catch
        @log.error "[BUILD] #src failed: "
        @log.error e.message.toString!
    return

module.exports = lscbuild
