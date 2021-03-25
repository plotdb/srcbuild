// Generated by LiveScript 1.6.0
var fs, fsExtra, path, pug, pugbuild, reload, fsp, pugViewEngine;
fs = require('fs');
fsExtra = require('fs-extra');
path = require('path');
pug = require('pug');
pugbuild = require("../ext/pug");
reload = require("require-reload")(require);
fsp = fs.promises;
pugViewEngine = function(options){
  var builder, extapi, logger, pugcache, log;
  builder = new pugbuild({
    logger: options.logger,
    i18n: options.i18n,
    viewdir: options.viewdir,
    srcdir: options.srcdir
  });
  extapi = builder.getExtapi();
  logger = options.logger;
  pugcache = {};
  log = function(f, opt, t, type, cache){
    return logger.debug(f.replace(opt.basedir, '') + " served in " + t + "ms (" + type + (cache ? ' cached' : '') + ")");
  };
  return function(src, opt, cb){
    var lc, intl, ref$, desv, desh, startTime, mtime, ret, e;
    lc = {
      isCached: false
    };
    if (opt.settings.env === 'development') {
      lc.dev = true;
    }
    lc.useCache = true || opt.settings['view cache'];
    intl = opt.i18n ? path.join("intl", opt._locals.language) : '';
    ref$ = builder.map(src, ''), src = ref$.src, desv = ref$.desv, desh = ref$.desh;
    startTime = Date.now();
    try {
      mtime = +fs.statSync(desv).mtime;
      if (!lc.useCache || !pugcache[desv] || mtime - pugcache[desv].mtime > 0) {
        ret = pugcache[desv] = {
          js: reload(desv),
          mtime: mtime
        };
      } else {
        lc.isCached = true;
        ret = pugcache[desv];
      }
      if (!ret.js) {
        throw new Error('');
      }
      ret = ret.js(opt);
      if (lc.dev) {
        log(src, opt, Date.now() - startTime, 'precompiled', lc.isCached);
      }
      return cb(null, ret);
    } catch (e$) {
      e = e$;
      return Promise.resolve().then(function(){
        lc.mtime = +fs.statSync(src).mtime;
        if (!lc.useCache || !pugcache[src] || lc.mtime - pugcache[src].mtime > 0) {
          return fsp.readFile(src).then(function(buf){
            return pugcache[src] = {
              buf: buf
            };
          });
        } else {
          return Promise.resolve(pugcache[src]);
        }
      }).then(function(obj){
        var ret, ref$;
        if (!(lc.isCached = obj.mtime != null && lc.useCache)) {
          obj.mtime = lc.mtime;
        }
        ret = pug.compileClient(obj.buf, import$((ref$ = import$({}, opt), ref$.filename = src, ref$.basedir = basedir, ref$), extapi));
        ret = " (function() { " + ret + "; module.exports = template; })() ";
        return fsExtra.ensureDir(path.dirname(desv)).then(function(){
          return fsp.writeFile(desv, ret);
        });
      }).then(function(){
        var ref$;
        return ref$ = pugcache[desv] || (pugcache[desv] = {}), ref$.js = reload(desv), ref$.mtime = lc.mtime, ref$;
      }).then(function(){
        var ret;
        ret = pugcache[desv].js(opt);
        if (lc.dev) {
          log(src, opt, Date.now() - startTime, 'from pug', lc.isCached);
        }
        return cb(null, ret);
      })['catch'](function(err){
        logger.error({
          err: err
        }, src + " view rendering failed.");
        return cb(err, null);
      });
    }
  };
};
module.exports = pugViewEngine;
function import$(obj, src){
  var own = {}.hasOwnProperty;
  for (var key in src) if (own.call(src, key)) obj[key] = src[key];
  return obj;
}