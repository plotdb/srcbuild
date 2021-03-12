require! <[fs ./srcbuild ./srcwatch ./aux]>
pugbuild = require "./ext/pug"
stylusbuild = require "./ext/stylus"
lscbuild = require "./ext/lsc"

base = 'web'
builders = [
  new pugbuild {base}
  new stylusbuild {base}
  new lscbuild {base}
].map -> it.get-builder!

new srcwatch {builders}
