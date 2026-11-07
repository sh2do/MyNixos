// Raven art as data: each part is a list of paths in design units (facing
// left, perch line y = 64). Emits an SVG preview (art.svg) and QML ShapePath
// blocks (parts.json) for RavenBody.qml.
const fs = require("fs");
const OUT = __dirname;

const f = n => (Math.round(n * 100) / 100).toString();
const P = pts => pts.map(f).join(",");

// A feather in a local frame, its tip pointing +x: base at bx, tip at
// (tx, ty), half width h, `round` 1 for a rounded tip, ~0 for a pointed one.
function feather(bx, by, tx, ty, h, round) {
  const k = 0.552 * h;
  const sh = tx - h * (round ? 1 : 2.2); // where the tip starts to curve
  const top = `M${P([bx, by - h * 0.8])} C${P([bx + (sh - bx) * 0.5, by - h])} ${P([sh - (sh - bx) * 0.25, ty - h])} ${P([sh, ty - h])}`;
  const tip = round
    ? ` C${P([sh + k, ty - h])} ${P([tx, ty - k])} ${P([tx, ty])} C${P([tx, ty + k])} ${P([sh + k, ty + h])} ${P([sh, ty + h])}`
    : ` C${P([sh + h * 1.3, ty - h * 0.9])} ${P([tx - h * 0.25, ty - h * 0.25])} ${P([tx, ty + h * 0.1])} C${P([tx - h * 0.35, ty + h * 0.6])} ${P([sh + h * 1.2, ty + h])} ${P([sh, ty + h])}`;
  const bot = ` C${P([sh - (sh - bx) * 0.25, ty + h])} ${P([bx + (sh - bx) * 0.5, by + h])} ${P([bx, by + h * 0.8])} Z`;
  // The fringe: the tip and a little of the lower edge.
  const fringe = round
    ? `M${P([sh - h * 0.6, ty - h * 0.96])} L${P([sh, ty - h])} C${P([sh + k, ty - h])} ${P([tx, ty - k])} ${P([tx, ty])} C${P([tx, ty + k])} ${P([sh + k, ty + h])} ${P([sh, ty + h])} L${P([sh - h * 1.2, ty + h * 0.98])}`
    : `M${P([sh - h * 2, ty - h * 0.97])} L${P([sh, ty - h])} C${P([sh + h * 1.3, ty - h * 0.9])} ${P([tx - h * 0.25, ty - h * 0.25])} ${P([tx, ty + h * 0.1])}`;
  const shaft = `M${P([bx + (tx - bx) * 0.1, by + (ty - by) * 0.1])} L${P([sh - h * 0.2, ty + h * 0.05])}`;
  // Barbs: short strokes slanting tipward from the shaft to both vanes.
  let barbs = "";
  const n = Math.max(3, Math.round((sh - bx) / 1.15));
  for (let i = 1; i < n; i++) {
    const u = 0.18 + 0.8 * i / n;
    const x = bx + (sh - bx) * u, y = by + (ty - by) * u;
    const w = h * (0.55 + 0.35 * Math.sin(Math.PI * u));
    barbs += `M${P([x, y])} L${P([x + w * 0.9, y - w])} M${P([x, y])} L${P([x + w * 0.9, y + w])} `;
  }
  return { body: top + tip + bot, fringe, shaft, barbs: barbs.trim() };
}
// Every feather's full slate edge.
const outline = (d, op) => ({ d, stroke: "edge", sw: 0.26, op: op ?? 0.5 });

// Scallop rows (coverts): small rounded feathers, tips listed.
function covertRow(tips, len, h, fill, fringeOp) {
  const out = [];
  for (const [tx, ty] of tips) {
    const fe = feather(tx - len, ty - 0.4, tx, ty, h, 1);
    out.push({ d: fe.body, fill });
    out.push(outline(fe.body, 0.38));
    out.push({ d: fe.fringe, stroke: "edge", sw: 0.42, op: fringeOp, cap: "round" });
  }
  return out;
}

const parts = {};

