// Generated by LiveScript 1.6.0
var fs, colors, aux, log;
fs = require('fs');
colors = require('@plotdb/colors');
aux = {
  newer: function(f1, files, strict){
    var mtime, dtime;
    files == null && (files = []);
    strict == null && (strict = false);
    if (!fs.existsSync(f1)) {
      return false;
    }
    mtime = +fs.statSync(f1).mtime;
    if (files instanceof Date || typeof files === 'number') {
      dtime = mtime - +files;
      return strict
        ? dtime > 0
        : dtime >= 0;
    }
    files = Array.isArray(files)
      ? files
      : [files];
    return files.length === files.filter(function(f2){
      var dtime;
      if (!fs.existsSync(f2)) {
        return true;
      }
      dtime = mtime - +fs.statSync(f2).mtime;
      if (strict) {
        return dtime > 0;
      } else {
        return dtime >= 0;
      }
    }).length;
  }
};
aux.logger = log = {};
[['info', 'green'], ['warn', 'yellow'], ['error', 'red']].map(function(n){
  return log[n[0]] = function(){
    var args, res$, i$, to$;
    res$ = [];
    for (i$ = 0, to$ = arguments.length; i$ < to$; ++i$) {
      res$.push(arguments[i$]);
    }
    args = res$;
    args = [n[0].toUpperCase()[n[1]] + "\t: [build]"].concat(args);
    return console[n[0]].apply(console, args);
  };
});
module.exports = aux;