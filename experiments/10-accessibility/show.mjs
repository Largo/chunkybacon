// Prints a compact view of one axe result file: node show.mjs out/axe-en-hallo.json
import { readFileSync } from 'node:fs';
const r = JSON.parse(readFileSync(process.argv[2], 'utf8'));
for (const kind of ['violations', 'incomplete']) {
  console.log(`== ${kind}`);
  for (const v of r[kind]) {
    console.log(`${v.impact} ${v.id}: ${v.help} (${v.nodes.length})`);
    for (const n of v.nodes.slice(0, 4)) console.log('   ', JSON.stringify(n.target), n.html.slice(0, 140).replace(/\n/g, ' '));
  }
}
