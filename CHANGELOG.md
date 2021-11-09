# Change Log

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

