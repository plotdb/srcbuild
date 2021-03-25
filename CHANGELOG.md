# Change Log

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

