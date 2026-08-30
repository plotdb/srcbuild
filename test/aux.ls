require! <[fs path os fs-extra]>

# a silent logger: these tests deliberately drive error paths.
quiet = {}
<[info warn error]>.map (n) -> quiet[n] = ->

tmpdir = ->
  d = fs.mkdtemp-sync path.join(os.tmpdir!, 'srcbuild-test-')
  return d

write = (root, files) ->
  for name, content of files =>
    fn = path.join(root, name)
    fs-extra.ensure-dir-sync path.dirname(fn)
    fs.write-file-sync fn, content
  return root

# bump mtime of `fn` by `delta` ms so freshness comparisons are unambiguous.
touch = (fn, delta = 2000) ->
  t = new Date(Date.now! + delta)
  fs.utimes-sync fn, t, t
  return +t

module.exports = {quiet, tmpdir, write, touch}
