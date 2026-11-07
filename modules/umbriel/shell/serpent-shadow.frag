#version 440
// The serpent's cast shadow: the body's mesh again, drawn first and offset,
// black with a soft falloff across v. No blur.
// Compiled to serpent-shadow.frag.qsb by modules/umbriel/default.nix (qsb --qt6).
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

void main() {
    float s = sin(qt_TexCoord0.y * 3.14159265);
    fragColor = vec4(0.0, 0.0, 0.0, 0.45 * s * s * qt_Opacity);
}
