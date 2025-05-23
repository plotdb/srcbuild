// Generated by LiveScript 1.6.0
var fs, path, fsExtra, pug, livescript, uglifyJs, uglifycss, stylus, jsYaml, marked, crypto, colors, base, aux, bundle, cwd, pugbuild;
fs = require('fs');
path = require('path');
fsExtra = require('fs-extra');
pug = require('pug');
livescript = require('livescript');
uglifyJs = require('uglify-js');
uglifycss = require('uglifycss');
stylus = require('stylus');
jsYaml = require('js-yaml');
marked = require('marked');
crypto = require('crypto');
colors = require('@plotdb/colors');
base = require('./base');
aux = require('../aux');
bundle = require('./bundle');
cwd = process.cwd();
pugbuild = function(opt){
  opt == null && (opt = {});
  this.i18n = opt.i18n || null;
  this.intlbase = opt.intlbase || 'intl';
  this.filters = opt.filters || {};
  this.locals = opt.locals || {};
  this.extapi = this.getExtapi();
  this.bundler = opt.bundler;
  this.init(import$({
    srcdir: 'src/pug',
    desdir: 'static'
  }, opt));
  this.viewdir = path.normalize(path.join(this.base, opt.viewdir || '.view'));
  this._noView = opt.noView || false;
  this._buildIntl = opt.buildIntl != null ? opt.buildIntl : true;
  return this;
};
pugbuild.prototype = import$(Object.create(base.prototype), {
  pugResolve: function(fn, src, opt){
    var e;
    try {
      if (/^@\//.exec(fn)) {
        return require.resolve(fn.replace(/^@\//, ""), {
          paths: [this.base]
        });
      } else if (/^@static\//.exec(fn)) {
        return path.resolve(fn.replace(/^@static/, this.desdir));
      } else if (/^@/.exec(fn)) {
        throw new Error('path starting with `@` is reserved. please use other pathname.');
      } else if (/^\//.exec(fn)) {
        return path.resolve(path.join(opt.basedir, fn));
      } else {
        return path.resolve(path.join(path.dirname(src), fn));
      }
    } catch (e$) {
      e = e$;
      throw new Error("error when looking up " + fn + ": " + e.toString());
    }
  },
  getExtapi: function(){
    var ret, this$ = this;
    ret = import$(import$({}, this.locals || {}), {
      plugins: [{
        resolve: function(){
          var args, res$, i$, to$;
          res$ = [];
          for (i$ = 0, to$ = arguments.length; i$ < to$; ++i$) {
            res$.push(arguments[i$]);
          }
          args = res$;
          return this$.pugResolve.apply(this$, args);
        },
        postParse: function(dom, opt){
          if (!(dom.nodes[0] && dom.nodes[0].type === 'Doctype')) {
            return dom;
          }
          dom.nodes.splice(1, 0, {
            type: 'Include',
            block: {
              type: 'Block',
              nodes: []
            },
            file: {
              type: 'FileReference',
              filename: opt.filename,
              path: '@/@plotdb/srcbuild/dist/lib.pug'
            }
          });
          return dom;
        }
      }],
      filters: import$(this.filters || {}, {
        'bundle': function(text, _opt){
          var opts, ret;
          opts = Array.isArray(_opt.options)
            ? _opt.options
            : [_opt.options];
          opts = opts.filter(function(it){
            var ref$;
            return it && ((ref$ = it.type) === 'js' || ref$ === 'css' || ref$ === 'block');
          });
          ret = "";
          opts.forEach(function(o){
            var list, name, str, spec, des, relDesMin, relDes;
            list = o.files;
            list.forEach(function(d){
              if (!d.type) {
                return d.type = o.type;
              }
            });
            if (o.type === 'block' && !(o.sort != null || o.sort)) {
              list.sort(function(a, b){
                var i$, ref$, len$, n, ref1$, c, d;
                for (i$ = 0, len$ = (ref$ = ['ns', 'name', 'version', 'path']).length; i$ < len$; ++i$) {
                  n = ref$[i$];
                  ref1$ = [a[n] || '', b[n] || ''], c = ref1$[0], d = ref1$[1];
                  if (c < d) {
                    return -1;
                  } else if (c > d) {
                    return 1;
                  }
                }
                return 0;
              });
            }
            if (o.name) {
              name = o.name;
            } else {
              str = (o.type + ":") + list.join(';');
              name = crypto.createHash('md5').update(str).digest('hex');
              name = path.join(name.substring(0, 4), name.substring(4));
            }
            spec = {
              name: name,
              type: o.type,
              src: list,
              specsrc: _opt.filename
            };
            if (this$.bundler) {
              this$.bundler.addSpec(spec);
              des = this$.bundler.desPath(spec);
            } else {
              des = bundle.desPath(import$({
                desdir: this$.desdir
              }, spec));
            }
            relDesMin = path.relative(this$.desdir, des.desMin);
            relDes = path.relative(this$.desdir, des.des);
            if (o.type === 'css') {
              return ret += "<link rel=\"stylesheet\" type=\"text/css\" href=\"/" + relDesMin + "\"/>";
            } else if (o.type === 'js') {
              return ret += "<script type=\"text/javascript\" src=\"/" + relDesMin + "\"></script>";
            } else if (o.type === 'block') {
              return ret += "<link rel=\"block\" href=\"/" + relDesMin + "\">";
            }
          });
          return ret;
        },
        'lsc': function(text, opt){
          var code, codeMin;
          code = livescript.compile(text, {
            bare: true,
            header: false
          });
          codeMin = uglifyJs.minify(code, {
            compress: false
          }).code || '';
          return codeMin;
        },
        'lson': function(text, opt){
          return livescript.compile(text, {
            bare: true,
            header: false,
            json: true
          });
        },
        'stylus': function(text, opt){
          var code, codeMin;
          code = stylus(text).set('filename', 'inline').define('index', function(a, b){
            a = (a.string || a.val).split(' ');
            return new stylus.nodes.Unit(a.indexOf(b.val));
          }).render();
          return codeMin = uglifycss.processString(code, {
            uglyComments: true
          });
        },
        'md': function(text, opt){
          return marked.parse(text);
        }
      }),
      json: function(it){
        return JSON.parse(fs.readFileSync(it));
      },
      md: marked.parse,
      yaml: function(it){
        return jsYaml.load(fs.readFileSync(it));
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
            return jsYaml.load(fs.readFileSync(it));
          } catch (e$) {
            e = e$;
            return this$.log.error("[ERROR@" + it + "]: ", e);
          }
        });
        return ret;
      },
      md5: function(str){
        return crypto.createHash('md5').update(str).digest('hex');
      },
      hashfile: function(arg$){
        var type, name, files, src, spec;
        type = arg$.type, name = arg$.name, files = arg$.files, src = arg$.src;
        if (!this$.bundler) {
          return;
        }
        files = files.map(function(file){
          if (/^https?:/.exec(file.url || file)) {
            return file.url || file;
          }
          if (file.url || typeof file === 'string') {
            return path.join(this$.desdir, file.url || file);
          }
          if (typeof file === 'object') {
            return import$({
              type: type
            }, file);
          }
          return file;
        });
        spec = {
          type: type,
          name: name,
          src: files,
          specsrc: [src]
        };
        return this$.bundler.addSpec(spec);
      }
    });
    if (this.i18n) {
      ret.i18n = function(it){
        return this$.i18n.t((it || '').trim());
      };
      ret.i18n.language = function(){
        return this$.i18n.language;
      };
      ret.i18n.intlbase = function(p, lng){
        p == null && (p = "");
        lng == null && (lng = "");
        if (!(lng = lng || this$.i18n.language)) {
          return p;
        }
        return path.join('/', this$.intlbase, lng, p);
      };
      ret.intlbase = function(p, lng){
        p == null && (p = "");
        lng == null && (lng = "");
        if (!(lng = lng || this$.i18n.language)) {
          return p;
        }
        return path.join('/', this$.intlbase, lng, p);
      };
      (ret.filters || (ret.filters = {})).i18n = function(t, o){
        return this$.i18n.t((t || '').trim());
      };
    }
    return ret;
  },
  getDependencies: function(file){
    var code, opt, ret, root;
    code = fs.readFileSync(file);
    opt = import$({
      basedir: path.resolve(this.srcdir),
      filename: file,
      doctype: 'html',
      compileDebug: false
    }, this.extapi);
    ret = pug.compileClientWithDependenciesTracked(code, opt);
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
    var alt;
    if (~file.indexOf(this.srcdir)) {
      return {
        src: file,
        desh: file.replace(this.srcdir, path.join(this.desdir, intl)).replace(/.pug$/, '.html'),
        desv: file.replace(this.srcdir, path.join(this.viewdir, intl)).replace(/.pug/, '.js')
      };
    } else {
      alt = path.resolve(path.join('/', path.relative('.', file)));
      return {
        src: file,
        desh: path.join(cwd, this.desdir, '.@root', intl, alt).replace(/.pug$/, '.html'),
        desv: path.join(cwd, this.viewdir, '.@root', intl, alt).replace(/.pug$/, '.js')
      };
    }
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
        var i$, ref$, len$, ref1$, file, mtime, src, desh, desv, code, t1, desvdir, opt, ret, t2, desdir, e, results$ = [];
        for (i$ = 0, len$ = (ref$ = files).length; i$ < len$; ++i$) {
          ref1$ = ref$[i$], file = ref1$.file, mtime = ref1$.mtime;
          ref1$ = this$.map(file, intl), src = ref1$.src, desh = ref1$.desh, desv = ref1$.desv;
          if (!fs.existsSync(src) || aux.newer(this$._noView ? desh : desv, mtime)) {
            continue;
          }
          code = fs.readFileSync(src).toString();
          try {
            t1 = Date.now();
            if (/^\/\/- ?module ?/.exec(code)) {
              continue;
            }
            if (!this$._noView) {
              desvdir = path.dirname(desv);
              fsExtra.ensureDirSync(desvdir);
              opt = import$({
                filename: src,
                basedir: path.resolve(this$.srcdir),
                doctype: 'html',
                compileDebug: false
              }, this$.extapi);
              ret = pug.compileClient(code, opt);
              ret = " (function() { " + ret + "; module.exports = template; })() ";
              fs.writeFileSync(desv, ret);
              t2 = Date.now();
              this$.log.info(src + " --> " + desv + " ( " + (t2 - t1) + "ms )");
            }
            if (!/^\/\/- ?view ?/.exec(code)) {
              desdir = path.dirname(desh);
              fsExtra.ensureDirSync(desdir);
              opt = import$({
                filename: src,
                basedir: path.resolve(this$.srcdir),
                doctype: 'html',
                compileDebug: false
              }, this$.extapi);
              fs.writeFileSync(desh, pug.render(code, opt));
              t2 = Date.now();
              results$.push(this$.log.info(src + " --> " + desh + " ( " + (t2 - t1) + "ms )"));
            }
          } catch (e$) {
            e = e$;
            this$.log.error((src + " failed: ").red);
            results$.push(this$.log.error(e.message.toString()));
          }
        }
        return results$;
      });
    };
    lngs = [''].concat(this.i18n && this._buildIntl
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
          return this$.log.warn((src + " --> " + f + " deleted.").yellow);
        }
      });
    };
    lngs = [''].concat(this.i18n && this._buildIntl
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