// --- Far leg (behind the body): darker, simpler.
function leg(dx, dy, col, op, scutes) {
  const T = (x, y) => [x + dx, y + dy];
  const out = [];
  out.push({ d: `M${P(T(38.4, 53.8))} C${P(T(39.2, 57.4))} ${P(T(39.8, 60.4))} ${P(T(40.0, 63.0))} L${P(T(41.7, 62.8))} C${P(T(41.4, 59.8))} ${P(T(40.9, 56.6))} ${P(T(40.4, 53.6))} Z`, fill: col, op });
  // Scutes: the scaled front of the tarsus, plate on plate.
  for (let i = 0; i < 7; i++) {
    const y = 55.2 + i * 1.08, x = 39.0 + (y - 55) * 0.2;
    out.push({ d: `M${P(T(x - 0.2, y))} Q${P(T(x + 0.6, y + 0.45))} ${P(T(x + 1.35, y - 0.2))}`, stroke: "edge", sw: 0.26, op: (scutes ? 0.6 : 0.3) * op });
  }
  // Toes along the perch and claws curling over its edge.
  const toe = (d, w) => ({ d, stroke: col, sw: w, op, cap: "round" });
  out.push(toe(`M${P(T(40.8, 63.3))} C${P(T(38.8, 63.3))} ${P(T(36.6, 63.4))} ${P(T(34.8, 63.7))}`, 1.15));
  out.push(toe(`M${P(T(34.8, 63.7))} C${P(T(33.7, 63.9))} ${P(T(33.2, 64.7))} ${P(T(33.5, 65.8))}`, 0.62));
  out.push(toe(`M${P(T(40.9, 63.1))} C${P(T(39.8, 63.0))} ${P(T(38.6, 63.1))} ${P(T(37.7, 63.5))}`, 1.0));
  out.push(toe(`M${P(T(37.7, 63.5))} C${P(T(36.9, 63.8))} ${P(T(36.7, 64.5))} ${P(T(37.0, 65.3))}`, 0.55));
  out.push(toe(`M${P(T(41.2, 63.4))} C${P(T(42.6, 63.5))} ${P(T(43.8, 63.6))} ${P(T(44.8, 63.9))}`, 1.05));
  out.push(toe(`M${P(T(44.8, 63.9))} C${P(T(45.7, 64.2))} ${P(T(45.9, 64.9))} ${P(T(45.5, 65.8))}`, 0.58));
  if (scutes) {
    // A glint on each claw's curve.
    for (const c of [[33.4, 64.4], [36.8, 64.1], [45.6, 64.5]])
      out.push({ d: `M${P(T(c[0] + 0.15, c[1] - 0.5))} Q${P(T(c[0] - 0.25, c[1]))} ${P(T(c[0] - 0.05, c[1] + 0.6))}`, stroke: "edge", sw: 0.2, op: 0.7, cap: "round" });
    // A pale glint along the top of the toes.
    out.push({ d: `M${P(T(40.0, 62.85))} C${P(T(38.4, 62.85))} ${P(T(36.6, 62.95))} ${P(T(35.0, 63.25))}`, stroke: "edge", sw: 0.3, op: 0.6 });
    out.push({ d: `M${P(T(41.6, 63.0))} C${P(T(42.8, 63.05))} ${P(T(43.8, 63.15))} ${P(T(44.6, 63.4))}`, stroke: "edge", sw: 0.3, op: 0.5 });
  }
  return out;
}
parts.farLeg = leg(3.0, -0.5, "deep", 1, false);
parts.nearLeg = leg(0, 0, "beak", 1, true);

