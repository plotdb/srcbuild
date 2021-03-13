# srcbuild

building source files.


## Usage


## Custom Adapter

extend base builder for a customized builder:

    base = require("@plotdb/srcbuild").base

    mybuild = (opt = {}) -> @init({srcdir: 'src', desdir: 'des'} <<< opt)
    mybuild.prototype = Object.create(base.prototype) <<< {
      is-supported: (file) -> return true
      get-dependencies: (file) -> return []
      build: (files) -> # build will be called if is supported.
    }

check `src/ext/lsc.ls` or `src/ext/pug.ls` for example. 


## License

MIT
