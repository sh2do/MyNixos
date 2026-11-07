#version 440
// The serpent's body: its skin strip, rounded by a falloff across v, a
// specular line, the iridescent thin-film sheen along the upper flank, the
// travelling muscle ripple, and the shed's greying. Premultiplied alpha.
// Compiled to serpent.frag.qsb by modules/umbriel/default.nix (qsb --qt6).
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 1) in vec2 tangent;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float bodyWidth;   // px
    float time;        // seconds
    float sheen;       // 0..1, iridescence strength
    float dull;        // 0..1, the shed's greying
    float ripplePhase; // radians, advanced by the caller
    float rippleAmp;   // brightness swing of the muscle ripple
    // The spine: 24 evenly spaced points, xy in px, z the width scale.
    vec4 s0;
    vec4 s1;
    vec4 s2;
    vec4 s3;
    vec4 s4;
    vec4 s5;
    vec4 s6;
    vec4 s7;
    vec4 s8;
    vec4 s9;
    vec4 s10;
    vec4 s11;
    vec4 s12;
    vec4 s13;
    vec4 s14;
    vec4 s15;
    vec4 s16;
    vec4 s17;
    vec4 s18;
    vec4 s19;
    vec4 s20;
    vec4 s21;
    vec4 s22;
    vec4 s23;
};
layout(binding = 1) uniform sampler2D source;

void main() {
    float u = qt_TexCoord0.x, v = qt_TexCoord0.y;
    vec4 skin = texture(source, qt_TexCoord0);
    vec3 c = skin.rgb * (0.55 + 0.45 * sin(v * 3.14159265));
    // Specular line along the upper flank.
    float spec = exp(-pow((v - 0.3) / 0.03, 2.0));
    c += vec3(0.35) * spec * skin.a;
    // Thin film: the hue turns with the body's angle to the light and drifts with time.
    float h = dot(tangent, normalize(vec2(-0.6, -0.8))) * 0.5 + 0.5 + time * 0.03;
    vec3 film = 0.5 + 0.5 * cos(6.2831853 * (h + vec3(0.0, 0.33, 0.67)));
    float band = smoothstep(0.25, 0.3, v) * (1.0 - smoothstep(0.35, 0.4, v));
    c += film * sheen * band * 0.35 * skin.a;
    c *= 1.0 + rippleAmp * sin(u * 40.0 - ripplePhase);
    c = mix(c, vec3(dot(c, vec3(0.299, 0.587, 0.114))) * 0.9, dull);
    fragColor = vec4(c, skin.a) * qt_Opacity;
}
