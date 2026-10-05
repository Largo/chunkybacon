// Headless smoke test for the notebook UI: demo cells, => results without
// puts, exercise checks, shared kernel state, errors, i18n, persistence.
import { chromium } from '/usr/local/lib/node_modules/playwright/index.mjs';

const BASE = process.env.BASE || 'http://127.0.0.1:8011/';
const browser = await chromium.launch();
// a German browser: the checks below read the German interface
const page = await browser.newPage({ locale: 'de-DE' });
page.on('console', m => { if (m.type() === 'error') console.log('[console.error]', m.text()); });
page.on('pageerror', e => console.log('[pageerror]', e.message));

let failures = 0;
const check = (name, cond) => {
  console.log(`${cond ? 'PASS' : 'FAIL'} ${name}`);
  if (!cond) failures++;
};

const exerciseIdx = () => page.getAttribute('.cell.exercise .run-cell', 'data-idx');
const runExercise = async () => { await page.click('.cell.exercise .run-cell'); await page.waitForTimeout(400); };
const setExercise = async code => {
  const idx = await exerciseIdx();
  await page.evaluate(([i, c]) => window.cellEditors[i].setValue(c), [idx, code]);
};
const exerciseOut = async () => {
  const idx = await exerciseIdx();
  return (await page.textContent(`#cell-out-${idx}`)) || '';
};

// The page is drawn by the shell (PicoRuby); the kernel that runs the code
// (CRuby, 10 MB) loads afterwards. A run asked for meanwhile waits for it.
const kernelReady = p => p.waitForFunction(() => window.ChunkyBridge && window.ChunkyBridge.ready, null, { timeout: 120000 });

await page.goto(BASE, { waitUntil: 'domcontentloaded' });
await page.waitForSelector('#app', { state: 'visible', timeout: 120000 });
check('app becomes visible after wasm boot', true);
check('the lesson is readable before the kernel has loaded',
      (await page.textContent('#lessonBody h2')).includes('Hallo') && !(await page.evaluate(() => window.ChunkyBridge.ready)));
await page.click('.run-cell[data-idx="1"]');
await kernelReady(page);
await page.waitForFunction(() => document.getElementById('cell-out-1').textContent.includes('=> 2'), null, { timeout: 30000 });
check('a run clicked while the kernel loads runs once it is up', true);

check('German title', (await page.textContent('#siteTitle')).includes('Ruby lernen mit Chunky Bacon'));
check('51 lessons in nav', (await page.$$('#lessonNav a')).length === 51);
check('nav has course sections', (await page.textContent('#lessonNav')).includes('Aufbaukurs'));
check('gems panel shows cached chips', (await page.textContent('#gemsList')).includes('chunky_png'));
check('lesson 1 has demo + exercise cells', (await page.$$('#lessonBody .cell')).length === 3);
check('exercise cell has task label', (await page.getAttribute('.cell.exercise', 'data-label')) === 'Aufgabe');

// the keyboard: Tab indents in an editor, Escape then Tab (or Shift+Tab)
// leaves it - no keyboard trap; the editor has a name
const focusIn = () => page.evaluate(() => {
  const a = document.activeElement;
  return a.closest('.CodeMirror') ? 'editor' : a.closest('.cell-toolbar') ? 'toolbar' : a.tagName;
});
check('editors are named for screen readers',
      (await page.evaluate(() => window.cellEditors[1].getInputField().getAttribute('aria-label'))) === 'Code, Zelle 1');
const code1 = await page.evaluate(() => window.cellEditors[1].getValue());
await page.evaluate(() => { window.cellEditors[1].focus(); window.cellEditors[1].setCursor(0, 0); });
await page.keyboard.press('Tab');
check('Tab indents in an editor',
      (await focusIn()) === 'editor' && (await page.evaluate(() => window.cellEditors[1].getValue())) !== code1);
await page.evaluate(c => window.cellEditors[1].setValue(c), code1);
await page.keyboard.press('Escape');
await page.keyboard.press('Tab');
check('Escape, Tab leaves the editor for its toolbar', (await focusIn()) === 'toolbar');
await page.keyboard.press('Shift+Tab');
check('Shift+Tab from the toolbar goes back into the editor', (await focusIn()) === 'editor');
await page.keyboard.press('Escape');
await page.keyboard.press('Shift+Tab');
check('Escape, Shift+Tab leaves the editor backwards', !['editor', 'toolbar'].includes(await focusIn()));

// demo cell shows => value without puts
await page.click('.cell .run-cell');
await page.waitForTimeout(400);
check('demo cell shows => 2', (await page.textContent('#cell-out-1')).includes('=> 2'));

// starter fails the check
await runExercise();
check('starter marked as fail', (await page.getAttribute('#chunkyChat', 'class')).includes('fail'));

// no-puts solution: plain string as last expression
await setExercise('"Hallo, Welt!"');
await runExercise();
check('no-puts solution passes', (await page.getAttribute('#chunkyChat', 'class')).includes('pass'));
check('exercise output shows => "Hallo, Welt!"', (await exerciseOut()).includes('=> "Hallo, Welt!"'));
check('nav shows done tick class', (await page.getAttribute('#lessonNav a:first-of-type', 'class')).includes('done'));

// next-lesson link advances
await page.click('#nextLessonLink');
await page.waitForTimeout(300);
check('advanced to lesson 2', (await page.textContent('#lessonBody')).includes('Taschenrechner'));

// error handling: broken code shows inline error + fail bubble
await setExercise('puts nope_not_defined');
await runExercise();
check('inline NameError shown', (await exerciseOut()).includes('NameError'));
check('error bubble on exercise error', (await page.getAttribute('#chunkyChat', 'class')).includes('fail'));

// solve lesson 2 without puts
await setExercise('6 * 7');
await runExercise();
check('lesson 2 passes without puts', (await page.getAttribute('#chunkyChat', 'class')).includes('pass'));

// lesson 3: cells share one binding (notebook kernel)
await page.click('#lessonNav a[data-id="variablen"]');
await page.waitForTimeout(300);
await page.click('.run-cell[data-idx="1"]');
await page.waitForTimeout(400);
await page.click('.run-cell[data-idx="3"]');
await page.waitForTimeout(400);
check('shared state: menge * 2 => 6', (await page.textContent('#cell-out-3')).includes('=> 6'));

// reset restores starter code
page.on('dialog', d => d.accept());
await page.click('#reset-code');
await page.waitForTimeout(300);
const cell1 = await page.evaluate(() => window.cellEditors[1].getValue());
check('reset restores demo cell code', cell1.includes('essen = "Speck"'));
check('reset hides cell output', !(await page.isVisible('#cell-out-3')));

// lesson 13: gems — the course's own gem from the local cache, then
// chunky_png drawing an image
await page.click('#lessonNav a[data-id="gems"]');
await page.waitForTimeout(300);
await page.click('.run-cell[data-idx="1"]');
await page.waitForTimeout(1500);
check('chunky_bacon installs from cache and Chunky shouts', (await page.textContent('#cell-out-1')).includes('CHUNKY BACON!'));
check('gems panel marks chunky_bacon installed', (await page.textContent('#gemsList')).includes('chunky_bacon ✓'));
check('in the browser the gem keeps the page helpers', await page.evaluate(() => !document.querySelector('#cell-out-1 .cell-error')));
await page.click('.run-cell[data-idx="3"]');
await page.waitForTimeout(1500);
check('gems panel marks chunky_png installed', (await page.textContent('#gemsList')).includes('chunky_png ✓'));
check('demo cell renders a PNG image', await page.isVisible('#cell-out-3 img.cell-image'));
await setExercise('install_gem "chunky_png"\nrequire "chunky_png"\nbild = ChunkyPNG::Image.new(8, 8, ChunkyPNG::Color::WHITE)\n8.times do |y|\n  next unless y.even?\n  8.times { |x| bild[x, y] = ChunkyPNG::Color.rgb(193, 74, 46) }\nend\nshow_image bild');
await runExercise();
check('bacon flag exercise passes', (await page.getAttribute('#chunkyChat', 'class')).includes('pass'));
check('exercise shows the flag image', await page.isVisible('.cell.exercise .cell-out img.cell-image'));
check('a pixel picture is a 160px thumbnail', (await page.$eval('.cell.exercise .cell-out img.cell-image', img => img.offsetWidth)) === 160);
// an SVG (anything with to_data_url) keeps its own size instead
await setExercise(`svg = %(<svg xmlns="http://www.w3.org/2000/svg" width="400" height="60"><rect width="400" height="60" fill="#c14a2e"/></svg>)
show_image Struct.new(:to_data_url).new("data:image/svg+xml;base64," + [svg].pack("m0"))`);
await runExercise();
check('an SVG under a cell keeps its own width', (await page.$eval('.cell.exercise .cell-out img.cell-image', img => img.clientWidth)) === 400);

// lesson 14: HTML parsing with Nokogiri (nokogiri-pure, from the gem cache)
await page.click('#lessonNav a[data-id="html"]');
await page.waitForTimeout(300);
await page.click('.run-cell[data-idx="1"]');
await page.waitForTimeout(3000);
const nokoInstall = await page.textContent('#cell-out-1');
check('nokogiri installs (nokogiri-pure)', nokoInstall.includes('nokogiri 1.19'));
check('installed gem files are not offered as downloads', !nokoInstall.includes('.rb'));
await page.click('.run-cell[data-idx="3"]');
await page.waitForTimeout(6000);
check('nokogiri parses: 3 li elements', (await page.textContent('#cell-out-3')).includes('=> 3'));
await page.click('.run-cell[data-idx="5"]');
await page.waitForTimeout(800);
check('nokogiri css text extraction', (await page.textContent('#cell-out-5')).includes('Speck'));
await setExercise('links = doc.css("a").map { |link| link["href"] }\nlinks');
await runExercise();
check('link extraction exercise passes', (await page.getAttribute('#chunkyChat', 'class')).includes('pass'));

// gems from rubygems.org (via the proxy) that need nokogiri, a gem whose
// load path is not lib/ (concurrent-ruby, via i18n), and a native
// dependency named as the culprit
await page.evaluate(() => window.cellEditors[5].setValue(
  'install_gem "loofah"\nrequire "loofah"\nLoofah.fragment(%(<p>Hi<script>x()</script></p>)).scrub!(:prune).to_s'));