// --- Tail: a wedge, in a local frame along its axis (origin at its base).
parts.tail = (() => {
  const out = [];
  // Undertail coverts, under the base.
  out.push({ d: "M-2,1.6 C3,3.8 9,4.8 14.5,4.6 C10,6.4 3,6.4 -3,4.4 Z", fill: "body" });
  // A wedge: the outer feathers shortest, the central pair longest.
  const L = [22, 25.2, 28.2, 30.6], Y = [2.7, 1.6, 0.5, -0.6];
  for (let i = 0; i < 4; i++) {
    const fe = feather(-1, Y[i] * 0.6, L[i], Y[i], 1.85, 1);
    out.push({ d: fe.body, fill: { lin: [0, -2, 0, 4], stops: [[0, "mid", 1], [0.55, "body", 1], [1, "deep", 1]] } });
    out.push(outline(fe.body));
    out.push({ d: fe.barbs, stroke: "edge", sw: 0.14, op: 0.2 });
    out.push({ d: fe.fringe, stroke: "edge", sw: 0.45, op: 0.6, cap: "round" });
    out.push({ d: fe.shaft, stroke: "edge", sw: 0.24, op: 0.4 });
  }
  // A long rim light along the top of the central feathers.
  out.push({ d: "M2,-1.9 C10,-2.4 20,-2.3 28.4,-2.2", stroke: "edge", sw: 0.4, op: 0.35, cap: "round" });
  return out;
})();

// --- Body: breast, belly, back; thigh feathers.
const BODY = "M31,16.6 C38.4,17.2 45.4,21.8 51.2,29.8 C55.6,35.8 58.8,41.4 60.8,46.6 L57.6,50.8 C52.2,53.8 46.2,55.6 40.4,55.8 C33.6,56 27.2,52.6 23.6,46.8 C20.4,41.6 19.6,35.2 20.4,30.0 C21.2,25.2 24.6,20.2 31,16.6 Z";
const MANTLE = "M31,17 C38.4,17.6 45.4,22 51.2,30 C53.8,33.6 55.8,36.8 57.2,39.8 L49,36 C43.6,30.4 37.4,26.2 29.6,24.4 Z";
parts.body = (() => {
  const out = [];
  out.push({ d: BODY, fill: { lin: [46, 20, 26, 54], stops: [[0, "mid", 1], [0.42, "body", 1], [1, "deep", 1]] } });
  // Breast and belly: faint scalloped contour feathers, row on row.
  for (let r = 0; r < 7; r++) {
    const y = 27.5 + r * 3.6;
    const front = 21.2 + Math.pow((y - 36) / 11, 2) * 3.2;
    const n = r < 5 ? 3 : 2;
    for (let i = 0; i < n; i++) {
      const x = front + 2.4 + i * 3.4 + (r % 2) * 1.7;
      out.push({ d: `M${P([x - 1.5, y - 0.4])} C${P([x - 1.1, y + 1.1])} ${P([x + 1.1, y + 1.1])} ${P([x + 1.5, y - 0.4])}`, stroke: "edge", sw: 0.34, op: 0.16 + 0.05 * (r < 3), cap: "round" });
    }
  }
  // The mantle and nape: rows of small scalloped feathers down the back.
  for (const [x0, y0, n, w] of [[30.4, 19.2, 4, 1.7], [31.6, 22.4, 4, 1.9], [34.4, 25.6, 4, 2.0], [38.4, 28.8, 3, 2.1]])
    for (let i = 0; i < n; i++) {
      const x = x0 + i * w * 1.7, y = y0 + i * w * 0.95;
      out.push({ d: `M${P([x - w, y - 0.3])} C${P([x - w * 0.7, y + w * 0.6])} ${P([x + w * 0.7, y + w * 0.6])} ${P([x + w, y - 0.3])}`, stroke: "edge", sw: 0.3, op: 0.32, cap: "round" });
    }
  // Rim lights: along the back, and a softer one down the breast.
  out.push({ d: "M33,17.2 C39.6,18.2 45.8,22.6 51.2,30 C55.4,35.8 58.6,41.4 60.6,46.4", stroke: "edge", sw: 0.6, op: 0.55, cap: "round" });
  out.push({ d: "M23.4,46.4 C20.4,41.4 19.8,35.2 20.6,30.2 C21.0,27.6 22.0,25.4 23.6,23.4", stroke: "edge", sw: 0.55, op: 0.42, cap: "round" });
  // Thigh feathers, shaggy over the top of the legs.
  out.push({ d: "M33.6,49.4 C35.8,46.8 41.2,46.4 44.2,49.2 C45.4,51.8 44.8,54.4 43.4,56.4 L42.2,55.2 L41.6,57.4 L40.2,55.8 L39.2,57.6 L38.2,55.6 C36.2,55 34.4,53.2 33.6,49.4 Z", fill: { lin: [40, 47, 40, 57], stops: [[0, "body", 1], [1, "deep", 1]] } });
  for (const [x, y] of [[38.4, 51.4], [40.4, 52], [42.4, 51.8], [39.4, 54], [41.6, 54.2]])
    out.push({ d: `M${P([x - 0.6, y - 1.6])} L${P([x, y + 1.4])}`, stroke: "edge", sw: 0.3, op: 0.3, cap: "round" });
  return out;
})();
parts.mantleSheen = [{ d: MANTLE, fill: "sheen", sheen: [30, 17, 58, 42] }];

