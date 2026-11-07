#version 440
// The serpent's body: its skin strip, rounded by a falloff across v, and a
// specular line along whichever flank is on top on screen. Premultiplied
// alpha.
// Compiled to serpent.frag.qsb by modules/umbriel/default.nix (qsb --qt6).
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 1) in vec2 tangent;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float bodyWidth;   // px
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
    float v = qt_TexCoord0.y;
    vec4 skin = texture(source, qt_TexCoord0);
    vec3 c = skin.rgb * (0.55 + 0.45 * sin(v * 3.14159265));
    // The lit flank is whichever edge faces up on screen: v grows along the
    // normal (-t.y, t.x), so v = 0 is on top while the body runs rightward.
    // Blended where the body runs vertical, so it never jumps.
    float top = smoothstep(-0.35, 0.35, tangent.x);
    float vl = mix(1.0 - v, v, top);
    // Specular line along the upper flank.
    float spec = exp(-pow((vl - 0.3) / 0.03, 2.0));
    c += vec3(0.35) * spec * skin.a;
    fragColor = vec4(c, skin.a) * qt_Opacity;
}
