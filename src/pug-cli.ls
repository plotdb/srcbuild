require! <[fs fs-extra path yargs pug]>
pugbuild = require "./ext/pug"
opt = {basedir: '.', init-scan: false}
argv = yargs
  .option \base, do
    alias: \b
    description: "base directory"
    type: \string
  .option \output, do
    alias: \o
    description: "output filename"
    type: \string
  .check (argv, options) ->
    if !(argv._.0 and fs.exists-sync(argv._.0)) => throw new Error("source file not found")
    return true
  .argv
src = argv._.0
des = argv.o
basedir = argv.b or path.dirname(src) or '.'
builder = new pugbuild opt
extapi = builder.get-extapi!
ret = pug.render(
  fs.read-file-sync(src).toString!,
  {} <<< {filename: src, basedir: opt.basedir, doctype: \html, compileDebug: false} <<< extapi
)
if des =>
  fs-extra.ensure-dir-sync path.dirname(des)
  fs.write-file-sync des, ret
else console.log ret
