// Headless test for keeping work on the learner's machine: the progress file
// (download, load, merge), the workshop (multi-file programs, gets, the File
// API) and a connected folder. The folder is driven through the origin-
// private file system: the same API as a folder picked with the File System
// Access API, without the native picker a test cannot click through.
import { chromium } from '/usr/local/lib/node_modules/playwright/index.mjs';
import { readFileSync } from 'node:fs';

const BASE = process.env.BASE || 'http://127.0.0.1:8011/';
const browser = await chromium.launch();

let failures = 0;
const check = (name, cond) => {
  console.log(`${cond ? 'PASS' : 'FAIL'} ${name}`);
  if (!cond) failures++;
};

async function open(ctx, hash = '') {
  const page = await ctx.newPage();
  page.on('pageerror', e => console.log('[pageerror]', e.message));
  page.on('dialog', d => d.accept());
  await page.goto(BASE + hash, { waitUntil: 'domcontentloaded' });
  await page.waitForSelector('#app', { state: 'visible', timeout: 120000 });
  await kernelReady(page);
  return page;
}
// the page is drawn by the shell (PicoRuby) before the kernel (CRuby) is up
const kernelReady = p => p.waitForFunction(() => window.ChunkyBridge && window.ChunkyBridge.ready, null, { timeout: 120000 });
const exerciseIdx = page => page.getAttribute('.cell.exercise .run-cell', 'data-idx');
const exerciseCode = async page => page.evaluate(i => window.cellEditors[i].getValue(), await exerciseIdx(page));
const isDone = async (page, id) => (await page.getAttribute(`#lessonNav a[data-id="${id}"]`, 'class')).includes('done');
const message = page => page.textContent('#progressDialog .pd-message');

async function download(page) {
  await page.click('#progressBtn');
  const [dl] = await Promise.all([
    page.waitForEvent('download'),
    page.click('#progressDialog >> text=Datei herunterladen')
  ]);
  const text = readFileSync(await dl.path(), 'utf8');
  await page.keyboard.press('Escape');
  return text;
}

async function load(page, text, outcome = 'ok') {
  await page.click('#progressBtn');
  await page.setInputFiles('#progressDialog input[type=file]',
    { name: 'progress.json', mimeType: 'application/json', buffer: Buffer.from(text) });
  await page.waitForSelector(`#progressDialog .pd-message.is-${outcome}`);
  const said = await message(page);
  await page.keyboard.press('Escape');
  return said;
}

// ---------- 1. progress travels as a file ----------
const ctxA = await browser.newContext({ acceptDownloads: true, locale: 'de-DE' });
const a = await open(ctxA);
await a.evaluate(i => window.cellEditors[i].setValue('puts "Hallo, Welt!"'), await exerciseIdx(a));
await a.click('.cell.exercise .run-cell');
await a.waitForTimeout(500);
check('lesson 1 solved', await isDone(a, 'hallo'));

await a.click('#workshopLink');
await a.waitForSelector('#wsFiles li');
check('workshop starts with a main.rb', (await a.textContent('#wsFiles')).includes('main.rb'));
await a.evaluate(() => window.ChunkyStorage.files.write('notiz.txt', 'Speck!'));

const fileA = await download(a);
const doc = JSON.parse(fileA);
check('download is a progress file', doc.format === 'chunkybacon-progress' && doc.version === 1);
check('it holds the finished lessons', JSON.parse(doc.entries.chunky_done.v).includes('hallo'));
check('it holds the cell code', Object.entries(doc.entries)
  .some(([k, e]) => k.startsWith('chunky_cell_de_hallo_') && e.v === 'puts "Hallo, Welt!"'));
check('it holds the workshop files', doc.entries['chunky_file:notiz.txt']?.v === 'Speck!');

const ctxB = await browser.newContext({ acceptDownloads: true, locale: 'de-DE' });
const b = await open(ctxB, '#hallo');
check('a fresh browser starts without progress', !(await isDone(b, 'hallo')));
check('loading reports success', (await load(b, fileA)).includes('geladen'));
check('the loaded lesson shows as done', await isDone(b, 'hallo'));
check('the loaded code is in the editor', (await exerciseCode(b)) === 'puts "Hallo, Welt!"');
check('the loaded workshop file is there', (await b.evaluate(() => window.ChunkyStorage.files.read('notiz.txt'))) === 'Speck!');
check('a foreign file is refused', (await load(b, '{"hello": 1}', 'error')).includes('keine Fortschrittsdatei'));

