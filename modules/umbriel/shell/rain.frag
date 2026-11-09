#version 440
// Rain inside the hydrangea frame: two layers of thin slanted streaks, plus
// the misty light behind the trees slowly brightening and dimming (9 s).
// The real weather (Weather.qml) sets how hard it rains: `amount` 1 is the
// usual rain, 0 none (mist only), 2 a storm; `slant` leans it with the wind
// and `fall` slows it to snow. Also laid over the stormy ruins, mist off.
// Compiled to rain.frag.qsb by modules/umbriel/default.nix (qsb --qt6).
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;      // seconds, wrapped hourly by the caller
    vec2 size;       // item size in px
    vec2 glowPos;    // centre of the misty light, px in the item
    float glowRadius;
    float fallen;    // seconds of falling at the usual speed, wrapped hourly
    float amount;
    float slant;
    float fall;
    float mist;
};

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// One layer of streaks. Columns `cell` px wide (after the slant), each with
// drops `len` px long falling at `speed` px/s; `density` of the slots are wet.
float streaks(vec2 p, float cell, float speed, float slant, float len, float density) {
    p.x += p.y * slant;
    float col = floor(p.x / cell);
    float y = p.y - fallen * speed - hash(vec2(col, 1.0)) * 997.0;
    float slot = len * 3.0;
    float row = floor(y / slot);
    if (hash(vec2(col, row)) > density)
        return 0.0;
    float off = hash(vec2(col, row + 3.0)) * (cell - 2.0) + 1.0;
    float dx = abs(p.x - col * cell - off);
    float t = fract(y / slot) * 3.0;
    // Bright head at the bottom, fading tail above.
    return step(t, 1.0) * t * (1.0 - smoothstep(0.4, 1.0, dx));
}

void main() {
    vec2 p = qt_TexCoord0 * size;
    float rain = 0.0;
    if (amount > 0.001) {
        float a = min(amount, 2.5);
        // Heavier rain: more drops, a little brighter; slow (snow): shorter.
        float bright = 0.6 + 0.4 * min(a, 2.0);
        float len = 0.3 + 0.7 * clamp(fall, 0.0, 1.0);
        rain = streaks(p, 9.0, 700.0, 0.2 + slant, 26.0 * len, min(0.25 * a, 0.9)) * 0.12 * bright
             + streaks(p, 17.0, 1100.0, 0.24 + slant, 44.0 * len, min(0.2 * a, 0.9)) * 0.2 * bright;
    }
    // The mist swings between a little brighter and a little darker than the still.
    float breathe = -cos(time * 6.2831853 / 9.0) * mist;
    float fall = 1.0 - smoothstep(0.0, glowRadius, distance(p, glowPos));
    vec3 white = vec3(0.933, 0.945, 0.961); // Palette.bright
    vec4 mist = breathe > 0.0 ? vec4(white, 1.0) * breathe * 0.14 * fall
                              : vec4(0.0, 0.0, 0.0, -breathe * 0.1 * fall);
    vec4 drops = vec4(white, 1.0) * clamp(rain, 0.0, 1.0);
    // Premultiplied: rain over mist.
    fragColor = (drops + mist * (1.0 - drops.a)) * qt_Opacity;
}
