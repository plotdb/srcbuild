// Generated by LiveScript 1.6.0
var fs, path, fsExtra, chokidar, debounce, aux, watch;
fs = require('fs');
path = require('path');
fsExtra = require('fs-extra');
chokidar = require('chokidar');
debounce = require('@loadingio/debounce.js');
aux = require('./aux');
watch = function(opt){
  opt == null && (opt = {});
  this.opt = opt;
  this.buf = {};
  this.adapters = opt.adapters || [];
  this.chokidarCfg = {
    persistent: true,
    ignored: [],
    ignoreInitial: true
  };
  this.log = opt.logger || aux.logger;
  this.init();
  return this;
};
watch.prototype = import$(Object.create(Object.prototype), {
  addAdapter: function(b){
    if (Array.isArray(b)) {
      return this.adapters = this.adapters.concat(b);
    } else {
      return this.adapters.push(b);
    }
  },
  init: function(){
    var this$ = this;
    this.watcher = chokidar.watch(['.'], this.chokidarCfg).on('add', function(it){
      return this$.add(path.normalize(it));
    }).on('change', function(it){
      return this$.change(path.normalize(it));
    }).on('unlink', function(it){
      return this$.unlink(path.normalize(it));
    });
    this.log.info("watching src for file change");
    return this.changeDebounced = debounce(function(){
      var files;
      files = Array.from(this$.buf.change);
      this$.buf.change = null;
      return this$.adapters.map(function(it){
        return it.change(files);
      });
    });
  },
  add: function(file){
    return this.adapters.map(function(it){
      return it.change(file);
    });
  },
  unlink: function(file){
    return this.adapters.map(function(it){
      return it.unlink(file);
    });
  },
  change: function(file){
    if (!this.buf.change) {
      this.buf.change = new Set();
    }
    this.buf.change.add(file);
    return this.changeDebounced();
  }
});
module.exports = watch;
function import$(obj, src){
  var own = {}.hasOwnProperty;
  for (var key in src) if (own.call(src, key)) obj[key] = src[key];
  return obj;
}