// newer beats older: running again makes B's code newer than the file
await b.evaluate(i => window.cellEditors[i].setValue('puts "Hallo, Welt!" # neu'), await exerciseIdx(b));
await b.click('.cell.exercise .run-cell');
await b.waitForTimeout(400);
check('an older file brings nothing new', (await load(b, fileA)).includes('nichts'));
check('the newer code stays', (await exerciseCode(b)).endsWith('# neu'));

// a reset lesson stays reset where its file is loaded, finished stays finished
await b.click('#reset-code');
await b.waitForTimeout(300);
const fileB = await download(b);
await a.click('#lessonNav a[data-id="hallo"]');
await load(a, fileB);
check('a reset travels: the starter code is back', (await exerciseCode(a)) === '# Dein Code:\n');
check('finished lessons are united', await isDone(a, 'hallo'));

// a file from before fingerprints (chunky_cell_<lang>_<id>_<idx>): lesson 7
// has had two more cells before its exercise since, which was cell 7 then
const oldFile = JSON.stringify({ format: 'chunkybacon-progress', version: 1,
  entries: { chunky_cell_de_arrays_7: { v: 'fruehstueck = ["Speck"]', t: Date.now() - 60000 } } });
await b.click('#lessonNav a[data-id="arrays"]');
await load(b, oldFile);
check('an old file\'s exercise code lands in the exercise', await exerciseIdx(b) === '9' &&
  (await exerciseCode(b)) === 'fruehstueck = ["Speck"]');
check('not in the cell that has its old place', !(await b.evaluate(() => window.cellEditors[7].getValue())).includes('Speck'));
const moved = JSON.parse(await download(b)).entries;
check('it travels on under the fingerprinted key, the old key as removed',
  moved.chunky_cell_de_arrays_7?.v === null &&
  Object.entries(moved).some(([k, e]) => k.startsWith('chunky_cell_de_arrays_9@') && e.v === 'fruehstueck = ["Speck"]'));
check('the old file cannot bring the old key back', (await load(b, oldFile)).includes('nichts'));

// ---------- 2. the workshop ----------
await a.click('#workshopLink');
await a.waitForSelector('#wsFiles li');
await a.click('#wsFiles >> text=+ Neue Datei');
await a.fill('.ws-newname', 'rechner');
await a.press('.ws-newname', 'Enter');
check('a new file gets .rb and opens', (await a.textContent('#wsTab')) === 'rechner.rb');
await a.evaluate(() => window.cellEditors[0].replaceRange('def doppelt(x) = x * 2\n', { line: 0, ch: 0 }));
await a.waitForTimeout(900);
check('typing saves the file', (await a.evaluate(() => window.ChunkyStorage.files.read('rechner.rb'))) === 'def doppelt(x) = x * 2\n');

await a.click('#wsFiles >> text=main.rb');
await a.evaluate(() => window.cellEditors[0].setValue(
  'require_relative "rechner"\nname = gets.chomp\nFile.write("aus/ergebnis.txt", "#{name}: #{doppelt(21)}")\n' +
  'puts File.read("aus/ergebnis.txt")\nFile.delete("notiz.txt")\n:ok'));
await a.click('#wsStdinBox summary');
await a.fill('#wsStdin', 'Isi\n');
await a.click('.run-cell[data-idx="0"]');
await a.waitForTimeout(800);
check('a program runs with require_relative and gets', (await a.textContent('#cell-out-0')).includes('Isi: 42'));
check('what it writes lands in the project', (await a.evaluate(() => window.ChunkyStorage.files.read('aus/ergebnis.txt'))) === 'Isi: 42');
check('it can delete a project file', (await a.evaluate(() => window.ChunkyStorage.files.read('notiz.txt'))) === null);
check('the file list shows what it wrote', (await a.textContent('#wsFiles')).includes('aus/ergebnis.txt'));
check('running saved the program', (await a.evaluate(() => window.ChunkyStorage.files.read('main.rb'))).startsWith('require_relative'));

await a.evaluate(() => window.ChunkyStorage.files.write('rechner.rb', 'def doppelt(x) = x * zwei\n'));
await a.click('.run-cell[data-idx="0"]');
await a.waitForTimeout(800);
check('an error in a required file names file and line', (await a.textContent('#cell-out-0')).includes('(rechner.rb:1)'));

