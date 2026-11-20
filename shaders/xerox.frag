#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uImageSize;
uniform vec4 uSourceRect;
uniform vec4 uDestinationRect;
uniform float uSeed;
uniform float uEdge;
uniform float uContrast;
uniform float uGrain;
uniform float uInvert;
uniform sampler2D uImage;

out vec4 fragColor;

vec3 sampleOnWhite(vec2 uv) {
  vec4 color = texture(uImage, uv);
  return color.rgb + vec3(1.0 - color.a);
}

float luminance(vec2 uv) {
  return dot(sampleOnWhite(uv), vec3(0.299, 0.587, 0.114));
}

float stableNoise(vec2 pixel) {
  vec2 seededPixel = pixel + vec2(uSeed * 0.0002925, uSeed * 0.0001095);
  vec3 hash = fract(vec3(seededPixel.xyx) * vec3(0.1031, 0.1030, 0.0973));
  hash += dot(hash, hash.yxz + 33.33);
  return fract((hash.x + hash.y) * hash.z);
}

float paperFiber(vec2 uv) {
  vec2 grid = uv * 60.0;
  vec2 cell = floor(grid);
  float seed = stableNoise(cell + vec2(123.0, 491.0));
  float jitter = stableNoise(cell + vec2(713.0, 237.0));
  vec2 point = fract(grid) - (0.30 + 0.40 * vec2(seed, jitter));
  vec2 local = seed < 0.5 ? point : point.yx;
  float across = local.y - local.x * (jitter - 0.5) * 1.3 -
      local.x * local.x * (seed - 0.5);
  float taper = 1.0 - smoothstep(0.10, 0.27, abs(local.x));
  float width = 1.0 - smoothstep(0.008, 0.075, abs(across));
  return taper * width;
}

void main() {
  vec2 destinationUv =
      (FlutterFragCoord().xy - uDestinationRect.xy) / uDestinationRect.zw;
  vec2 uv = (uSourceRect.xy + destinationUv * uSourceRect.zw) / uImageSize;
  vec2 halfTexel = 0.5 / uImageSize;
  vec2 minUv = (uSourceRect.xy + halfTexel) / uImageSize;
  vec2 maxUv = (uSourceRect.xy + uSourceRect.zw - halfTexel) / uImageSize;
  uv = clamp(uv, minUv, maxUv);

  vec2 texel = 1.0 / uImageSize;
  float center = luminance(uv);
  float dx = luminance(clamp(uv + vec2(texel.x, 0.0), minUv, maxUv)) -
      luminance(clamp(uv - vec2(texel.x, 0.0), minUv, maxUv));
  float dy = luminance(clamp(uv + vec2(0.0, texel.y), minUv, maxUv)) -
      luminance(clamp(uv - vec2(0.0, texel.y), minUv, maxUv));
  float edge = sqrt(dx * dx + dy * dy) * uEdge;
  float value = (center < uContrast / 255.0 || edge > 40.0 / 255.0)
      ? 0.0
      : 1.0;
  if (uInvert > 0.5) value = 1.0 - value;

  bool isPaper = value > 0.5;
  vec2 localPixel = floor(uv * uImageSize - uSourceRect.xy);
  value = clamp(
      value + (stableNoise(localPixel) - 0.5) * uGrain * 150.0 / 255.0,
      0.0,
      1.0);

  // Thin paper fibers are only visible once the raster can resolve them.
  float detail = smoothstep(96.0, 256.0, min(uDestinationRect.z, uDestinationRect.w));
  if (isPaper && uGrain > 0.0 && detail > 0.0) {
    float fiber = paperFiber(destinationUv) * detail * uGrain * 26.0 / 255.0;
    value = min(value, 1.0 - fiber);
  }
  fragColor = vec4(vec3(value), 1.0);
}