await page.click('.run-cell[data-idx="5"]');
await page.waitForTimeout(8000);
check('loofah (needs nokogiri) installs and sanitizes', (await page.textContent('#cell-out-5')).includes('<p>Hi</p>'));
await page.evaluate(() => window.cellEditors[5].setValue(
  'install_gem "i18n"\nrequire "i18n"\nI18n.backend.store_translations(:de, speck: "Speck!")\nI18n.t(:speck, locale: :de)'));
await page.click('.run-cell[data-idx="5"]');
await page.waitForTimeout(8000);
check('i18n with concurrent-ruby (lib/concurrent-ruby load path)', (await page.textContent('#cell-out-5')).includes('Speck!'));
await page.evaluate(() => window.cellEditors[5].setValue(
  'install_gem "nori"\nrequire "nori"\nrequire "bigdecimal"\n[Nori.new(parser: :nokogiri).parse("<n>1</n>")["n"], BigDecimal("0.1") + BigDecimal("0.2"), BigDecimalPure.pure?]'));
await page.click('.run-cell[data-idx="5"]');
await page.waitForTimeout(8000);
check('bigdecimal dependency resolves to bigdecimal-pure', (await page.textContent('#cell-out-5')).includes('["1", 0.3e0, true]'));
await page.evaluate(() => window.cellEditors[5].setValue('install_gem "jekyll-sass-converter"'));
await page.click('.run-cell[data-idx="5"]');
await page.waitForTimeout(8000);
check('native dependency is named in the error', (await page.textContent('#cell-out-5')).includes('jekyll-sass-converter braucht google-protobuf'));
await page.evaluate(() => window.cellEditors[5].setValue('doc.css("a").map { |link| link.text }'));

// remote gem install through the nginx rubygems proxy
await setExercise('install_gem "paint"');
await runExercise();
check('remote install via proxy works', (await exerciseOut()).includes('paint '));

// modules lesson: namespace demo + mixin exercise
await page.click('#lessonNav a[data-id="module"]');
await page.waitForTimeout(300);
await page.click('.run-cell[data-idx="4"]');
await page.waitForTimeout(600);
check('module namespace demo works', (await page.textContent('#cell-out-4')).includes('=> "Chunky Bacon!"'));
await page.click('.run-cell[data-idx="6"]');
await page.waitForTimeout(600);
check('mixin demo works', (await page.textContent('#cell-out-6')).includes('Hallo, ich bin Isi!'));
await setExercise('module Laut\n  def ruf\n    "CHUNKY BACON!"\n  end\nend\n\nclass Dachs\n  include Laut\nend\n\nDachs.new.ruf');
await runExercise();
check('modules exercise passes', (await page.getAttribute('#chunkyChat', 'class')).includes('pass'));

// IRB lesson: interactive terminal widget
await page.click('#lessonNav a[data-id="irb"]');
await page.waitForTimeout(300);
await page.click('.run-cell[data-idx="1"]');
await page.waitForTimeout(600);
check('irb terminal appears', await page.isVisible('.irb-term'));
const irbType = async (line) => {
  await page.fill('.irb-input', line);
  await page.press('.irb-input', 'Enter');
  await page.waitForTimeout(300);
};
await irbType('6 * 7');
check('irb evaluates 6 * 7', (await page.textContent('.irb-history')).includes('=> 42'));
await irbType('_ + 1');
check('irb underscore holds last result', (await page.textContent('.irb-history')).includes('=> 43'));
await irbType('def verdoppeln(x)');
check('irb continuation prompt with *', (await page.textContent('.irb-prompt')).includes('*'));
await irbType('x * 2');
await irbType('end');
check('irb multi-line def completes', (await page.textContent('.irb-history')).includes('=> :verdoppeln'));
await irbType('verdoppeln(21)');
check('irb calls defined method', (await page.textContent('.irb-history')).includes('=> 42'));
await irbType('puts "Ha"');
check('irb shows stdout and nil', (await page.textContent('.irb-history')).includes('Ha') && (await page.textContent('.irb-history')).includes('=> nil'));
await irbType('exit');
check('irb exit shows playful note', (await page.textContent('.irb-history')).includes('IRB'));
await setExercise('[4, 8, 15].map { |x| x * 3 }');
await runExercise();
check('irb lesson exercise passes', (await page.getAttribute('#chunkyChat', 'class')).includes('pass'));

// lesson: Sinatra — mini browser widget, links, params, exercise
await page.click('#lessonNav a[data-id="sinatra"]');
await page.waitForTimeout(300);
const courseStyle = () => page.evaluate(() => {
  const s = getComputedStyle(document.body);
  return [s.color, s.textAlign, s.fontSize].join(' ');
});
const courseStyleBefore = await courseStyle();
await page.click('.run-cell[data-idx="1"]');
await page.waitForTimeout(8000);
check('sinatra widget renders root page', (await page.textContent('#cell-out-1 .mb-page')).includes('Chunkys Imbiss'));
check('sinatra widget status 200', (await page.textContent('#cell-out-1 .mb-status')).trim() === '200');
await page.click('#cell-out-1 .mb-page a');
await page.waitForTimeout(600);
check('clicking a link navigates the fake browser', (await page.textContent('#cell-out-1 .mb-page')).includes('Speisekarte'));
await page.fill('#cell-out-1 .mb-url', '/hallo/Kaz');
await page.click('#cell-out-1 .mb-go');
await page.waitForTimeout(600);
check('sinatra param route in widget', (await page.textContent('#cell-out-1 .mb-page')).includes('Hallo, Kaz!'));
await page.fill('#cell-out-1 .mb-url', '/pizza');
await page.click('#cell-out-1 .mb-go');
await page.waitForTimeout(600);
check('sinatra 404 in widget', (await page.textContent('#cell-out-1 .mb-status')).trim() === '404');
// Sinatra's 404 page brings <style>body { color:#888; text-align:center; font-size:22px }</style>
check('the 404 page\'s style stays inside the mini browser', (await courseStyle()) === courseStyleBefore);
check('... and still styles the page there (its body rule applies to .mb-page)',
      (await page.$eval('#cell-out-1 .mb-page', el => { const s = getComputedStyle(el); return [s.color, s.textAlign, s.fontSize].join(' '); })) === 'rgb(136, 136, 136) center 22px');
await runExercise();
check('sinatra starter fails (404 on /speck)', (await page.getAttribute('#chunkyChat', 'class')).includes('fail'));
await setExercise('install_gem "sinatra"\nrequire "sinatra/base"\nclass MeineSeite < Sinatra::Base\n  get "/" do\n    "<h1>Meine Seite</h1>"\n  end\n  get "/speck" do\n    "CHUNKY BACON!"\n  end\nend\nshow_browser MeineSeite, "/speck"');
await runExercise();
check('sinatra exercise passes', (await page.getAttribute('#chunkyChat', 'class')).includes('pass'));
check('sinatra exercise widget shows response', (await page.textContent('.cell.exercise .mb-page')).includes('CHUNKY BACON!'));

// lesson 14: Roda — routing tree, string matcher, 404, exercise
await page.click('#lessonNav a[data-id="roda"]');
await page.waitForTimeout(300);
await page.click('.run-cell[data-idx="1"]');
await page.waitForTimeout(6000);
check('roda widget renders root', (await page.textContent('#cell-out-1 .mb-page')).includes('Chunkys Laden'));
await page.fill('#cell-out-1 .mb-url', '/gruss/Ada');
await page.click('#cell-out-1 .mb-go');
await page.waitForTimeout(600);
check('roda string matcher in widget', (await page.textContent('#cell-out-1 .mb-page')).includes('Hallo, Ada!'));
await setExercise('install_gem "roda"\nrequire "roda"\nclass Kiosk < Roda\n  route do |r|\n    r.root do\n      "<h1>Kiosk</h1>"\n    end\n    r.get "bestellung", Integer do |anzahl|\n      "#{anzahl} Streifen Speck, kommt sofort!"\n    end\n  end\nend\nshow_browser Kiosk, "/bestellung/5"');
await runExercise();
check('roda exercise passes', (await page.getAttribute('#chunkyChat', 'class')).includes('pass'));
check('roda exercise widget shows order', (await page.textContent('.cell.exercise .mb-page')).includes('5 Streifen Speck'));

// HTTP lesson: Net::HTTP shim through the browser bridge
await page.click('#lessonNav a[data-id="http"]');
await page.waitForTimeout(300);
await page.click('.run-cell[data-idx="1"]');
await page.waitForTimeout(3000);
check('net/http fetches ruby-lang.org (code 200)', (await page.textContent('#cell-out-1')).includes('=> "200"'));
await page.click('.run-cell[data-idx="3"]');
await page.waitForTimeout(800);
check('response body holds HTML', /DOCTYPE|html/i.test(await page.textContent('#cell-out-3')));
await page.click('.run-cell[data-idx="5"]');
await page.waitForTimeout(2000);
check('rubygems JSON API via proxy', /=> \d{6,}/.test(await page.textContent('#cell-out-5')));
await setExercise('require "net/http"\nrequire "json"\ninfo = JSON.parse(Net::HTTP.get(URI("https://rubygems.org/api/v1/gems/sinatra.json")))\ninfo["downloads"]');
await runExercise();
check('http exercise passes', (await page.getAttribute('#chunkyChat', 'class')).includes('pass'));
await setExercise('require "net/http"\nNet::HTTP.get(URI("https://example.com/"))');
await runExercise();
check('unknown host raises friendly SocketError', (await exerciseOut()).includes('SocketError'));

// 3D lesson: three-rb builds the scene in Ruby, three.js draws it on WebGL
const canvasColors = async (selector) => page.evaluate((sel) => {
  const canvas = document.querySelector(sel);
  if (!canvas) return null;
  const gl = canvas.getContext('webgl2') || canvas.getContext('webgl');
  if (!gl) return null;
  const w = gl.drawingBufferWidth, h = gl.drawingBufferHeight;
  const px = new Uint8Array(w * h * 4);
  gl.readPixels(0, 0, w, h, gl.RGBA, gl.UNSIGNED_BYTE, px);
  const seen = new Set();
  let signature = 0;
  for (let i = 0; i < px.length; i += 4) {
    seen.add((px[i] << 16) | (px[i + 1] << 8) | px[i + 2]);
    signature = (signature + px[i] * (i + 1)) % 2147483647;
  }
  return { distinct: seen.size, signature };
}, selector);