// pictures and PDFs a program writes: shown below the editor, kept in the
// project, opened in place of the editor - and renaming
const files = () => a.evaluate(() => window.ChunkyStorage.files.list());
await a.evaluate(() => window.cellEditors[0].setValue(
  'install_gem "chunky_png"\nrequire "chunky_png"\n' +
  'bild = ChunkyPNG::Image.new(8, 8, ChunkyPNG::Color.rgb(232, 114, 42))\nbild.save("bild.png")\n' +
  'File.binwrite("mini.pdf", "%PDF-1.4\\n1 0 obj << /Type /Catalog >> endobj\\ntrailer << /Root 1 0 R >>\\n%%EOF\\n")\n:ok'));
await a.click('.run-cell[data-idx="0"]');
await a.waitForTimeout(2500);
check('a picture the program saves shows below the editor', await a.isVisible('#cell-out-0 img.cell-image'));
check('a PDF it writes shows in the viewer below', (await a.$$('#cell-out-0 iframe.cell-pdf')).length === 1);
const kept = await a.evaluate(() => [window.ChunkyStorage.files.read('bild.png'), window.ChunkyStorage.files.read('mini.pdf')]);
check('both are kept in the project', kept[0]?.startsWith('data:image/png;base64,') && kept[1]?.startsWith('data:application/pdf;base64,'));
await a.click('#wsFiles >> text=bild.png');
check('a picture opens in place of the editor', (await a.getAttribute('#wsPreview img', 'src')).startsWith('data:image/png;base64,') &&
  !(await a.isVisible('.ws-editor .CodeMirror')));
await a.click('#wsFiles >> text=mini.pdf');
check('a PDF opens in the browser viewer', (await a.getAttribute('#wsPreview iframe.ws-pdf', 'src')).startsWith('blob:'));
await a.click('#wsFiles button.ws-ren[aria-label*="bild.png"]');
await a.fill('.ws-newname', 'fuchs');
await a.press('.ws-newname', 'Enter');
await a.waitForTimeout(300);
check('a renamed file keeps its extension', (await files()).includes('fuchs.png') && !(await files()).includes('bild.png'));
await a.click('#wsFiles >> text=main.rb');
check('a text file brings the editor back', await a.isVisible('.ws-editor .CodeMirror'));
await a.evaluate(() => window.cellEditors[0].setValue('require "chunky_png"\nChunkyPNG::Image.from_file("fuchs.png").width'));
await a.click('.run-cell[data-idx="0"]');
await a.waitForTimeout(1500);
check('a program reads a picture from the project', (await a.textContent('#cell-out-0')).includes('=> 8'));

await a.click('#lessonNav a[data-id="tl-formats"]');
const cellIdx = await a.getAttribute('#lessonBody .cell:not(.exercise) .run-cell', 'data-idx');
await a.evaluate(i => window.cellEditors[i].setValue('[File.exist?("notizen.txt"), File.exist?("rechner.rb")]'), cellIdx);
await a.click(`.run-cell[data-idx="${cellIdx}"]`);
await a.waitForTimeout(600);
check('lessons keep their own files', (await a.textContent(`#cell-out-${cellIdx}`)).includes('[true, false]'));

// ---------- 3. a connected folder ----------
const ctxC = await browser.newContext({ locale: 'de-DE' });
await ctxC.addInitScript(() => {
  window.showDirectoryPicker = async () =>
    (await navigator.storage.getDirectory()).getDirectoryHandle('kurs', { create: true });
});
const c = await open(ctxC, '#werkstatt');
await c.waitForSelector('#wsFiles li');
await c.evaluate(() => window.ChunkyStorage.files.write('mein.rb', 'puts 1'));
const readFolder = path => c.evaluate(async p => {
  let dir = await (await navigator.storage.getDirectory()).getDirectoryHandle('kurs');
  const parts = p.split('/');
  const name = parts.pop();
  try {
    for (const part of parts) dir = await dir.getDirectoryHandle(part);
    return await (await (await dir.getFileHandle(name)).getFile()).text();
  } catch (e) { return null; }
}, path);

