require! <[uglify-js uglifycss @plotdb/colors]>

# one place for every minifier call in this package.
#
# the reason it exists: `uglify-js.minify` does not throw on a syntax error, it returns
# `{error}` - with no `code` field at all. every call site used to read `.code` off that
# and get `undefined`, then either `or ''` it into an empty output file or `.join('')`
# it into a bundle, where `undefined` simply vanishes. a source file with a typo would
# disappear from the minified build with no log, no throw, and a perfectly fine
# unminified twin sitting next to it.
#
# so: never silently produce nothing. on failure hand back the input unchanged and say
# what happened. an unminified asset is bigger, not broken.

# {code, error, failed}. `code` is always a string worth writing:
# the minified form when it worked, the input when it did not.
minify = (type, code, opt = {}) ->
  if !code => return {code: '', failed: false}
  if type == \js =>
    ret = try
      uglify-js.minify code, opt
    catch e
      {error: e}
    # `ret.code` can legitimately be '' ( minifying whitespace-only input ), so test
    # `error` rather than the truthiness of `code`.
    if ret.error => return {code, error: ret.error, failed: true}
    return {code: (ret.code or ''), failed: false}
  else if type == \css =>
    try
      return {code: uglifycss.processString(code, uglyComments: true), failed: false}
    catch e
      return {code, error: e, failed: true}
  # not a type we minify: pass through.
  return {code, failed: false}

# the shape a caller usually wants: log on failure, always get a string back.
minify.or-original = (type, code, opt, log, what) ->
  ret = minify type, code, opt
  if ret.failed and log =>
    log.error "minify #type failed#{if what => " ( #what )" else ''}: #{ret.error?.message or ret.error}. left unminified.".red
  return ret.code

module.exports = minify