await page.click('#lessonNav a[data-id="three"]');
await page.waitForTimeout(500);
check('three.js module loads for the 3D lesson', await page.evaluate(() => window.ensureThree().then(() => window.threeReady)));
await page.click('.run-cell[data-idx="1"]');
await page.waitForTimeout(6000);
check('three-rb installs from cache', (await page.textContent('#gemsList')).includes('three-rb ✓'));
check('3D stage canvas appears', await page.isVisible('#cell-out-1 .three-stage canvas'));
const still = await canvasColors('#cell-out-1 .three-stage canvas');
check('static scene renders more than the clear color', still !== null && still.distinct > 1);
await page.click('.run-cell[data-idx="3"]');
await page.waitForTimeout(1500);
check('rotated cube still renders', (await canvasColors('#cell-out-3 .three-stage canvas')).distinct > 1);
await page.click('.run-cell[data-idx="5"]');
await page.waitForTimeout(2000);
check('lit sphere renders many shades', (await canvasColors('#cell-out-5 .three-stage canvas')).distinct > 20);
await page.click('.run-cell[data-idx="7"]');
await page.waitForTimeout(1500);
const frameA = await canvasColors('#cell-out-7 .three-stage canvas');
await page.waitForTimeout(1200);
const frameB = await canvasColors('#cell-out-7 .three-stage canvas');
check('animation block keeps redrawing new frames', frameA.signature !== frameB.signature);
await setExercise('turm = Three::Scene.new\nturm.add(Three::AmbientLight.new(0xffffff, 0.4))\nlampe = Three::DirectionalLight.new(0xffffff, 2.0)\nlampe.position.set(2, 4, 3)\nturm.add(lampe)\n\n3.times do |i|\n  klotz = Three::Mesh.new(\n    Three::BoxGeometry.new(1, 1, 1),\n    Three::MeshStandardMaterial.new(color: 0xe8722a)\n  )\n  klotz.position.y = i - 1.0\n  turm.add(klotz)\nend\n\nshow_three turm, kamera do\n  turm.rotation.y += 0.01\nend');
await runExercise();
await page.waitForTimeout(1200);
check('tower exercise passes', (await page.getAttribute('#chunkyChat', 'class')).includes('pass'));
check('tower exercise renders its own stage', (await canvasColors('.cell.exercise .three-stage canvas')).distinct > 1);

// ruby_pptx lesson: the gem runs on REXML in the browser, and files a cell
// saves are offered below it as downloads
const downloadLinks = async (sel) => page.$$eval(`${sel} a.cell-download`, as => as.map(a => ({ name: a.getAttribute('download'), href: a.href })));
const firstBytes = async (href) => page.evaluate(async (h) => Array.from(new Uint8Array(await (await fetch(h)).arrayBuffer())).slice(0, 2), href);
const waitForDownload = async (sel, name) => {
  for (let i = 0; i < 60; i++) {
    const found = (await downloadLinks(sel)).find(l => l.name === name);
    if (found) return found;
    await page.waitForTimeout(500);
  }
  return null;
};
await page.click('#lessonNav a[data-id="pptx"]');
await page.waitForTimeout(300);
await page.click('.run-cell[data-idx="1"]');
const deckLink = await waitForDownload('#cell-out-1', 'chunky.pptx');
check('ruby_pptx installs from cache', (await page.textContent('#gemsList')).includes('ruby_pptx ✓'));
check('saving a deck offers it for download', deckLink !== null);
check('the download is a real .pptx (zip)', deckLink !== null && JSON.stringify(await firstBytes(deckLink.href)) === '[80,75]');
const shapeCell = {};
for (const idx of [5, 7, 9]) {
  await page.click(`.run-cell[data-idx="${idx}"]`);
  shapeCell[idx] = await waitForDownload(`#cell-out-${idx}`, 'chunky.pptx');
}
check('2.cm works after using Pptx::Lengths (shape and chart cells)',
      shapeCell[7] !== null && shapeCell[9] !== null &&
      !(await page.textContent('#cell-out-7')).includes('Error') && !(await page.textContent('#cell-out-9')).includes('Error'));
await page.click('.run-cell[data-idx="11"]');
await page.waitForTimeout(1500);
check('the saved deck reads back slide by slide', (await page.textContent('#cell-out-11')).includes('"Speck pro Tag"'));
await setExercise('download_file "Hallo", "gruss.txt"');
await runExercise();
check('download_file offers data that was never a file', (await downloadLinks('.cell.exercise')).some(l => l.name === 'gruss.txt'));
await setExercise('karte = Pptx::Presentation.new_default\ntitel = karte.slides.add(karte.slide_layouts["Title Slide"])\ntitel.shapes.title.text = "Speisekarte"\n%w[Vorspeisen Hauptgänge].each do |gang|\n  folie = karte.slides.add(karte.slide_layouts["Title and Content"])\n  folie.shapes.title.text = gang\n  folie.placeholders[1].text_frame.text = "Speck\\nEier"\nend\nkarte.save("karte.pptx")');
await runExercise();
await waitForDownload('.cell.exercise', 'karte.pptx');
await page.waitForTimeout(500);
check('menu exercise passes', (await page.getAttribute('#chunkyChat', 'class')).includes('pass'));

// PDF lesson: Prawn writes PDFs, HexaPDF reads, stamps and merges them;
// show_pdf puts the browser's own viewer below the cell
await page.click('#lessonNav a[data-id="pdf"]');
await page.waitForTimeout(300);
await page.click('.run-cell[data-idx="1"]');
await page.waitForSelector('#cell-out-1 iframe.cell-pdf', { timeout: 60000 });
check('prawn installs from cache', (await page.textContent('#gemsList')).includes('prawn ✓'));
const pdfSrc = await page.getAttribute('#cell-out-1 iframe.cell-pdf', 'src');
check('show_pdf shows a real PDF (%P)', JSON.stringify(await firstBytes(pdfSrc.split('#')[0])) === '[37,80]');
await page.click('.run-cell[data-idx="3"]');
check('a PDF the cell wrote is offered for download', (await waitForDownload('#cell-out-3', 'speisekarte.pdf')) !== null);
await page.evaluate(() => { document.getElementById('cell-out-3').innerHTML = ''; });
await page.click('.run-cell[data-idx="3"]');
check('writing the same bytes again still offers the file', (await waitForDownload('#cell-out-3', 'speisekarte.pdf')) !== null);
await page.click('.run-cell[data-idx="5"]');
await page.waitForSelector('#cell-out-5 iframe.cell-pdf', { timeout: 60000 });
check('hexapdf opens and stamps both pages', (await page.textContent('#cell-out-5')).includes('=> 2'));
await page.click('.run-cell[data-idx="7"]');
await page.waitForSelector('#cell-out-7 iframe.cell-pdf', { timeout: 60000 });
check('hexapdf merges into 4 pages', (await page.textContent('#cell-out-7')).includes('=> 4'));
await setExercise('Prawn::Document.generate("urkunde.pdf") do\n  text "Stufe 1"\n  start_new_page\n  text "Stufe 2"\n  start_new_page\n  text "Stufe 3"\nend');
await runExercise();
await waitForDownload('.cell.exercise', 'urkunde.pdf');
await page.waitForTimeout(300);
check('certificate exercise passes', (await page.getAttribute('#chunkyChat', 'class')).includes('pass'));

// JPEG lesson: pure_jpeg writes and reads JPEGs in pure Ruby; show_image
// takes the encoder, the bytes or the name of a file, shown as image/jpeg
await page.click('#lessonNav a[data-id="jpeg"]');
await page.waitForTimeout(300);
await page.click('.run-cell[data-idx="1"]');
await page.waitForSelector('#cell-out-1 img.cell-image', { timeout: 60000 });
check('pure_jpeg installs from cache', (await page.textContent('#gemsList')).includes('pure_jpeg ✓'));
check('show_image shows a JPEG as a JPEG', (await page.getAttribute('#cell-out-1 img.cell-image', 'src')).startsWith('data:image/jpeg;base64,/9j/'));
check('the sunset is 1400 bytes', (await page.textContent('#cell-out-1')).includes('=> 1400'));
await page.click('.run-cell[data-idx="3"]');
await page.waitForFunction(() => document.querySelectorAll('#cell-out-3 img.cell-image').length === 3, null, { timeout: 30000 }).catch(() => {});
check('three qualities, three pictures', (await page.$$('#cell-out-3 img.cell-image')).length === 3 &&
  (await page.textContent('#cell-out-3')).includes('quality 5: 760 Bytes'));
await page.click('.run-cell[data-idx="5"]');
await page.waitForFunction(() => (document.getElementById('cell-out-5').textContent || '').includes('=>'), null, { timeout: 30000 }).catch(() => {});
check('a JPEG reads back pixel by pixel, almost exactly', (await page.textContent('#cell-out-5')).includes('=> [96, 64, 255, 210, 59]'));
await page.click('.run-cell[data-idx="7"]');
await page.waitForFunction(() => (document.getElementById('cell-out-7').textContent || '').includes('=>'), null, { timeout: 30000 }).catch(() => {});
check('show_image takes the name of a file the cell wrote', (await page.$$('#cell-out-7 img.cell-image')).length === 2);
check('the JPEG the cell wrote is offered for download', (await waitForDownload('#cell-out-7', 'sonne-grau.jpg')) !== null);
check('PureJPEG.info finds that file', (await page.textContent('#cell-out-7')).includes('component_count=1'));
await setExercise('karte = PureJPEG::Source::RawSource.new(80, 60) { |x, y| y < 30 ? [100, 160, 230] : [60, 160, 60] }\nPureJPEG.encode(karte).write("postkarte.jpg")');
await runExercise();
await waitForDownload('.cell.exercise', 'postkarte.jpg');
await page.waitForTimeout(300);
check('postcard exercise passes', (await page.getAttribute('#chunkyChat', 'class')).includes('pass'));
await page.evaluate(() => { document.getElementById('chunkyChat').className = ''; });
await runExercise();
await waitForDownload('.cell.exercise', 'postkarte.jpg');
await page.waitForTimeout(300);
check('... and again with the same bytes', (await page.getAttribute('#chunkyChat', 'class')).includes('pass'));

