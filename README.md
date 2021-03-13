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

Options in `srcbuild.lsp` will in turn be passed to custom builders ( `lsc`, `stylus` and `pug` ). See following sections for additional options in custom builders.


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
 - resolve(file): return source file path for given target file `file`.
   - return null if the given target file can't be derived from any supported source files.

check `src/ext/lsc.ls` or `src/ext/pug.ls` for example. 


## options for custom builder

 - `i18n`: `i18n-next` style i18n object.
 - `intlbase`: base dir of i18n files. default `intl`.

use `srcbuild.i18n` to quickly setup an `i18next` object:

    require! <[srcbuild]>
    srcbuild.i18n(options)
      .then (i18n) -> srcbuild.lsp {i18n}

`options` is passed to `i18next` init function. Additional fields in `options` used by `srcbuild.i18n`:

 - `enabled`: true if i18n is enabled. default false


## on demand build

use `watch.demand(target-file)` to force rebuild by request. e.g., 

    require! <[srcbuild]>
    watch = srcbuild.lsp!

    # this triggers rebuilding of `web/src/pug/index.pug` file.
    watch.demand('web/static/index.html').then -> console.log "built."

`target` to `source` file mapping is done by `resolve` function in custom builder, so to use on demand build, `resolve` must be implemented.


## License

MIT
