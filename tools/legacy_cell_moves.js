// Prints Store::LEGACY_MOVES (html/shell/store.rb) for the current
// html/lessons.js: where the code cells of the lessons from before saved
// code had fingerprints (aa6f700~1, 2026-10-05) sit now. A cell is found by
// its code, else as the next code cell of its kind; the indices must agree
// in de, en and ja. Run it after moving code cells and paste the result.
//   node tools/legacy_cell_moves.js
const { execFileSync } = require("child_process");
const fs = require("fs");
const path = require("path");
const root = path.join(__dirname, "..");
const load = src => { global.window = {}; eval(src); return JSON.parse(window.LESSONS_JSON); };
const old = load(execFileSync("git", ["show", "aa6f700~1:html/lessons.js"], { cwd: root, maxBuffer: 1 << 28 }).toString());
const now = load(fs.readFileSync(path.join(root, "html", "lessons.js"), "utf8"));
const byId = Object.fromEntries(now.lessons.map(l => [l.id, l]));
const isCode = c => c.t === "c" || c.t === "x";

const moves = (oc, nc) => {
  const list = [];
  let from = 0;
  oc.forEach((c, i) => {
    if (!isCode(c)) return;
    let j = nc.findIndex((d, k) => k >= from && d.t === c.t && d.code === c.code);
    if (j < 0) j = nc.findIndex((d, k) => k >= from && d.t === c.t);
    if (j < 0) throw new Error(`no cell for old cell ${i}`);
    if (j !== i) list.push([i, j]);
    from = j + 1;
  });
  return list;
};

const rows = [];
for (const lesson of old.lessons) {
  const current = byId[lesson.id];
  if (!current) continue;
  const [de, en, ja] = ["de", "en", "ja"].map(lang => JSON.stringify(moves(lesson[lang].cells, current[lang].cells)));
  if (de !== en || de !== ja) throw new Error(`${lesson.id}: the languages moved differently: ${de} ${en} ${ja}`);
  const list = JSON.parse(de);
  if (list.length) rows.push(`      "${lesson.id}" => { ${list.map(([a, b]) => `${a} => ${b}`).join(", ")} }`);
}
console.log(`    LEGACY_MOVES = {\n${rows.join(",\n")}\n    }.freeze`);
