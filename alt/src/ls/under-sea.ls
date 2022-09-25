(->
  require! <[glslify]>
  mod = do
    id: \under-sea
    name: "Under the Sea"
    type: \background
    desc: "Dive into the tropical coral reef..."
    tags: <[pink sea light flow wave ocean nautical]>
    slug: "pink-under-the-sea"
    license: \CC0
    edit:
      bg1: name: "Background 1", type: \color, default: \#ffbb19
      bg2: name: "Background 2", type: \color, default: \#664dbd
      fg: name: "Foreground", type: \color, default: \#fff
    support: {}
    watch: (n, o) ->
      u = @shaders.0.uniforms
      u.speed.value = n.speed
      for name in <[bg1 bg2 fg]> => u[name]value = ldColor.rgbfv(n[name])
    shaders: [
      {
        uniforms:
          fg: type: \3fv, value: [1, 1, 1]
          bg1: type: \3fv, value: [1, 0.7, 0.1]
          bg2: type: \3fv, value: [0.4, 0.3, 0.7]
          speed: type: \1f, value: 1

        fragmentShader: glslify '''
          precision highp float;
          #pragma glslify: aspect_ratio = require("shaderlib/func/aspect_ratio")
          #pragma glslify: quantize = require("shaderlib/func/quantize")
          #pragma glslify: fbm = require("shaderlib/func/fbm")
          #pragma glslify: noise = require("glsl-noise/simplex/2d")

          // Processing specific input
          uniform float uTime;
          uniform vec2 uResolution;
          uniform vec3 fg;
          uniform vec3 bg1;
          uniform vec3 bg2;
          uniform float speed;

          void main() {
            vec3 uv = aspect_ratio(uResolution, 1);
            float t = uTime * .5 * speed;
            float len = length(uv.xy - vec2(.5, 1.));
            float c = smoothstep(1., .2, len);
            float a = (acos((uv.y - 1.) / len) + 1.23456) * 4.326;
            float p = .6 + fbm((fbm(a) + t) * 1.258) * .5 + .1 * pow(fbm(t + uv.x), .5);
            float m = 0.;
            for(float i=0.;i<4.;i++) {
              float size = 2. + i * i * 4.;
              vec2 id = floor(uv.xy * size);
              vec2 ft = fract(uv.xy * size);
              float n = fbm(id + id.x * id.y + i);
              float n2 = n * (6.28 + t);

              vec2 pt = vec2(
                0.5 + 0.35 * sin(n2 + id.y),
                0.5 + 0.35 * cos(n2 + id.x)
              );

              float b = n * 0.12;
              float f = n * 1.;
              float r = fract(n * 2898.35);
              if(r < 0.4) {
                m += smoothstep(
                  b * (1. + f), b * (1. - f), length(ft - pt)
                ) * (i + 1.) / 13.; //(1. - pow(f, .5));
              }

            }
            vec3 color1 = bg1 * c * p;
            vec3 color2 = fg * m * p;
            vec3 bk = bg2;
            gl_FragColor = vec4(color1 + color2 + bk, 1.);
          }

        '''
      }]

    init: ({shaderlib}) -> @ <<< shaderlib.prepare @shaders
    step: (t) -> @renderer.render t
    destroy: ->

  if module? => module.exports = mod
  if ModManager? => ModManager.register mod
  return mod
)!