// PyCall lesson: pandas in Pyodide (Python in WebAssembly, ~21 MB, loaded
// when the lesson opens), reached through html/pycall.rb with PyCall's API;
// a run started while Python loads waits for it (shell/bridge.js)
await page.click('#lessonNav a[data-id="pycall"]');
await page.waitForTimeout(300);
check('opening the lesson starts loading Python', await page.evaluate(() => !!(window.chunkyPython.loading || window.chunkyPython.ready)));
const pyCell = async (idx, timeout = 30000) => {
  await page.click(`.run-cell[data-idx="${idx}"]`);
  await page.waitForFunction(i => !document.querySelector(`.run-cell[data-idx="${i}"]`).disabled &&
    document.getElementById('cell-out-' + i).style.display !== 'none', idx, { timeout }).catch(() => {});
  return (await page.textContent(`#cell-out-${idx}`)) || '';
};
check('a run waits for Python, then PyCall imports pandas', (await pyCell(1, 120000)).includes('=> "3.0.2"'));
check('the Python -> Ruby cheat sheet is a table', (await page.$$('.lessonText table.cheat tbody tr')).length === 6);
await pyCell(3);
check('a DataFrame shows as pandas\' table', (await page.$$('#cell-out-3 table.dataframe')).length === 1);
check('a single column is a Series', (await pyCell(5)).includes('Name: preis'));
await pyCell(7);
check('keyword arguments reach Python (sorted, highest first)',
  (await page.textContent('#cell-out-7 tbody tr:first-child')).includes('Kaffee'));
const pyNumbers = await pyCell(9);
check('a Python float comes back as a Ruby Float', pyNumbers.includes('Gesamt: 30.0 Fr.') && pyNumbers.includes('=> Float'));
check('a comparison is a Series of True and False', (await pyCell(11)).includes('True'));
await pyCell(13);
check('the mask picks the rows', (await page.$$('#cell-out-13 table.dataframe tbody tr')).length === 2);
check('tolist.to_a gives a Ruby array', (await pyCell(15)).includes('=> ["Speck", "Kaffee"]'));
check('value_counts counts', (await pyCell(17)).includes('Speck     3'));
check('groupby counts per table', /1\s+3/.test(await pyCell(19)));
await page.evaluate(() => window.cellEditors[19].setValue('pd.DataFrame.new({ "a" => [1] })["nope"]'));
check('a Python exception is a PyCall::PyError', (await pyCell(19)).includes('PyCall::PyError: KeyError'));
await setExercise('require "pycall"\npd = PyCall.import_module("pandas")\nrechnung = pd.DataFrame.new({ "gast" => ["Kaz", "Isi", "Kaz", "Isi", "Kaz"], "preis" => [4.5, 2.0, 3.0, 4.5, 3.5] })\nausgaben = rechnung.groupby("gast")["preis"].sum.to_dict.to_h');
await runExercise();
await page.waitForTimeout(800);
check('spending exercise passes', (await page.getAttribute('#chunkyChat', 'class')).includes('pass'));

// SymPy lesson: the same bridge; opening it loads sympy (+ mpmath, ~5 MB)
// on top of the Pyodide that is already there
await page.click('#lessonNav a[data-id="sympy"]');
await page.waitForTimeout(300);
const exact = await pyCell(1, 120000);
check('a float is rounded, a Rational is exact', exact.includes('0.30000000000000004') && exact.includes('=> 3/10'));
check('opening the lesson loaded sympy', await page.evaluate(() => !!window.chunkyPython.packages.sympy));
const roots = await pyCell(3);
check('square roots stay exact, evalf gives 50 digits', roots.includes('2*sqrt(2)') && roots.includes('1.4142135623730950488016887242096980785696718753769'));
const algebra = await pyCell(5);
check('expand and factor', algebra.includes('x**2 + 2*x + 1') && algebra.includes('(x - 3)*(x + 3)'));
const pretty = await pyCell(7);
check('pretty draws, and 3 * x coerces', pretty.includes('-----') && pretty.includes('3*x') && pretty.includes('\\/'));
check('solve finds both roots', (await pyCell(9)).includes('=> [2, 3]'));
check('subs puts numbers in', (await pyCell(11)).includes('=> [0, 0, 2]'));
check('diff', (await pyCell(13)).includes('3*x**2 + 2'));
await page.evaluate(() => window.cellEditors[13].setValue('[sp.Rational.new(1, 2) == sp.Rational.new(2, 4), sp.Rational.new(1, 2) == sp.Rational.new(1, 3)]'));
check('== is Python\'s, between two handles too', (await pyCell(13)).includes('=> [true, false]'));
await setExercise('require "pycall"\nsp = PyCall.import_module("sympy")\nx = sp.symbols("x")\nkurve = x ** 3 - 6 * x ** 2 + 9 * x\nflach = sp.solve(sp.diff(kurve, x), x)');
await runExercise();
await page.waitForTimeout(800);
check('flat-curve exercise passes', (await page.getAttribute('#chunkyChat', 'class')).includes('pass'));

// NumPy lesson: numpy is already there (pandas brought it)
await page.click('#lessonNav a[data-id="numpy"]');
await page.waitForTimeout(300);
check('an array computes as a whole', (await pyCell(1, 120000)).includes('=> array([54.5, 59. , 49.1, 69.8, 65.3])'));
const stats = await pyCell(3);
check('mean, max, argmax come back as Ruby numbers', stats.includes('15.3') && stats.includes('21.0') && stats.includes('=> 3'));
check('a mask picks values', (await pyCell(5)).includes('=> array([21. , 18.5])'));
check('arange and linspace', (await pyCell(7)).includes('81 100]'));
const grid = await pyCell(9);
check('reshape, shape (a tuple, so a Ruby Array), sum along an axis', grid.includes('shape: [3, 4]') && grid.includes('array([12, 15, 18, 21])'));
check('seeded dice: the same counts every time', (await pyCell(11)).includes('array([   0, 1009, 1013,  998,  993,  984, 1003])'));
check('tolist.to_a, then Ruby again', (await pyCell(13)).includes('=> [13, 15, 10, 21, 19]'));
await setExercise('require "pycall"\nnp = PyCall.import_module("numpy")\npunkte = np.array([55, 72, 61, 48, 90, 67, 59])\nbestanden = (punkte >= 60).sum');
await runExercise();
await page.waitForTimeout(800);
check('passed-count exercise passes', (await page.getAttribute('#chunkyChat', 'class')).includes('pass'));

// matplotlib lesson: opening it loads matplotlib (~9 MB) and imports pyplot
// ahead, step by step (index.html: warmMatplotlib); plt.show() puts the chart
// under the cell as an SVG (pycall.rb's backend)
await page.click('#lessonNav a[data-id="matplotlib"]');
await page.waitForTimeout(300);
await page.waitForFunction(() => window.chunkyPython.warm, null, { timeout: 180000 }).catch(() => {});
check('opening the lesson loaded matplotlib and imported pyplot ahead',
      await page.evaluate(() => !!window.chunkyPython.packages.matplotlib && window.chunkyPython.warm === true));
const charts = idx => page.$$eval(`#cell-out-${idx} img.cell-image`, imgs => imgs.map(img => ({
  svg: img.src.startsWith('data:image/svg+xml;base64,') ? new TextDecoder().decode(Uint8Array.from(atob(img.src.split(',')[1]), c => c.charCodeAt(0))) : '',
  width: img.getBoundingClientRect().width
})));
const chartText = async idx => (await charts(idx)).map(c => c.svg).join('\n');
await pyCell(1, 120000);
let drawn = await charts(1);
check('plt.show draws the chart as an SVG under the cell, its text as text',
      drawn.length === 1 && drawn[0].svg.includes('<svg') && drawn[0].svg.includes('Eine Woche Wetter'));
check('the chart keeps its own size (not a 160px thumbnail)', drawn.length === 1 && drawn[0].width > 300);
await pyCell(1);
check('a second run draws it once', (await charts(1)).length === 1);
await pyCell(3);
check('a bar chart with a y label', (await chartText(3)).includes('verkaufte Glaces'));
await pyCell(5);
check('fig, ax = plt.subplots unpacks (a tuple is a Ruby Array)', (await chartText(5)).includes('Temperatur'));
await pyCell(7);
const curves = await chartText(7);
check('two curves from NumPy, with a legend', curves.includes('>sin<') && curves.includes('>cos<'));
await pyCell(9);
const panels = await chartText(9);
const weather = await waitForDownload('#cell-out-9', 'wetter.png');
check('two panels side by side, from axes[0] and axes[1]', panels.includes('Glaces je Temperatur') && panels.includes('Temperatur'));
check('plt.savefig offers the PNG below the cell', !!weather && (await firstBytes(weather.href)).join(',') === '137,80');
const pyEval = async code => {
  await page.evaluate(c => window.cellEditors[9].setValue(c), code);
  return pyCell(9);
};
check('plt.subplots is an Array of two, as with the gem', (await pyEval('pair = plt.subplots\n[pair.class, pair.size]')).includes('=> [Array, 2]'));
check('fig, (a, b) does not unpack the axes - a NumPy array, as with the gem',
      (await pyEval('fig, (a, b) = plt.subplots(1, 2)\n[b.nil?, a.shape]')).includes('=> [true, [2]]'));
check('a figure not shown is closed after the run', (await pyEval('plt.bar(["x"], [1])\nplt.get_fignums.to_a')).includes('=> [1]') &&
      (await pyEval('plt.get_fignums.to_a')).includes('=> []'));
