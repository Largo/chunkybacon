// WCAG contrast ratios for candidate colours: node contrast_calc.mjs
const hex = h => [1, 3, 5].map(i => parseInt(h.slice(i, i + 2), 16));
const lum = c => { const f = v => { v /= 255; return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4; }; const [r, g, b] = c.map(f); return 0.2126 * r + 0.7152 * g + 0.0722 * b; };
const ratio = (a, b) => { const x = lum(hex(a)), y = lum(hex(b)); return ((Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05)).toFixed(2); };
const mix = (fg, bg, a) => '#' + hex(fg).map((v, i) => Math.round(v * a + hex(bg)[i] * (1 - a)).toString(16).padStart(2, '0')).join('');
const bgs = { paper: '#ffffff', code: '#eef2f6', fat: '#fdeee3', highlight: '#ffc9a1', bubbleFail: '#fde6dc', bubblePass: '#e6f4e7', okBg: '#e3f2e4' };
const rows = {
  'linenumber now #7d8894': '#7d8894', 'linenumber #5f6b78': '#5f6b78', 'linenumber #66717e': '#66717e',
  '--bacon now #c14a2e': '#c14a2e', '--bacon #b3401f': '#b3401f', '--bacon #ad3f25': '#ad3f25',
  '--ok now #2e7d32': '#2e7d32', '--ok #276d2b': '#276d2b',
  '--ink-soft #5f5247': '#5f5247', '--fox #e8722a (ui)': '#e8722a', '--ink #1a1208': '#1a1208',
  'download small: --bacon @.75': mix('#c14a2e', '#ffffff', 0.75), 'ws-del: ink-soft @.45': mix('#5f5247', '#ffffff', 0.45), 'ws-del: ink-soft @.8': mix('#5f5247', '#ffffff', 0.8),
};
console.log('colour'.padEnd(34), Object.keys(bgs).map(k => k.padStart(10)).join(''));
for (const [name, c] of Object.entries(rows)) console.log(`${name} ${c}`.padEnd(34), Object.values(bgs).map(b => ratio(c, b).padStart(10)).join(''));
console.log('ink on fox (run button):', ratio('#1a1208', '#e8722a'), ' focus ring #2f6db5 on paper:', ratio('#2f6db5', '#ffffff'), ' on highlight:', ratio('#2f6db5', '#ffc9a1'));
