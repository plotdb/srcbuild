require! <[fs path fs-extra @plotdb/colors]>
require! <[./base ../aux ../adapter]>

assetbuild = (opt={}) ->
  @_ext = opt.ext or <[png gif jpg svg json]>
  @init({srcdir: 'src/assets', desdir: 'static/assets'} <<< opt)
  @_re = new RegExp("^#{@desdir}/(.+?\.(?:#{@_ext.join('|')}))$")
  @
assetbuild.prototype = Object.create(base.prototype) <<< do
  get-dependencies: (file) -> return []
  is-supported: (file) -> ((file.split(\.)[* - 1] or '') in @_ext) and file.startsWith(@srcdir)
  resolve: (file) ->
    if !(ret = @_re.exec(file)) => return null
    return path.join(@srcdir, "#{ret.1}")
  map: (file) ->
    src: file
    des: file.replace(@srcdir, @desdir)
  build: (files) ->
    for {file, mtime} in files =>
      try
        {src,des} = @map file
        if !fs.exists-sync(src) or aux.newer(des, mtime) => continue
        t1 = Date.now!
        desdir = path.dirname des
        fs-extra.ensure-dir-sync desdir
        fs-extra.copy-sync src, des
        t2 = Date.now!
        @log.info "#src --> #des ( #{t2 - t1}ms )"
      catch
        @log.error "#src failed: ".red
        @log.error e.message.toString!
  purge: (files) ->
    for {file, mtime} in files =>
      {src,des} = @map file
      if !fs.exists-sync des => return
      fs.unlink-sync des
      @log.warn "#src --> #des deleted.".yellow

module.exports = assetbuild