await pyEval('fig, ax = plt.subplots\nax.bar(["a", "b"], [3, 4])\nax.set_title("nur eines")\nshow_plot fig\nplt.show');
check('show_plot shows one figure, which is closed then', (await charts(9)).length === 1 && (await chartText(9)).includes('nur eines'));
await pyEval('plt.plot([1, 2, 3])\nplt.title("1週間の天気")\nplt.show');
check('Japanese text in a chart stays text in the SVG', (await chartText(9)).includes('1週間の天気'));
check('a matplotlib error is a PyCall::PyError', (await pyEval('plt.plot([1, 2], [1, 2, 3])')).includes('PyCall::PyError: ValueError'));
await runExercise();
await page.waitForTimeout(800);
check('matplotlib starter fails', (await page.getAttribute('#chunkyChat', 'class')).includes('fail'));
await setExercise('require "pycall"\nplt = PyCall.import_module("matplotlib.pyplot")\ntage = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]\nmaeuse = [3, 5, 2, 6, 4, 7, 1]\nfig, ax = plt.subplots\nax.bar(tage, maeuse)\nax.set_title("Fuchs-Jagd")\nplt.show');
await runExercise();
await page.waitForTimeout(800);
check('fox-hunt bar chart exercise passes', (await page.getAttribute('#chunkyChat', 'class')).includes('pass'));
await setExercise('require "pycall"\nplt = PyCall.import_module("matplotlib.pyplot")\ntage = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]\nmaeuse = [3, 5, 2, 6, 4, 7, 1]\nplt.plot(tage, maeuse)\nplt.title("Fuchs-Jagd")\nplt.show');
await runExercise();
await page.waitForTimeout(800);
check('a line chart with the title does not pass', (await page.getAttribute('#chunkyChat', 'class')).includes('fail'));

// scikit-learn lesson: opening it loads scikit-learn and SciPy (~19 MB)
await page.click('#lessonNav a[data-id="sklearn"]');
await page.waitForTimeout(300);
check('a linear regression predicts', (await pyCell(1, 180000)).includes('=> array([55.725])'));
check('opening the lesson loaded scikit-learn', await page.evaluate(() => !!window.chunkyPython.packages['scikit-learn']));
const line = await pyCell(3);
check('coef_ and intercept_', line.includes('Glaces pro Grad: 3.18') && line.includes('-23.65'));
check('the tree prints what it learned', (await pyCell(5)).includes('ohren <= 8.00'));
check('the tree judges new animals', (await pyCell(7)).includes('=> ["Katze", "Fuchs", "Katze"]'));
check('iris comes with scikit-learn', (await pyCell(9)).includes('=> [150, 4]'));
check('tested on hidden flowers', (await pyCell(11)).includes('=> 0.955'));
await setExercise('require "pycall"\nlm = PyCall.import_module("sklearn.linear_model")\nstunden = [[1], [2], [3], [4], [5]]\npunkte = [52, 59, 66, 73, 80]\nmodell = lm.LinearRegression.new\nmodell.fit(stunden, punkte)\nprognose = modell.predict([[6]])[0]');
await runExercise();
await page.waitForTimeout(800);
check('forecast exercise passes', (await page.getAttribute('#chunkyChat', 'class')).includes('pass'));

// Rumale lesson: pure Ruby on a pure-Ruby Numo (numo_narray.rb), digits.csv
// next to the code, and a letter to write a postcode on (letter.js)
await page.click('#lessonNav a[data-id="rumale"]');
await page.waitForTimeout(300);
const rumaleCell = async (idx) => {
  await page.click(`.run-cell[data-idx="${idx}"]`, { noWaitAfter: true });
  await page.waitForFunction(i => !document.querySelector(`.run-cell[data-idx="${i}"]`).disabled &&
    document.getElementById('cell-out-' + i).style.display !== 'none', idx, { timeout: 120000 }).catch(() => {});
  return (await page.textContent(`#cell-out-${idx}`)) || '';
};
check('Rumale installs on the Numo stand-in', (await rumaleCell(1)).includes('=> [9, 2]'));
check('nearest neighbours judge vegetables', (await rumaleCell(3)).includes('=> ["Gurke", "Tomate", "Rüebli"]'));
check('digits.csv lies next to the code', (await rumaleCell(5)).includes('=> [1797, 64]'));
check('a digit drawn with characters', (await rumaleCell(7)).includes('=> 0'));
check('48 of 50 hidden digits', (await rumaleCell(9)).includes('=> 0.96'));
await rumaleCell(11);
check('show_letter draws an envelope', await page.isVisible('#cell-out-11 .letter-canvas'));
// a 3, then three 0s, as pen strokes in the letter's coordinates (box i at x = 52 + 64 i)
const ring = (x0) => Array.from({ length: 21 }, (_, k) => {
  const a = -Math.PI / 2 + k * 2 * Math.PI / 20;
  return [x0 + 27 + 12 * Math.cos(a), 202 + 25 * Math.sin(a)];
});
const three = Array.from({ length: 21 }, (_, k) => {
  const a = k < 11 ? -2.6 + k * 0.42 : -1.6 + (k - 10) * 0.42;
  return k < 11 ? [79 + 12 * Math.cos(a), 190 + 12 * Math.sin(a)] : [79 + 14 * Math.cos(a), 215 + 13 * Math.sin(a)];
});
await page.evaluate(strokes => document.querySelector('#cell-out-11 .letter-widget').chunkyLetter.draw(strokes),
                    [three, ring(116), ring(180), ring(244)]);
await page.waitForFunction(() => document.querySelector('#cell-out-11 .letter-widget').getAttribute('data-answer'), null, { timeout: 30000 }).catch(() => {});
check('the letter reads the postcode', (await page.getAttribute('#cell-out-11 .letter-widget', 'data-answer')) === '3000 Bern');
await setExercise('sieben = <<~BILD\n  .######.\n  ......#.\n  .....#..\n  ....#...\n  ...#....\n  ...#....\n  ..#.....\n  ..#.....\nBILD\npixel = sieben.delete("\\n").chars.map { |z| z == "#" ? 16 : 0 }\nziffer = lerner.predict(Numo::DFloat[pixel])[0]');
await runExercise();
await page.waitForTimeout(800);
check('the seven exercise passes', (await page.getAttribute('#chunkyChat', 'class')).includes('pass'));

// Sequel lesson: the real Sequel gem on the sqlite3 stand-in
// (sqlite3_sqljs.rb over sql.js, loaded when the lesson opens)
await page.click('#lessonNav a[data-id="sequel"]');
await page.waitForTimeout(300);
check('opening the lesson starts loading SQLite', await page.evaluate(() => !!(window.chunkySqlite.loading || window.chunkySqlite.ready)));
check('Sequel creates a table', (await pyCell(1, 60000)).includes('=> [:eintraege]'));
check('insert adds rows', (await pyCell(3)).includes('=> 4'));
const rows = await pyCell(5);
check('dates, booleans and floats come back as Ruby values',
  rows.includes('2026-10-05  Chunky  2.5 h Fr.') && rows.includes('=> [Hash, Date, TrueClass]'));
const chained = await pyCell(7);
check('a dataset shows its SQL', chained.includes("SELECT * FROM `eintraege` WHERE (`projekt` = 'Chunky') ORDER BY `tag`") && chained.includes('=> [2.5, 3.0]'));
const counted = await pyCell(9);
check('where with a block, sum, group_and_count', counted.includes('7.0') && counted.includes('{projekt: "Speck", count: 1}'));
check('a timesheet in one query', (await pyCell(11)).includes('{projekt: "Chunky", total: 5.5}'));
check('update and delete', (await pyCell(13)).includes('=> ["Chunky", "Bacon", "Chunky"]'));
check('a model with its own method (create runs in a transaction)', (await pyCell(15)).includes('"2026-10-07: 1.5 h für Speck"'));
check('NOT NULL becomes Sequel::NotNullConstraintViolation', (await pyCell(17)).includes('Abgelehnt: Sequel::NotNullConstraintViolation'));
await page.evaluate(() => window.cellEditors[17].setValue('DB.create_table(:leute) { String :mail, unique: true }\nDB[:leute].insert(mail: "a@b.c")\nbegin\n  DB[:leute].insert(mail: "a@b.c")\nrescue Sequel::UniqueConstraintViolation => e\n  puts e.class\nend\nDB.transaction { DB[:leute].insert(mail: "x@y.z"); raise Sequel::Rollback }\n[DB[:leute].count, DB.get(Sequel.lit("?", 2**40))]'));
const guarded = await pyCell(17);
check('UNIQUE, a rollback, and big integers stay exact', guarded.includes('Sequel::UniqueConstraintViolation') && guarded.includes('=> [1, 1099511627776]'));
// a database in a file: kept across runs, offered as a real SQLite file
check('a database in a file is created', /=> 1(?!\d)/.test(await pyCell(19)));
check('... and keeps its rows for the next run', /=> 2(?!\d)/.test(await pyCell(19)));
const dbLink = await waitForDownload('#cell-out-19', 'zeiterfassung.db');
const dbHead = dbLink && await page.evaluate(async h => String.fromCharCode(...new Uint8Array(await (await fetch(h)).arrayBuffer()).slice(0, 15)), dbLink.href);
check('... offered as a download that is a SQLite file', dbHead === 'SQLite format 3');
await page.evaluate(() => window.cellEditors[17].setValue('class Arbeit < Sequel::Model(zeiterfassung[:eintraege]); end\na = Arbeit.first\na.stunden = 0.25\na.save'));
await pyCell(17);
await page.evaluate(() => window.cellEditors[17].setValue('zeiterfassung.run("BEGIN")\nzeiterfassung[:eintraege].insert(projekt: "Halb", stunden: 9)'));
await pyCell(17);
await page.evaluate(() => window.cellEditors[19].setValue('Sequel.sqlite("zeiterfassung.db")[:eintraege].map(:stunden)'));
check('a model saves into the file; an open transaction is not saved half-way', (await pyCell(19)).includes('=> [0.25, 1.5]'));
// a write that failed (its folder is missing) is tried again after the next run
await page.evaluate(() => window.cellEditors[17].setValue('nachher = SQLite3::Database.new("/chunky_nachher/nachher.db")\nnachher.execute("CREATE TABLE t (x INTEGER)")\nnachher.execute("INSERT INTO t VALUES (7)")\nDir.exist?("/chunky_nachher")'));
await pyCell(17);
await page.evaluate(() => window.cellEditors[17].setValue('Dir.mkdir("/chunky_nachher")'));
await pyCell(17);
await page.evaluate(() => window.cellEditors[17].setValue('SQLite3::Database.new("/chunky_nachher/nachher.db").execute("SELECT x FROM t")'));
check('a database whose file could not be written is saved on a later run', (await pyCell(17)).includes('=> [[7]]'));
await setExercise('install_gem "sequel"\nrequire "sequel"\nzeit = Sequel.sqlite\nzeit.create_table(:arbeit) do\n  primary_key :id\n  String :projekt\n  Float  :stunden\nend\nzeit[:arbeit].import([:projekt, :stunden], [["Chunky", 2.5], ["Speck", 0.5], ["Bacon", 1.5], ["Chunky", 3.0], ["Speck", 1.5]])\nstunden_pro_projekt = zeit[:arbeit].group(:projekt).select(:projekt) { sum(:stunden).as(:total) }.as_hash(:projekt, :total)');
await runExercise();
await page.waitForTimeout(800);
check('hours-per-project exercise passes', (await page.getAttribute('#chunkyChat', 'class')).includes('pass'));

