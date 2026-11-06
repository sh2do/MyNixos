#!/usr/bin/env python3
"""Writes templates/koi.svg, the fastfetch logo: koi in a round pond, seen from
above. Two koi circle each other nose to tail; a third, gold, passes deeper
under a lily pad. Colours are matugen placeholders, so rice-wall re-renders
it in the wallpaper's colours, like the bar's koi (modules/shell/Koi.qml).

Every fish is laid out along a curved spine; its outline, patches, scale
rows and fin rays are placed in body coordinates (u along the spine from nose
to tail, v across it from -1 to 1), so they all bend with the body.

Run: python3 modules/theme/make-koi-svg.py
"""
import math
import os
import random

C = {
    "surface": "{{colors.surface.default.hex}}",
    "deep": "{{colors.surface_container.default.hex}}",
    "rim": "{{colors.surface_container_high.default.hex}}",
    "white": "{{colors.on_surface.default.hex}}",
    "primary": "{{colors.primary.default.hex}}",
    "pad": "{{colors.primary_container.default.hex}}",
    "tertiary": "{{colors.tertiary.default.hex}}",
    "outline": "{{colors.outline.default.hex}}",
    # Fixed, as in the bar: koi red, ink (sumi), and ogon gold.
    "hi": "#d8432f",
    "sumi": "#151214",
    "gold": "#e2a64a",
}

CX, CY, POND = 100.0, 100.0, 92.0


def f(x):
    return f"{x:.2f}".rstrip("0").rstrip(".")


def pts(ps):
    return " ".join(f"{f(x)},{f(y)}" for x, y in ps)


class Fish:
    """A koi along an arc around the pond centre: radius `r`, nose at angle
    `a0` (degrees), body sweeping `sweep` degrees behind it (negative sweeps
    clockwise), with a gentle S-wave of `wave` px."""

    def __init__(self, r, a0, sweep, width, wave=3.0, phase=0.0, cx=CX, cy=CY):
        self.r, self.a0, self.sweep = r, math.radians(a0), math.radians(sweep)
        self.width, self.wave, self.phase = width, wave, phase
        self.cx, self.cy = cx, cy
        self.length = abs(r * self.sweep)

    def spine(self, u):
        rr = self.r + self.wave * math.sin(math.pi * 1.4 * u + self.phase)
        a = self.a0 - self.sweep * u
        return self.cx + rr * math.cos(a), self.cy + rr * math.sin(a)

    def frame(self, u):
        """Point, unit tangent (toward the nose) and unit normal at u."""
        e = 1e-3
        x0, y0 = self.spine(u - e)
        x1, y1 = self.spine(u + e)
        tx, ty = x0 - x1, y0 - y1
        n = math.hypot(tx, ty)
        tx, ty = tx / n, ty / n
        return self.spine(u), (tx, ty), (-ty, tx)

    def half(self, u):
        """Half the body's width at u: a round nose, widest a third back,
        narrowing to the tail stalk."""
        W = self.width / 2
        if u <= 0:
            return 0.0
        if u < 0.32:
            return W * math.sin(u / 0.32 * math.pi / 2) ** 0.55
        if u <= 0.84:
            return W * (1 - 0.82 * ((u - 0.32) / 0.52) ** 1.4)
        return W * 0.18

    def at(self, u, v):
        """Body coordinates to pond coordinates."""
        (x, y), _, (nx, ny) = self.frame(u)
        h = self.half(min(max(u, 0.0), 0.84)) if u <= 0.84 else self.half(0.84)
        return x + nx * v * h, y + ny * v * h

    def outline(self, n=90):
        us = [0.84 * (i / n) ** 1.0 for i in range(n + 1)]
        left = [self.at(u, 1) for u in us]
        right = [self.at(u, -1) for u in reversed(us)]
        return left + right

    def blob(self, u, v, lu, lv, seed, k=11):
        """An irregular patch centred at (u, v), lu long and lv wide (body
        units), as a polygon in pond coordinates."""
        rnd = random.Random(seed)
        out = []
        jit = [0.72 + 0.5 * rnd.random() for _ in range(k)]
        for i in range(48):
            t = 2 * math.pi * i / 48
            # Smoothly interpolated jitter round the edge.
            p = i / 48 * k
            j0, j1 = jit[int(p) % k], jit[(int(p) + 1) % k]
            m = p - int(p)
            jj = j0 + (j1 - j0) * (3 * m * m - 2 * m * m * m)
            out.append(self.at(u + math.cos(t) * lu * jj, v + math.sin(t) * lv * jj))
        return out


