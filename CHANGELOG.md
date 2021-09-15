# Change Log

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