await c.click('#progressBtn');
await c.click('#progressDialog >> text=Ordner wählen');
await c.waitForSelector('#progressDialog .pd-connected');
check('the folder is connected', (await c.textContent('#progressDialog .pd-connected')).includes('kurs'));
check('the header shows the connected dot', (await c.getAttribute('#progressBtn', 'class')).includes('is-connected'));
check('the progress file is in the folder', JSON.parse(await readFolder('chunkybacon-progress.json')).format === 'chunkybacon-progress');
check('the workshop files moved into the folder', (await readFolder('mein.rb')) === 'puts 1' && (await readFolder('main.rb')) !== null);
await c.keyboard.press('Escape');
check('the workshop shows the folder', (await c.textContent('.ws-where')).includes('kurs'));

await c.click('#wsFiles >> text=mein.rb');
await c.evaluate(() => window.cellEditors[0].setValue('File.write("daten/liste.txt", "Speck\\nEier\\n")\nFile.read("daten/liste.txt").lines.size'));
await c.click('.run-cell[data-idx="0"]');
await c.waitForTimeout(1000);
check('the program runs from the folder', (await c.textContent('#cell-out-0')).includes('=> 2'));
check('what it writes is a real file in the folder', (await readFolder('daten/liste.txt')) === 'Speck\nEier\n');
check('running saved the program into the folder', (await readFolder('mein.rb')).startsWith('File.write'));

// a picture in the folder is a real PNG; renaming moves it there too
const pngIn = path => c.evaluate(async p => {
  let dir = await (await navigator.storage.getDirectory()).getDirectoryHandle('kurs');
  const parts = p.split('/');
  const name = parts.pop();
  try {
    for (const part of parts) dir = await dir.getDirectoryHandle(part);
    const bytes = new Uint8Array(await (await (await dir.getFileHandle(name)).getFile()).arrayBuffer());
    return String.fromCharCode(...bytes.slice(1, 4)) === 'PNG';
  } catch (e) { return false; }
}, path);
await c.evaluate(() => window.cellEditors[0].setValue(
  'install_gem "chunky_png"\nrequire "chunky_png"\nChunkyPNG::Image.new(4, 4, ChunkyPNG::Color::BLACK).save("punkt.png")\n:ok'));
await c.click('.run-cell[data-idx="0"]');
await c.waitForTimeout(2500);
check('a picture the program saves is a real PNG in the folder', await pngIn('punkt.png'));
await c.click('#wsFiles button.ws-ren[aria-label*="punkt.png"]');
await c.fill('.ws-newname', 'bilder/punkt.png');
await c.press('.ws-newname', 'Enter');
await c.waitForTimeout(1000);
check('renaming moves it in the folder', !(await pngIn('punkt.png')) && (await pngIn('bilder/punkt.png')));

await c.click('#lessonNav a[data-id="hallo"]');
await c.evaluate(i => window.cellEditors[i].setValue('"Hallo, Welt!"'), await exerciseIdx(c));
await c.click('.cell.exercise .run-cell');
await c.waitForTimeout(2000);
const saved = JSON.parse(await readFolder('chunkybacon-progress.json'));
check('progress goes into the folder by itself', JSON.parse(saved.entries.chunky_done.v).includes('hallo'));

await c.reload({ waitUntil: 'domcontentloaded' });
await c.waitForSelector('#app', { state: 'visible', timeout: 120000 });
await kernelReady(c);
await c.waitForFunction(() => window.ChunkyStorage.state() === 'folder', null, { timeout: 15000 });
check('the folder comes back after a reload', true);
check('pictures in the folder come back as pictures',
  (await c.evaluate(() => window.ChunkyStorage.files.read('bilder/punkt.png') || '')).startsWith('data:image/png;base64,'));

await c.click('#workshopLink');
await c.waitForSelector('#wsFiles li');
await c.evaluate(async () => {
  const dir = await (await navigator.storage.getDirectory()).getDirectoryHandle('kurs');
  const w = await (await dir.getFileHandle('extern.rb', { create: true })).createWritable();
  await w.write('puts :extern');
  await w.close();
  window.dispatchEvent(new Event('focus'));
});
await c.waitForTimeout(1000);
check('a file added in another program shows up', (await c.textContent('#wsFiles')).includes('extern.rb'));

await c.click('#progressBtn');
await c.click('#progressDialog >> text=Ordner trennen');
await c.waitForSelector('#progressDialog >> text=Ordner wählen');
check('the folder can be disconnected', (await c.evaluate(() => window.ChunkyStorage.state())) === 'none');

await browser.close();
console.log(failures === 0 ? 'ALL PROGRESS TESTS OK' : `${failures} FAILURES`);
process.exit(failures === 0 ? 0 : 1);
