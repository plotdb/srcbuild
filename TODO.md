 - track files failed to `get-dependencies` and retry each time a new change event is fired.
 - custom functions access files relative to module root instead of relative to source file.
   - have to access locals to resolve correct path
 - glslify should not be plugged directly inside `lscbuild`.
   - We should remove it, and perhaps make it a independent builder


## Tailwind Consideration

We can try generate tailwind-based css automatically.

Yet Tailwind doesn't provide string-based conversion API, but we can use Unocss:

    require! <[pug fs]>
    (unocss) <- ``import('unocss')`` .then _
    html = pug.render fs.read-file-sync("index.pug").toString!, {}
    (uno) <- unocss.createGenerator presets: [unocss.presetWind!] .then _
    uno.generate html .then -> console.log it.css

for a whole-site generation, union result of available files from uno (pseudo code):

    some-map = new Map! # file > uno obj
    bundle = (files) ->
      objs = files.map (f) -> some-map(f)
      uno.generate objs
    watch = (file, is-delete) ->
      if is-delete => some-map file .remove!
      else some-map(file).set uno.generate htmlfrom(file)
