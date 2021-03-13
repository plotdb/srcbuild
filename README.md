# srcbuild

Source file tree builder.


## Usage

setup a lsp watcher:

    require! <[@plotdb/srcbuild]>
    srcbuild.lsp {base: 'web', logger: ...}

where

 - `base`: root dir for `src` and `static` folders. default `.`
 - `logger`: optional. for logging output. use `console.log` by default. 
   - sample logger with `pino`:

     require! <[@plotdb/srcbuild pino]>
     srcbuild.lsp({pino({level: 'debug'})})



## Custom Adapter

extend base builder for a customized builder:

    base = require("@plotdb/srcbuild").base

    mybuild = (opt = {}) -> @init({srcdir: 'src', desdir: 'des'} <<< opt)
    mybuild.prototype = Object.create(base.prototype) <<< {
      is-supported: (file) -> return true
      get-dependencies: (file) -> return []
      build: (files) -> # build will be called if is supported.
    }

with following user-defined functions:

 - is-supported(file): return true if `file` is supported by this builder, otherwise return false.
   - `file`: file name for file to be verified. Relative to cwd. 
 - get-dependencies(file): return a list of files that this file depends on.
   - `file`: same as `is-supported`
 - build(files): should compile / generate target files of given file list `files`.
   - `files`: a list of objects corresponding to files to be compiled, with following fields:
     - `file`: path of the file to be built, relative to cwd.
     - `mtime`: timestamp of the modified time of this file. may be modified time of its dependencies.
 - purge(files): should remove generated files corresponding to files listed in `files`.
   - `files`: same as `build`.

check `src/ext/lsc.ls` or `src/ext/pug.ls` for example. 


## License

MIT
