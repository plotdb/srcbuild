// Generated by LiveScript 1.6.0
var fs, path, fsExtra, pug, livescript, stylus, jsYaml, marked, colors, base, aux, pugbuild;
fs = require('fs');
path = require('path');
fsExtra = require('fs-extra');
pug = require('pug');
livescript = require('livescript');
stylus = require('stylus');
jsYaml = require('js-yaml');
marked = require('marked');
colors = require('colors');
base = require('./base');
aux = require('../aux');
pugbuild = function(opt){
  opt == null && (opt = {});
  this.i18n = opt.i18n || null;
  this.intlbase = opt.intlbase || 'intl';
  this.extapi = this.getExtapi();
  this.init(import$({
    srcdir: 'src/pug',
    desdir: 'static'
  }, opt));
  this.viewdir = path.normalize(path.join(this.base, opt.viewdir || '.view'));
  return this;
};
pugbuild.prototype = import$(Object.create(base.prototype), {
  pugResolve: function(fn, src, opt){
    var des, e;
    if (!/^@/.exec(fn)) {
      return path.resolve(path.join(path.dirname(src), fn));
    }
    try {
      if (/^@\//.exec(fn)) {
        return require.resolve(fn.replace(/^@\//, ""));
      } else if (/^@static\//.exec(fn)) {
        des = "/" + path.join(this.srcdir.split('/').filter(function(it){
          return it;
        }).map(function(){
          return '..';
        }).join('/'), this.desdir);
        return path.resolve(path.join(path.dirname(src), fn.replace(/^@static/, des)));
      }
    } catch (e$) {
      e = e$;
      throw new Error("no such file or directory: " + fn);
    }
  },
  getExtapi: function(){
    var ret, this$ = this;
    ret = {
      plugins: [{
        resolve: function(){
          var args, res$, i$, to$;
          res$ = [];
          for (i$ = 0, to$ = arguments.length; i$ < to$; ++i$) {
            res$.push(arguments[i$]);
          }
          args = res$;
          return this$.pugResolve.apply(this$, args);
        }
      }],
      filters: {
        'lsc': function(text, opt){
          return livescript.compile(text, {
            bare: true,
            header: false
          });
        },
        'lson': function(text, opt){
          return livescript.compile(text, {
            bare: true,
            header: false,
            json: true
          });
        },
        'stylus': function(text, opt){
          return stylus(text).set('filename', 'inline').define('index', function(a, b){
            a = (a.string || a.val).split(' ');
            return new stylus.nodes.Unit(a.indexOf(b.val));
          }).render();
        },
        'md': function(text, opt){
          return marked(text);
        }
      },
      md: marked,
      yaml: function(it){
        return jsYaml.safeLoad(fs.readFileSync(it));
      },
      yamls: function(dir){
        var ret;
        ret = fs.readdirSync(dir).map(function(it){
          return dir + "/" + it;
        }).filter(function(it){
          return /\.yaml$/.exec(it);
        }).map(function(it){
          var e;
          try {
            return jsYaml.safeLoad(fs.readFileSync(it));
          } catch (e$) {
            e = e$;
            return this$.log.error("[ERROR@" + it + "]: ", e);
          }
        });
        return ret;
      }
    };
    if (this.i18n) {
      ret.i18n = function(it){
        return this$.i18n.t((it || '').trim());
      };
      ret.intlbase = function(p){
        p == null && (p = "");
        if (this$.i18n.language) {
          return path.join(this$.intlbase, opt.i18n.language, p);
        } else {
          return p;
        }
      };
      (ret.filters || (ret.filters = {})).i18n = function(t, o){
        return this.i18n.t((t || '').trim());
      };
    }
    return ret;
  },
  getDependencies: function(file){
    var code, ret, root;
    code = fs.readFileSync(file);
    ret = pug.compileClientWithDependenciesTracked(code, import$({
      basedir: path.join(path.dirname(file)),
      filename: file
    }, this.extapi));
    root = path.resolve('.') + '/';
    return (ret.dependencies || []).map(function(it){
      return it.replace(root, '');
    });
  },
  isSupported: function(file){
    return /\.pug$/.exec(file) && file.startsWith(this.srcdir);
  },
  resolve: function(file){
    var res, i$, len$, re, ret;
    res = ["^" + this.desdir + "/" + this.intlbase + "/[^/]+/(.+).html$", "^" + this.viewdir + "/" + this.intlbase + "/[^/]+/(.+).js$", "^" + this.desdir + "/(.+).html$", "^" + this.viewdir + "/(.+).js$"].map(function(it){
      return new RegExp(it);
    });
    for (i$ = 0, len$ = res.length; i$ < len$; ++i$) {
      re = res[i$];
      ret = re.exec(file);
      if (ret) {
        return path.join(this.srcdir, ret[1] + ".pug");
      }
    }
    return null;
  },
  map: function(file, intl){
    return {
      src: file,
      desh: file.replace(this.srcdir, path.join(this.desdir, intl)).replace(/.pug$/, '.html'),
      desv: file.replace(this.srcdir, path.join(this.viewdir, intl)).replace(/.pug/, '.js')
    };
  },
  build: function(files){
    var _, lngs, ref$, consume, this$ = this;
    _ = function(lng){
      var intl, p, that, ref$;
      lng == null && (lng = '');
      intl = lng ? path.join(this$.intlbase, lng) : '';
      p = this$.i18n && this$.i18n.changeLanguage
        ? this$.i18n.changeLanguage((that = lng)
          ? that
          : ((ref$ = this$.i18n).options || (ref$.options = {})).fallbackLng)
        : Promise.resolve();
      return p.then(function(){
        var i$, ref$, len$, ref1$, file, mtime, src, desh, desv, code, t1, desvdir, ret, t2, desdir, e, results$ = [];
        for (i$ = 0, len$ = (ref$ = files).length; i$ < len$; ++i$) {
          ref1$ = ref$[i$], file = ref1$.file, mtime = ref1$.mtime;
          ref1$ = this$.map(file, intl), src = ref1$.src, desh = ref1$.desh, desv = ref1$.desv;
          if (!fs.existsSync(src) || aux.newer(desv, mtime)) {
            continue;
          }
          code = fs.readFileSync(src).toString();
          try {
            t1 = Date.now();
            if (/^\/\/- ?module ?/.exec(code)) {
              continue;
            }
            desvdir = path.dirname(desv);
            fsExtra.ensureDirSync(desvdir);
            ret = pug.compileClient(code, import$({
              filename: src,
              basedir: this$.srcdir
            }, this$.extapi));
            ret = " (function() { " + ret + "; module.exports = template; })() ";
            fs.writeFileSync(desv, ret);
            t2 = Date.now();
            this$.log.info("build: " + src + " --> " + desv + " ( " + (t2 - t1) + "ms )");
            if (!/^\/\/- ?view ?/.exec(code)) {
              desdir = path.dirname(desh);
              fsExtra.ensureDirSync(desdir);
              fs.writeFileSync(desh, pug.render(code, import$({
                filename: src,
                basedir: this$.srcdir
              }, this$.extapi)));
              t2 = Date.now();
              results$.push(this$.log.info("build: " + src + " --> " + desh + " ( " + (t2 - t1) + "ms )"));
            }
          } catch (e$) {
            e = e$;
            this$.log.error(("build " + src + " failed: ").red);
            results$.push(this$.log.error(e.message.toString()));
          }
        }
        return results$;
      });
    };
    lngs = [''].concat(this.i18n
      ? ((ref$ = this.i18n).options || (ref$.options = {})).lng || []
      : []);
    consume = function(i){
      i == null && (i = 0);
      if (i >= lngs.length) {
        return Promise.resolve();
      }
      return _(lngs[i]).then(function(){
        return consume(i + 1);
      });
    };
    return consume();
  },
  purge: function(files){
    var _, lngs, ref$, consume, this$ = this;
    _ = function(lng){
      var intl, p, that, ref$;
      lng == null && (lng = '');
      intl = lng ? path.join(this$.intlbase, lng) : '';
      p = this$.i18n && this$.i18n.changeLanguage
        ? this$.i18n.changeLanguage((that = lng)
          ? that
          : ((ref$ = this$.i18n).options || (ref$.options = {})).fallbackLng)
        : Promise.resolve();
      return p.then(function(){
        var i$, ref$, len$, ref1$, file, mtime, src, desh, desv, results$ = [];
        for (i$ = 0, len$ = (ref$ = files).length; i$ < len$; ++i$) {
          ref1$ = ref$[i$], file = ref1$.file, mtime = ref1$.mtime;
          ref1$ = this$.map(file, intl), src = ref1$.src, desh = ref1$.desh, desv = ref1$.desv;
          results$.push([desh, desv].filter(fn$));
        }
        return results$;
        function fn$(f){
          if (!fs.existsSync(f)) {
            return;
          }
          fs.unlinkSync(f);
          return this$.log.warn(("purge: " + src + " --> " + f + " deleted.").yellow);
        }
      });
    };
    lngs = [''].concat(this.i18n
      ? ((ref$ = this.i18n).options || (ref$.options = {})).lng || []
      : []);
    consume = function(i){
      i == null && (i = 0);
      if (i >= lngs.length) {
        return Promise.resolve();
      }
      return _(lngs[i]).then(function(){
        return consume(i + 1);
      });
    };
    return consume();
  }
});
module.exports = pugbuild;
function import$(obj, src){
  var own = {}.hasOwnProperty;
  for (var key in src) if (own.call(src, key)) obj[key] = src[key];
  return obj;
}