// RubyKaigi lesson: weird but valid Ruby, and Prism (a C extension built
// into the wasm) splitting and parsing code the way IRB reads it
await page.click('#lessonNav a[data-id="rubykaigi"]');
await page.waitForTimeout(300);
const ranCell = async (idx) => {
  await page.click(`.run-cell[data-idx="${idx}"]`);
  await page.waitForFunction(i => !document.querySelector(`.run-cell[data-idx="${i}"]`).disabled &&
    document.getElementById('cell-out-' + i).style.display !== 'none', idx, { timeout: 30000 }).catch(() => {});
  return (await page.textContent(`#cell-out-${idx}`)) || '';
};
check('%%% and friends are valid Ruby', (await ranCell(2)).includes('"RubyKaigi 2024"'));
check('emoji names and two heredocs on a line', (await ranCell(4)).includes('Chunky liebt Speck') &&
  (await page.textContent('#cell-out-4')).includes('"Erste Zeile\\nZweite Zeile\\n"'));
check('a regexp finds the primes', (await ranCell(6)).includes('[2, 3, 5, 7, 11, 13, 17, 19, 23, 29]'));
check('+= on a constant makes a second one', (await ranCell(8)).includes('["Chunky", "Chunky Bacon"]'));
check('Prism splits code into tokens', (await ranCell(11)).includes('[:IDENTIFIER, :INTEGER, :STAR, :INTEGER, :EOF]'));
const parsed = await ranCell(13);
check('Prism tells finished code from unfinished', parsed.includes('["def fuchs\\nend", true]') && parsed.includes('["def fuchs", false]'));
check('... and says what is missing', parsed.includes('expected an `end` to close the `def` statement'));
await setExercise('require "prism"\ndef eingaben(zeilen)\n  fertig = []\n  puffer = []\n  zeilen.each do |zeile|\n    puffer << zeile\n    code = puffer.join("\\n")\n    if Prism.parse(code).success?\n      fertig << code\n      puffer = []\n    end\n  end\n  fertig\nend');
await runExercise();
await page.waitForTimeout(300);
check('line collector exercise passes', (await page.getAttribute('#chunkyChat', 'class')).includes('pass'));

// TTY lesson: pastel's ANSI colours become spans (ansi.rb), tty-table and
// tty-box draw with box-drawing characters as wide as the code font's
// letters (chunky-box-drawing.woff), so their lines meet
await page.click('#lessonNav a[data-id="tty"]');
await page.waitForTimeout(500);
const runAndWait = async idx => {
  await page.click(`.run-cell[data-idx="${idx}"]`);
  await page.waitForFunction(i => !document.querySelector(`.run-cell[data-idx="${i}"]`).disabled &&
    (document.getElementById(`cell-out-${i}`).textContent || '').trim(), idx, { timeout: 60000 });
};
await runAndWait(1);
check('pastel installs from cache', (await page.textContent('#gemsList')).includes('pastel ✓'));
check('ANSI green becomes a green span', (await page.textContent('#cell-out-1 .cell-stdout .ansi-fg-2')) === '12 Tests, 0 Fehler');
check('red and bold together', (await page.$$('#cell-out-1 .ansi-fg-1.ansi-bold')).length === 1);
check('the result shows the escape codes themselves', (await page.textContent('#cell-out-1 .cell-result')).includes('\\e[31mSpeck\\e[0m'));
await runAndWait(3);
check('tty-table draws a unicode table', (await page.textContent('#cell-out-3')).includes('│ Brezel │   2.0 │     30 │'));
check('box drawing is as wide as letters', await page.evaluate(() => {
  const width = text => {
    const span = document.createElement('span');
    span.textContent = text;
    document.querySelector('#cell-out-3 .cell-stdout').appendChild(span);
    const w = span.getBoundingClientRect().width;
    span.remove();
    return w;
  };
  return Math.abs(width('┌──┬─┐│═╔█░') - width('abcdefghijk')) < 0.5;
}));
await runAndWait(5);
check('tty-box frames with a title', (await page.textContent('#cell-out-5')).includes('┌ Kiosk ─'));
await runAndWait(7);
check('tty-tree draws the project', (await page.textContent('#cell-out-7')).includes('└── test'));
await runExercise();
check('tty starter fails', (await page.getAttribute('#chunkyChat', 'class')).includes('fail'));
await setExercise('puts TTY::Table.new(header: ["Artikel", "Menge"], rows: [["Speck", 3], ["Brezel", 2]]).render(:unicode)');
await runExercise(); await page.waitForTimeout(300);
check('tty exercise passes', (await page.getAttribute('#chunkyChat', 'class')).includes('pass'));

// Processing lesson: the processing gem's API on processing.rb, each frame
// painted by processing.js; the sketch keeps running and hears the mouse
await page.click('#lessonNav a[data-id="processing"]');
await page.waitForTimeout(500);
const runSketch = async idx => {
  await page.click(`.run-cell[data-idx="${idx}"]`);
  await page.waitForFunction(i => !document.querySelector(`.run-cell[data-idx="${i}"]`).disabled &&
    document.querySelector(`#cell-out-${i} .sketch-stage, #cell-out-${i} .cell-error`), idx, { timeout: 60000 }).catch(() => {});
  await page.locator(`#cell-out-${idx}`).scrollIntoViewIfNeeded();   // out of view, a sketch rests
};
const sketchPixel = (idx, x, y) => page.evaluate(([i, px, py]) =>
  document.querySelector(`#cell-out-${i} .sketch-stage`).chunkySketch.pixel(px, py), [idx, x, y]);
const near = (got, want) => Array.isArray(got) && want.every((v, k) => Math.abs(got[k] - v) <= 6);
const sketchFrames = async idx => Number(await page.getAttribute(`#cell-out-${idx} .sketch-stage`, 'data-frames'));
await runSketch(1);
check('a sketch opens at the size it asks for', await page.evaluate(() => {
  const canvas = document.querySelector('#cell-out-1 .sketch-canvas');
  return Boolean(canvas) && canvas.style.width === '400px' && canvas.style.aspectRatio === '400 / 300';
}));
check('the sketch paints its background and an orange circle',
      near(await sketchPixel(1, 10, 10), [250, 240, 220]) && near(await sketchPixel(1, 200, 130), [230, 120, 40]));
check('a sketch shows no => line', !(await page.$('#cell-out-1 .cell-result')));
await runSketch(3);
const framesBefore = await sketchFrames(3);
await page.waitForTimeout(600);
check('draw runs again and again', (await sketchFrames(3)) > framesBefore + 10);
await runSketch(5);
const box = await (await page.$('#cell-out-5 .sketch-canvas')).boundingBox();
await page.mouse.move(box.x + 100 * box.width / 400, box.y + 80 * box.height / 300);
await page.waitForTimeout(300);
check('the circle follows the mouse', near(await sketchPixel(5, 100, 80), [255, 160, 0]));
await page.mouse.down();
await page.waitForTimeout(300);
check('mousePressed turns it red', near(await sketchPixel(5, 100, 80), [255, 80, 80]));
await page.mouse.up();
await runSketch(7);
check('push, rotate and HSB colours draw a flower', await page.evaluate(() => {
  const sketch = document.querySelector('#cell-out-7 .sketch-stage').chunkySketch;
  const [r, g, b] = sketch.pixel(200, 150);
  const hues = new Set();
  for (let k = 0; k < 72; k++) {
    const [pr, pg, pb] = sketch.pixel(200 + 80 * Math.cos(k * Math.PI / 36), 150 + 80 * Math.sin(k * Math.PI / 36));
    if (Math.max(pr, pg, pb) - Math.min(pr, pg, pb) > 100) hues.add(`${pr >> 6}${pg >> 6}${pb >> 6}`);
  }
  return r < 40 && g < 40 && b < 40 && hues.size >= 6;
}));
await runSketch(9);
const bubbleBox = await (await page.$('#cell-out-9 .sketch-canvas')).boundingBox();
await page.mouse.click(bubbleBox.x + 200 * bubbleBox.width / 400, bubbleBox.y + 280 * bubbleBox.height / 300);
await page.waitForTimeout(200);
check('a click starts a bubble', await page.evaluate(() => {
  const sketch = document.querySelector('#cell-out-9 .sketch-stage').chunkySketch;
  for (let y = 200; y < 300; y += 2) for (let x = 150; x < 250; x += 2) {
    const [r, g, b] = sketch.pixel(x, y);
    if (r > 80 && b > 150) return true;
  }
  return false;
}));
await runSketch(9);
check('a re-run replaces the sketch', (await page.$$('#cell-out-9 .sketch-stage')).length === 1);
await runExercise();
check('processing starter fails', (await page.getAttribute('#chunkyChat', 'class')).includes('fail'));
const sketchIdx = await exerciseIdx();
await page.locator(`#cell-out-${sketchIdx}`).scrollIntoViewIfNeeded();
await setExercise('require "processing"\nusing Processing\nsetup do\n  size 400, 300\nend\ndraw do\n  raise "Kaputt im Bild #{frameCount}" if frameCount == 3\nend');
await runExercise();
await page.waitForFunction(i => document.querySelector(`#cell-out-${i} .sketch-stage`)?.getAttribute('data-error'), sketchIdx, { timeout: 10000 }).catch(() => {});
check('an error in a later frame stops the sketch and says so',
      (await page.getAttribute(`#cell-out-${sketchIdx} .sketch-stage`, 'data-error')) === 'RuntimeError: Kaputt im Bild 3');