def path_closed(ps):
    return "M " + " L ".join(f"{f(x)} {f(y)}" for x, y in ps) + " Z"


def fin_fan(fish, u, side, length, spread, back, rays, colour, ray_colour, op):
    """A pectoral or pelvic fin: a fan rooted at the body's edge at u,
    swept `back` degrees toward the tail, `spread` degrees wide."""
    (x, y), (tx, ty), (nx, ny) = fish.frame(u)
    h = fish.half(u) * 0.8
    rx, ry = x + nx * side * h, y + ny * side * h
    base = math.atan2(ny * side, nx * side)
    tail = math.atan2(-ty, -tx)
    # Rotate the outward normal toward the tail by `back` degrees.
    d = math.atan2(math.sin(tail - base), math.cos(tail - base))
    mid = base + math.copysign(math.radians(back), d)
    a0, a1 = mid - math.radians(spread) / 2, mid + math.radians(spread) / 2
    edge = []
    for i in range(13):
        a = a0 + (a1 - a0) * i / 12
        # Rounded, slightly scalloped trailing edge.
        rl = length * (0.82 + 0.18 * math.sin(math.pi * i / 12)) * (1 - 0.04 * (i % 2))
        edge.append((rx + math.cos(a) * rl, ry + math.sin(a) * rl))
    s = [f'<path d="{path_closed([(rx, ry)] + edge)}" fill="{colour}" fill-opacity="{op}"/>']
    for i in range(rays):
        a = a0 + (a1 - a0) * (i + 0.5) / rays
        rl = length * 0.9
        s.append(f'<path d="M {f(rx)} {f(ry)} L {f(rx + math.cos(a) * rl)} {f(ry + math.sin(a) * rl)}" '
                 f'stroke="{ray_colour}" stroke-opacity="0.35" stroke-width="0.35" fill="none"/>')
    return s


def tail_fin(fish, colour, ray_colour, op):
    """The tail: two flowing lobes from the stalk, forked in the middle, with
    rays. Drawn in body coordinates past the stalk, so it follows the curve."""
    W = fish.width / 2
    def p(u, off):
        (x, y), _, (nx, ny) = fish.frame(u)
        return x + nx * off, y + ny * off
    top, bot = [], []
    n = 16
    for i in range(n + 1):
        t = i / n
        u = 0.82 + 0.26 * t
        w = W * (0.16 + 1.05 * t ** 1.3)
        top.append(p(u, w))
        bot.append(p(u, -w))
    # Trailing edge: out to the lobe tips, in to the fork.
    end = []
    for i in range(1, 12):
        t = i / 12
        side = 1 - 2 * t
        fork = 0.07 * (1 - abs(side)) ** 1.5
        wav = 0.012 * math.sin(t * math.pi * 5)
        end.append(p(1.08 - fork + wav, side * W * 1.21))
    shape = top + end + list(reversed(bot))
    s = [f'<path d="{path_closed(shape)}" fill="{colour}" fill-opacity="{op}"/>']
    for i in range(11):
        side = -1 + 2 * i / 10
        a = p(0.83, side * W * 0.14)
        fork = 0.07 * (1 - abs(side)) ** 1.5
        b = p(1.07 - fork, side * W * 1.18)
        s.append(f'<path d="M {f(a[0])} {f(a[1])} L {f(b[0])} {f(b[1])}" stroke="{ray_colour}" '
                 f'stroke-opacity="0.3" stroke-width="0.35" fill="none"/>')
    return s


