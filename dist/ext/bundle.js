// Generated by LiveScript 1.6.0
var fs, path, fsExtra, uglifyJs, uglifycss, colors, base, aux, adapter, bundlebuild;
fs = require('fs');
path = require('path');
fsExtra = require('fs-extra');
uglifyJs = require('uglify-js');
uglifycss = require('uglifycss');
colors = require('colors');
base = require('./base');
aux = require('../aux');
adapter = require('../adapter');
bundlebuild = function(opt){
  opt == null && (opt = {});
  this.config = opt.config || {
    css: {},
    js: {}
  };
  this.configFile = opt.configFile || null;
  this.prepareConfig();
  return this.init(import$({
    srcdir: 'static',
    desdir: 'static'
  }, opt));
};
bundlebuild.prototype = import$(Object.create(base.prototype), {
  prepareConfig: function(){
    var type, name, ref$, list, i$, len$, f;
    if (this.configFile && fs.existsSync(this.configFile)) {
      this.config = JSON.parse(fs.readFileSync(this.configFile).toString());
    }
    this.fileList = new Set();
    this.fileMap = {};
    for (type in this.config) {
      for (name in ref$ = this.config[type]) {
        list = ref$[name];
        for (i$ = 0, len$ = list.length; i$ < len$; ++i$) {
          f = list[i$];
          this.fileList.add(f);
          this.fileMap[f] = {
            type: type,
            name: name
          };
        }
      }
    }
    return this.fileList.add(this.configFile);
  },
  getDependencies: function(file){
    return file === this.configFile
      ? []
      : [this.configFile];
  },
  isSupported: function(file){
    return this.fileList.has(file);
  },
  resolve: function(file){
    var re, ret;
    re = new RegExp("^" + this.desdir + "/(css|js)/pack/(.+?)(.min)?.(css|js)");
    if (!(ret = re.exec(file))) {
      return null;
    }
    return (this.config[ret[1]][ret[2]] || [])[0];
  },
  build: function(files){
    var dirty, i$, len$, file, ret, key$, ps, type, name, desdir, des, this$ = this;
    if (files.filter(function(it){
      return it.file === this$.configFile;
    }).length) {
      this.prepareConfig();
      files = Array.from(this.fileList);
      files.splice(files.indexOf(this.configFile), 1);
      return this.build(files);
    }
    dirty = {};
    for (i$ = 0, len$ = files.length; i$ < len$; ++i$) {
      file = files[i$];
      if (!(ret = this.fileMap[file.file])) {
        continue;
      }
      (dirty[key$ = ret.type] || (dirty[key$] = {}))[ret.name] = true;
    }
    ps = [];
    for (type in dirty) {
      for (name in dirty[type]) {
        desdir = path.join(this.desdir, type, 'pack');
        des = path.join(desdir, name + "." + type);
        if (aux.newer(des, (this.config[type][name] || []).concat([this.configFile]))) {
          continue;
        }
        ps.push(this.buildByName({
          type: type,
          name: name
        }));
      }
    }
    return Promise.all(ps);
  },
  buildByName: function(arg$){
    var name, type, this$ = this;
    name = arg$.name, type = arg$.type;
    return Promise.resolve().then(function(){
      var t1, srcs, desdir, des, desMin;
      t1 = Date.now();
      srcs = this$.config[type][name];
      desdir = path.join(this$.desdir, type, 'pack');
      des = path.join(desdir, name + "." + type);
      desMin = path.join(desdir, name + ".min." + type);
      return Promise.resolve().then(function(){
        return new Promise(function(res, rej){
          return fsExtra.ensureDir(desdir, function(){
            return res();
          });
        });
      }).then(function(){
        return Promise.all([
          Promise.all(srcs.map(function(f){
            return new Promise(function(res, rej){
              return fs.readFile(f, function(e, b){
                if (e) {
                  return rej(e);
                } else {
                  return res({
                    name: f,
                    code: b.toString()
                  });
                }
              });
            });
          })), Promise.all(srcs.map(function(f){
            return new Promise(function(res, rej){
              var fm;
              fm = f.replace(/\.(js|css)$/, '.min.$1');
              return fs.readFile(fm, function(e, b){
                if (e) {
                  return fs.readFile(f, function(e, b){
                    if (e) {
                      return rej(e);
                    } else {
                      return res({
                        name: fm,
                        code: b.toString()
                      });
                    }
                  });
                } else {
                  return res({
                    name: f,
                    code: b.toString()
                  });
                }
              });
            });
          }))
        ]);
      }).then(function(ret){
        var normal, minified;
        normal = ret[0].map(function(it){
          return it.code;
        }).join('');
        minified = ret[1].map(function(arg$){
          var name, code;
          name = arg$.name, code = arg$.code;
          return /\.min\./.exec(name)
            ? code
            : type === 'js'
              ? uglifyJs.minify(code).code
              : type === 'css' ? uglifycss.processString(code, {
                uglyComments: true
              }) : code;
        }).join('');
        return Promise.all([
          new Promise(function(res, rej){
            return fs.writeFile(des, normal, function(e, b){
              return res(b);
            });
          }), new Promise(function(res, rej){
            return fs.writeFile(desMin, minified, function(e, b){
              return res(b);
            });
          })
        ]);
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
        this$.log.info("bundle: static/" + type + "/pack/" + name + "." + type + " ( " + size + " bytes / " + elapsed + "ms )");
        this$.log.info("bundle: static/" + type + "/pack/" + name + ".min." + type + " ( " + sizeMin + " bytes / " + elapsed + "ms )");
        return ret;
      });
    });
  },
  purge: function(files){
    return this.build(files);
  }
});
module.exports = bundlebuild;
function import$(obj, src){
  var own = {}.hasOwnProperty;
  for (var key in src) if (own.call(src, key)) obj[key] = src[key];
  return obj;
}