await setExercise('require "processing"\nusing Processing\nsetup do\n  size 400, 300\n  background 255\n  strokeWeight 4\nend\ndraw do\n  line pmouseX, pmouseY, mouseX, mouseY if mousePressed\nend');
await runExercise(); await page.waitForTimeout(300);
check('processing exercise passes', (await page.getAttribute('#chunkyChat', 'class')).includes('pass'));
await page.locator(`#cell-out-${sketchIdx}`).scrollIntoViewIfNeeded();
const paintBox = await (await page.$(`#cell-out-${sketchIdx} .sketch-canvas`)).boundingBox();
const at = (x, y) => [paintBox.x + x * paintBox.width / 400, paintBox.y + y * paintBox.height / 300];
await page.mouse.move(...at(50, 150));
await page.waitForTimeout(100);
await page.mouse.down();
for (let x = 60; x <= 350; x += 10) { await page.mouse.move(...at(x, 150)); await page.waitForTimeout(20); }
await page.mouse.up();
await page.waitForTimeout(200);
check('... and paints with the mouse after the check', near(await sketchPixel(sketchIdx, 200, 150), [0, 0, 0]) &&
      near(await sketchPixel(sketchIdx, 200, 100), [255, 255, 255]));

// Faker lesson: faker, i18n and concurrent-ruby from the cache; the first
// lookup reads 318 YAML files (seconds), which a live run leaves to ▶
await page.click('#lessonNav a[data-id="faker"]');
await page.waitForTimeout(500);
await page.evaluate(() => {
  const cm = window.cellEditors[1];
  cm.replaceRange(cm.getValue() + '\n', { line: 0, ch: 0 }, { line: cm.lineCount(), ch: 0 }, '+input');
});
await page.waitForFunction(() => (document.getElementById('cell-out-1').textContent || '').includes('▶'), null, { timeout: 60000 }).catch(() => {});
check('a live run leaves the dictionaries to ▶', (await page.textContent('#cell-out-1')).includes('ihre Daten zum ersten Mal lesen'));
await runAndWait(1);
check('faker installs from cache', (await page.textContent('#gemsList')).includes('faker ✓'));
check('Faker makes up a name, an email and a sentence', await page.evaluate(() => {
  const lines = document.querySelector('#cell-out-1 .cell-stdout').textContent.trim().split('\n');
  return lines.length === 4 && lines[1].includes('@') && /=> ".+\."/.test(document.querySelector('#cell-out-1 .cell-result').textContent);
}));
await runAndWait(3);
check('the same seed, the same names', (await page.textContent('#cell-out-3')).endsWith('true]'));
await runAndWait(5);
check('Swiss names and postcodes', /\n\d{4} \S/.test(await page.textContent('#cell-out-5 .cell-stdout')));
await runAndWait(7);
await runAndWait(7);
check('unique throws each number once, again after clear', await page.evaluate(() => {
  const m = /=> \[([\d, ]+)\]/.exec(document.getElementById('cell-out-7').textContent);
  return Boolean(m) && m[1].split(', ').map(Number).sort().join() === '1,2,3,4,5,6';
}));
await runAndWait(9);
check('test data for timelog', /\d h\n/.test(await page.textContent('#cell-out-9 .cell-stdout')));
await runExercise();
check('faker starter fails', (await page.getAttribute('#chunkyChat', 'class')).includes('fail'));
await setExercise('Faker::Config.random = Random.new(2024)\nkunden = 5.times.map { { name: Faker::Name.name, email: Faker::Internet.email } }');
await runExercise(); await page.waitForTimeout(300);
check('faker exercise passes', (await page.getAttribute('#chunkyChat', 'class')).includes('pass'));

// ERB lesson: ERB from the standard library, a page in the mini browser;
// then Herb - the gem from the cache, its C parser as WebAssembly
// (herb_bridge.rb, assets/herb/), loaded when the lesson opens
await page.click('#lessonNav a[data-id="erb"]');
await page.waitForTimeout(500);
await runAndWait(1);
check('ERB fills a template from a hash', (await page.textContent('#cell-out-1')).includes('Hallo Chunky, hier sind 3 Streifen Speck.'));
await runAndWait(3);
check('a loop with trim mode leaves no empty lines',
      (await page.textContent('#cell-out-3 .cell-stdout')).startsWith('Einkaufszettel:\n- 3 x Speck\n- 2 x Brezel\n'));
await runAndWait(5);
check('ERB::Util.h escapes a script',
      (await page.textContent('#cell-out-5 .cell-stdout')).includes('<p>&lt;script&gt;alert(&#39;Aller Speck'));
await runAndWait(7);
check('an ERB page in the mini browser', (await page.textContent('#cell-out-7 .mb-page')).includes('Brezel: 2.00 Fr.'));
await page.waitForFunction(() => window.chunkyHerb && window.chunkyHerb.ready, null, { timeout: 60000 }).catch(() => {});
check('Herb\'s parser loads when the lesson opens', await page.evaluate(() => window.chunkyHerb.ready === true));
await runAndWait(9);
const herbOut = await page.textContent('#cell-out-9');
check('herb installs from the cache', (await page.textContent('#gemsList')).includes('herb ✓'));
check('ERB renders the broken template, Herb finds both mistakes',
      herbOut.includes('<div>Chunky</span>') && herbOut.includes("Opening tag `<div>` at (1:1) doesn't have a matching closing tag") &&
      herbOut.includes('Found closing tag `</span>`') && herbOut.includes('=> false'));
await runAndWait(11);
check('Herb\'s syntax tree, nodes of the gem', /@ HTMLElementNode[\s\S]*@ ERBContentNode/.test(await page.textContent('#cell-out-11')));
await runAndWait(13);
const herbTest = await page.textContent('#cell-out-13');
check('a Minitest test with Herb: one passes, the void element fails with its message',
      herbTest.includes('2 runs,') && herbTest.includes(' 1 failures, 0 errors') &&
      herbTest.includes('`img` is a void element and should not be used as a closing tag'));
await runExercise();
check('erb starter fails', (await page.getAttribute('#chunkyChat', 'class')).includes('fail'));
await setExercise('install_gem "herb"\nrequire "herb"\nrequire "minitest"\n\ndef ladenliste\n  "<ul><% waren.each do |ware| %><li><%= ware %></li><% end %></ul>"\nend\n\nclass LadenTest < Minitest::Test\n  def test_ladenliste_ist_heil\n    assert_empty Herb.parse(ladenliste).errors\n  end\nend\nrun_tests');
await runExercise(); await page.waitForTimeout(300);
check('erb exercise passes', (await page.getAttribute('#chunkyChat', 'class')).includes('pass'));

// Scarpe lesson: real Shoes apps from the lacci gem, drawn into the page by a
// Lacci display service (shoes_dom.rb); several stay live at once
await page.click('#lessonNav a[data-id="scarpe"]');
await page.waitForTimeout(500);
await page.click('.run-cell[data-idx="1"]');
await page.waitForFunction(() => !document.querySelector('.run-cell[data-idx="1"]').disabled, null, { timeout: 90000 });
check('lacci installs from cache', (await page.textContent('#gemsList')).includes('lacci ✓'));
check('a Shoes app renders below the cell', (await page.textContent('#cell-out-1 .shoes-app')).includes('Hallo aus einer Shoes-App!'));
check('no lacci CHANGELOG noise in the output', !(await page.textContent('#cell-out-1')).includes('CHANGELOG'));
for (const i of [3, 5, 7]) { await page.click(`.run-cell[data-idx="${i}"]`); await page.waitForTimeout(1500); }
check('stack/flow layout renders', (await page.$$('#cell-out-3 .shoes-flow .shoes-button')).length === 3);
await page.click('#cell-out-5 .shoes-button'); await page.waitForTimeout(400);
await page.click('#cell-out-5 .shoes-button'); await page.waitForTimeout(400);
check('button block updates a para through Lacci', (await page.textContent('#cell-out-5 .shoes-app p')).includes('2 Streifen'));
await page.fill('#cell-out-7 .shoes-editline', 'Kaz'); await page.waitForTimeout(400);
check('edit_line change reaches the Shoes block', (await page.textContent('#cell-out-7 .shoes-app p')).includes('Hallo, Kaz!'));
await page.click('#cell-out-5 .shoes-button'); await page.waitForTimeout(400);
check('an earlier app stays live after later ones mount', (await page.textContent('#cell-out-5 .shoes-app p')).includes('3 Streifen'));
await page.click('.run-cell[data-idx="5"]'); await page.waitForTimeout(1500);
await page.click('#cell-out-5 .shoes-button'); await page.waitForTimeout(400);
check('re-running a cell starts a fresh app', (await page.textContent('#cell-out-5 .shoes-app p')).includes('1 Streifen'));
await runExercise();
check('scarpe starter fails', (await page.getAttribute('#chunkyChat', 'class')).includes('fail'));
await setExercise('show_shoes do\n  stack do\n    title "Gruss-App"\n    @feld = edit_line ""\n    @gruss = para "Wer bist du?"\n    button "Gruess mich" do\n      @gruss.replace("Hallo, #{@feld.text}!")\n    end\n  end\nend');
await runExercise(); await page.waitForTimeout(1200);
check('scarpe exercise passes', (await page.getAttribute('#chunkyChat', 'class')).includes('pass'));
await page.fill('.cell.exercise .shoes-editline', 'Isi');
await page.click('.cell.exercise .shoes-button'); await page.waitForTimeout(400);
check('the greeter greets', (await page.textContent('.cell.exercise .shoes-app')).includes('Hallo, Isi!'));

