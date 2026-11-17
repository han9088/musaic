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

  vec2 localPixel = floor(uv * uImageSize - uSourceRect.xy);
  value = clamp(
      value + (stableNoise(localPixel) - 0.5) * uGrain * 150.0 / 255.0,
      0.0,
      1.0);
  fragColor = vec4(vec3(value), 1.0);
}
