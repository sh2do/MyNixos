// Film grain over the whole screen: hash noise at about 4%, weaker in the
// highlights. Static: a grain reseeded from umbriel_time 24 times a second
// made Umbriel draw continuously and cost about 2.5% CPU at idle, so the
// pattern is fixed and only redraws when something else does.

float grain_hash(vec2 p) {
  vec3 q = fract(vec3(p.xyx) * 0.1031);
  q += dot(q, q.yzx + 33.33);
  return fract((q.x + q.y) * q.z);
}

vec4 screen(vec2 uv) {
  vec4 c = umbriel_sample(uv);
  vec2 px = floor(uv * umbriel_size * umbriel_scale);
  float n = grain_hash(px) - 0.5;
  float luma = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
  float amount = 0.04 * (1.0 - 0.7 * luma);
  return vec4(clamp(c.rgb + n * amount * c.a, 0.0, c.a), c.a);
}
