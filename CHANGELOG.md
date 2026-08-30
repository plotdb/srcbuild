# Change Log

## v0.1.1

 - fix bug: the url -> pages index was memory-only, and it is only filled while a page
   renders. a warm start rebuilds nothing, so the index was empty exactly when the first
   edit after a restart needed it: the content hash moved and no page was re-rendered to
   follow it. it now lives in the manifest ( `refs` per url ) and is loaded on start.
   writes are deferred and only happen when a ref is new, so a cold build does not write
   the manifest once per asset per page.
 - `invalidate-url` logs the page count even when it is zero. returning silently is what
   made the above look like it was working.
 - a deleted pug file is dropped from the index.

## v0.1.0

 - content addressing is OPT IN: `hash: {enabled: true}`. off, nothing changes.
   it rewrites the url of every generated asset in every page and buys nothing until
   the edge serves the addressed form with a long max-age, so a project turns it on
   when it has done that.
 - two modes. `filename` writes `<name>.<hash>[.min].<ext>` next to the output: a url
   names exactly one byte sequence, so it can be immutable, at the cost of expiring old
   copies. `query` points at `<name>.min.js?v=<hash>` instead: nothing accumulates and
   nothing 404s, but stale html silently gets the current bytes and some CDNs ignore the
   query when caching.
 - the plain name is always written and always current in both modes - already deployed
   html, the pre-first-build fallback, and the nginx try_files target all land on it.
 - built files are now content-addressed. `hashstore` ( `.bundle-dep/manifest.json`,
   one per base, shared by every builder ) writes `<name>.<hash>[.min].<ext>` next to
   each output and records `"<plain url>" -> {url: "<hashed url>", generations}`.
   this covers bundles, compiled `.ls` ( `/js/*.js` ) and compiled `.styl`
   ( `/css/*.css` ). the plain name keeps being written: it is what already deployed
   html points at, and the fallback for a page rendered before the first build.
   the bundle spec name still hashes the *url list* - that is the spec's identity and
   the `.dep` filename - so the content hash is a separate filename segment.
 - `asseturl(url, src)` and `bundleurl({type, name, min, src})` are new pug locals,
   used by `lib.pug`'s `+script` / `+css` and by the `bundle` filter. they record which
   pug file embedded which url, which is how a hash change finds its way back to the
   pages: a built asset is in no page's pug dependency graph. with a hashed url no
   `libLoader._v` is appended - the filename already moves with the content.
 - the store announces a url change only when the hash actually moved, so
   page -> asset -> page settles in one pass instead of looping.
 - the manifest is written synchronously before the change is announced, so a render
   right after a rebuild can never read a manifest that is still behind.
 - a builder that skips because its output is fresh now adopts that output into the
   store, so a wiped manifest heals instead of falling back to the plain url forever.
 - block bundles re-resolve their dependencies from the block manager on every build.
   the set was only ever captured when the declaring pug file was analysed, so a block
   that gained a dependency did not rebuild when that new dependency changed.
 - the express view engine resolves these urls by reading the manifest off disk
   ( keyed on mtime ), so it works without a store wired in and across processes.
 - a spec that loses its last `specsrc` ( the pug file declaring it was deleted ) now
   drops its built output and its manifest entry, not just its `.dep`.
 - hashed generations are expired by age as well as by count: a generation is deleted
   only when it is both beyond `keep` ( default 3 ) and older than `keepDays`
   ( default 30 ). count alone answers the wrong question - three rebuilds can be three
   hours or three months, while the risk is how long a browser tab stays open.
 - `store` may be given as a function, for a host that constructs its express view
   engine before the builders exist.
 - fix bug: `specmgr.clear-dirty` was a prototype-level `debounce`, whose timer lives in
   one closure. with more than one base, one bundler's pending flush was cancelled by
   another's and its spec changes were silently dropped.
 - fix bug: a non-minified `pack` bundle produced `<name>..js` ( double dot ).
 - fix bug: `adapter.change` enumerated dependency *paths* instead of visiting nodes.
   a dependency cycle hung the process, and a fan-in/fan-out graph made the queue grow
   multiplicatively. dependency mtime is now a separate memoised pass, shared with
   `dirty-check`.
 - fix bug: a file whose `get-dependencies` threw was dropped entirely - it was never
   built, and its edges were never recorded, so fixing the *included* file triggered
   nothing. failed files are now built anyway ( so the real error is reported ) and
   retried on every subsequent change event.
 - fix bug: `specmgr.unlink` called `Set::remove`, and `specmgr.del-specsrc` called
   `unlink` on a spec instead of on the manager. both threw. as a result the reverse
   index only ever grew: a file bundled once kept triggering that bundle forever.
 - fix bug: `specmgr.delete` never removed the spec nor its `.dep` cache, so
   `load-caches` resurrected dead specs on the next start.
 - a deleted pug file now releases the bundle specs it declared.
 - `build-by-spec` skips when the output is newer than every source, like every other
   builder. bundles are no longer rewritten on each event and on each restart.
 - fix bug: a `bundle.json` change in the same batch as a source change dropped the
   source change silently.
 - fix bug: the `.min` filename was derived with a string `replace`, which hits the
   first occurrence - `three.js/main/index.js` produced `three.min.js/main/index.js`.
 - fix bug: the pug build's freshness guard only looked at the precompiled view, so a
   missing static html was not regenerated.
 - fix bug: the express view engine constructed a pug builder with the default
   `initScan`, so it ran a second full scan and rebuilt the whole pug tree in parallel
   with the real builder - whichever finished last won the output. it only needs `map`
   and `getExtapi`, so it no longer scans.
 - `view/pug` honours express' `view cache` setting instead of forcing it on.
 - add a test suite ( `npm test`, node:test ).

