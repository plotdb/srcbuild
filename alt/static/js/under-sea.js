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
      fragmentShader: glslify('precision highp float;\n#pragma glslify: aspect_ratio = require("shaderlib/func/aspect_ratio")\n#pragma glslify: quantize = require("shaderlib/func/quantize")\n#pragma glslify: fbm = require("shaderlib/func/fbm")\n#pragma glslify: noise = require("glsl-noise/simplex/2d")\n\n// Processing specific input\nuniform float uTime;\nuniform vec2 uResolution;\nuniform vec3 fg;\nuniform vec3 bg1;\nuniform vec3 bg2;\nuniform float speed;\n\nvoid main() {\n  vec3 uv = aspect_ratio(uResolution, 1);\n  float t = uTime * .5 * speed;\n  float len = length(uv.xy - vec2(.5, 1.));\n  float c = smoothstep(1., .2, len);\n  float a = (acos((uv.y - 1.) / len) + 1.23456) * 4.326;\n  float p = .6 + fbm((fbm(a) + t) * 1.258) * .5 + .1 * pow(fbm(t + uv.x), .5);\n  float m = 0.;\n  for(float i=0.;i<4.;i++) {\n    float size = 2. + i * i * 4.;\n    vec2 id = floor(uv.xy * size);\n    vec2 ft = fract(uv.xy * size);\n    float n = fbm(id + id.x * id.y + i);\n    float n2 = n * (6.28 + t);\n\n    vec2 pt = vec2(\n      0.5 + 0.35 * sin(n2 + id.y),\n      0.5 + 0.35 * cos(n2 + id.x)\n    );\n\n    float b = n * 0.12;\n    float f = n * 1.;\n    float r = fract(n * 2898.35);\n    if(r < 0.4) {\n      m += smoothstep(\n        b * (1. + f), b * (1. - f), length(ft - pt)\n      ) * (i + 1.) / 13.; //(1. - pow(f, .5));\n    }\n\n  }\n  vec3 color1 = bg1 * c * p;\n  vec3 color2 = fg * m * p;\n  vec3 bk = bg2;\n  gl_FragColor = vec4(color1 + color2 + bk, 1.);\n}\n')
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