// --- Wing, folded, in a local frame along its axis (origin at the
// shoulder, tip toward +x, the belly side +y).
const WING = "M0,-1 C8,-3.6 20,-3.8 32,-2.6 C40,-1.8 47.4,-0.8 53.6,0.2 C50,1.8 46,3.4 41,4.8 C34,7.6 25,10.2 17,10.8 C10,11.2 4,9.6 1,6 C-0.8,4 -1,1.4 0,-1 Z";
parts.wingBase = [{ d: WING, fill: { lin: [0, -3, 0, 11], stops: [[0, "mid", 1], [0.5, "body", 1], [1, "deep", 1]] } }];
// Primaries, one item each (they spread in a flap): longest at the bottom.
const PRIM = [[53.6, 0.2], [50.6, 1.5], [47.6, 2.7], [44.6, 3.7], [41.8, 4.5]];
PRIM.forEach(([tx, ty], i) => {
  const fe = feather(22 + i * 0.8, ty * 0.5 + 0.4, tx, ty, 1.9 - i * 0.05, 0);
  parts["primary" + i] = [
    { d: fe.body, fill: { lin: [30, -2, 30, 4], stops: [[0, "mid", 1], [0.6, "body", 1], [1, "deep", 1]] } },
    outline(fe.body, 0.55),
    { d: fe.barbs, stroke: "edge", sw: 0.14, op: 0.24 },
    { d: fe.fringe, stroke: "edge", sw: 0.48, op: 0.65, cap: "round" },
    { d: fe.shaft, stroke: "edge", sw: 0.26, op: 0.5 }
  ];
});
parts.wingFront = (() => {
  const out = [];
  // Secondaries and tertials: broad, rounded, their tips the wing's
  // scalloped lower edge (outer first, the tertials on top).
  for (const [tx, ty] of [[40.2, 5.4], [35.4, 7.6], [30.4, 9.0], [25, 9.8], [19.4, 10.0]]) {
    const fe = feather(tx - 17, ty - 3.2, tx, ty, 2.5, 1);
    out.push({ d: fe.body, fill: { lin: [0, ty - 3, 0, ty + 3], stops: [[0, "mid", 1], [0.7, "body", 1], [1, "deep", 1]] } });
    out.push(outline(fe.body, 0.45));
    out.push({ d: fe.barbs, stroke: "edge", sw: 0.14, op: 0.18 });
    out.push({ d: fe.fringe, stroke: "edge", sw: 0.45, op: 0.5, cap: "round" });
    out.push({ d: fe.shaft, stroke: "edge", sw: 0.22, op: 0.3 });
  }
  // Scapulars along the top edge.
  for (const [tx, ty] of [[33.6, -1.0], [27.4, -1.6], [21.4, -2.0]]) {
    const fe = feather(tx - 13, ty - 0.6, tx, ty, 1.8, 1);
    out.push({ d: fe.body, fill: "body" });
    out.push(outline(fe.body, 0.42));
    out.push({ d: fe.fringe, stroke: "edge", sw: 0.4, op: 0.46, cap: "round" });
  }
  // Greater, median and lesser coverts.
  out.push(...covertRow([[30.6, 3.0], [27.2, 4.4], [23.8, 5.6], [20.4, 6.4], [17, 6.8], [13.6, 6.8]], 7, 1.75, "mid", 0.34));
  out.push(...covertRow([[21, 0.2], [18, 1.6], [15, 2.8], [12, 3.6], [9, 4.0], [6.2, 4.2]], 5.2, 1.45, "body", 0.3));
  out.push(...covertRow([[13, -1.6], [10.4, -0.6], [7.8, 0.4], [5.2, 1.2], [2.8, 1.8], [10.4, -2.6], [6.8, -1.4]], 3.6, 1.15, "body", 0.26));
  // The wrist's leading edge.
  out.push({ d: "M0.2,-1.2 C6,-3.2 14,-3.8 22,-3.4", stroke: "edge", sw: 0.55, op: 0.5, cap: "round" });
  return out;
})();
// Preening: a few scapulars lifted and parted on the back where the beak
// works, over its tip (in the torso's frame).
parts.preenTuft = (() => {
  const out = [];
  // Base on the back, angle (degrees), length: a ruffled fan.
  for (const [bx, by, ang, L] of [[50.4, 33.4, -62, 5.2], [52.4, 35.0, -44, 5.8], [54.2, 37.0, -26, 5.6], [55.4, 39.2, -8, 4.8]]) {
    const a = ang * Math.PI / 180;
    const fe = feather(0, 0, L, 0, 1.55, 0);
    const R = (x, y) => [bx + x * Math.cos(a) - y * Math.sin(a), by + x * Math.sin(a) + y * Math.cos(a)];
    const tr = d => d.replace(/(-?[\d.]+),(-?[\d.]+)/g, (_, x, y) => P(R(+x, +y)));
    out.push({ d: tr(fe.body), fill: { lin: [bx, by - 6, bx, by + 2], stops: [[0, "mid", 1], [1, "body", 1]] } });
    out.push(outline(tr(fe.body), 0.5));
    out.push({ d: tr(fe.fringe), stroke: "edge", sw: 0.36, op: 0.6, cap: "round" });
  }
  return out;
})();
parts.wingSheen = [{ d: WING, fill: "sheen", sheen: [0, -4, 54, 12] }];

