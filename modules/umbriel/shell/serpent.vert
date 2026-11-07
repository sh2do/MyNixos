#version 440
// Bends the serpent's straight skin strip along its spine. The GridMesh's
// texcoord u runs along the body (0 at the neck, 1 at the tail tip) and v
// across it; each vertex is placed on the Catmull-Rom curve through the 24
// spine points at u * 23, offset along the normal by its share of the width.
// Shared by serpent.frag and serpent-shadow.frag; the uniform block must stay
// identical in all three. Compiled to serpent.vert.qsb by modules/umbriel/default.nix.
layout(location = 0) in vec4 qt_Vertex;
layout(location = 1) in vec2 qt_MultiTexCoord0;
layout(location = 0) out vec2 qt_TexCoord0;
layout(location = 1) out vec2 tangent;
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

out gl_PerVertex { vec4 gl_Position; };

void main() {
    vec4 s[24] = vec4[24](s0, s1, s2, s3, s4, s5, s6, s7, s8, s9, s10, s11, s12, s13, s14, s15, s16, s17, s18, s19, s20, s21, s22, s23);
    float f = clamp(qt_MultiTexCoord0.x, 0.0, 1.0) * 23.0;
    int i = min(int(f), 22);
    float t = f - float(i);
    // Clamped ends: the missing neighbour is the end point itself.
    vec4 p0 = s[max(i - 1, 0)], p1 = s[i], p2 = s[i + 1], p3 = s[min(i + 2, 23)];
    float t2 = t * t, t3 = t2 * t;
    vec2 pos = 0.5 * (2.0 * p1.xy + (p2.xy - p0.xy) * t
             + (2.0 * p0.xy - 5.0 * p1.xy + 4.0 * p2.xy - p3.xy) * t2
             + (3.0 * p1.xy - p0.xy - 3.0 * p2.xy + p3.xy) * t3);
    vec2 d = 0.5 * ((p2.xy - p0.xy)
           + 2.0 * (2.0 * p0.xy - 5.0 * p1.xy + 4.0 * p2.xy - p3.xy) * t
           + 3.0 * (3.0 * p1.xy - p0.xy - 3.0 * p2.xy + p3.xy) * t2);
    float dl = length(d);
    vec2 dir = dl > 1e-4 ? d / dl : normalize(p2.xy - p1.xy + vec2(1e-4, 0.0));
    float w = mix(p1.z, p2.z, t);
    pos += vec2(-dir.y, dir.x) * (qt_MultiTexCoord0.y - 0.5) * bodyWidth * w;
    qt_TexCoord0 = qt_MultiTexCoord0;
    tangent = dir;
    gl_Position = qt_Matrix * vec4(pos, 0.0, 1.0);
}
