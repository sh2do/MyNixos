// Window opening: the window arrives as a dark, drifting blur that clears in
// noisy patches and settles into the sharp window.

float smoke_hash(vec2 p) {
  vec3 q = fract(vec3(p.xyx) * 0.1031);
  q += dot(q, q.yzx + 33.33);
  return fract((q.x + q.y) * q.z);
}

float smoke_noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  return mix(mix(smoke_hash(i), smoke_hash(i + vec2(1.0, 0.0)), f.x),
             mix(smoke_hash(i + vec2(0.0, 1.0)), smoke_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float smoke_fbm(vec2 p) {
  return 0.55 * smoke_noise(p) + 0.3 * smoke_noise(p * 2.1 + 7.3) + 0.15 * smoke_noise(p * 4.3 + 2.9);
}

vec4 animation(vec2 uv) {
  float t = umbriel_direction > 0.0 ? umbriel_clamped_progress : 1.0 - umbriel_clamped_progress;
  vec2 px = uv * umbriel_size;
  vec2 seed = umbriel_random_seed.xy * 64.0;

  // Smoke rising through the window; low noise clears first.
  float n = smoke_fbm(px / 90.0 + seed + vec2(0.0, t * 1.2));
  float clear = smoothstep(n - 0.2, n + 0.2, t * 1.4 - 0.2);

  // A blur that wanders with the smoke and shrinks as it clears.
  vec2 spread = (1.0 - t) * 14.0 / umbriel_size;
  vec2 drift = (vec2(smoke_noise(px / 60.0 + seed), smoke_noise(px / 60.0 + seed + 31.7)) - 0.5) * spread * 3.0;
  vec2 p = uv + drift;
  vec4 blurred = (umbriel_sample(p) * 2.0
                + umbriel_sample(p + vec2(spread.x, 0.0)) + umbriel_sample(p - vec2(spread.x, 0.0))
                + umbriel_sample(p + vec2(0.0, spread.y)) + umbriel_sample(p - vec2(0.0, spread.y))
                + umbriel_sample(p + spread) + umbriel_sample(p - spread)) / 8.0;
  vec4 c = mix(blurred, umbriel_sample(uv), clear);

  // Dark at first, thin where the smoke is thick, whole once it clears.
  float light = mix(0.2, 1.0, smoothstep(0.0, 0.85, t));
  float alpha = smoothstep(0.0, 0.5, t) * mix(0.35 + 0.65 * (1.0 - n), 1.0, clear);
  return vec4(c.rgb * light, c.a) * alpha;
}
