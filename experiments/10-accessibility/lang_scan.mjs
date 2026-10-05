// Japanese text in the German and English lessons (would need lang="ja"):
// node lang_scan.mjs  - loads ../../html/lessons.js in a fake window
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { join, dirname } from 'node:path';
import vm from 'node:vm';
const here = dirname(fileURLToPath(import.meta.url));
const src = readFileSync(join(here, '../../html/lessons.js'), 'utf8');
const sandbox = { window: {} };
vm.runInNewContext(src, sandbox);
const data = JSON.parse(sandbox.window.LESSONS_JSON);
const JA = /[぀-ヿ㐀-鿿]+[^<"\n]{0,20}/g;
for (const lang of ['de', 'en']) {
  for (const l of data.lessons) {
    const t = l[lang]; if (!t) continue;
    t.cells.forEach((c, i) => {
      for (const field of ['html', 'code', 'hint']) {
        const m = (c[field] || '').match(JA);
        if (m) console.log(`${lang} ${l.id} cell ${i} ${field}: ${m.slice(0, 3).join(' | ')}${(c[field] || '').includes('lang="ja"') ? '  [has lang="ja"]' : ''}`);
      }
    });
  }
  for (const [k, v] of Object.entries(data.ui[lang])) { const s = JSON.stringify(v); if (/[぀-ヿ㐀-鿿]/.test(s)) console.log(`${lang} ui.${k}: ${s.slice(0, 80)}`); }
}
console.log(`scanned ${data.lessons.length} lessons; ja cells with Latin-only German/English prose are not checked`);