def dorsal(fish, colour):
    """The dorsal fin, folded flat along the back: a narrow ribbed band."""
    s = []
    left = [fish.at(u, 0.16) for u in [0.36 + 0.3 * i / 20 for i in range(21)]]
    right = [fish.at(u, -0.06) for u in [0.66 - 0.3 * i / 20 for i in range(21)]]
    s.append(f'<path d="{path_closed(left + right)}" fill="{colour}" fill-opacity="0.35"/>')
    for i in range(10):
        u = 0.37 + 0.28 * i / 9
        a, b = fish.at(u, -0.05), fish.at(u + 0.02, 0.15)
        s.append(f'<path d="M {f(a[0])} {f(a[1])} L {f(b[0])} {f(b[1])}" stroke="{C["sumi"]}" '
                 f'stroke-opacity="0.25" stroke-width="0.3"/>')
    return s


def scales(fish, clip, colour, op, metallic=False):
    """Rows of scale edges: small arcs that open toward the tail."""
    s = [f'<g clip-path="url(#{clip})" fill="none" stroke="{colour}" stroke-opacity="{op}" stroke-width="0.3">']
    rows = 7
    dv = 2 / (rows - 1)
    u = 0.19
    k = 0
    while u < 0.86:
        # A scale is as long as it is wide, so the step along the spine
        # follows the body's width here.
        px = fish.half(u) * dv
        step = px / fish.length
        for j in range(rows + 1):
            v = -1 + dv * (j - 0.5 * (k % 2))
            if abs(v) > 1.02:
                continue
            a = fish.at(u, v - dv / 2)
            m = fish.at(u + step * 1.3, v)
            b = fish.at(u, v + dv / 2)
            s.append(f'<path d="M {f(a[0])} {f(a[1])} Q {f(m[0])} {f(m[1])} {f(b[0])} {f(b[1])}"/>')
            if metallic and (j + k) % 3 == 0:
                c = fish.at(u + step * 0.4, v)
                s.append(f'<circle cx="{f(c[0])}" cy="{f(c[1])}" r="0.45" fill="white" fill-opacity="0.25" stroke="none"/>')
        u += step * 0.8
        k += 1
    s.append("</g>")
    return s


def head(fish, eye_ring):
    s = []
    for side in (-1, 1):
        ex, ey = fish.at(0.1, side * 0.5)
        s.append(f'<circle cx="{f(ex)}" cy="{f(ey)}" r="1.45" fill="{C["sumi"]}" stroke="{eye_ring}" stroke-opacity="0.55" stroke-width="0.4"/>')
        hx, hy = fish.at(0.095, side * 0.56)
        s.append(f'<circle cx="{f(hx)}" cy="{f(hy)}" r="0.35" fill="white" fill-opacity="0.8"/>')
        nx_, ny_ = fish.at(0.025, side * 0.35)
        s.append(f'<circle cx="{f(nx_)}" cy="{f(ny_)}" r="0.4" fill="{C["sumi"]}" fill-opacity="0.5"/>')
        # Two pairs of barbels at the mouth, curling back along the cheek.
        for k, (lu, lv) in enumerate(((0.005, 0.32), (0.018, 0.5))):
            a = fish.at(lu, side * lv)
            b = fish.at(lu - 0.012, side * (lv + 0.75))
            c = fish.at(lu + 0.02 + 0.01 * k, side * (lv + 1.15))
            s.append(f'<path d="M {f(a[0])} {f(a[1])} Q {f(b[0])} {f(b[1])} {f(c[0])} {f(c[1])}" '
                     f'stroke="{C["white"]}" stroke-opacity="0.55" stroke-width="0.45" fill="none" stroke-linecap="round"/>')
    # The gill cover's edge.
    gill = [fish.at(0.17 + 0.02 * math.cos(t), math.sin(t) * 0.92) for t in
            [-math.pi / 2 + math.pi * i / 14 for i in range(15)]]
    s.append(f'<path d="M {" L ".join(f"{f(x)} {f(y)}" for x, y in gill)}" stroke="{C["sumi"]}" '
             f'stroke-opacity="0.18" stroke-width="0.5" fill="none"/>')
    return s


