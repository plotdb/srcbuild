// Generated by LiveScript 1.6.0
var fs, path, fsExtra, pug, aux, adapter;
fs = require('fs');
path = require('path');
fsExtra = require('fs-extra');
pug = require('pug');
aux = require('./aux');
adapter = function(opt){
  var that;
  opt == null && (opt = {});
  this.opt = opt;
  this.base = opt.base || '.';
  this.log = opt.logger || aux.logger;
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
  logDependencies: function(file){
    var list, e, setby, this$ = this;
    try {
      list = (this.getDependencies(file) || []).map(path.normalize);
    } catch (e$) {
      e = e$;
      list = [];
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
  change: function(files){
    var affectedFiles, mtimes, queue, ret, file, mtime, this$ = this;
    affectedFiles = new Set();
    mtimes = {};
    queue = (Array.isArray(files)
      ? files
      : [files]).map(function(it){
      return it;
    });
    ret = [];
    while (queue.length) {
      affectedFiles.add(file = queue.pop());
      if (!fs.existsSync(file)) {
        continue;
      }
      if (this.isSupported(file)) {
        this.logDependencies(file);
      }
      mtime = fs.statSync(file).mtime;
      if (!mtimes[file] || mtimes[file] < mtime) {
        mtimes[file] = mtime;
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
    if (ret.length) {
      return this.build(ret);
    }
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
      var that;
      if (that = mtimes[file]) {
        return that;
      }
      if (!fs.existsSync(file)) {
        return 0;
      }
      return mtimes[file] = Math.max.apply(Math, [+fs.statSync(file).mtime].concat(Array.from(this$.depends.by[file] || []).map(function(f){
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
    var initBuilds, recurse, this$ = this;
    initBuilds = [];
    recurse = function(root){
      var files, i$, len$, file, results$ = [];
      if (!fs.existsSync(root)) {
        return;
      }
      files = fs.readdirSync(root).map(function(it){
        return path.normalize(root + "/" + it);
      });
      for (i$ = 0, len$ = files.length; i$ < len$; ++i$) {
        file = files[i$];
        if (fs.statSync(file).isDirectory()) {
          recurse(file);
        }
        if (!this$.isSupported(file)) {
          continue;
        }
        this$.logDependencies(file);
        results$.push(initBuilds.push(file));
      }
      return results$;
    };
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