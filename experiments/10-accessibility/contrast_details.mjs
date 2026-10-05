// Groups axe color-contrast violations of all result files by the colour pair
// axe reports: node contrast_details.mjs
import { readFileSync, readdirSync } from 'node:fs';
const groups = {};
for (const f of readdirSync('out').filter(f => f.startsWith('axe-en-') && f.endsWith('.json') && f !== 'axe-summary.json')) {
  const r = JSON.parse(readFileSync('out/' + f, 'utf8'));
  for (const v of r.violations.filter(v => v.id === 'color-contrast')) {
    for (const n of v.nodes) {
      const m = (n.summary || '').match(/contrast of ([\d.]+) \(foreground color: (#\w+), background color: (#\w+), font size: ([^,]+), font weight: (\w+)\)\. Expected contrast ratio of ([\d.:]+)/);
      const key = m ? `${m[2]} on ${m[3]} = ${m[1]} (need ${m[6]}, ${m[4]} ${m[5]})` : n.summary;
      (groups[key] ||= new Set()).add(`${f.slice(7, -5)}: ${n.html.slice(0, 90).replace(/\s+/g, ' ')}`);
    }
  }
}
for (const [k, s] of Object.entries(groups)) { console.log(k, `(${s.size})`); [...s].slice(0, 3).forEach(x => console.log('    ', x)); }