## v0.0.71

 - upgrade i18next-fs-backend to fix vulnerability


## v0.0.70

 - upgrade i18next-fs-backend and other dependencies to fix vulnerability


## v0.0.69

 - use `buildIntl` option to toggle `intl` folder generation.


## v0.0.68

 - upgrade dependencies for vulnerability fixing


## v0.0.67

 - support customized locals in pug builder


## v0.0.66

 - fix bug: cached source file is not updated - it's mtime is not retrieved because getting desv mtime failure.


## v0.0.65

 - fix bug: precompiled js isn't updated even if src file updated.


## v0.0.64

 - fix bug: `srcbuild-pug` triggers a directory traverse which shouldn't happen.
 - add option `initScan` for toggling initial directory traverse.



## v0.0.63

 - bundle should add both codesrc and src so the dependencies will be accurate


## v0.0.62

 - use bundler class api for bundled file path if bundler is not provided in pugbuild


## v0.0.61

 - auto set type when loading config if type is not defined 
 - upgrade @plotdb/block, @plotdb/css and @plotdb/rescope dependencies for bug fixing


## v0.0.60

 - upgrade dependencies `@plotdb/block`, `@plotdb/rescope` and `@plotdb/csscope`


## v0.0.59

 - fix bug: bunlder filter should only work if bundler is provided and available


## v0.0.58

 - separate ext/base init into `initAdapter` and `initVars` so we can update vars first
 - bundler ext:
   - accept function as manager parameter in bundler.
   - `relativePath` is now by default true 
   - tweak error logging for bundling issue


## v0.0.57

 - breaking change: in bundler, path of `configFile` should now be relative to `base`.
 - support block bundling with `bundle` filter
 - upgrade dependencies


## v0.0.56

 - audit fix vulnerability about dependency `minimatch`
 - enable asset build directly in lsp


## v0.0.55

 - remove logging when view rendering fails since it should be handled by express server
 - make error of view rendering fails a lderror with id 1033


## v0.0.54

 - fix bug: bunlder is not added into adapter list in lsp, thus sometimes rebuild wont be triggered.
 - fix bug: pack option in css/script should by default use minimized file.
 - support `min` option to explicitly use unminimized file with pack option


## v0.0.53

 - fix bug: ext/bundle fails if `relative-path` is false


## v0.0.52

 - fix bug: precompiled pug js should still be run with custom option and api


## v0.0.51

 - support auto packing with limitation.


## v0.0.50

 - fix bug: multiple subtree features doesn't work, because we didn't add all adapters into watcher


## v0.0.49

 - support building of multiple subtree


## v0.0.48

 - support pug generation from outside of src dir


## v0.0.47

 - disable pug `compileDebug` option by default
 - rebuild demo dir


