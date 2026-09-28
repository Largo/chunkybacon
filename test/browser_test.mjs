// Headless smoke test for the notebook UI: demo cells, => results without
// puts, exercise checks, shared kernel state, errors, i18n, persistence.
import { chromium } from '/usr/local/lib/node_modules/playwright/index.mjs';

const BASE = process.env.BASE || 'http://127.0.0.1:8011/';
const browser = await chromium.launch();
const page = await browser.newPage();
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

await page.goto(BASE, { waitUntil: 'domcontentloaded' });
await page.waitForSelector('#app', { state: 'visible', timeout: 120000 });
check('app becomes visible after wasm boot', true);

check('German title', (await page.textContent('#siteTitle')).includes('Ruby lernen mit Chunky Bacon'));
check('35 lessons in nav', (await page.$$('#lessonNav a')).length === 35);
check('nav has course sections', (await page.textContent('#lessonNav')).includes('Aufbaukurs'));
check('gems panel shows cached chips', (await page.textContent('#gemsList')).includes('chunky_png'));
check('lesson 1 has demo + exercise cells', (await page.$$('#lessonBody .cell')).length === 3);
check('exercise cell has task label', (await page.getAttribute('.cell.exercise', 'data-label')) === 'Aufgabe');

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

// lesson 11: gems — install chunky_png from local cache, draw an image
await page.click('#lessonNav a[data-id="gems"]');
await page.waitForTimeout(300);
await page.click('.run-cell[data-idx="1"]');
await page.waitForTimeout(1500);
check('chunky_png installs from cache', (await page.textContent('#cell-out-1')).includes('chunky_png 1.4.0'));
check('gems panel marks chunky_png installed', (await page.textContent('#gemsList')).includes('chunky_png ✓'));
await page.click('.run-cell[data-idx="3"]');
await page.waitForTimeout(1000);
check('demo cell renders a PNG image', await page.isVisible('#cell-out-3 img.cell-image'));
await setExercise('install_gem "chunky_png"\nrequire "chunky_png"\nbild = ChunkyPNG::Image.new(8, 8, ChunkyPNG::Color::WHITE)\n8.times do |y|\n  next unless y.even?\n  8.times { |x| bild[x, y] = ChunkyPNG::Color.rgb(193, 74, 46) }\nend\nshow_image bild');
await runExercise();
check('bacon flag exercise passes', (await page.getAttribute('#chunkyChat', 'class')).includes('pass'));
check('exercise shows the flag image', await page.isVisible('.cell.exercise .cell-out img.cell-image'));

// lesson 12: HTML parsing — nokogiri fails helpfully, gammo works
await page.click('#lessonNav a[data-id="html"]');
await page.waitForTimeout(300);
await page.click('.run-cell[data-idx="1"]');
await page.waitForTimeout(2000);
check('nokogiri explains native extension limit', (await page.textContent('#cell-out-1')).includes('native extension'));
await page.click('.run-cell[data-idx="3"]');
await page.waitForTimeout(2000);
check('gammo parses: 3 li elements', (await page.textContent('#cell-out-3')).includes('=> 3'));
await page.click('.run-cell[data-idx="5"]');
await page.waitForTimeout(800);
check('gammo css text extraction', (await page.textContent('#cell-out-5')).includes('Speck'));
await setExercise('links = doc.css("a").map { |link| link.attributes.to_h["href"] }\nlinks');
await runExercise();
check('link extraction exercise passes', (await page.getAttribute('#chunkyChat', 'class')).includes('pass'));

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
await page.click('.run-cell[data-idx="1"]');
await page.waitForTimeout(8000);
check('sinatra widget renders root page', (await page.textContent('#cell-out-1 .mb-view')).includes('Chunkys Imbiss'));
check('sinatra widget status 200', (await page.textContent('#cell-out-1 .mb-status')).trim() === '200');
await page.click('#cell-out-1 .mb-view a');
await page.waitForTimeout(600);
check('clicking a link navigates the fake browser', (await page.textContent('#cell-out-1 .mb-view')).includes('Speisekarte'));
await page.fill('#cell-out-1 .mb-url', '/hallo/Kaz');
await page.click('#cell-out-1 .mb-go');
await page.waitForTimeout(600);
check('sinatra param route in widget', (await page.textContent('#cell-out-1 .mb-view')).includes('Hallo, Kaz!'));
await page.fill('#cell-out-1 .mb-url', '/pizza');
await page.click('#cell-out-1 .mb-go');
await page.waitForTimeout(600);
check('sinatra 404 in widget', (await page.textContent('#cell-out-1 .mb-status')).trim() === '404');
await runExercise();
check('sinatra starter fails (404 on /speck)', (await page.getAttribute('#chunkyChat', 'class')).includes('fail'));
await setExercise('install_gem "sinatra"\nrequire "sinatra/base"\nclass MeineSeite < Sinatra::Base\n  get "/" do\n    "<h1>Meine Seite</h1>"\n  end\n  get "/speck" do\n    "CHUNKY BACON!"\n  end\nend\nshow_browser MeineSeite, "/speck"');
await runExercise();
check('sinatra exercise passes', (await page.getAttribute('#chunkyChat', 'class')).includes('pass'));
check('sinatra exercise widget shows response', (await page.textContent('.cell.exercise .mb-view')).includes('CHUNKY BACON!'));

