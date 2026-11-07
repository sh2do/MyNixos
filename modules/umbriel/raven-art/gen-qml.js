// Writes modules/umbriel/shell/RavenBody.qml from parts.json (art.js) and
// the template RavenBody.qml.in, whose `//@shape <part>` lines become that
// part's Shape. Run art.js first; OUTQML overrides where it writes.
const fs = require("fs");
const parts = JSON.parse(fs.readFileSync(__dirname + "/parts.json", "utf8"));

const COL = { body: "root.bodyColor", edge: "root.edgeColor", beak: "root.beakColor", eye: "root.eyeColor", membrane: "root.membraneColor", deep: "root.deep", mid: "root.mid", iris: "root.iris", beakHi: "root.beakHi" };
const col = (c, op) => (op === undefined || op === 1) ? COL[c] : `Qt.alpha(${COL[c]}, ${op})`;

function shapePath(p, ind) {
  const I = " ".repeat(ind);
  const L = [];
  L.push(`${I}ShapePath {`);
  if (p.stroke) {
    L.push(`${I}    strokeColor: ${col(p.stroke, p.op)}`);
    L.push(`${I}    strokeWidth: ${p.sw}`);
    if (p.cap === "round") L.push(`${I}    capStyle: ShapePath.RoundCap`);
    L.push(`${I}    fillColor: "transparent"`);
  } else {
    L.push(`${I}    strokeColor: "transparent"`);
    if (p.fill === "sheen") {
      const [x1, y1, x2, y2] = p.sheen;
      L.push(`${I}    fillTransform: PlanarTransform.fromTranslate(root.sheenShift * ${f(x2 - x1)}, root.sheenShift * ${f(y2 - y1)})`);
      L.push(`${I}    fillGradient: LinearGradient {`);
      L.push(`${I}        x1: ${x1}; y1: ${y1}; x2: ${x2}; y2: ${y2}`);
      L.push(`${I}        spread: ShapeGradient.ReflectSpread`);
      L.push(`${I}        GradientStop { position: 0; color: root.sheenColors[0] }`);
      L.push(`${I}        GradientStop { position: 0.45; color: root.sheenColors[1] }`);
      L.push(`${I}        GradientStop { position: 1; color: root.sheenColors[2] }`);
      L.push(`${I}    }`);
    } else if (typeof p.fill === "string") {
      L.push(`${I}    fillColor: ${col(p.fill, p.op)}`);
    } else {
      const [x1, y1, x2, y2] = p.fill.lin;
      L.push(`${I}    fillGradient: LinearGradient {`);
      L.push(`${I}        x1: ${x1}; y1: ${y1}; x2: ${x2}; y2: ${y2}`);
      for (const s of p.fill.stops)
        L.push(`${I}        GradientStop { position: ${s[0]}; color: ${col(s[1], s[2])} }`);
      L.push(`${I}    }`);
    }
  }
  L.push(`${I}    PathSvg { path: "${p.d}" }`);
  L.push(`${I}}`);
  return L.join("\n");
}
function f(n) { return (Math.round(n * 100) / 100).toString(); }

// A Shape holding a part's paths.
function shape(name, ind, extra) {
  const I = " ".repeat(ind);
  return `${I}Shape {\n${I}    preferredRendererType: Shape.CurveRenderer\n${extra ? extra.map(e => I + "    " + e + "\n").join("") : ""}${parts[name].map(p => shapePath(p, ind + 4)).join("\n")}\n${I}}`;
}

let tpl = fs.readFileSync(__dirname + "/RavenBody.qml.in", "utf8");
const lines = tpl.split("\n");
for (let i = 0; i < lines.length; i++) {
  const m = lines[i].match(/^\s*\/\/@shape (\w+)(?: (.*))?$/);
  if (!m) continue;
  let j = i - 1;
  while (j >= 0 && !lines[j].trim()) j--;
  const prev = lines[j];
  // Inside the block just opened, or level with the item before.
  let ind = prev.match(/^ */)[0].length + (prev.trimEnd().endsWith("{") ? 4 : 0);
  if (!prev.trimEnd().endsWith("{") && prev.trim() === "}") ind = prev.match(/^ */)[0].length;
  if (!prev.trimEnd().endsWith("{") && prev.trim() !== "}") ind = prev.match(/^ */)[0].length;
  lines[i] = shape(m[1], ind, m[2] ? m[2].split(" ;; ") : null);
}
tpl = lines.join("\n");
const out = process.env.OUTQML || (__dirname + "/../shell/RavenBody.qml");
fs.writeFileSync(out, tpl);
console.log("wrote", out, tpl.split("\n").length, "lines");
