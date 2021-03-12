require! <[fs]>
aux = do
  logger: {info: console.info, warn: console.warn, error: console.error}
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

module.exports = aux
