// Window closing: the window breaks up into grain, speck by speck, darkening
// and fading as it goes.

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

vec4 animation(vec2 uv) {
  // 1 while whole, 0 once gone.
  float v = umbriel_direction > 0.0 ? umbriel_clamped_progress : 1.0 - umbriel_clamped_progress;
  vec2 seed = umbriel_random_seed.xy * 64.0;
  vec4 c = umbriel_sample(uv);

  // Per-pixel grain, clumped a little by soft noise so it goes in drifts.
  float grain = smoke_hash(floor(uv * umbriel_size * umbriel_scale) + seed * 13.0);
  float clump = smoke_noise(uv * umbriel_size / 70.0 + seed);
  float n = mix(grain, clump, 0.45);

  float edge = mix(-0.1, 1.1, v);
  float keep = 1.0 - smoothstep(edge - 0.08, edge + 0.08, n);
  // Pixels about to go flash to grey grain first.
  float fringe = keep * (1.0 - smoothstep(0.0, 0.15, edge - n));
  vec3 rgb = mix(c.rgb, vec3(grain * 0.6) * c.a, fringe * 0.7);
  rgb *= mix(0.45, 1.0, v);
  return vec4(rgb, c.a) * keep * smoothstep(0.0, 0.25, v);
}
