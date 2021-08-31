(function(){function r(e,n,t){function o(i,f){if(!n[i]){if(!e[i]){var c="function"==typeof require&&require;if(!f&&c)return c(i,!0);if(u)return u(i,!0);var a=new Error("Cannot find module '"+i+"'");throw a.code="MODULE_NOT_FOUND",a}var p=n[i]={exports:{}};e[i][0].call(p.exports,function(r){var n=e[i][1][r];return o(n||r)},p,p.exports,r,e,n,t)}return n[i].exports}for(var u="function"==typeof require&&require,i=0;i<t.length;i++)o(t[i]);return o}return r})()({1:[function(require,module,exports){
(function(){
  var glslify, mod;
  glslify = require('glslify');
  mod = {
    id: 'under-sea',
    name: "Under the Sea",
    type: 'background',
    desc: "Dive into the tropical coral reef...",
    tags: ['pink', 'sea', 'light', 'flow', 'wave', 'ocean', 'nautical'],
    slug: "pink-under-the-sea",
    license: 'CC0',
    edit: {
      bg1: {
        name: "Background 1",
        type: 'color',
        'default': '#ffbb19'
      },
      bg2: {
        name: "Background 2",
        type: 'color',
        'default': '#664dbd'
      },
      fg: {
        name: "Foreground",
        type: 'color',
        'default': '#fff'
      }
    },
    support: {},
    watch: function(n, o){
      var u, i$, ref$, len$, name, results$ = [];
      u = this.shaders[0].uniforms;
      u.speed.value = n.speed;
      for (i$ = 0, len$ = (ref$ = ['bg1', 'bg2', 'fg']).length; i$ < len$; ++i$) {
        name = ref$[i$];
        results$.push(u[name].value = ldColor.rgbfv(n[name]));
      }
      return results$;
    },
    shaders: [{
      uniforms: {
        fg: {
          type: '3fv',
          value: [1, 1, 1]
        },
        bg1: {
          type: '3fv',
          value: [1, 0.7, 0.1]
        },
        bg2: {
          type: '3fv',
          value: [0.4, 0.3, 0.7]
        },
        speed: {
          type: '1f',
          value: 1
        }
      },
      fragmentShader: glslify(["precision highp float;\n#define GLSLIFY 1\n/* z: pixel size */\nvec3 aspect_ratio_1540259130(vec2 res, int iscover) {\n  // iscover: 0 = contains, 1 = cover, 2 = stretch\n  float r;\n  vec3 ret = vec3((gl_FragCoord.xy / res.xy), 0.);\n  if(iscover == 2) {\n    ret.z = 1. / max(res.x, res.y);\n  } else if(iscover == 0 ^^ res.x > res.y) {\n    r = res.y / res.x;\n    ret.y = ret.y * r - (r - 1.) * 0.5;\n    ret.z = 1. / (iscover == 0 ? res.x : res.y);\n  } else {\n    r = res.x / res.y;\n    ret.x = (ret.x * r) - (r - 1.) * 0.5;\n    ret.z = 1. / (iscover == 0 ? res.y : res.x);\n  } \n  return ret;\n}\n\n/*\nret.y = ret.y * res.y / res.x\nret.x = ret.x * res.x / res.x\nret.xy = ret.xy * res.yx / max(res.x, res.y)\n\nfloat base;\nbase = res.xy / (iscover == 0 ? min(res.x, res.y) : max(res.x, res.y));\nret.z = 1. / base;\nret.xy = ( ret.xy * res.yx / base ) - ret.xy / base;\n*/\n\nvec2 quantize(float value, float step) {\n  vec2 ret;\n  value = smoothstep(0., 1., value) * (step + 1.);\n  ret = vec2(floor(value) / (step + 1.), fract(value));\n  return ret;\n}\n\nfloat hash(float n) { return fract(sin(n) * 1e4); }\nfloat hash(vec2 p) { return fract(1e4 * sin(17.0 * p.x + p.y * 0.1) * (0.1 + abs(sin(p.y * 13.0 + p.x)))); }\n\nfloat noise(float x) {\n        float i = floor(x);\n        float f = fract(x);\n        float u = f * f * (3.0 - 2.0 * f);\n        return mix(hash(i), hash(i + 1.0), u);\n}\n\nfloat noise(vec2 x) {\n        vec2 i = floor(x);\n        vec2 f = fract(x);\n\n        // Four corners in 2D of a tile\n        float a = hash(i);\n        float b = hash(i + vec2(1.0, 0.0));\n        float c = hash(i + vec2(0.0, 1.0));\n        float d = hash(i + vec2(1.0, 1.0));\n\n        // Simple 2D lerp using smoothstep envelope between the values.\n        // return vec3(mix(mix(a, b, smoothstep(0.0, 1.0, f.x)),\n        //                      mix(c, d, smoothstep(0.0, 1.0, f.x)),\n        //                      smoothstep(0.0, 1.0, f.y)));\n\n        // Same code, with the clamps in smoothstep and common subexpressions\n        // optimized away.\n        vec2 u = f * f * (3.0 - 2.0 * f);\n        return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;\n}\n\n// This one has non-ideal tiling properties that I'm still tuning\nfloat noise(vec3 x) {\n        const vec3 step = vec3(110, 241, 171);\n\n        vec3 i = floor(x);\n        vec3 f = fract(x);\n \n        // For performance, compute the base input to a 1D hash from the integer part of the argument and the \n        // incremental change to the 1D based on the 3D -> 1D wrapping\n    float n = dot(i, step);\n\n        vec3 u = f * f * (3.0 - 2.0 * f);\n        return mix(mix(mix( hash(n + dot(step, vec3(0, 0, 0))), hash(n + dot(step, vec3(1, 0, 0))), u.x),\n                   mix( hash(n + dot(step, vec3(0, 1, 0))), hash(n + dot(step, vec3(1, 1, 0))), u.x), u.y),\n               mix(mix( hash(n + dot(step, vec3(0, 0, 1))), hash(n + dot(step, vec3(1, 0, 1))), u.x),\n                   mix( hash(n + dot(step, vec3(0, 1, 1))), hash(n + dot(step, vec3(1, 1, 1))), u.x), u.y), u.z);\n}\n\n#define NUM_OCTAVES 5\n\nfloat fbm(float x) {\n  float v = 0.0;\n  float a = 0.5;\n  float shift = float(100);\n  for (int i = 0; i < NUM_OCTAVES; ++i) {\n    v += a * noise(x);\n    x = x * 2.0 + shift;\n    a *= 0.5;\n  }\n  return v;\n}\n\nfloat fbm(vec2 x) {\n  float v = 0.0;\n  float a = 0.5;\n  vec2 shift = vec2(100);\n  // Rotate to reduce axial bias\n  mat2 rot = mat2(cos(0.5), sin(0.5), -sin(0.5), cos(0.50));\n  for (int i = 0; i < NUM_OCTAVES; ++i) {\n    v += a * noise(x);\n    x = rot * x * 2.0 + shift;\n    a *= 0.5;\n  }\n  return v;\n}\n\nfloat fbm(vec3 x) {\n  float v = 0.0;\n  float a = 0.5;\n  vec3 shift = vec3(100);\n  for (int i = 0; i < NUM_OCTAVES; ++i) {\n    v += a * noise(x);\n    x = x * 2.0 + shift;\n    a *= 0.5;\n  }\n  return v;\n}\n\n//\n// Description : Array and textureless GLSL 2D simplex noise function.\n//      Author : Ian McEwan, Ashima Arts.\n//  Maintainer : ijm\n//     Lastmod : 20110822 (ijm)\n//     License : Copyright (C) 2011 Ashima Arts. All rights reserved.\n//               Distributed under the MIT License. See LICENSE file.\n//               https://github.com/ashima/webgl-noise\n//\n\nvec3 mod289(vec3 x) {\n  return x - floor(x * (1.0 / 289.0)) * 289.0;\n}\n\nvec2 mod289(vec2 x) {\n  return x - floor(x * (1.0 / 289.0)) * 289.0;\n}\n\nvec3 permute(vec3 x) {\n  return mod289(((x*34.0)+1.0)*x);\n}\n\nfloat snoise(vec2 v)\n  {\n  const vec4 C = vec4(0.211324865405187,  // (3.0-sqrt(3.0))/6.0\n                      0.366025403784439,  // 0.5*(sqrt(3.0)-1.0)\n                     -0.577350269189626,  // -1.0 + 2.0 * C.x\n                      0.024390243902439); // 1.0 / 41.0\n// First corner\n  vec2 i  = floor(v + dot(v, C.yy) );\n  vec2 x0 = v -   i + dot(i, C.xx);\n\n// Other corners\n  vec2 i1;\n  //i1.x = step( x0.y, x0.x ); // x0.x > x0.y ? 1.0 : 0.0\n  //i1.y = 1.0 - i1.x;\n  i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);\n  // x0 = x0 - 0.0 + 0.0 * C.xx ;\n  // x1 = x0 - i1 + 1.0 * C.xx ;\n  // x2 = x0 - 1.0 + 2.0 * C.xx ;\n  vec4 x12 = x0.xyxy + C.xxzz;\n  x12.xy -= i1;\n\n// Permutations\n  i = mod289(i); // Avoid truncation effects in permutation\n  vec3 p = permute( permute( i.y + vec3(0.0, i1.y, 1.0 ))\n    + i.x + vec3(0.0, i1.x, 1.0 ));\n\n  vec3 m = max(0.5 - vec3(dot(x0,x0), dot(x12.xy,x12.xy), dot(x12.zw,x12.zw)), 0.0);\n  m = m*m ;\n  m = m*m ;\n\n// Gradients: 41 points uniformly over a line, mapped onto a diamond.\n// The ring size 17*17 = 289 is close to a multiple of 41 (41*7 = 287)\n\n  vec3 x = 2.0 * fract(p * C.www) - 1.0;\n  vec3 h = abs(x) - 0.5;\n  vec3 ox = floor(x + 0.5);\n  vec3 a0 = x - ox;\n\n// Normalise gradients implicitly by scaling m\n// Approximation of: m *= inversesqrt( a0*a0 + h*h );\n  m *= 1.79284291400159 - 0.85373472095314 * ( a0*a0 + h*h );\n\n// Compute final noise value at P\n  vec3 g;\n  g.x  = a0.x  * x0.x  + h.x  * x0.y;\n  g.yz = a0.yz * x12.xz + h.yz * x12.yw;\n  return 130.0 * dot(m, g);\n}\n\n// Processing specific input\nuniform float uTime;\nuniform vec2 uResolution;\nuniform vec3 fg;\nuniform vec3 bg1;\nuniform vec3 bg2;\nuniform float speed;\n\nvoid main() {\n  vec3 uv = aspect_ratio_1540259130(uResolution, 1);\n  float t = uTime * .5 * speed;\n  float len = length(uv.xy - vec2(.5, 1.));\n  float c = smoothstep(1., .2, len);\n  float a = (acos((uv.y - 1.) / len) + 1.23456) * 4.326;\n  float p = .6 + fbm((fbm(a) + t) * 1.258) * .5 + .1 * pow(fbm(t + uv.x), .5);\n  float m = 0.;\n  for(float i=0.;i<4.;i++) {\n    float size = 2. + i * i * 4.;\n    vec2 id = floor(uv.xy * size);\n    vec2 ft = fract(uv.xy * size);\n    float n = fbm(id + id.x * id.y + i);\n    float n2 = n * (6.28 + t);\n\n    vec2 pt = vec2(\n      0.5 + 0.35 * sin(n2 + id.y),\n      0.5 + 0.35 * cos(n2 + id.x)\n    );\n\n    float b = n * 0.12;\n    float f = n * 1.;\n    float r = fract(n * 2898.35);\n    if(r < 0.4) {\n      m += smoothstep(\n        b * (1. + f), b * (1. - f), length(ft - pt)\n      ) * (i + 1.) / 13.; //(1. - pow(f, .5));\n    }\n\n  }\n  vec3 color1 = bg1 * c * p;\n  vec3 color2 = fg * m * p;\n  vec3 bk = bg2;\n  gl_FragColor = vec4(color1 + color2 + bk, 1.);\n}\n"])
    }],
    init: function(arg$){
      var shaderlib;
      shaderlib = arg$.shaderlib;
      return import$(this, shaderlib.prepare(this.shaders));
    },
    step: function(t){
      return this.renderer.render(t);
    },
    destroy: function(){}
  };
  if (typeof module != 'undefined' && module !== null) {
    module.exports = mod;
  }
  if (typeof ModManager != 'undefined' && ModManager !== null) {
    ModManager.register(mod);
  }
  return mod;
})();
function import$(obj, src){
  var own = {}.hasOwnProperty;
  for (var key in src) if (own.call(src, key)) obj[key] = src[key];
  return obj;
}
},{"glslify":2}],2:[function(require,module,exports){
module.exports = function(strings) {
  if (typeof strings === 'string') strings = [strings]
  var exprs = [].slice.call(arguments,1)
  var parts = []
  for (var i = 0; i < strings.length-1; i++) {
    parts.push(strings[i], exprs[i] || '')
  }
  parts.push(strings[i])
  return parts.join('')
}

},{}]},{},[1]);
