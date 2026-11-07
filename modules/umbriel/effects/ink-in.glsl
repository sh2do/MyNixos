// Window opening: ink dropped in water. The window bleeds out from its centre
// behind a feathered, tendrilled front with a soft dark fringe; what it has
// covered starts dark and washed out, then clears into the plain window.

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
  bool opening = umbriel_direction > 0.0;
  float t = opening ? umbriel_clamped_progress : 1.0 - umbriel_clamped_progress;
  float lin = opening ? umbriel_linear_progress : 1.0 - umbriel_linear_progress;
  vec2 seed = umbriel_random_seed.xy * 64.0;

  // Distance from the centre, 1 at the corners, pushed about by
  // domain-warped noise so the front grows in tendrils that drift as it goes.
  vec2 q = (uv - 0.5) * umbriel_size;
  float d = length(q) / (0.5 * length(umbriel_size));
  vec2 p = q / 150.0 + seed;
  vec2 warp = vec2(ink_fbm(p + t * 0.5), ink_fbm(p + vec2(5.2, 1.3) - t * 0.5)) - 0.5;
  float n = ink_fbm(p + warp * 2.5);
  float dw = d * (0.7 + 0.6 * n) + warp.x * 0.25;

  // The front: 0 at the centre, past every tendril by the end.
  float r = t * 1.45 - 0.05;
  float soft = 0.1;
  float covered = 1.0 - smoothstep(r - soft, r, dw);
  // How long ago the front passed here, 0 at the front.
  float age = clamp((r - dw) / 0.45, 0.0, 1.0);

  // The content just behind the front sways a little with the water, and is
  // still by the last frames so the hand-over to the window does not ghost.
  float whole = smoothstep(0.82, 1.0, lin);
  vec4 c = umbriel_sample(uv + warp * (1.0 - age) * (1.0 - whole) * 18.0 / umbriel_size);

  // Freshly covered content is dark and grey; it clears with age.
  float clear = age * smoothstep(0.1, 0.8, t);
  float grey = dot(c.rgb, vec3(0.299, 0.587, 0.114));
  vec3 rgb = mix(vec3(grey), c.rgb, clear) * mix(0.25, 1.0, clear);
  vec4 win = vec4(rgb, c.a) * covered;

  // A dark slate ink cloud straddling the front, thinner out in the water.
  float ahead = smoothstep(r - soft * 1.5, r, dw) * (1.0 - smoothstep(r, r + 0.2, dw));
  float wisps = 0.55 + 0.45 * ink_noise(q / 18.0 + seed * 3.0);
  float ink = ahead * wisps * 0.85 * (1.0 - smoothstep(0.75, 1.0, t));
  vec4 res = win * (1.0 - ink) + vec4(vec3(0.035, 0.039, 0.05), 1.0) * ink;

  // The last frames settle exactly on the window.
  return mix(res, umbriel_sample(uv), whole);
}
