// Lesson `rails` in a browser: Rails 8 boots in the page from the gem cache,
// a controller renders view files from the app's folder, the mini browser
// walks the routes, the exercise passes with a second controller - in
// English and in German (the app is Diner there, Imbiss here).
//
//   BASE=http://127.0.0.1:8011/ node rails_test.mjs     (~1 min)
import { chromium } from '/usr/local/lib/node_modules/playwright/index.mjs';

const BASE = process.env.BASE || 'http://127.0.0.1:8011/';
const browser = await chromium.launch();
let failures = 0;
const check = (name, cond, detail = '') => {
  console.log(`${cond ? 'PASS' : 'FAIL'} ${name}${cond || !detail ? '' : ' - ' + String(detail).slice(0, 300)}`);
  if (!cond) failures++;
};

// one language: a fresh page, so Rails boots from nothing each time
const run = async (lang, words) => {
  const page = await browser.newPage({ locale: lang === 'de' ? 'de-DE' : 'en-US' });
  page.on('pageerror', (e) => { console.log('[pageerror]', e.message); failures++; });
  const out = (idx) => page.evaluate((i) => document.getElementById(`cell-out-${i}`).innerText, idx);
  const until = (fn, arg, timeout = 90000) => page.waitForFunction(fn, arg, { timeout }).then(() => true, () => false);
  const codeCells = () => page.$$eval('.run-cell', (buttons) => buttons.map((b) => b.getAttribute('data-idx')));
  // the mini browser below a cell: its page lives in a shadow root
  const mbText = (idx) => page.$eval(`#cell-out-${idx} .mb-view`, (view) => view.shadowRoot.querySelector('.mb-page').innerText);
  const mbStatus = (idx) => page.$eval(`#cell-out-${idx} .mb-status`, (el) => el.textContent);
  const mbGo = async (idx, path) => {
    await page.fill(`#cell-out-${idx} .mb-url`, path);
    await page.click(`#cell-out-${idx} .mb-go`);
  };

  await page.goto(`${BASE}?lang=${lang}#rails`, { waitUntil: 'domcontentloaded' });
  await page.waitForSelector('#app', { state: 'visible', timeout: 120000 });
  check(`${lang}: the lesson opens`, (await page.textContent('#lessonBody h2')).includes('Rails'));
  const [boot, app, routes, exercise] = await codeCells();

  // 1. boot: Rails from the cache, the application initialized
  await page.click(`.run-cell[data-idx="${boot}"]`);
  check(`${lang}: Rails boots and answers its version`,
        await until((i) => /=> "8\.\d+\.\d+"/.test(document.getElementById(`cell-out-${i}`).innerText), boot, 180000),
        await out(boot));

  // 2. the app: routes file, views, controller; the mini browser on /
  await page.click(`.run-cell[data-idx="${app}"]`);
  check(`${lang}: the mini browser shows the home page`,
        await until((i) => { const v = document.querySelector(`#cell-out-${i} .mb-view`); return v && v.shadowRoot && /Chunky/.test(v.shadowRoot.textContent); }, app),
        await out(app));
  const mbLog = (idx) => page.$eval(`#cell-out-${idx} .mb-log`, (el) => el.innerText);
  const log = await mbLog(app);
  check(`${lang}: the Rails log is under the page`, /Started GET "\/"/.test(log) && /Processing by \w+Controller#\w+ as HTML/.test(log) && /Completed 200 OK/.test(log), log);
  check(`${lang}: the view file was rendered`, new RegExp(`Rendering \\w+/${words.home}\\.html\\.erb`).test(log), log);
  // a link in the page, then the menu's view with the controller's instance variable
  await page.$eval(`#cell-out-${app} .mb-view`, (view) => view.shadowRoot.querySelector('a').click());
  check(`${lang}: a link reaches the menu action`, await until((i) => { const v = document.querySelector(`#cell-out-${i} .mb-view`); return /Kaffee|Coffee/.test(v.shadowRoot.textContent); }, app), await mbText(app));
  check(`${lang}: the log grows with every request`, (await mbLog(app)).split('Started GET').length === 3, await mbLog(app));
  check(`${lang}: route helpers wrote the link`, await page.$eval(`#cell-out-${app} .mb-view`, (view) => view.shadowRoot.querySelector('a').getAttribute('href')) === '/');
  await mbGo(app, `/${words.hello}/Kaz`);
  check(`${lang}: params from the path`, await until((i) => /Kaz/.test(document.querySelector(`#cell-out-${i} .mb-view`).shadowRoot.textContent), app), await mbText(app));
  await mbGo(app, '/pizza');
  check(`${lang}: a path without a route is Rails' routing error`,
        await until((i) => document.querySelector(`#cell-out-${i} .mb-status`).textContent === '404', app) && /Routing Error|No route matches/.test(await mbText(app)),
        await mbText(app));

  // 3. the route table
  await page.click(`.run-cell[data-idx="${routes}"]`);
  check(`${lang}: the route table`, await until((i) => /GET\s+\/\s+\w+#\w+/.test(document.getElementById(`cell-out-${i}`).innerText), routes), await out(routes));
  check(`${lang}: without Rails' own routes`, !/rails\/info/.test(await out(routes)));

  // 4. the exercise: the starter is a 404, the solution a second controller
  await page.click(`.run-cell[data-idx="${exercise}"]`);
  check(`${lang}: the starter shows the routing error`, await until((i) => (document.querySelector(`#cell-out-${i} .mb-status`) || {}).textContent === '404', exercise), await out(exercise));
  check(`${lang}: the starter does not pass`, !(await page.getAttribute('#chunkyChat', 'class')).includes('pass'));
  const starter = await page.evaluate((i) => window.cellEditors[i].getValue(), exercise);
  const solution = starter.replace(`# get "/${words.bacon}"`, `get "/${words.bacon}"`)
    .replace(`# def ${words.bacon}\n  #   render plain: "..."\n  # end`, `def ${words.bacon}\n    render plain: "CHUNKY BACON!"\n  end`);
  check(`${lang}: the solution differs from the starter`, solution !== starter && !solution.includes('"..."'), solution);
  await page.evaluate(([i, c]) => window.cellEditors[i].setValue(c), [exercise, solution]);
  await page.click(`.run-cell[data-idx="${exercise}"]`);
  check(`${lang}: the solution passes`, await until(() => document.getElementById('chunkyChat').className.includes('pass'), null), await out(exercise));
  check(`${lang}: the mini browser shows the new action`, (await mbStatus(exercise)) === '200' && /CHUNKY BACON!/.test(await mbText(exercise)), await mbText(exercise));
  // the first mini browser still works: the routes file holds every route
  await mbGo(app, '/');
  check(`${lang}: the home page is still there after the exercise`, await until((i) => /Chunky/.test(document.querySelector(`#cell-out-${i} .mb-view`).shadowRoot.textContent) && document.querySelector(`#cell-out-${i} .mb-status`).textContent === '200', app), await mbText(app));
  await page.close();
};

// lesson `activerecord`: Active Record on the sqlite3 stand-in (sql.js loads
// when the lesson opens: the shell sees "sqlite3" in a cell)
const runModel = async (lang, words) => {
  const page = await browser.newPage({ locale: lang === 'de' ? 'de-DE' : 'en-US' });
  page.on('pageerror', (e) => { console.log('[pageerror]', e.message); failures++; });
  const out = (idx) => page.evaluate((i) => document.getElementById(`cell-out-${i}`).innerText, idx);
  const until = (fn, arg, timeout = 90000) => page.waitForFunction(fn, arg, { timeout }).then(() => true, () => false);
  const codeCells = () => page.$$eval('.run-cell', (buttons) => buttons.map((b) => b.getAttribute('data-idx')));
  const outHas = (idx, re, timeout) => until(([i, src]) => new RegExp(src).test(document.getElementById(`cell-out-${i}`).innerText), [idx, re.source], timeout);

  await page.goto(`${BASE}?lang=${lang}#activerecord`, { waitUntil: 'domcontentloaded' });
  await page.waitForSelector('#app', { state: 'visible', timeout: 120000 });
  check(`${lang}: the model lesson opens`, (await page.textContent('#lessonBody h2')).includes('Active Record'));
  const [setup, model, queries, exercise] = await codeCells();

  await page.click(`.run-cell[data-idx="${setup}"]`);
  check(`${lang}: the schema makes the tables`, await outHas(setup, /=> \[.*"schema_migrations".*\]/, 180000) && new RegExp(`=> \\[.*"${words.table}"`).test(await out(setup)), await out(setup));
  check(`${lang}: the SQL is logged under the cell`, /CREATE TABLE "\w+"/.test(await out(setup)), await out(setup));
  check(`${lang}: the database file is a download`, (await page.$$eval(`#cell-out-${setup} .cell-download`, (links) => links.map((a) => a.textContent).join(' '))).includes(words.db));

  await page.click(`.run-cell[data-idx="${model}"]`);
  check(`${lang}: three rows created`, await outHas(model, /=> 3(\n|$)/), await out(model));
  check(`${lang}: INSERT with RETURNING in the log`, /INSERT INTO "\w+" .* RETURNING "id"/.test(await out(model)), await out(model));

  await page.click(`.run-cell[data-idx="${queries}"]`);
  check(`${lang}: a relation's SQL, find_by, update!, the validation`, await outHas(queries, /=> \["Name can't be blank"\]/), await out(queries));
  const q = await out(queries);
  check(`${lang}: where and order become SQL`, /SELECT .* WHERE \(\w+ < 4\) ORDER BY/.test(q) && /\["\w+", "\w+"\]/.test(q) && /UPDATE "\w+" SET/.test(q), q);

  await page.click(`.run-cell[data-idx="${exercise}"]`);
  check(`${lang}: the starter lists both guests`, await outHas(exercise, /=> \["Kaz", "Ada"\]/), await out(exercise));
  check(`${lang}: the starter does not pass`, !(await page.getAttribute('#chunkyChat', 'class')).includes('pass'));
  const starter = await page.evaluate((i) => window.cellEditors[i].getValue(), exercise);
  const solution = starter.replace('# validates ...', 'validates :name, presence: true')
    .replace(`${words.model}.all`, `${words.model}.where("${words.visits} >= ?", 2)`);
  check(`${lang}: the solution differs from the starter`, solution !== starter && solution.includes('where('), solution);
  await page.evaluate(([i, c]) => window.cellEditors[i].setValue(c), [exercise, solution]);
  await page.click(`.run-cell[data-idx="${exercise}"]`);
  check(`${lang}: the solution passes`, await until(() => document.getElementById('chunkyChat').className.includes('pass'), null), await out(exercise));
  check(`${lang}: only the regular`, /=> \["Kaz"\]/.test(await out(exercise)), await out(exercise));
  await page.close();
};

await run('en', { home: 'home', hello: 'hello', bacon: 'bacon' });
await run('de', { home: 'start', hello: 'hallo', bacon: 'speck' });
await runModel('en', { db: 'diner.db', table: 'dishes', model: 'Guest', visits: 'visits' });
await runModel('de', { db: 'imbiss.db', table: 'gerichte', model: 'Gast', visits: 'besuche' });

await browser.close();
console.log(failures === 0 ? 'ALL RAILS CHECKS OK' : `${failures} failures`);
process.exit(failures === 0 ? 0 : 1);
