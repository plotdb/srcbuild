# Change Log

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

