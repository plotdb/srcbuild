// Generated by LiveScript 1.6.0
var path, uglifyJs, uglifycss, debounce, base, aux, fs, spec, specmgr, build;
path = require('path');
uglifyJs = require('uglify-js');
uglifycss = require('uglifycss');
debounce = require('@loadingio/debounce.js');
base = require('./base');
aux = require('../aux');
fs = require("fs-extra");
spec = function(o){
  var ref$;
  o == null && (o = {});
  this.mgr = o.manager;
  this.log = o.log;
  this.o = JSON.parse(JSON.stringify({
    name: o.name,
    type: o.type,
    codesrc: o.codesrc,
    specsrc: o.specsrc,
    deps: o.deps
  }));
  this.type = (ref$ = this.o).type;
  this.name = ref$.name;
  this.src = (Array.isArray(o.src)
    ? o.src
    : [o.src]).filter(function(it){
    return it;
  });
  this.codesrc = new Set(this.o.codesrc || []);
  this.specsrc = new Set(this.o.specsrc || []);
  this.deps = new Set(this.o.deps || []);
  return this;
};
spec.prototype = import$(Object.create(Object.prototype), {
  toObject: function(){
    var ref$;
    return ref$ = {
      codesrc: Array.from(this.codesrc),
      specsrc: Array.from(this.specsrc),
      deps: Array.from(this.deps)
    }, ref$.type = this.type, ref$.name = this.name, ref$;
  },
  cacheFn: function(){
    return this.mgr.getCacheName(this);
  },
  syncCache: function(){
    var fn, this$ = this;
    fn = this.cacheFn();
    return fs.ensureDir(path.dirname(fn)).then(function(){
      fs.writeFile(fn, JSON.stringify(this$.toObject()));
      return this$.log.info("bundle dependency written to " + fn);
    });
  }
});
specmgr = function(o){
  o == null && (o = {});
  this.log = o.log;
  this.cachedir = o.cachedir;
  this.evthdr = {};
  this._ = {};
  this.codesrc = {};
  this.specsrc = {};
  this.deps = {};
  this._dirty = new Set();
  return this;
};
specmgr.prototype = import$(Object.create(Object.prototype), {
  on: function(n, cb){
    var this$ = this;
    return (Array.isArray(n)
      ? n
      : [n]).map(function(n){
      var ref$;
      return ((ref$ = this$.evthdr)[n] || (ref$[n] = [])).push(cb);
    });
  },
  fire: function(n){
    var v, res$, i$, to$, ref$, len$, cb, results$ = [];
    res$ = [];
    for (i$ = 1, to$ = arguments.length; i$ < to$; ++i$) {
      res$.push(arguments[i$]);
    }
    v = res$;
    for (i$ = 0, len$ = (ref$ = this.evthdr[n] || []).length; i$ < len$; ++i$) {
      cb = ref$[i$];
      results$.push(cb.apply(this, v));
    }
    return results$;
  },
  key: function(o){
    o == null && (o = {});
    if (typeof o === 'object') {
      return o.type + "/" + o.name;
    } else {
      return o;
    }
  },
  getCacheName: function(spec){
    return path.join(this.cachedir, spec.type, spec.name + ".dep");
  },
  setDirty: function(o){
    o == null && (o = {});
    this._dirty.add(this.key(o));
    return this.clearDirty();
  },
  clearDirty: debounce(1000, function(){
    var specs, this$ = this;
    specs = Array.from(this._dirty).map(function(k){
      return this$.get(k);
    }).filter(function(it){
      return it;
    });
    this.fire('build-by-spec', specs);
    specs.map(function(s){
      return s.syncCache();
    });
    return this._dirty.clear();
  }),
  add: function(o, opt){
    var k, that, s, this$ = this;
    o == null && (o = {});
    opt == null && (opt = {});
    k = this.key(o);
    if (that = this._[k] && !opt.force) {
      return that;
    }
    this._[k] = s = new spec(import$({
      log: this.log,
      manager: this
    }, o));
    s.codesrc.forEach(function(n){
      return this$.link({
        codesrc: n,
        spec: s
      });
    });
    s.specsrc.forEach(function(n){
      return this$.link({
        specsrc: n,
        spec: s
      });
    });
    s.deps.forEach(function(n){
      return this$.link({
        deps: n,
        spec: s
      });
    });
    if (!opt.init) {
      this.setDirty(s);
    }
    return s;
  },
  set: function(o, opt){
    o == null && (o = {});
    opt == null && (opt = {});
    return this.add(o, import$({
      force: true
    }, opt));
  },
  hasCode: function(f){
    return !!this.codesrc[f] || !!this.deps[f];
  },
  touchCode: function(files){
    var keys, this$ = this;
    files = Array.isArray(files)
      ? files
      : [files];
    keys = new Set();
    files.map(function(f){
      if (typeof f === 'object') {
        f = f.file;
      }
      if (this$.codesrc[f]) {
        Array.from(this$.codesrc[f]).forEach(function(k){
          return keys.add(k);
        });
      }
      if (this$.deps[f]) {
        return Array.from(this$.deps[f]).forEach(function(k){
          return keys.add(k);
        });
      }
    });
    return this.fire('build-by-spec', Array.from(keys).map(function(k){
      return this$.get(k);
    }));
  },
  update: function(o){
    var k, dirty, s, this$ = this;
    o == null && (o = {});
    k = this.key(o);
    dirty = false;
    if (!(s = this._[k])) {
      this.add(o);
      return true;
    }
    if (Array.from(s.codesrc).join(',') !== (o.codesrc || []).join(',')) {
      dirty = true;
    }
    if (s.src.join(',') !== (o.src || []).join(',')) {
      dirty = true;
    }
    s.src = (Array.isArray(o.src)
      ? o.src
      : [o.src]).filter(function(it){
      return it;
    });
    s.codesrc = new Set(o.codesrc || []);
    s.deps = new Set(o.deps || []);
    (Array.isArray(o.specsrc)
      ? o.specsrc
      : [o.specsrc]).forEach(function(n){
      if (!s.specsrc.has(n)) {
        dirty = true;
      }
      return s.specsrc.add(n);
    });
    s.codesrc.forEach(function(n){
      return this$.link({
        codesrc: n,
        spec: s
      });
    });
    s.specsrc.forEach(function(n){
      return this$.link({
        specsrc: n,
        spec: s
      });
    });
    s.deps.forEach(function(n){
      return this$.link({
        deps: n,
        spec: s
      });
    });
    if (dirty) {
      this.setDirty(s);
    }
    return dirty;
  },
  get: function(o){
    o == null && (o = {});
    return this._[this.key(o)];
  },
  'delete': function(o){
    var s, this$ = this;
    o == null && (o = {});
    s = this._[this.key(o)];
    s.codesrc.forEach(function(n){
      return this$.unlink({
        codesrc: n,
        spec: s
      });
    });
    s.specsrc.forEach(function(n){
      return this$.unlink({
        specsrc: n,
        spec: s
      });
    });
    s.deps.forEach(function(n){
      return this$.unlink({
        deps: n,
        spec: s
      });
    });
    return this.setDirty(o);
  },
  link: function(o){
    var f, s, that;
    o == null && (o = {});
    f = o.codesrc
      ? 'codesrc'
      : o.specsrc ? 'specsrc' : 'deps';
    s = (that = this[f][o[f]])
      ? that
      : this[f][o[f]] = new Set();
    if (!s) {
      return;
    }
    return s.add(this.key(o.spec));
  },
  unlink: function(o){
    var f, s, ref$, key$, ref1$;
    o == null && (o = {});
    f = o.codesrc
      ? 'codesrc'
      : o.specsrc ? 'specsrc' : 'deps';
    if (!(s = this[f][o[f]])) {
      return;
    }
    s.remove(this.key(o.spec));
    if (s.size) {
      return;
    }
    return ref1$ = (ref$ = this[f])[key$ = o[f]], delete ref$[key$], ref1$;
  },
  delSpecsrc: function(n){
    var s, ref$, ref1$, this$ = this;
    if (!(s = this.specsrc[n])) {
      return;
    }
    s.forEach(function(k){
      var spec;
      if (!(spec = this$.get(k))) {
        return;
      }
      spec.unlink({
        specsrc: n
      });
      return this$.setDirty(k);
    });
    return ref1$ = (ref$ = this.specsrc)[n], delete ref$[n], ref1$;
  }
});
build = function(o){
  o == null && (o = {});
  this.mgr = o.manager;
  this.defcfg = o.config || null;
  this.cachedir = path.join(o.base, '.bundle-dep');
  this.cfgfn = o.configFile || null;
  this.reldir = typeof o.relativePath === 'string'
    ? o.relativePath
    : o.relativePath && this.cfgfn
      ? path.dirname(this.cfgfn)
      : process.cwd();
  this.log = o.logger || aux.logger;
  this.reload();
  this.init(import$({
    srcdir: 'static',
    desdir: 'static'
  }, o));
  return this;
};
build.prototype = import$(Object.create(base.prototype), {
  getPath: function(f){
    var version, p;
    if (typeof f === 'string') {
      return f;
    }
    if (this.mgr) {
      return this.mgr.getUrl(f);
    }
    version = f.version || 'main';
    p = f.path
      ? f.path
      : f.type === 'css'
        ? 'index.min.css'
        : f.type === 'block' ? 'index.html' : 'index.min.js';
    return path.join(this.desdir, "assets/lib/" + f.name + "/" + version + "/" + p);
  },
  reload: function(){
    this.reset();
    this.loadCfg();
    return this.loadCaches();
  },
  reset: function(){
    var this$ = this;
    this.specmgr = new specmgr({
      cachedir: this.cachedir,
      log: this.log
    });
    return this.specmgr.on('build-by-spec', function(specs){
      return specs.forEach(function(spec){
        return this$.buildBySpec(spec);
      });
    });
  },
  loadCfg: function(){
    var cfgs, cfg, e, i$, len$, ref$, fn, lresult$, type, lresult1$, name, list, codesrc, results$ = [], this$ = this;
    cfgs = [['', this.defcfg]];
    if (this.cfgfn && fs.existsSync(this.cfgfn)) {
      try {
        cfg = JSON.parse(fs.readFileSync(this.cfgfn).toString());
      } catch (e$) {
        e = e$;
        this.log.error(("parse error of config file " + this.cfgfn).red);
        cfg = {};
      }
      cfgs.push([this.cfgfn, cfg]);
    }
    for (i$ = 0, len$ = cfgs.length; i$ < len$; ++i$) {
      ref$ = cfgs[i$], fn = ref$[0], cfg = ref$[1];
      lresult$ = [];
      for (type in cfg) {
        lresult1$ = [];
        for (name in ref$ = cfg[type]) {
          list = ref$[name];
          codesrc = list.map(fn$);
          lresult1$.push(this.specmgr.set({
            type: type,
            name: name,
            src: list,
            codesrc: codesrc,
            specsrc: [fn]
          }, {
            init: true
          }));
        }
        lresult$.push(lresult1$);
      }
      results$.push(lresult$);
    }
    return results$;
    function fn$(n){
      if (typeof n === 'string') {
        return path.join(this$.reldir, n);
      } else {
        return this$.getPath(n);
      }
    }
  },
  loadCaches: function(){
    var traverse, files, this$ = this;
    if (!fs.existsSync(this.cachedir)) {
      return;
    }
    traverse = function(dir){
      var files, ret, i$, len$, file;
      files = fs.readdirSync(dir).map(function(n){
        return path.join(dir, n);
      });
      ret = [];
      for (i$ = 0, len$ = files.length; i$ < len$; ++i$) {
        file = files[i$];
        if (fs.statSync(file).isDirectory()) {
          ret = ret.concat(traverse(file));
        }
        if (/\.dep$/.exec(file)) {
          ret.push(file);
        }
      }
      return ret;
    };
    files = traverse(this.cachedir);
    return files.forEach(function(n){
      var json, e;
      try {
        json = JSON.parse(fs.readFileSync(n).toString());
      } catch (e$) {
        e = e$;
        console.log(e);
        this$.log.error(("parse error of cache file " + n).red);
      }
      return this$.specmgr.set(json, {
        init: true
      });
    });
  },
  delSpecsrc: function(n){
    return specmgr.delSpecsrc(n);
  },
  addSpec: function(opts){
    var this$ = this;
    opts == null && (opts = []);
    opts = (Array.isArray(opts)
      ? opts
      : [opts]).filter(function(it){
      return it;
    });
    return opts.map(function(o){
      var codesrc, specsrc, deps, ref$, ref1$;
      if (o.type === 'block') {
        return this$.mgr.bundle({
          blocks: o.codesrc || (o.codesrc = [])
        }).then(function(r){
          var deps, codesrc, specsrc, ref$, ref1$;
          if (!(r && r.deps)) {
            this$.log.warn("block bundle requires block > 4.8.0 to work properly");
          }
          deps = r.deps || {
            js: [],
            css: [],
            block: []
          };
          deps = (deps.js.concat(deps.css, deps.block)).map(function(f){
            return this$.getPath(f);
          });
          codesrc = (o.src || (o.src = [])).map(function(f){
            return this$.getPath(f);
          });
          specsrc = Array.isArray(o.specsrc)
            ? o.specsrc
            : [o.specsrc];
          return this$.specmgr.update((ref$ = (ref1$ = {}, ref1$.name = o.name, ref1$.type = o.type, ref1$.src = o.src, ref1$), ref$.codesrc = codesrc, ref$.specsrc = specsrc, ref$.deps = deps, ref$));
        });
      } else {
        codesrc = (o.src || (o.src = [])).map(function(f){
          return this$.getPath(f);
        });
        specsrc = (Array.isArray(o.specsrc)
          ? o.specsrc
          : [o.specsrc]).filter(function(it){
          return it;
        });
        deps = (Array.isArray(o.deps)
          ? o.deps
          : [o.deps]).filter(function(it){
          return it;
        });
        return this$.specmgr.update((ref$ = (ref1$ = {}, ref1$.name = o.name, ref1$.type = o.type, ref1$.src = o.src, ref1$), ref$.codesrc = codesrc, ref$.specsrc = specsrc, ref$.deps = deps, ref$));
      }
    });
  },
  getDependencies: function(file){
    return [];
  },
  isSupported: function(file){
    return this.specmgr.hasCode(file);
  },
  purge: function(files){
    return this.build(files);
  },
  build: function(files, opt){
    var force, this$ = this;
    force = typeof opt === 'boolean' ? opt : false;
    if (opt == null) {
      opt = {};
    }
    if (files.filter(function(it){
      return it.file === this$.cfgfn;
    }).length) {
      return this.reload();
    }
    return this.specmgr.touchCode(files);
  },
  desPath: function(arg$){
    var name, type, _desdir, ext, des, desMin, desdir;
    name = arg$.name, type = arg$.type;
    _desdir = path.join(this.desdir, 'assets', 'bundle');
    ext = type === 'block' ? 'html' : type;
    des = path.join(_desdir, name + "." + ext);
    desMin = path.join(_desdir, name + ".min." + ext);
    desdir = path.dirname(des);
    return {
      desdir: desdir,
      des: des,
      desMin: desMin
    };
  },
  buildBySpec: function(spec){
    var this$ = this;
    return Promise.resolve().then(function(){
      var name, type, t1, srcs, ref$, desdir, des, desMin, ext;
      name = spec.name, type = spec.type;
      t1 = Date.now();
      srcs = Array.from(spec.codesrc);
      ref$ = this$.desPath({
        name: name,
        type: type
      }), desdir = ref$.desdir, des = ref$.des, desMin = ref$.desMin;
      ext = type === 'block' ? 'html' : type;
      return fs.ensureDir(desdir).then(function(){
        var ps;
        if (type === 'block') {
          return this$.mgr.bundle({
            blocks: spec.src
          }).then(function(ret){
            var code;
            code = ret.code || ret;
            return Promise.all([fs.writeFile(des, code), fs.writeFile(desMin, code)]);
          });
        } else {
          ps = srcs.map(function(f){
            var fMin;
            f = f.replace(".min." + ext, "." + ext);
            fMin = f.replace("." + ext, ".min." + ext);
            return fs.readFile(f)['catch'](function(){
              return "";
            }).then(function(b){
              return fs.readFile(fMin)['catch'](function(){
                return "";
              }).then(function(bm){
                return {
                  name: f,
                  code: b.toString(),
                  codeMin: bm.toString()
                };
              });
            });
          });
          return Promise.all(ps).then(function(ret){
            var normal, minified;
            normal = ret.map(function(it){
              return it.code || it.codeMin;
            }).join('');
            minified = ret.map(function(o){
              if (o.codeMin) {
                return o.codeMin;
              }
              if (!o.code) {
                return "";
              }
              return type === 'js'
                ? uglifyJs.minify(o.code).code
                : type === 'css'
                  ? uglifycss.processString(o.code, {
                    uglyComments: true
                  })
                  : o.code;
            }).join('');
            return Promise.all([fs.writeFile(des, normal), fs.writeFile(desMin, minified)]);
          });
        }
      }).then(function(){
        var ret, size, sizeMin, elapsed;
        ret = {
          type: type,
          name: name,
          elapsed: Date.now() - t1,
          size: fs.statSync(des).size,
          sizeMin: fs.statSync(desMin).size
        };
        size = ret.size, sizeMin = ret.sizeMin, elapsed = ret.elapsed;
        this$.log.info("bundle " + des + " ( " + size + " bytes / " + elapsed + "ms )");
        this$.log.info("bundle " + desMin + " ( " + sizeMin + " bytes / " + elapsed + "ms )");
        return ret;
      })['catch'](function(e){
        this$.log.error((des + " failed: ").red);
        return this$.log.error(e.message.toString());
      });
    });
  }
});
module.exports = build;
function import$(obj, src){
  var own = {}.hasOwnProperty;
  for (var key in src) if (own.call(src, key)) obj[key] = src[key];
  return obj;
}