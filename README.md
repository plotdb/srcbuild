# srcbuild

Source file tree builder.


## Usage

setup a lsp ( livescript + stylus + pug ) watcher:

    require! <[@plotdb/srcbuild]>
    srcbuild.lsp {base: 'web', i18n: ..., logger: ...}

where

 - `base`: root dir for `src` and `static` folders. default `.`
 - `i18n`: i18n object.
 - `ignored`: files to be ignored. in [anymatch](https://github.com/micromatch/anymatch)-compatible definition.
   - by default ['.git']
 - `hash`: optional. content addressing for built files. off unless `enabled`.
   see [Content Addressing](#content-addressing).
 - `logger`: optional. for logging output. use `console.log` by default.
   - sample logger with `pino`:

     require! <[@plotdb/srcbuild pino]>
     srcbuild.lsp({logger: pino({level: 'debug'})})

These fields will be passed to all customized builders. Additionally, configurations in builder-specific fields will lso be passed to corresponding customized builders. For example, `bundle` field will be passed to `bundle` builder:

    srcbuild.lsp {bundle: { ... /* this will be passed to bundle builder */ }, ...}

For `lsp`, there are 6 different builders:

 - `lsc`: build `*.ls` from `src/ls` to `static/js`.
 - `stylus`: build `*.styl` from `src/styl` to `static/css`.
 - `pug`: build `*.pug` from `src/pug` to `static`.
 - `bundle`: bundle `css` and `js` files
 - `asset`: copy whitelisted extensions from `src/assets` to `static/assets`.
 - `raw`: copy `src/raw` to `static`, verbatim. see below.

See following sections for additional options in custom builders.


## src/raw - the hand-written half of the document root

Everything above generates its output. A site also has files that are simply *served*:
`favicon.ico`, `robots.txt`, images, fonts, a `site.webmanifest`. Put them in `src/raw`
and they land in `static` unchanged:

    src/raw/favicon.ico          ->  static/favicon.ico
    src/raw/robots.txt           ->  static/robots.txt
    src/raw/assets/img/logo.png  ->  static/assets/img/logo.png

No extension whitelist - the tree exists to be copied, so filtering it could only mean
silently failing to ship a file someone added. Junk is still excluded ( `.DS_Store`,
`Thumbs.db`, `*.swp`, `*~`, `.git` ), and anything in `ignored` on top of that.

    srcbuild.lsp {raw: {srcdir: 'src/raw', desdir: 'static'}}   # the defaults
    srcbuild.lsp {raw: false}                                   # turn it off

**Why this is worth doing.** It is what makes `static/` entirely derived. Once no file
exists only there, `rm -rf static` is always safe, the directory does not belong in
version control, and a deploy is a build rather than a merge of hand-placed files with
generated ones.

**`raw` is a separate option from `asset`, deliberately.** `asset` is the older
whitelist-based copier ( `src/assets/**.{png,gif,jpg,svg,json} -> static/assets` ), and
projects override it - servebase points it at `src/pug` so images can sit next to the
pug that uses them. If `raw` were another entry in `asset`, every one of those overrides
would silently drop it. Both run; migrate at your own pace.


## Content Addressing

A generated file keeps its name and changes its bytes on every build, so its url cannot
be cached: the browser has to ask every time whether it is still current. Content
addressing gives it a second name derived from what is inside it, which can be cached
forever because that name can never mean anything else.

Off by default. It rewrites the url of every generated asset in every page, and buys
nothing until the server in front actually serves the addressed form with a long
`max-age`, so a project turns it on once it has done that:

    srcbuild.lsp {
      hash:
        enabled: true       # off unless set
        mode: 'filename'    # or 'query'
        keep: 3             # filename mode: generations kept
        keepDays: 0         # filename mode: also keep anything younger than this
    }

Two modes:

    filename   also write `<name>.<hash>[.min].<ext>`; pages point at that.
               a url names exactly one byte sequence, so it can be immutable. old
               copies have to be expired, and html older than the retention window
               points at a name that is gone.
    query      leave one file and point at `<name>.min.js?v=<hash>`. nothing
               accumulates and nothing 404s, but html older than the last build
               silently gets whatever the file holds now, and some CDNs ignore the
               query string when caching.

Either way the plain name is always written and always current. It is what already
deployed html points at, what a page rendered before the first build falls back to, and
what a `try_files` in the server can fall back to in filename mode.

Covers what `lsc`, `stylus` and `bundle` produce - reached through the `script` and
`css` mixins and the `bundle` filter. A url written directly into a template, an image,
or anything not built here is passed through untouched.

### The manifest

`<base>/.bundle-dep/manifest.json`, one per base, shared by every builder:

    "/js/site.min.js": {
      "url": "/js/site.4b6ac41e1bea.min.js",
      "refs": ["src/pug/index.pug"],
      "generations": [{"files": ["static/js/site.4b6ac41e1bea.min.js"], "at": ...}]
    }

`url` is what the mixins look up - pug cannot compute it, since it never reads the
built file. `refs` is which pug files embedded the url, and is the only way back to
them when the hash moves: a built asset is in no page's pug dependency graph, so
nothing else can know a page went stale. `generations` is what lets old copies be
expired.

It is an index into `static/`, so the two belong together. Losing it is recoverable but
not free: `url` comes back on the next build ( existing outputs are adopted ), while
`refs` only comes back when pages actually render.

### Retention ( filename mode )

A generation is deleted only once it is both beyond `keep` and older than `keepDays`.
Count alone answers the wrong question - three rebuilds can be three hours or three
months, while the risk is how long a browser tab stays open. `keepDays` defaults to 0,
because a client holding old js across a deploy is already exposed to backend api
drift, and the answer to that is a "site updated, please reload" prompt rather than
keeping every artefact forever. Raise it if you would rather spend disk.

There is no sweep: expiry happens when that url is next rebuilt. So nothing grows
without bound, but a url that never changes again keeps whatever it had.


## Waiting for the first build

`lsp` returns the watcher; `watcher.ready` is a promise that resolves once every
adapter's initial scan has built, including the bundles those builds triggered.

```js
const srcbuild = require('@plotdb/srcbuild').lsp({base: 'web'});
await srcbuild.ready;
app.listen(port);
```

Without it a host starts serving during the first build, which is the heaviest build of
the process's life. That is where cold-start flakiness comes from: on makechart, every
one of 38 database connection timeouts over four years fell within 30s of a build event,
28 of them within 30s of a start, and none at all in the 30-120s band.

It never rejects. A source that fails to build has already logged; refusing to start
over one bad file would be worse than serving the rest.

Bundles are waited for separately from the adapters, because a bundle is not built by
the watcher noticing a file - it is built because a pug page named it through the
`bundle` filter, one tick after that page's own build resolved.


## Minification

Minification runs on a `worker_threads` worker, not on the main thread.

It matters when srcbuild shares a process with a server, which is the usual dev setup.
`uglify-js` is synchronous CPU work and a large bundle takes seconds: measured on a
0.94MB bundle, 2677ms of minify blocked the event loop for 1769ms in one stall. Nothing
else in that process runs during it - long enough for a fresh `pg.Pool` connect with a
2s timeout to expire while its handshake callbacks cannot be delivered, so the request
fails with a database error that has nothing to do with the database.

The same bundle through the worker: ~20% more total time ( a worker has its own heap and
warms its own JIT ), 9ms of it spent moving the strings across, and the loop's worst tick
was 13ms.

There is no size threshold, because cost does not track size: in the same corpus 800KB
took 88ms and 960KB took 2319ms, one construct in the last chunk being pathological for
uglify. Everything the builders minify goes across.

The worker is spawned on first use, `unref`'d, and terminated after 30s idle. If it
cannot start or it dies, minification falls back in-process for the rest of the run -
slower, never broken.

`SRCBUILD_MINIFY_WORKER=0` keeps everything in-process.

Two things stay synchronous, both deliberately:

 - the `lsc` and `stylus` **pug filters**. Pug's filter interface has no async form.
   They handle inline `include:lsc` snippets, which are small.
 - a source file that ships its own `.min` twin is never minified at all, so it never
   reaches the worker.

On failure the minifier returns the input unchanged and logs. It never writes an empty
output: `uglify-js.minify` signals a syntax error by returning `{error}` with no `code`
field, and reading `.code` off that used to yield an empty `.min.js`, or - inside a
bundle's `join` - a file that silently vanished from the output.


## Burst rebuilds

While a bundle is being built, further requests for that same bundle do not queue. They
set a flag, and the run in flight does exactly one more pass when it finishes - which
reads whatever is on disk by then, so it subsumes every request that arrived while it
was busy. N requests cost at most two builds.

This matters because rebuilds arrive in bursts: `fedep` touching every lib file, or a
save that invalidates a shared include. Before this, makechart's log shows one bundle
built back to back at 8.6s, 6.4s and 3.4s. Moving minification to a worker does not help
there - it only moves the queue onto the other thread.

`force` is sticky across the collapse: if any collapsed request needed the freshness
guard bypassed ( because the source *list* changed, which mtimes cannot show ), the
rerun bypasses it too.


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

and the common options for `init` are as following:

 - `base`: root directory for srcbuild to run.
 - `srcdir`: directory for source files. should be relative to `base`. default `src` if omitted.
 - `desdir`: directory for built files. should be relative to `base`. default `static` if omitted.
 - `logger`: logger for log output. use `console` if omitted.
 - `initScan`: default true. if true, run a directory scanning for files to build when adapter is initing.

check `src/ext/lsc.ls` or `src/ext/pug.ls` for example.


## Options for custom builder

Except common options, each builder may support different options:

 - `pug`:
   - `intlbase`: base dir to place i18n files. for example, `intl` part of `/intl/zh-TW/index.html`. default `intl`.
   - `i18n`: an optional i18n object having the same interface with `i18next`
     - when provided, enable i18n building with following additional features:
       - if `buildIntl` is set to true, build source files to locations by i18n config like `/intl/zh-TW/index.html`.
       - an additional function `i18n` will be available during pug compilation.
         - `i18n(text)`: translate `text` based on the `i18n` object provided.
         - `language()`: return current language. ( e.g., `zh-TW` )
         - `intlbase(p, lng)`: return a path to given `p`, based on current i18n ( or specified `lng` arg ) setup.
           - for example, `intlbase('link', 'kr')` may generate `/intl/kr/link`, based on he base dir config.
         - additionally, a pug filter `i18n` is also available, which can be used like:

             span:i18n translate this text

   - `noView`: default false. when true, js view files ( generated to `viewdir` ) won't be built.
   - `buildIntl`: default true. when true build locale-based files under `static/intl/` and `.view/intl`
     - requires `i18n`; omitted if `i18n` is not available
   - `viewdir`: default `.view`. a directory for storing prebuilt pug files ( in .js format )
   - `bundler`: default null. Auto packing will be possible only if this is provided.
   - `locals`: additional local variables for pug context when compiling.
 - `lsc`:
   - `useGlslify`: default false. set to true if you need glslify of lsc files.
     - *NOTE* this is an experiment feature and may be removed ( move to standalone builder ) in the future.
 - `bundle`: bundle options. includes:
   - `configFile`: json file storing bundle configuration. optional.
   - `relativePath`: use relative path for paths in config file. default false. possible values:
     - `false`: all files in `configFile` are relative to current working directory.
     - `true`: all files in `configFile` are relative to the directory containing `bundle.json`
     - or, specific a path as the relative root.
   - `manager`: block manager, optional. required for @plotdb/block bundling.
     - can be either an `block.manager` object, or ...
     - a function returning such object which accepts an object with following fields as parameter:
       - `base`: the base dir of this bundle.
   - `config`: bundle configuration in following format:
     {
       "css": {
         "name": [ ... list of files to bundle together ]
       },
       "js": {
         ...
       }
     }
 - `asset`: for copying asset files.
   - `ext`: array of file extensions to copy. default `["png", "gif", "jpg", "svg", "json"]`

These options are constructor options for corresponding builder, e.g., for pug builder:

    new pugbuild({ i18n: ... })

When using shorthands like `srcbuild.lsp(...)`, you can also specify corresponding option in scope, such as:

    srcbuild.lsp({
      base: '...', i18n: '...',
      pug: {intlbase: '...'}
    });

common options will be overwritten by scoped options.


## Using custom builders

Send adapters to watcher from `getAdapter()` of each custom builders:

    require! <[@plotdb/srcbuild/dist/watch @plotdb/srcbuild/dist/ext/pug]>
    pugbuilder = new pug(...)
    watcher = new watch({adapters: [pugbuilder.getAdapter]})

By default, watcher watches the current working directory. Change watcher behavior with following constructor options:

 - `adapters`: array of adapters to use to handle file change events.
 - `ignored`: array of glob strings to ignore when watching for changes. by default `[".git"]`.
 - `root`: directory, or array of directories to watch. by default `["."]`.
 - `logger`: optional. logger object with logging functions such as `info`, `warn` and `error`.


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


### Mixins

use `script` and `css` builtin mixins to load external script and css files:

    +script({name: "module-name", version: "main", path: "somefile.js"})
    +css({name: "module-name", version: "main", path: "somefile.js"})

where the fields of the parameters:

 - `name`: module name
 - `version`: module version. default `main`, if omitted.
 - `path`: path of file to load. default `index.min.js`, if omitted.
 - `defer`: defer execution or not. default `true` if omitted.
 - `async`: async loading or not. default `false` if omitted.

By default the above script mixin generates a script tag pointing to files under `/assets/lib/<name>/<version>/<path>`. You can customize the `/assets/lib/` by calling `libLoader.root(desiredPath)`.

With [content addressing](#content-addressing) enabled, a url these mixins emit is
looked up in the manifest and replaced by its addressed form when there is one. A url
with no entry - an external url, a file this build did not produce, anything before its
first build - is emitted unchanged, with `libLoader._v` appended as before.


Additionally, you can also use a list of modules:

    +script([
      {name: "module-a", version: "0.0.1", path: "somefile.js"},
      {name: "module-b", version: "0.2.1", path: "another.js"},
      {name: "module-c", path: "with-default-version.js"},
      {name: "module-d", version: "with.default.path" },
      {name: "with-defer-async", defer: false, async: true}
      {name: "omit-everything"},
    ])

Use the second option object to specify additional parameters, including:

 - `pack`: *experimental* *deprecated* default false. Enable auto packing or not.
   - if true, enable auto packing which trigger bundling automatically to a filename from md5 of all script urls.
   - require `bundler` option in pugbuild constructor.
   - doesn't work with external urls.
   - there are still issues about rebuilding and build from view.
   - replaced by `bundle` filter, which runs in compile time.
 - `min`: default true. When true, use minimized packed file with pack option.


### Filters

Following formats and filters are supported:

 - `lsc`: transpile content from livescript to JavaScript.
 - `stylus`: transpile content from `stylus` to `CSS`.
 - `md`: transpile content from `markdown` to `HTML`.
 - `bundle`: bundle files including js, css or block. usage sample:

    :bundle(options = {type: "block", files: [ { bid }, ...  ]})




### JS functions

Following functions are added:

 - `md(code)`: convert `markdown` to `HTML`.
 - `yaml(path)`: read `yaml` file and return object. (tentative)
 - `yamls(path)`: read content of `yaml` files under `path` directory. (tentative)
 - `asseturl(url, src)`: the content-addressed form of a built file's url, or `url`
   unchanged when there is none. `src` is the pug file asking, recorded so the page can
   be re-rendered when the hash moves. used by the `script` and `css` mixins.
 - `bundleurl({type, name, min, src})`: the same lookup for a bundle, addressed by its
   spec rather than its url. returns null when the bundle has not been built yet, so
   callers fall back to the plain name.
 - `hashfile({type, name, files, src})`: declare a bundle from a list of files. used by
   the `pack` option of the mixins.

`asseturl` and `bundleurl` do nothing but return their input when content addressing is
off, so a template can call them unconditionally.


### Additional filters / functions

There are some additional `i18n` filters available if properly configured. See above for more information.


## License

MIT