// running a cell: the running state is on screen before Ruby blocks, and
// the cell settles afterwards
await page.evaluate(() => window.cellEditors[3].setValue('t = Time.now\nn = 0\nn += 1 while Time.now - t < 1.5\nn'));
// The page cannot answer an evaluate() while Ruby blocks it, so the states are
// recorded as they happen by an observer installed beforehand.
await page.evaluate(() => {
  const cell = document.querySelector('.run-cell[data-idx="3"]').closest('.cell');
  window.__runLog = [];
  new MutationObserver(() => {
    const b = cell.querySelector('.run-cell');
    window.__runLog.push({ running: cell.classList.contains('running'), disabled: b.disabled, fox: !!b.querySelector('.run-fox'), t: performance.now() });
  }).observe(cell, { attributes: true, subtree: true, childList: true });
});
await page.click('.run-cell[data-idx="3"]');
await page.waitForFunction(() => !document.querySelector('.run-cell[data-idx="3"]').disabled, null, { timeout: 20000 });
const runLog = await page.evaluate(() => window.__runLog);
const on = runLog.find(e => e.running), off = runLog.findLast(e => !e.running);
check('run marks the cell as running', !!on);
check('run button is disabled with a running label', !!on && on.disabled && on.fox);
check('the running state lasts for the run', !!on && !!off && off.t - on.t > 1200);
check('running state is cleared afterwards', await page.evaluate(() => !document.querySelector('.run-cell[data-idx="3"]').closest('.cell').classList.contains('running')));
check('run time is shown', /1[,.]\d s/.test(await page.evaluate(() => document.querySelector('.run-cell[data-idx="3"]').closest('.cell').querySelector('.run-time').textContent)));
await page.evaluate(() => window.cellEditors[3].setValue('nope_not_defined'));
await page.click('.run-cell[data-idx="3"]'); await page.waitForTimeout(500);
check('an error shakes the cell', await page.evaluate(() => document.querySelector('.run-cell[data-idx="3"]').closest('.cell').classList.contains('shake')));

// lesson URLs: deep links, real hrefs, back/forward, bad ids
check('nav entries are real links', (await page.getAttribute('#lessonNav a[data-id="three"]', 'href')) === '#three');
check('URL names the open lesson', (await page.evaluate(() => location.hash)) === '#scarpe');
check('tab title names the lesson', (await page.title()).includes('Scarpe'));
await page.click('#lessonNav a[data-id="three"]'); await page.waitForTimeout(500);
check('clicking a lesson updates the URL', (await page.evaluate(() => location.hash)) === '#three');
await page.goBack(); await page.waitForTimeout(800);
check('back returns to the previous lesson', (await page.getAttribute('#lessonNav a.active', 'data-id')) === 'scarpe');
await page.evaluate(() => { location.hash = 'nonsense'; }); await page.waitForTimeout(600);
check('an unknown lesson id is corrected in the URL', (await page.evaluate(() => location.hash)) === '#scarpe');

// timelog track: simulated filesystem + explorer widget
await page.click('#lessonNav a[data-id="tl-formats"]');
await page.waitForTimeout(300);
await page.click('.run-cell[data-idx="7"]');
await page.waitForTimeout(1000);
check('file explorer widget appears', await page.isVisible('.file-explorer'));
check('explorer lists demo + written files', (await page.textContent('.fe-list')).includes('notizen.txt') && (await page.textContent('.fe-list')).includes('projekte/plan.txt'));
await page.click('.fe-file[data-path="notizen.txt"]');
await page.waitForTimeout(300);
check('clicking a file previews content', (await page.textContent('.fe-preview')).includes('Speck kaufen'));
await page.click('.run-cell[data-idx="9"]');
await page.waitForTimeout(600);
check('File.read and Dir.glob work in cells', (await page.textContent('#cell-out-9')).includes('projekte/plan.txt'));
await setExercise('require "csv"\n\ndaten = [\n  { projekt: "A", stunden: 1.5 },\n  { projekt: "B", stunden: 2.0 }\n]\n\ndef nach_csv(eintraege)\n  CSV.generate do |csv|\n    csv << ["projekt", "stunden"]\n    eintraege.each { |e| csv << [e[:projekt], e[:stunden]] }\n  end\nend\n\ndef aus_csv(text)\n  CSV.parse(text, headers: true).map { |z| { projekt: z["projekt"], stunden: z["stunden"].to_f } }\nend\n\nFile.write("eintraege.csv", nach_csv(daten))\naus_csv(File.read("eintraege.csv"))');
await runExercise();
check('file round-trip exercise passes', (await page.getAttribute('#chunkyChat', 'class')).includes('pass'));

// timelog track: simulated threads with virtual sleep
await page.click('#lessonNav a[data-id="tl-performance"]');
await page.waitForTimeout(300);
await page.click('.run-cell[data-idx="3"]');
await page.waitForTimeout(1500);
check('simulated thread downloads collect values', (await page.textContent('#cell-out-3')).includes('kunden: geladen'));
await page.click('.run-cell[data-idx="5"]');
await page.waitForTimeout(1500);
const interleaved = await page.textContent('#cell-out-5');
check('sim threads print all steps', interleaved.includes('Faden 0: Schritt 2') && interleaved.includes('Faden 1: Schritt 2'));
check('sim threads genuinely interleave', interleaved.indexOf('Faden 1: Schritt 0') < interleaved.indexOf('Faden 0: Schritt 1'));

// timelog track: Minitest runs for real in the browser. Runs after the
// ruby_pptx lesson on purpose: rubyzip loads full RubyGems, which once let
// minitest's plugin scan pull the bundled minitest 6 over the cached 5.x.
await page.click('#lessonNav a[data-id="tl-minitest"]');
await page.waitForTimeout(300);
await page.click('.run-cell[data-idx="1"]');
await page.waitForTimeout(2500);
check('minitest demo reports green run', /2 runs.*0 failures/.test(await page.textContent('#cell-out-1')));
await page.click('.run-cell[data-idx="3"]');
await page.waitForTimeout(1500);
check('minitest failing demo reports failure', /1 failures/.test(await page.textContent('#cell-out-3')));
await setExercise('class Eintrag\n  attr_reader :projekt, :stunden\n  def initialize(projekt, stunden)\n    @projekt = projekt\n    @stunden = stunden\n  end\n  def gueltig?\n    stunden > 0 && !projekt.to_s.empty?\n  end\nend\n\nclass TestEintrag < Minitest::Test\n  def test_gueltig\n    assert Eintrag.new("X", 2.0).gueltig?\n  end\n  def test_negative\n    refute Eintrag.new("X", -1).gueltig?\n  end\nend\n\nrun_tests');
await runExercise();
check('minitest exercise passes', (await page.getAttribute('#chunkyChat', 'class')).includes('pass'));

// timelog capstone: Roda + ERB web view in the mini browser
await page.click('#lessonNav a[data-id="tl-capstone"]');
await page.waitForTimeout(300);
await page.click('.run-cell[data-idx="1"]');
await page.waitForTimeout(6000);
check('capstone ERB table renders', (await page.textContent('#cell-out-1 .mb-page')).includes('timelog'));
await setExercise('install_gem "roda"\nrequire "roda"\nrequire "erb"\n\nEINTRAEGE = [\n  { projekt: "ProjectX", stunden: 3.5 },\n  { projekt: "Intern",   stunden: 2.0 },\n  { projekt: "ProjectX", stunden: 3.0 }\n]\n\nclass TimelogWeb < Roda\n  route do |r|\n    r.root do\n      "<h1>timelog</h1><a href=\'/projekt/ProjectX\'>ProjectX</a>"\n    end\n    r.get "projekt", String do |name|\n      passende = EINTRAEGE.select { |e| e[:projekt] == name }\n      "<h2>#{name}</h2>" + passende.map { |e| "#{e[:stunden]}h" }.join(", ")\n    end\n  end\nend\n\nshow_browser TimelogWeb, "/"');
await runExercise();
check('capstone exercise passes', (await page.getAttribute('#chunkyChat', 'class')).includes('pass'));
await page.click('.cell.exercise .mb-page a');
await page.waitForTimeout(600);
check('capstone project link navigates', (await page.textContent('.cell.exercise .mb-page')).includes('3.5h'));

// gems panel input installs (paint is now already installed → instant);
// the panel is folded at the foot of the sidebar until opened
await page.click('#gemsTitle');
await page.fill('#gemNameInput', 'paint');
await page.click('#gemInstallBtn');
await page.waitForTimeout(500);
check('panel install shows bubble', (await page.textContent('#chunkyText')).includes('paint'));

// switch language to English
await page.selectOption('#langSelect', 'en');
await page.waitForTimeout(300);
check('English title', (await page.textContent('#siteTitle')).includes('Learn Ruby with Chunky Bacon'));
check('English lesson rendered', (await page.textContent('#lessonBody')).includes('Everything together'));
check('progress survives lang switch', (await page.getAttribute('#lessonNav a:first-of-type', 'class')).includes('done'));

// reload: language + progress persist
await page.reload({ waitUntil: 'domcontentloaded' });
await page.waitForSelector('#app', { state: 'visible', timeout: 120000 });
await kernelReady(page);
check('after reload still English', (await page.textContent('#siteTitle')).includes('Learn Ruby'));
check('after reload progress kept', (await page.getAttribute('#lessonNav a:first-of-type', 'class')).includes('done'));

// solve the class lesson (lesson 10) end to end in English
await page.click('#lessonNav a[data-id="klassen"]');
await page.waitForTimeout(300);
await setExercise('class Fox\n  attr_reader :name\n  def initialize(name)\n    @name = name\n  end\n  def shout\n    "Chunky Bacon!"\n  end\nend\nFox.new("Kaz").shout');
await runExercise();
check('class lesson passes', (await page.getAttribute('#chunkyChat', 'class')).includes('pass'));
check('class lesson shows => "Chunky Bacon!"', (await exerciseOut()).includes('=> "Chunky Bacon!"'));

// Japanese: the lesson around the same (English) code, and it still passes
await page.selectOption('#langSelect', 'ja');
await page.waitForTimeout(300);
check('Japanese title', (await page.textContent('#siteTitle')).includes('Chunky Baconと学ぶRuby'));
check('Japanese sets <html lang>', (await page.getAttribute('html', 'lang')) === 'ja');
check('Japanese run button', (await page.textContent('.run-cell')).includes('実行'));
await setExercise('class Fox\n  attr_reader :name\n  def initialize(name)\n    @name = name\n  end\n  def shout\n    "Chunky Bacon!"\n  end\nend\nFox.new("Kaz").shout');
await runExercise();
check('class lesson passes in Japanese', (await page.getAttribute('#chunkyChat', 'class')).includes('pass'));

await page.screenshot({ path: '/tmp/chunkybacon.png', fullPage: true });
await browser.close();
console.log(failures === 0 ? 'ALL BROWSER TESTS OK' : `${failures} FAILURES`);
process.exit(failures === 0 ? 0 : 1);
