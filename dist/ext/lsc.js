// Generated by LiveScript 1.6.0
var fs, path, stream, fsExtra, livescript, uglifyJs, colors, base, aux, adapter, rootdir, glslify, browserify, lscbuild;
fs = require('fs');
path = require('path');
stream = require('stream');
fsExtra = require('fs-extra');
livescript = require('livescript');
uglifyJs = require('uglify-js');
colors = require('colors');
base = require('./base');
aux = require('../aux');
adapter = require('../adapter');
rootdir = path.dirname(fs.realpathSync(__filename));
glslify = null;
browserify = null;
lscbuild = function(opt){
  opt == null && (opt = {});
  this.useGlslify = opt.useGlslify;
  if (this.useGlslify && !glslify) {
    glslify = require("glslify");
    browserify = require("browserify");
  }
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
    var this$ = this;
    return Promise.all(files.map(function(arg$){
      var file, mtime, ref$, src, des, desMin, t1;
      file = arg$.file, mtime = arg$.mtime;
      ref$ = this$.map(file), src = ref$.src, des = ref$.des, desMin = ref$.desMin;
      t1 = Date.now();
      return Promise.resolve().then(function(){
        var code, desdir;
        if (!fs.existsSync(src) || aux.newer(des, mtime)) {
          return Promise.resolve();
        }
        code = fs.readFileSync(src).toString();
        desdir = path.dirname(des);
        fsExtra.ensureDirSync(desdir);
        code = livescript.compile(fs.readFileSync(src).toString(), {
          bare: true,
          header: false
        });
        if (!this$.useGlslify) {
          return Promise.resolve();
        }
        return new Promise(function(res, rej){
          var s, bobj;
          s = new stream.Readable();
          s.push(code);
          s.push(null);
          bobj = browserify(s, {
            basedir: rootdir
          });
          bobj.transform('glslify');
          return bobj.bundle(function(e, b){
            if (e) {
              return rej(e);
            } else {
              return res(b);
            }
          });
        });
      }).then(function(code){
        var codeMin, t2;
        if (!code) {
          return;
        }
        codeMin = uglifyJs.minify(code).code || '';
        fs.writeFileSync(des, code);
        fs.writeFileSync(desMin, codeMin);
        t2 = Date.now();
        return this$.log.info(src + " --> " + des + " / " + desMin + " ( " + (t2 - t1) + "ms )");
      })['catch'](function(e){
        this$.log.error((src + " failed: ").red);
        return this$.log.error(e.message.toString());
      });
    }));
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
      return this$.log.warn((src + " --> " + f + " deleted.").yellow);
    }
  }
});
module.exports = lscbuild;
function import$(obj, src){
  var own = {}.hasOwnProperty;
  for (var key in src) if (own.call(src, key)) obj[key] = src[key];
  return obj;
}