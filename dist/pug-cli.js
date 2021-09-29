// Generated by LiveScript 1.6.0
var fs, fsExtra, path, yargs, pug, pugbuild, opt, argv, src, des, basedir, builder, extapi, ret;
fs = require('fs');
fsExtra = require('fs-extra');
path = require('path');
yargs = require('yargs');
pug = require('pug');
pugbuild = require("./ext/pug");
opt = {
  basedir: '.'
};
argv = yargs.option('base', {
  alias: 'b',
  description: "base directory",
  type: 'string'
}).option('output', {
  alias: 'o',
  description: "output filename",
  type: 'string'
}).check(function(argv, options){
  if (!(argv._[0] && fs.existsSync(argv._[0]))) {
    throw new Error("source file not found");
  }
  return true;
}).argv;
src = argv._[0];
des = argv.o;
basedir = argv.b || path.dirname(src) || '.';
builder = new pugbuild(opt);
extapi = builder.getExtapi();
ret = pug.render(fs.readFileSync(src).toString(), import$({
  filename: src,
  basedir: opt.basedir
}, extapi));
if (des) {
  fsExtra.ensureDirSync(path.dirname(des));
  fs.writeFileSync(des, ret);
} else {
  console.log(ret);
}
function import$(obj, src){
  var own = {}.hasOwnProperty;
  for (var key in src) if (own.call(src, key)) obj[key] = src[key];
  return obj;
}