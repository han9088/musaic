#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uCenter;
uniform vec2 uHalfSize;
uniform float uRadius;
uniform float uFeather;

out vec4 fragColor;

void main() {
  vec2 delta = abs(FlutterFragCoord().xy - uCenter);
  vec2 core = uHalfSize - vec2(uRadius);
  float distance = length(max(delta - core, vec2(0.0))) - uRadius;
  fragColor = vec4(0.0, 0.0, 0.0, smoothstep(0.0, uFeather, distance));
}