def koi(fish, name, base, patches, scale_colour, scale_op, metallic=False, depth=1.0):
    """One koi: shadow, fins under the body, body with shading, patches,
    scales, dorsal fin, head details."""
    body = fish.outline()
    d = path_closed(body)
    s = [f'<clipPath id="{name}"><path d="{d}"/></clipPath>']
    # Shadow on the pond floor.
    s.append(f'<g filter="url(#soft)" opacity="{0.4 * depth}" transform="translate(3.5 4.5)">')
    s.append(f'<path d="{d}" fill="black"/>')
    s += tail_fin(fish, "black", "black", 0.6)
    s.append("</g>")
    fin = base
    s += tail_fin(fish, fin, C["sumi"], 0.62)
    for side in (-1, 1):
        s += fin_fan(fish, 0.3, side, fish.width * 0.62, 70, 62, 7, fin, C["sumi"], 0.6)
        s += fin_fan(fish, 0.56, side, fish.width * 0.36, 55, 70, 5, fin, C["sumi"], 0.5)
    s.append(f'<path d="{d}" fill="{base}"/>')
    s.append(f'<g clip-path="url(#{name})">')
    for poly, colour in patches:
        s.append(f'<path d="{path_closed(poly)}" fill="{colour}" filter="url(#edge)"/>')
    # Shading: darker flanks and a light along the back.
    s.append(f'<path d="{d}" fill="none" stroke="{C["sumi"]}" stroke-opacity="0.35" stroke-width="{f(fish.width * 0.28)}" filter="url(#soft)"/>')
    spine = [fish.at(0.08 + 0.7 * i / 30, 0.12) for i in range(31)]
    s.append(f'<path d="M {" L ".join(f"{f(x)} {f(y)}" for x, y in spine)}" stroke="white" stroke-opacity="0.28" '
             f'stroke-width="{f(fish.width * 0.16)}" stroke-linecap="round" fill="none" filter="url(#soft)"/>')
    s.append("</g>")
    s += scales(fish, name, scale_colour, scale_op, metallic)
    s += dorsal(fish, base)
    s += head(fish, Cmix(base))
    s.append(f'<path d="{d}" fill="none" stroke="{C["sumi"]}" stroke-opacity="0.3" stroke-width="0.4"/>')
    return s


def Cmix(base):
    return C["gold"] if base != C["gold"] else C["hi"]


def lily(cx, cy, r, rot):
    s = []
    notch = math.radians(28)
    edge = []
    for i in range(61):
        a = math.radians(rot) + notch / 2 + (2 * math.pi - notch) * i / 60
        rr = r * (1 + 0.025 * math.sin(i * 1.7))
        edge.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    d = path_closed([(cx, cy)] + edge)
    s.append(f'<path d="{d}" fill="black" opacity="0.35" filter="url(#soft)" transform="translate(2.5 3.5)"/>')
    s.append(f'<path d="{d}" fill="{C["pad"]}"/>')
    s.append(f'<path d="{d}" fill="url(#padshine)"/>')
    for i in range(9):
        a = math.radians(rot) + notch / 2 + (2 * math.pi - notch) * (i + 0.5) / 9
        s.append(f'<path d="M {f(cx)} {f(cy)} L {f(cx + math.cos(a) * r * 0.92)} {f(cy + math.sin(a) * r * 0.92)}" '
                 f'stroke="{C["primary"]}" stroke-opacity="0.35" stroke-width="0.45"/>')
    s.append(f'<path d="{d}" fill="none" stroke="{C["primary"]}" stroke-opacity="0.45" stroke-width="0.6"/>')
    return s


