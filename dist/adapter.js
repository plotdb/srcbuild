// Generated by LiveScript 1.6.0
var fs, path, fsExtra, anymatch, aux, adapter;
fs = require('fs');
path = require('path');
fsExtra = require('fs-extra');
anymatch = require('anymatch');
aux = require('./aux');
adapter = function(opt){
  var that;
  opt == null && (opt = {});
  this.opt = opt;
  this.base = opt.base || '.';
  this.log = opt.logger || aux.logger;
  this.initScan = opt.initScan != null ? opt.initScan : true;
  this.ignored = (opt.watcher || (opt.watcher = {})).ignored || [];
  this.depends = {
    on: {},
    by: {}
  };
  if (that = opt.getDependencies) {
    this.getDependencies = that;
  }
  if (that = opt.isSupported) {
    this.isSupported = that;
  }
  if (that = opt.build) {
    this.build = that;
  }
  if (that = opt.purge) {
    this.purge = that;
  }
  if (that = opt.resolve) {
    this.resolve = that;
  }
  return this;
};
adapter.prototype = import$(Object.create(Object.prototype), {
  getDependencies: function(){
    return [];
  },
  isSupported: function(file){
    return false;
  },
  purge: function(files){},
  build: function(files){},
  resolve: function(file){
    return null;
  },
  logDependencies: function(file){
    var list, e, ref$, setby, this$ = this;
    try {
      list = (this.getDependencies(file) || []).map(path.normalize);
    } catch (e$) {
      e = e$;
      this.log.error(("analyse " + file + " failed: ").red);
      this.log.error(e.message.toString());
      throw ref$ = new Error(), ref$.name = 'lderror', ref$.id = 999, ref$;
      return;
    }
    Array.from(this.depends.by[file] || []).map(function(f){
      if (this$.depends.on[f]) {
        return this$.depends.on[f]['delete'](file);
      }
    });
    setby = this.depends.by[file] = new Set();
    return list.map(function(f){
      var seton, that;
      seton = (that = this$.depends.on[f])
        ? that
        : this$.depends.on[f] = new Set();
      seton.add(file);
      return setby.add(f);
    });
  },
  unlink: function(files){
    var ret, this$ = this;
    ret = files.filter(function(it){
      return this$.isSupported(it);
    }).map(function(it){
      return {
        file: it,
        mtime: 0
      };
    });
    return this.purge(ret);
  },
  change: function(files, opt){
    var affectedFiles, mtimes, queue, ret, now, file, e, mtime, this$ = this;
    opt == null && (opt = {});
    affectedFiles = new Set();
    mtimes = {};
    queue = (Array.isArray(files)
      ? files
      : [files]).map(function(it){
      return it;
    });
    ret = [];
    now = Date.now();
    while (queue.length) {
      file = queue.pop();
      if (!fs.existsSync(file)) {
        continue;
      }
      if (this.isSupported(file)) {
        try {
          this.logDependencies(file);
        } catch (e$) {
          e = e$;
          if (e.name === 'lderror' && e.id === 999) {
            continue;
          }
        }
      }
      affectedFiles.add(file);
      mtime = opt.force
        ? now
        : fs.existsSync(file) ? fs.statSync(file).mtime : now;
      if (!mtimes[file] || mtimes[file] < mtime) {
        mtimes[file] = mtime;
      }
      if (opt.nonRecursive) {
        continue;
      }
      Array.from(this.depends.on[file] || []).map(fn$);
    }
    ret = Array.from(affectedFiles).filter(function(it){
      return this$.isSupported(it);
    }).map(function(it){
      return {
        file: it,
        mtime: mtimes[it]
      };
    });
    return Promise.resolve(ret.length ? this.build(ret) : null);
    function fn$(f){
      if (!mtimes[f] || mtimes[f] < mtimes[file]) {
        mtimes[f] = mtimes[file];
      }
      return queue.push(f);
    }
  },
  dirtyCheck: function(files){
    var mtimes, recurse, this$ = this;
    mtimes = {};
    recurse = function(file){
      var that, stat, e;
      if (that = mtimes[file]) {
        return that;
      }
      if (!fs.existsSync(file)) {
        return 0;
      }
      try {
        stat = fs.statSync(file);
      } catch (e$) {
        e = e$;
        return 0;
      }
      return mtimes[file] = Math.max.apply(Math, [+stat.mtime].concat(Array.from(this$.depends.by[file] || []).map(function(f){
        return recurse(f);
      })));
    };
    return this.build(files.map(function(file){
      return {
        file: file,
        mtime: recurse(file)
      };
    }));
  },
  init: function(){
    var initBuilds, recurse, t1, this$ = this;
    if (!this.initScan) {
      return Promise.resolve();
    }
    initBuilds = [];
    recurse = function(root){
      var len1, len2, files, i$, len$, file, stat, e, results$ = [];
      if (!fs.existsSync(root)) {
        return;
      }
      len1 = fs.readdirSync(root).length;
      len2 = fs.readdirSync(root).filter(function(it){
        return !anymatch(this$.ignored || [], it);
      }).length;
      files = fs.readdirSync(root).filter(function(it){
        return !anymatch(this$.ignored || [], it);
      }).map(function(it){
        return path.normalize(root + "/" + it);
      });
      for (i$ = 0, len$ = files.length; i$ < len$; ++i$) {
        file = files[i$];
        try {
          stat = fs.statSync(file);
        } catch (e$) {
          e = e$;
          continue;
        }
        if (stat.isDirectory()) {
          recurse(file);
        }
        if (!this$.isSupported(file)) {
          continue;
        }
        try {
          this$.logDependencies(file);
        } catch (e$) {
          e = e$;
          if (e.name === 'lderror' && e.id === 999) {
            continue;
          }
        }
        results$.push(initBuilds.push(file));
      }
      return results$;
    };
    t1 = Date.now();
    recurse(this.base);
    return this.dirtyCheck(initBuilds);
  }
});
module.exports = adapter;
function import$(obj, src){
  var own = {}.hasOwnProperty;
  for (var key in src) if (own.call(src, key)) obj[key] = src[key];
  return obj;
}