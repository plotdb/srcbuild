require! <[fs path fs-extra @plotdb/colors]>
require! <[./base ../aux ../adapter]>

# copies files from `srcdir` to `desdir` without touching them.
#
# two modes, and they exist for different jobs:
#  - an extension whitelist ( the default ) picks a few kinds of file out of a tree
#    that mostly holds something else. `src/pug/**.png -> static/**` is that: images
#    living next to the pug that uses them.
#  - `ext: '*'` copies the tree verbatim. that is what `raw` is: a tree whose whole
#    purpose is to land in the document root, where a whitelist is only a way to
#    silently fail to ship a file someone added.
assetbuild = (opt={}) ->
  @_ext = if opt.ext == '*' => null else (opt.ext or <[png gif jpg svg json]>)
  @init({srcdir: 'src/assets', desdir: 'static/assets'} <<< opt)
  @_re =
    if @_ext => new RegExp("^#{@desdir}/(.+?\.(?:#{@_ext.join('|')}))$")
    else new RegExp("^#{@desdir}/(.+)$")
  @
assetbuild.prototype = Object.create(base.prototype) <<< do
  get-dependencies: (file) -> return []
  is-supported: (file) ->
    if !file.startsWith(@srcdir) => return false
    if !@_ext => return true
    return ((file.split(\.)[* - 1] or '') in @_ext)
  resolve: (file) ->
    if !(ret = @_re.exec(file)) => return null
    src = path.join(@srcdir, "#{ret.1}")
    # `watch.demand` hands a wanted output to the first adapter that claims it. with
    # `ext: '*'` and `desdir: static`, this builder's claim is the entire document
    # root - it would answer for `static/index.html` and send the pug builder's page
    # to a `src/raw/index.html` that does not exist. owning an output means having
    # its source.
    if !fs.exists-sync(src) => return null
    return src
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
      # `continue`, not `return`: deleting a directory arrives as one batch of many
      # files, and the first one already gone used to abandon the rest of the batch.
      if !fs.exists-sync des => continue
      fs.unlink-sync des
      @log.warn "#src --> #des deleted.".yellow

module.exports = assetbuild