def flower(cx, cy):
    """A water lily: two rings of pointed petals and a gold centre."""
    s = [f'<circle cx="{f(cx + 1.5)}" cy="{f(cy + 2.5)}" r="8" fill="black" opacity="0.3" filter="url(#soft)"/>']
    for ring, (n, ln, wd, off, op) in enumerate(((10, 8.5, 2.6, 0, 0.85), (8, 6.2, 2.2, 0.4, 1))):
        for i in range(n):
            a = 2 * math.pi * (i + off) / n
            tip = (cx + math.cos(a) * ln, cy + math.sin(a) * ln)
            l = (cx + math.cos(a + 0.5) * wd, cy + math.sin(a + 0.5) * wd)
            r = (cx + math.cos(a - 0.5) * wd, cy + math.sin(a - 0.5) * wd)
            m1 = (cx + math.cos(a + 0.22) * ln * 0.75, cy + math.sin(a + 0.22) * ln * 0.75)
            m2 = (cx + math.cos(a - 0.22) * ln * 0.75, cy + math.sin(a - 0.22) * ln * 0.75)
            s.append(f'<path d="M {f(l[0])} {f(l[1])} Q {f(m1[0])} {f(m1[1])} {f(tip[0])} {f(tip[1])} '
                     f'Q {f(m2[0])} {f(m2[1])} {f(r[0])} {f(r[1])} Z" fill="{C["tertiary"] if ring else C["white"]}" '
                     f'fill-opacity="{op}" stroke="{C["tertiary"]}" stroke-opacity="0.6" stroke-width="0.3"/>')
    s.append(f'<circle cx="{f(cx)}" cy="{f(cy)}" r="2.3" fill="{C["gold"]}"/>')
    for i in range(8):
        a = 2 * math.pi * i / 8
        s.append(f'<circle cx="{f(cx + math.cos(a) * 1.5)}" cy="{f(cy + math.sin(a) * 1.5)}" r="0.4" fill="{C["hi"]}" fill-opacity="0.7"/>')
    return s