// lesson 14: Roda — routing tree, string matcher, 404, exercise
await page.click('#lessonNav a[data-id="roda"]');
await page.waitForTimeout(300);
await page.click('.run-cell[data-idx="1"]');
await page.waitForTimeout(6000);
check('roda widget renders root', (await page.textContent('#cell-out-1 .mb-view')).includes('Chunkys Laden'));
await page.fill('#cell-out-1 .mb-url', '/gruss/Ada');
await page.click('#cell-out-1 .mb-go');
await page.waitForTimeout(600);
check('roda string matcher in widget', (await page.textContent('#cell-out-1 .mb-view')).includes('Hallo, Ada!'));
await setExercise('install_gem "roda"\nrequire "roda"\nclass Kiosk < Roda\n  route do |r|\n    r.root do\n      "<h1>Kiosk</h1>"\n    end\n    r.get "bestellung", Integer do |anzahl|\n      "#{anzahl} Streifen Speck, kommt sofort!"\n    end\n  end\nend\nshow_browser Kiosk, "/bestellung/5"');
await runExercise();
check('roda exercise passes', (await page.getAttribute('#chunkyChat', 'class')).includes('pass'));
check('roda exercise widget shows order', (await page.textContent('.cell.exercise .mb-view')).includes('5 Streifen Speck'));

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
check('capstone ERB table renders', (await page.textContent('#cell-out-1 .mb-view')).includes('timelog'));
await setExercise('install_gem "roda"\nrequire "roda"\nrequire "erb"\n\nEINTRAEGE = [\n  { projekt: "ProjectX", stunden: 3.5 },\n  { projekt: "Intern",   stunden: 2.0 },\n  { projekt: "ProjectX", stunden: 3.0 }\n]\n\nclass TimelogWeb < Roda\n  route do |r|\n    r.root do\n      "<h1>timelog</h1><a href=\'/projekt/ProjectX\'>ProjectX</a>"\n    end\n    r.get "projekt", String do |name|\n      passende = EINTRAEGE.select { |e| e[:projekt] == name }\n      "<h2>#{name}</h2>" + passende.map { |e| "#{e[:stunden]}h" }.join(", ")\n    end\n  end\nend\n\nshow_browser TimelogWeb, "/"');
await runExercise();
check('capstone exercise passes', (await page.getAttribute('#chunkyChat', 'class')).includes('pass'));
await page.click('.cell.exercise .mb-view a');
await page.waitForTimeout(600);
check('capstone project link navigates', (await page.textContent('.cell.exercise .mb-view')).includes('3.5h'));

// gems panel input installs (paint is now already installed → instant)
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
check('after reload still English', (await page.textContent('#siteTitle')).includes('Learn Ruby'));
check('after reload progress kept', (await page.getAttribute('#lessonNav a:first-of-type', 'class')).includes('done'));

// solve the class lesson (lesson 10) end to end in English
await page.click('#lessonNav a[data-id="klassen"]');
await page.waitForTimeout(300);
await setExercise('class Fox\n  attr_reader :name\n  def initialize(name)\n    @name = name\n  end\n  def shout\n    "Chunky Bacon!"\n  end\nend\nFox.new("Kaz").shout');
await runExercise();
check('class lesson passes', (await page.getAttribute('#chunkyChat', 'class')).includes('pass'));
check('class lesson shows => "Chunky Bacon!"', (await exerciseOut()).includes('=> "Chunky Bacon!"'));

await page.screenshot({ path: '/tmp/chunkybacon.png', fullPage: true });
await browser.close();
console.log(failures === 0 ? 'ALL BROWSER TESTS OK' : `${failures} FAILURES`);
process.exit(failures === 0 ? 0 : 1);