// --- Head (and neck), hackles, beak, eye.
parts.hackles = (() => {
  const out = [];
  out.push({ d: "M17.8,19.4 C17.0,21.0 16.6,23.2 16.8,25.6 L18.2,23.8 C17.9,26.0 18.1,27.8 18.6,29.6 L19.8,27.0 C20.0,29.0 20.6,30.8 21.4,32.4 L22.2,29.4 C22.8,31.0 23.6,32.6 24.6,33.8 L24.9,30.4 C25.8,31.6 26.9,32.6 28.0,33.0 L27.6,29.8 C28.6,30.2 29.6,30.2 30.6,29.8 L30.8,25 C26.2,24.8 21.6,22.8 17.8,19.4 Z", fill: { lin: [22, 20, 24, 33], stops: [[0, "body", 1], [1, "deep", 1]] } });
  // A second, shorter layer of hackles over the first.
  out.push({ d: "M18.6,20.6 C18.2,22.4 18.4,24.2 19.0,25.8 L19.8,24.6 C20.0,26.2 20.6,27.6 21.4,28.8 L22.0,27.0 C22.6,28.4 23.4,29.4 24.4,30.2 L24.6,28.2 C25.6,29.0 26.6,29.4 27.6,29.4 L28,25.6 C24.8,25.2 21.4,23.4 18.6,20.6 Z", fill: "body" });
  for (const [a, b] of [[[18.6, 21], [17.6, 24.2]], [[19.8, 22.2], [18.7, 27.8]], [[21.2, 23.2], [21.2, 30.4]], [[23, 24], [24.2, 31.8]], [[25, 24.6], [27.4, 31.3]], [[27.2, 25], [30, 28.9]]])
    out.push({ d: `M${P(a)} Q${P([(a[0] + b[0]) / 2 - 0.3, (a[1] + b[1]) / 2])} ${P(b)}`, stroke: "edge", sw: 0.34, op: 0.5, cap: "round" });
  out.push({ d: "M16.8,25.6 L18.2,23.8 C17.9,26.0 18.1,27.8 18.6,29.6 L19.8,27.0 C20.0,29.0 20.6,30.8 21.4,32.4 L22.2,29.4 C22.8,31.0 23.6,32.6 24.6,33.8 L24.9,30.4 C25.8,31.6 26.9,32.6 28.0,33.0 L27.6,29.8 C28.6,30.2 29.6,30.2 30.6,29.8", stroke: "edge", sw: 0.36, op: 0.5, cap: "round" });
  out.push({ d: "M19.0,25.8 L19.8,24.6 C20.0,26.2 20.6,27.6 21.4,28.8 L22.0,27.0 C22.6,28.4 23.4,29.4 24.4,30.2 L24.6,28.2 C25.6,29.0 26.6,29.4 27.6,29.4", stroke: "edge", sw: 0.3, op: 0.4, cap: "round" });
  return out;
})();
parts.head = (() => {
  const out = [];
  out.push({ d: "M17.2,9.8 C18.2,6.8 21.2,4.9 24.8,4.9 C28.8,4.9 32.4,6.6 34.4,9.8 C36.0,12.4 36.8,16.0 36.4,19.6 L31,27 C27.2,27.6 23.2,27 20.8,24.4 C18.9,22.4 17.8,20 17.4,17.6 Z", fill: { lin: [27, 4.5, 25, 26], stops: [[0, "mid", 1], [0.45, "body", 1], [1, "deep", 1]] } });
  // Rim light over the crown and nape.
  out.push({ d: "M18.6,7.6 C20.4,5.8 22.6,5.1 24.8,5.1 C28.8,5.1 32.3,6.8 34.2,9.9 C35.6,12.2 36.3,15 36.3,18", stroke: "edge", sw: 0.6, op: 0.62, cap: "round" });
  // Crown and ear-covert feathering.
  for (const [x, y, w] of [[22.2, 6.6, 1.2], [24.5, 7.2, 1.6], [28, 7.6, 1.7], [31.2, 9.4, 1.6], [26.4, 9.6, 1.4], [29.6, 11.6, 1.5], [32.6, 13, 1.5], [34.6, 15.4, 1.2], [27.6, 14.4, 1.4], [30.6, 16.2, 1.5], [33.6, 17, 1.4], [25.2, 16.6, 1.3], [28.4, 18.8, 1.4], [31.6, 20.2, 1.3], [26.0, 20.8, 1.2], [23.0, 18.8, 1.1]])
    out.push({ d: `M${P([x - w, y - 0.3])} C${P([x - w * 0.7, y + 0.9])} ${P([x + w * 0.7, y + 0.9])} ${P([x + w, y - 0.3])}`, stroke: "edge", sw: 0.3, op: 0.28, cap: "round" });
  // The gape line, running back from the beak's hinge under the eye.
  out.push({ d: "M18.2,16.6 C19.6,16.4 21.0,15.8 22.4,14.8", stroke: "deep", sw: 0.45, op: 1, cap: "round" });
  out.push({ d: "M18.4,17.1 C19.8,16.9 21.2,16.3 22.5,15.4", stroke: "edge", sw: 0.22, op: 0.45, cap: "round" });
  // The brow: a raven's shaggy "eyebrow" over the eye.
  out.push({ d: "M19.2,9.1 C21,7.9 23.6,7.7 25.8,8.7", stroke: "edge", sw: 0.42, op: 0.5, cap: "round" });
  // Eye socket shade.
  out.push({ d: "M19.6,11.1 C19.6,9.5 21,8.6 22.4,8.6 C24,8.6 25.2,9.7 25.2,11.1 C25.2,12.6 24,13.6 22.4,13.6 C20.9,13.6 19.6,12.6 19.6,11.1 Z", fill: "deep", op: 0.7 });
  return out;
})();
parts.eye = [
  { d: "M20.85,11 a1.55,1.55 0 1,0 3.1,0 a1.55,1.55 0 1,0 -3.1,0 Z", fill: "iris" },
  { d: "M20.85,11 a1.55,1.55 0 1,0 3.1,0 a1.55,1.55 0 1,0 -3.1,0 Z", stroke: "edge", sw: 0.36, op: 0.8 }
];
parts.catchLight = [
  { d: "M21.3,10.45 a0.52,0.52 0 1,0 1.04,0 a0.52,0.52 0 1,0 -1.04,0 Z", fill: "eye" },
  { d: "M23.1,11.75 a0.22,0.22 0 1,0 0.44,0 a0.22,0.22 0 1,0 -0.44,0 Z", fill: "eye", op: 0.5 }
];
parts.membrane = [
  { d: "M20.85,11 a1.55,1.55 0 1,0 3.1,0 a1.55,1.55 0 1,0 -3.1,0 Z", fill: "membrane", op: 0.88 },
  { d: "M22.4,9.45 C23.5,10.1 23.6,11.9 22.4,12.55", stroke: "eye", sw: 0.24, op: 0.9, cap: "round" }
];
// A shut eye (asleep): the lid over it, and its seam.
parts.lid = [
  { d: "M20.7,11 a1.7,1.7 0 1,0 3.4,0 a1.7,1.7 0 1,0 -3.4,0 Z", fill: "mid" },
  { d: "M20.9,11.1 C21.8,11.9 23.1,11.9 23.9,11.1", stroke: "edge", sw: 0.4, op: 0.7, cap: "round" }
];
parts.bristles = (() => {
  const out = [];
  for (let k = 0; k < 5; k++) {
    const y0 = 9.0 + k * 0.7, tip = [9.8 + k * 1.25, 10.9 + k * 0.8];
    out.push({ d: `M${P([18.8, y0])} Q${P([14.4, y0 + 0.1])} ${P(tip)} Q${P([14.6, y0 + 1.05])} ${P([18.8, y0 + 1.25])} Z`, fill: "body" });
    out.push({ d: `M${P([18.4, y0 + 0.3])} Q${P([14.4, y0 + 0.4])} ${P(tip)}`, stroke: "edge", sw: 0.26, op: 0.55, cap: "round" });
  }
  return out;
})();
parts.mouth = [{ d: "M18.6,15.8 L7,17.6 L4.8,19.4 L18.6,17.6 Z", fill: "deep" }];
parts.beakUpper = [
  { d: "M17.6,9.5 C13.4,9.7 8.6,11.5 5.0,14.9 C3.6,16.3 2.6,17.8 2.3,19.3 C2.2,20.1 2.8,20.5 3.4,19.9 C3.8,19.4 4.4,19.0 5.2,18.7 C9.0,17.3 13.4,16.5 18.4,16.3 Z", fill: { lin: [10, 10, 10, 18], stops: [[0, "beakHi", 1], [0.5, "beak", 1], [1, "deep", 1]] } },
  // The culmen's sheen, and the cutting edge.
  { d: "M17,9.95 C12.8,10.3 8.4,12.1 5.0,15.3 C3.9,16.4 3.1,17.6 2.7,18.7", stroke: "edge", sw: 0.6, op: 0.85, cap: "round" },
  { d: "M14.6,10.5 C11.6,11.1 8.6,12.6 6.2,14.8", stroke: "eye", sw: 0.2, op: 0.25, cap: "round" },
  { d: "M18.3,16.3 C13.4,16.5 9.0,17.3 5.2,18.7 C4.4,19.0 3.8,19.4 3.4,19.9", stroke: "deep", sw: 0.4, op: 1, cap: "round" }
];
parts.beakLower = [
  { d: "M18.6,16.5 C13.8,16.7 9.4,17.6 5.6,19.0 C4.9,19.3 4.7,19.8 5.1,20.1 C8.7,20.8 13.3,20.5 18.2,19.7 Z", fill: { lin: [10, 16.5, 10, 20.5], stops: [[0, "beak", 1], [1, "deep", 1]] } },
  { d: "M17.6,19.6 C13,20.3 8.7,20.6 5.6,20.0", stroke: "edge", sw: 0.35, op: 0.45, cap: "round" }
];
// Two pale arcs from the beak: the silent caw (pivot at the beak tip).
parts.cawArcs = [
  { d: "M-1.2,14.6 C-2.6,16.2 -2.8,18.6 -1.6,20.4", stroke: "eye", sw: 0.7, op: 0.9, cap: "round" },
  { d: "M-4.4,12.6 C-6.6,15.4 -6.8,19.2 -5.0,22.2", stroke: "eye", sw: 0.7, op: 0.6, cap: "round" }
];

