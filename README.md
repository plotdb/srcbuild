# srcbuild

Source file tree builder.


## Usage

setup a lsp watcher:

    require! <[@plotdb/srcbuild]>
    srcbuild.lsp {base: 'web', i18n: ..., logger: ...}

where

 - `base`: root dir for `src` and `static` folders. default `.`
 - `i18n`: i18n object. 
 - `ignored`: files to be ignored. in [anymatch](https://github.com/micromatch/anymatch)-compatible definition.
   - by default ['.git']
 - `logger`: optional. for logging output. use `console.log` by default. 
   - sample logger with `pino`:

     require! <[@plotdb/srcbuild pino]>
     srcbuild.lsp({logger: pino({level: 'debug'})})

These fields will be passed to all customized builders. Additionally, configurations in builder-specific fields will lso be passed to corresponding customized builders. For example, `bundle` field will be passed to `bundle` builder:

    srcbuild.lsp {bundle: { ... /* this will be passed to bundle builder */ }, ...}

For `lsp`, there are 4 different builders:

 - `lsc`: build `*.ls` from `src/ls` to `static/js`.
 - `stylus`: build `*.styl` from `src/styl` to `static/css`.
 - `pug`: build `*.pug` from `src/pug` to `static`.
 - `bundle`: bundle `css` and `js` files

See following sections for additional options in custom builders.


## Custom Adapter

Extend base builder for a customized builder:

    base = require("@plotdb/srcbuild").base

    mybuild = (opt = {}) -> @init({srcdir: 'src', desdir: 'des'} <<< opt)
    mybuild.prototype = Object.create(base.prototype) <<< {
      is-supported: (file) -> return true
      get-dependencies: (file) -> return []
      build: (files) -> # build will be called if is supported.
    }

with following user-defined functions:

 - `is-supported(file)`: return true if `file` is supported by this builder, otherwise return false.
   - `file`: file name for file to be verified. Relative to cwd. 
 - `get-dependencies(file)`: return a list of files that this file depends on.
   - `file`: same as `is-supported`
 - `build(files)`: should compile / generate target files of given file list `files`.
   - `files`: a list of objects corresponding to files to be compiled, with following fields:
     - `file`: path of the file to be built, relative to cwd.
     - `mtime`: timestamp of the modified time of this file. may be modified time of its dependencies.
 - `purge(files)`: should remove generated files corresponding to files listed in `files`.
   - `files`: same as `build`.
 - `resolve(file)`: return source file path for given target file `file`.
   - return null if the given target file can't be derived from any supported source files.

check `src/ext/lsc.ls` or `src/ext/pug.ls` for example. 


## Options for custom builder

Except common options, each builder may support different options:

 - `pug`:
   - `i18n.intlbase(subpath)`: base dir of i18n files, with optional subpath parameter. default `intl`.
   - `i18n.language()`: current language. (e.g., `zh-TW` )
 - `bundle`: bundle options. includes:
   - `configFile`: json file storing bundle configuration. optional.
   - `config`: bundle configuration in following format:
     {
       "css": {
         "name": [ ... list of files to bundle together ]
       },
       "js": {
         ...
       }
     }


## ODB / On demand build

use `watch.demand(target-file)` to force rebuild by request. e.g., 

    require! <[srcbuild]>
    watch = srcbuild.lsp!

    # this triggers rebuilding of `web/src/pug/index.pug` file.
    watch.demand('web/static/index.html').then -> console.log "built."

`target` to `source` file mapping is done by `resolve` function in custom builder, so to use on demand build, `resolve` must be implemented.


## i18n

use `srcbuild.i18n` to quickly setup an `i18next` object:

    require! <[srcbuild]>
    srcbuild.i18n(options)
      .then (i18n) -> srcbuild.lsp {i18n}

`options` is passed to `i18next` init function. Additional fields in `options` used by `srcbuild.i18n`:

 - `enabled`: true if i18n is enabled. default true


When i18n object is provided, i18n data can be used in pug files via `i18n` function. e.g.,

    div= i18n("my-key")

will show `my-key` content defined in locale corresponding `default.yaml`:

    my-key: 這是我的鍵


To use a namespaced key, add `:` before key. For example:

    div= i18n("new-ns:another-key")

will access to `another-key` in `new-ns.yaml`. Be sure to add your namespace name in `ns` field of i18n option:

    "i18n": { ...  "ns": ["default", "new-ns"] }

additionally, use `intlbase` to wrap path with a i18n based relative path:

    a(href=intlbase('/faq'))


## Pug Extension

When building, we extend Pug via plugins and filters to support more features.

### Pug include path

Use `@` to include files in modules:

    include @/ldview/dist/ldview.pug

Use `@static` to include files under `static` folder:

    include @static/assets/sample.pug

Other paths starting with `@` are reserved and will cause error when used.


### Filters

Following formats and filters are supported:

 - `lsc`: transpile content from livescript to JavaScript.
 - `stylus`: transpile content from `stylus` to `CSS`.
 - `md`: transpile content from `markdown` to `HTML`.


### JS functions

Following functions are added:

 - `md(code)`: convert `markdown` to `HTML`.
 - `yaml(path)`: read `yaml` file and return object. (tentative)
 - `yamls(path)`: read content of `yaml` files under `path` directory. (tentative)


## License

MIT