def main():
    out = []
    out.append('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200" width="512" height="512">')
    out.append("  <!-- Generated by modules/theme/make-koi-svg.py; edit that, not this. Koi in a pond, "
               "seen from above, in the wallpaper's colours; rendered for fastfetch. -->")
    out.append("<defs>")
    out.append('<filter id="soft" x="-30%" y="-30%" width="160%" height="160%"><feGaussianBlur stdDeviation="1.6"/></filter>')
    out.append('<filter id="edge"><feGaussianBlur stdDeviation="0.22"/></filter>')
    out.append('<filter id="deep" x="-20%" y="-20%" width="140%" height="140%"><feGaussianBlur stdDeviation="0.9"/></filter>')
    out.append(f'<radialGradient id="water" cx="0.42" cy="0.38" r="0.75">'
               f'<stop offset="0" stop-color="{C["rim"]}"/><stop offset="0.55" stop-color="{C["deep"]}"/>'
               f'<stop offset="1" stop-color="{C["surface"]}"/></radialGradient>')
    out.append(f'<radialGradient id="vignette" cx="0.5" cy="0.5" r="0.5">'
               f'<stop offset="0.78" stop-color="black" stop-opacity="0"/><stop offset="1" stop-color="black" stop-opacity="0.45"/></radialGradient>')
    out.append('<linearGradient id="padshine" x1="0" y1="0" x2="1" y2="1">'
               '<stop offset="0" stop-color="white" stop-opacity="0.18"/><stop offset="1" stop-color="black" stop-opacity="0.15"/></linearGradient>')
    out.append(f'<clipPath id="pond"><circle cx="{CX}" cy="{CY}" r="{POND}"/></clipPath>')
    out.append("</defs>")

    # The pond and its stone rim.
    out.append(f'<circle cx="{CX}" cy="{CY}" r="{POND + 4}" fill="{C["rim"]}"/>')
    rnd = random.Random(4)
    for i in range(40):
        a = 2 * math.pi * (i + rnd.random() * 0.4) / 40
        rr = POND + 4 + rnd.uniform(-1, 1)
        out.append(f'<ellipse cx="{f(CX + math.cos(a) * rr)}" cy="{f(CY + math.sin(a) * rr)}" '
                   f'rx="{f(rnd.uniform(4, 6.5))}" ry="{f(rnd.uniform(2.6, 3.6))}" '
                   f'transform="rotate({f(math.degrees(a) + 90)} {f(CX + math.cos(a) * rr)} {f(CY + math.sin(a) * rr)})" '
                   f'fill="{C["rim"]}" stroke="{C["outline"]}" stroke-opacity="0.45" stroke-width="0.5"/>')
    out.append(f'<circle cx="{CX}" cy="{CY}" r="{POND}" fill="url(#water)"/>')
    out.append('<g clip-path="url(#pond)">')

    # Pebbles on the bottom, blurred by depth.
    out.append(f'<g filter="url(#deep)" opacity="0.35">')
    for i in range(55):
        a, rr = rnd.uniform(0, 2 * math.pi), POND * math.sqrt(rnd.random())
        out.append(f'<ellipse cx="{f(CX + math.cos(a) * rr)}" cy="{f(CY + math.sin(a) * rr)}" rx="{f(rnd.uniform(1, 2.6))}" '
                   f'ry="{f(rnd.uniform(0.8, 1.8))}" fill="{C["outline"]}" fill-opacity="{f(rnd.uniform(0.2, 0.6))}"/>')
    out.append("</g>")

    # The deep gold koi, passing under the lily pad.
    gold = Fish(r=70, a0=88, sweep=-60, width=14, wave=2, phase=1.0)
    out.append('<g filter="url(#deep)" opacity="0.6">')
    out += koi(gold, "kgold", C["gold"], [], "white", 0.25, metallic=True, depth=0.5)
    out.append("</g>")

    # The pair, nose to tail. A kohaku (white with red) and one in the
    # wallpaper's colour with red patches and ink spots.
    a = Fish(r=47, a0=200, sweep=-150, width=27, wave=3.5, phase=0.3)
    b = Fish(r=45, a0=20, sweep=-150, width=25, wave=3.5, phase=2.0)
    hi, sumi = C["hi"], C["sumi"]
    a_patches = [(a.blob(0.08, 0.0, 0.06, 0.55, 1), hi),
                 (a.blob(0.32, -0.35, 0.11, 0.85, 2), hi),
                 (a.blob(0.5, 0.45, 0.09, 0.75, 3), hi),
                 (a.blob(0.67, -0.25, 0.07, 0.7, 5), hi)]
    b_patches = [(b.blob(0.27, 0.3, 0.1, 0.8, 6), hi),
                 (b.blob(0.52, -0.4, 0.08, 0.7, 7), hi),
                 (b.blob(0.2, -0.55, 0.035, 0.35, 8), sumi),
                 (b.blob(0.42, 0.55, 0.03, 0.35, 9), sumi),
                 (b.blob(0.62, 0.2, 0.04, 0.4, 10), sumi),
                 (b.blob(0.74, -0.45, 0.025, 0.35, 11), sumi)]
    out += koi(a, "ka", C["white"], a_patches, C["sumi"], 0.16)
    out += koi(b, "kb", C["primary"], b_patches, "white", 0.22, metallic=True)

    # The surface: ripples rings where a koi just touched it, light caustics.
    for (x, y, rr) in ((56, 64, 9), (56, 64, 15), (56, 64, 21)):
        out.append(f'<ellipse cx="{x}" cy="{y}" rx="{rr}" ry="{f(rr * 0.92)}" fill="none" stroke="{C["white"]}" '
                   f'stroke-opacity="{f(0.32 - rr / 90)}" stroke-width="0.6"/>')
    for i in range(14):
        y = 18 + i * 12 + rnd.uniform(-3, 3)
        x0 = rnd.uniform(10, 120)
        seg = [(x0 + k * 6, y + 2.2 * math.sin(k * 1.3 + i)) for k in range(rnd.randint(5, 11))]
        out.append(f'<path d="M {" L ".join(f"{f(x)} {f(yy)}" for x, yy in seg)}" stroke="white" '
                   f'stroke-opacity="0.05" stroke-width="1.2" fill="none" stroke-linecap="round"/>')
    out += lily(50, 154, 19, 300)
    out += lily(84, 176, 10, 20)
    out += flower(46, 150)
    out.append(f'<circle cx="{CX}" cy="{CY}" r="{POND}" fill="url(#vignette)"/>')
    out.append("</g>")
    out.append(f'<circle cx="{CX}" cy="{CY}" r="{POND}" fill="none" stroke="black" stroke-opacity="0.35" stroke-width="1.2"/>')
    out.append("</svg>")

    here = os.path.dirname(os.path.abspath(__file__))
    with open(os.path.join(here, "templates", "koi.svg"), "w") as fh:
        fh.write("\n".join(out) + "\n")


if __name__ == "__main__":
    main()
