 (function() { function pug_rethrow(e,n,r,t){if(!(e instanceof Error))throw e;if(!("undefined"==typeof window&&n||t))throw e.message+=" on line "+r,e;var o,a,i,s;try{t=t||require("fs").readFileSync(n,{encoding:"utf8"}),o=3,a=t.split("\n"),i=Math.max(r-o,0),s=Math.min(a.length,r+o)}catch(t){return e.message+=" - could not read from "+n+" ("+t.message+")",void pug_rethrow(e,null,r)}o=a.slice(i,s).map(function(e,n){var t=n+i+1;return(t==r?"  > ":"    ")+t+"| "+e}).join("\n"),e.path=n;try{e.message=(n||"Pug")+":"+r+"\n"+o+"\n\n"+e.message}catch(e){}throw e}function template(locals) {var pug_html = "", pug_mixins = {}, pug_interp;var pug_debug_filename, pug_debug_line;try {;pug_debug_line = 1;pug_debug_filename = "web\u002Fsrc\u002Fpug\u002Fc.pug";
pug_html = pug_html + "\u003C!DOCTYPE html\u003E";
;pug_debug_line = 2;pug_debug_filename = "web\u002Fsrc\u002Fpug\u002Fc.pug";
pug_html = pug_html + "\u003Chtml\u003E";
;pug_debug_line = 3;pug_debug_filename = "web\u002Fsrc\u002Fpug\u002Fc.pug";
pug_html = pug_html + "\u003Chead\u003E\u003C\u002Fhead\u003E";
;pug_debug_line = 4;pug_debug_filename = "web\u002Fsrc\u002Fpug\u002Fc.pug";
pug_html = pug_html + "\u003Cbody\u003E";
;pug_debug_line = 1;pug_debug_filename = "\u002FUsers\u002Ftkirby\u002Fworkspace\u002Fzbryikt\u002Fplotdb\u002Fprojects\u002Fsrcbuild\u002Fweb\u002Fsrc\u002Fpug\u002Fb.pug";
pug_html = pug_html + "\u003C!DOCTYPE html\u003E";
;pug_debug_line = 2;pug_debug_filename = "\u002FUsers\u002Ftkirby\u002Fworkspace\u002Fzbryikt\u002Fplotdb\u002Fprojects\u002Fsrcbuild\u002Fweb\u002Fsrc\u002Fpug\u002Fb.pug";
pug_html = pug_html + "\u003Chtml\u003E";
;pug_debug_line = 3;pug_debug_filename = "\u002FUsers\u002Ftkirby\u002Fworkspace\u002Fzbryikt\u002Fplotdb\u002Fprojects\u002Fsrcbuild\u002Fweb\u002Fsrc\u002Fpug\u002Fb.pug";
pug_html = pug_html + "\u003Chead\u003E\u003C\u002Fhead\u003E";
;pug_debug_line = 4;pug_debug_filename = "\u002FUsers\u002Ftkirby\u002Fworkspace\u002Fzbryikt\u002Fplotdb\u002Fprojects\u002Fsrcbuild\u002Fweb\u002Fsrc\u002Fpug\u002Fb.pug";
pug_html = pug_html + "\u003Cbody\u003E";
;pug_debug_line = 5;pug_debug_filename = "\u002FUsers\u002Ftkirby\u002Fworkspace\u002Fzbryikt\u002Fplotdb\u002Fprojects\u002Fsrcbuild\u002Fweb\u002Fsrc\u002Fpug\u002Fb.pug";
pug_html = pug_html + "var a;\na = 1;\u003C\u002Fbody\u003E\u003C\u002Fhtml\u003E\u003C\u002Fbody\u003E\u003C\u002Fhtml\u003E";} catch (err) {pug_rethrow(err, pug_debug_filename, pug_debug_line);};return pug_html;}; module.exports = template; })() 