fs.writeFileSync(OUT + "/parts.json", JSON.stringify(parts, null, 1));

// --- SVG preview.
const COL = { body: "#121419", edge: "#3a404b", beak: "#1b1e24", eye: "#c7ccd4", membrane: "#8b94a3", deep: "#08090b", mid: "#1f232a", iris: "#050607", beakHi: "#2a2e36" };
let gid = 0;
const defs = [];
function svgPaths(list, sheenOp) {
  return list.map(p => {
    let fill = "none", stroke = "none";
    if (p.fill) {
      if (p.fill === "sheen") {
        const id = "g" + gid++;
        defs.push(`<linearGradient id="${id}" gradientUnits="userSpaceOnUse" x1="${p.sheen[0]}" y1="${p.sheen[1]}" x2="${p.sheen[2]}" y2="${p.sheen[3]}"><stop offset="0" stop-color="#2f4fb8"/><stop offset="0.45" stop-color="#5b3db0"/><stop offset="1" stop-color="#23866a"/></linearGradient>`);
        return `<path d="${p.d}" fill="url(#${id})" opacity="${sheenOp}"/>`;
      }
      if (typeof p.fill === "string") fill = COL[p.fill];
      else {
        const id = "g" + gid++;
        const [x1, y1, x2, y2] = p.fill.lin;
        defs.push(`<linearGradient id="${id}" gradientUnits="userSpaceOnUse" x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}">${p.fill.stops.map(s => `<stop offset="${s[0]}" stop-color="${COL[s[1]]}"/>`).join("")}</linearGradient>`);
        fill = `url(#${id})`;
      }
    }
    if (p.stroke) stroke = COL[p.stroke];
    return `<path d="${p.d}" fill="${fill}" stroke="${stroke}" stroke-width="${p.sw || 0}" stroke-linecap="${p.cap || "butt"}" opacity="${p.op ?? 1}"/>`;
  }).join("\n");
}
const WT = "translate(31,24) rotate(39.7)";
const TT = "translate(57,47) rotate(32.6)";
const body = `
<g>${svgPaths(parts.farLeg)}</g>
<g transform="${TT}">${svgPaths(parts.tail)}</g>
<g>${svgPaths(parts.body)}${svgPaths(parts.mantleSheen, 0.16)}</g>
<g>${svgPaths(parts.nearLeg)}</g>
<g transform="${WT}">${svgPaths(parts.wingBase)}${[0, 1, 2, 3, 4].map(i => svgPaths(parts["primary" + i])).join("")}${svgPaths(parts.wingFront)}${svgPaths(parts.wingSheen, 0.16)}</g>
<g>${svgPaths(parts.hackles)}${svgPaths(parts.head)}${svgPaths(parts.eye)}${svgPaths(parts.catchLight)}${svgPaths(parts.mouth)}${svgPaths(parts.beakLower)}${svgPaths(parts.beakUpper)}${svgPaths(parts.bristles)}</g>`;
const bg = process.argv[2] || "#0a0b0e";
fs.writeFileSync(OUT + "/art.svg", `<svg xmlns="http://www.w3.org/2000/svg" viewBox="-8 0 96 68" width="96" height="68"><defs>${defs.join("")}</defs><rect x="-8" y="0" width="96" height="68" fill="${bg}"/><line x1="30" y1="64" x2="88" y2="64" stroke="#262a31" stroke-width="0.6"/>${body}</svg>`);
console.log("ok");
