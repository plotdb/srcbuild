// Generated by LiveScript 1.6.0
var fs, path, fsExtra, stylus, uglifycss, base, aux, adapter, stylusbuild;
fs = require('fs');
path = require('path');
fsExtra = require('fs-extra');
stylus = require('stylus');
uglifycss = require('uglifycss');
base = require('./base');
aux = require('../aux');
adapter = require('../adapter');
stylusbuild = function(opt){
  opt == null && (opt = {});
  return this.init(import$({
    srcdir: 'src/styl',
    desdir: 'static/css'
  }, opt));
};
stylusbuild.prototype = import$(Object.create(base.prototype), {
  getDependencies: function(file){
    var code, ret, root;
    code = fs.readFileSync(file).toString();
    ret = code.split('\n').map(function(it){
      return /\s*(@import)\s+(.+)$/.exec(it);
    }).filter(function(it){
      return it;
    }).map(function(it){
      return it[2].replace(/'/g, '').replace(/(\.styl)?$/, '.styl');
    }).map(function(it){
      return it;
    });
    root = path.resolve('.') + '/';
    return (ret || []).map(function(it){
      return it.replace(root, '');
    });
  },
  isSupported: function(file){
    return /\.styl$/.exec(file) && file.startsWith(this.srcdir);
  },
  map: function(file){
    return {
      src: file,
      des: file.replace(this.srcdir, this.desdir).replace(/\.styl$/, '.css'),
      desMin: file.replace(this.srcdir, this.desdir).replace(/\.styl$/, '.min.css')
    };
  },
  build: function(files){
    var i$, len$, ref$, file, mtime, src, des, desMin, t1, code, desdir, e, results$ = [], this$ = this;
    for (i$ = 0, len$ = files.length; i$ < len$; ++i$) {
      ref$ = files[i$], file = ref$.file, mtime = ref$.mtime;
      ref$ = this.map(file), src = ref$.src, des = ref$.des, desMin = ref$.desMin;
      if (!fs.existsSync(src) || aux.newer(des, mtime)) {
        continue;
      }
      try {
        t1 = Date.now();
        code = fs.readFileSync(src).toString();
        if (/^\/\/- ?(module) ?/.exec(code)) {
          continue;
        }
        desdir = path.dirname(des);
        fsExtra.ensureDirSync(desdir);
        results$.push(stylus(code).set('filename', src).render(fn$));
      } catch (e$) {
        e = e$;
        this.log.error("build " + src + " failed: ");
        results$.push(this.log.error(e.message.toString()));
      }
    }
    return results$;
    function fn$(e, css){
      var codeMin, t2;
      if (e) {
        throw e;
      }
      codeMin = uglifycss.processString(css, {
        uglyComments: true
      });
      fs.writeFileSync(des, css);
      fs.writeFileSync(desMin, codeMin);
      t2 = Date.now();
      return this$.log.info("build: " + src + " --> " + des + " / " + desMin + " ( " + (t2 - t1) + "ms )");
    }
  },
  unlink: function(files){
    var i$, len$, ref$, file, mtime, src, des, desMin, results$ = [];
    for (i$ = 0, len$ = files.length; i$ < len$; ++i$) {
      ref$ = files[i$], file = ref$.file, mtime = ref$.mtime;
      ref$ = this.map(file), src = ref$.src, des = ref$.des, desMin = ref$.desMin;
      results$.push([des, desMin].filter(fn$));
    }
    return results$;
    function fn$(f){
      if (!fs.existsSync(f)) {
        return;
      }
      fs.unlinkSync(f);
      return this.log.warn(src + " --> " + f + " deleted.");
    }
  }
});
module.exports = stylusbuild;
function import$(obj, src){
  var own = {}.hasOwnProperty;
  for (var key in src) if (own.call(src, key)) obj[key] = src[key];
  return obj;
}