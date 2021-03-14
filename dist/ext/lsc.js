// Generated by LiveScript 1.6.0
var fs, path, fsExtra, livescript, uglifyJs, colors, base, aux, adapter, lscbuild;
fs = require('fs');
path = require('path');
fsExtra = require('fs-extra');
livescript = require('livescript');
uglifyJs = require('uglify-js');
colors = require('colors');
base = require('./base');
aux = require('../aux');
adapter = require('../adapter');
lscbuild = function(opt){
  opt == null && (opt = {});
  return this.init(import$({
    srcdir: 'src/ls',
    desdir: 'static/js'
  }, opt));
};
lscbuild.prototype = import$(Object.create(base.prototype), {
  getDependencies: function(file){
    return [];
  },
  isSupported: function(file){
    return /\.ls$/.exec(file) && file.startsWith(this.srcdir);
  },
  resolve: function(file){
    var re, ret;
    re = new RegExp("^" + this.desdir + "/(.+?)(.min)?.js");
    ret = re.exec(file);
    if (ret) {
      return path.join(this.srcdir, ret[1] + ".ls");
    }
    return null;
  },
  map: function(file){
    return {
      src: file,
      des: file.replace(this.srcdir, this.desdir).replace(/\.ls$/, '.js'),
      desMin: file.replace(this.srcdir, this.desdir).replace(/\.ls$/, '.min.js')
    };
  },
  build: function(files){
    var i$, len$, ref$, file, mtime, src, des, desMin, t1, code, desdir, codeMin, t2, e, results$ = [];
    for (i$ = 0, len$ = files.length; i$ < len$; ++i$) {
      ref$ = files[i$], file = ref$.file, mtime = ref$.mtime;
      ref$ = this.map(file), src = ref$.src, des = ref$.des, desMin = ref$.desMin;
      if (!fs.existsSync(src) || aux.newer(des, mtime)) {
        continue;
      }
      try {
        t1 = Date.now();
        code = fs.readFileSync(src).toString();
        desdir = path.dirname(des);
        fsExtra.ensureDirSync(desdir);
        code = livescript.compile(fs.readFileSync(src).toString(), {
          bare: true,
          header: false
        });
        codeMin = uglifyJs.minify(code).code;
        fs.writeFileSync(des, code);
        fs.writeFileSync(desMin, codeMin);
        t2 = Date.now();
        results$.push(this.log.info("build: " + src + " --> " + des + " / " + desMin + " ( " + (t2 - t1) + "ms )"));
      } catch (e$) {
        e = e$;
        this.log.error(("build " + src + " failed: ").red);
        results$.push(this.log.error(e.message.toString()));
      }
    }
    return results$;
  },
  purge: function(files){
    var i$, len$, ref$, file, mtime, src, des, desMin, results$ = [], this$ = this;
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
      return this$.log.warn(("purge: " + src + " --> " + f + " deleted.").yellow);
    }
  }
});
module.exports = lscbuild;
function import$(obj, src){
  var own = {}.hasOwnProperty;
  for (var key in src) if (own.call(src, key)) obj[key] = src[key];
  return obj;
}