## v0.0.46

 - in watcher log, show correct watched directory instead of `src`
 - set `_root` with default value `["."]` if option `root` is omitted.
 - force `intlbase` to return absolute path


## v0.0.45

 - support customizable watching directory.


## v0.0.44

 - support asset build ( static file copying )
 - support `noView` mode in pugbuild


## v0.0.43

 - support language modifier in `intlbase` API


## v0.0.42

 - trap bundle file parsing error and log, instead of crash directly


## v0.0.41

 - fix bug: pug view engine doesn't support `filters` option


## v0.0.40

 - support custom filter in ext/pug


## v0.0.39

 - bug fix: pug build fails when pug file is empty


## v0.0.38

 - upgrade @loadingio/debounce.js
 - tweak dependency range syntax
 - audit and fix cached-path-relative vulnerability


## v0.0.37

 - bug fix: crash when iterating to a symlink pointing to a non-existed file.


## v0.0.36

 - use `@plotdb/colors` to replace `colors`


## v0.0.35

 - upgrade marked for vulnerability fixing


## v0.0.34

 - support legacy syntax in libLoader for script loading
 - fix bug: `libLoader.root` doesn't work properly


## v0.0.33

 - support relative path in bundle.json
 - add test case for bundler
 - use local script for testing


## v0.0.32

 - bug fix: `defer` in libLoader should be by default true.
 - bug fix: stylus extension doesn't provide correct path for dependencies.


## v0.0.31

 - bug fix: the `script` and `css` mixin supports should be done by `postParse` plugin instead of code modification.


## v0.0.30

 - directly support `script` and `css` mixin in pug compiling.


## v0.0.29

 - bug fix: bundle not rebuild when bundle config file updated
 - bug fix: bundler exception not caught


## v0.0.28

 - totally remove `compress` option to prevent unwanted side effect of code removal


## v0.0.27

 - dont compress unused in pug lsc filter for our potential use of custom script block design in @plotdb/block


## v0.0.26

 - remove log


## v0.0.25

 - pass `ignored` to adapter to bypass unnecessary files to save time 
 - by default minimize javascript and css in pug filter.


## v0.0.24

 - set `doctype` to `html` also in `pug-cli` to prevent `t="t"` generation.


## v0.0.23

 - set `doctype` to `html` to prevent `t="t"` generation.


## v0.0.22

 - add `srcbuild-pug` command for building pug with extapi
 - fix yaml loading issue by using `load` instead of `safe-load`.


## v0.0.21

 - fix module resolving path bug


## v0.0.20

 - resolve module path from basedir in ext/pug.


## v0.0.19

 - bump stylus version to 0.55.0 for removing deprecated dependencies


## v0.0.18

 - fix bug: lsc builder doesn't build unless glslify is enabled


## v0.0.17

 - support `json` API for reading json file in pug


## v0.0.16

 - fix bug: glslify transformed by browserify should have basedir from src file dir.


## v0.0.15

 - upgrade `path-parse` to fix vulnerability
 - support glslify transfomration by option `use-glslify`


## v0.0.14

 - add `i18n.intlbase` and `i18n.langauge` pug api and deprecate `intlbase` pug api.


## v0.0.13

 - fix bug: incorrect parameter passing in view/pug to ext/pug


## v0.0.12

 - add bundling sample code
 - fix bundling file path shown in log


## v0.0.11

 - fix bug: `desdir` and `base` not passed to pug in pug view constructor


## v0.0.10

 - fix bug: basedir should be opt.basedir


## v0.0.9

 - support pug view engine for express


## v0.0.8

 - fix bug: trying to get mtime of a non-existed file. 
 - support options for files to ignore. by default, ignore `.git` folders.


## v0.0.7

 - simplify log


## v0.0.6

 - trap exception during `log-dependencies` and prevent from further building.
 - keep old dependency if `log-dependencies` fails.


## v0.0.5

 - support bundling


## v0.0.4

 - fix bug in ext/pug: basedir doesn't exist when initing, causing problem when getting dependencies. use path.resolve(srcdir) instead.


## v0.0.3

 - fix typo


## v0.0.2

 - fix bug: let pug use correct filename and basedir parameter. resolve pug files correctly

