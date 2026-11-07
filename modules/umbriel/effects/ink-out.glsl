// Window closing: the window clouds into ink and drains back to a point at
// its centre, its tendrilled edge drawing in behind a soft dark fringe.

float ink_hash(vec2 p) {
  vec3 q = fract(vec3(p.xyx) * 0.1031);
  q += dot(q, q.yzx + 33.33);
  return fract((q.x + q.y) * q.z);
}

float ink_noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  return mix(mix(ink_hash(i), ink_hash(i + vec2(1.0, 0.0)), f.x),
             mix(ink_hash(i + vec2(0.0, 1.0)), ink_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float ink_fbm(vec2 p) {
  return 0.5 * ink_noise(p) + 0.3 * ink_noise(p * 2.03 + 7.3) + 0.2 * ink_noise(p * 4.1 + 2.9);
}

vec4 animation(vec2 uv) {
  // 1 while whole, 0 once drained.
  bool opening = umbriel_direction > 0.0;
  float v = opening ? umbriel_clamped_progress : 1.0 - umbriel_clamped_progress;
  float lin = opening ? umbriel_linear_progress : 1.0 - umbriel_linear_progress;
  vec2 seed = umbriel_random_seed.xy * 64.0;

  // The same tendrilled distance field as ink-in, drifting the other way.
  vec2 q = (uv - 0.5) * umbriel_size;
  float d = length(q) / (0.5 * length(umbriel_size));
  vec2 p = q / 150.0 + seed;
  vec2 warp = vec2(ink_fbm(p - v * 0.5), ink_fbm(p + vec2(5.2, 1.3) + v * 0.5)) - 0.5;
  float n = ink_fbm(p + warp * 2.5);
  float dw = d * (0.7 + 0.6 * n) + warp.x * 0.25;

  float r = v * 1.45 - 0.05;
  float soft = 0.1;
  float kept = 1.0 - smoothstep(r - soft, r, dw);

  // The content sways with the water as it drains (still at the first frames,
  // so the hand-over from the window does not ghost).
  float whole = smoothstep(0.85, 1.0, lin);
  vec4 c = umbriel_sample(uv + warp * (1.0 - v) * (1.0 - whole) * 24.0 / umbriel_size);

  // It greys and darkens into ink, fastest near the receding edge.
  float edge = clamp((r - dw) / 0.45, 0.0, 1.0);
  float clear = edge * smoothstep(0.35, 1.0, v);
  float grey = dot(c.rgb, vec3(0.299, 0.587, 0.114));
  vec3 rgb = mix(vec3(grey), c.rgb, clear) * mix(0.18, 1.0, clear);
  vec4 win = vec4(rgb, c.a) * kept;

  // The dark fringe left along the edge as it draws in.
  float band = smoothstep(r - soft * 1.5, r, dw) * (1.0 - smoothstep(r, r + 0.2, dw));
  float wisps = 0.55 + 0.45 * ink_noise(q / 18.0 + seed * 3.0);
  float ink = band * wisps * 0.85 * smoothstep(0.0, 0.25, v) * (1.0 - smoothstep(0.85, 1.0, v));
  vec4 res = win * (1.0 - ink) + vec4(vec3(0.035, 0.039, 0.05), 1.0) * ink;

  // The first frame is still exactly the window.
  return mix(res, umbriel_sample(uv), whole);
}
