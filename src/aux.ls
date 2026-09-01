require! <[fs @plotdb/colors]>
aux = do
  # is f1 newer than any file in files?
  # or, is f1 newer than files ( as timestamp )?
  # strict: false for >=, or true for >
  newer: (f1, files = [], strict = false) ->
    if !fs.exists-sync(f1) => return false
    mtime = +fs.stat-sync(f1).mtime # `+` convert to timestamp
    if (files instanceof Date) or typeof(files) == \number =>
      dtime = (mtime - +files) # `+` convert to timestamp
      return if strict => dtime > 0 else dtime >= 0
    files = if Array.isArray(files) => files else [files]
    return files.length == files
      .filter (f2) ->
        if !fs.exists-sync(f2) => return true
        dtime = mtime - +fs.stat-sync(f2).mtime # `+` convert to timestamp
        if strict => dtime > 0 else dtime >= 0
      .length

aux.logger = log = {}
[<[info green]> <[warn yellow]> <[error red]>].map (n) ->
  log[n.0] = (...args) ->
    args = ( ["#{n.0.toUpperCase![n.1]}\t: [build]"] ++ args)
    console[n.0].apply console, args

# junk no project ever wants built, copied or watched. always applied, with
# `opt.ignored` appended - a whitelist-free builder ( `ext: '*'` ) would otherwise
# happily ship a `.DS_Store` into the document root.
#
# every pattern is written `**/x`, which matches both a bare basename and a full path.
# that matters: chokidar tests full paths, while the initial scan in `adapter.init`
# tests the basenames it gets back from `readdir`.
aux.junk = <[**/.git **/.git/** **/.DS_Store **/Thumbs.db **/*.swp **/*~]>

aux.ignored = (ignored) ->
  aux.junk ++ (if !ignored => [] else if Array.isArray(ignored) => ignored else [ignored])

module.exports = aux
