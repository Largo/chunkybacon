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
  check(`${lang}: the lesson opens`, /Rails/.test(await page.textContent('#lessonBody h2')));
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

// lesson `rails-mvc`: the Rails app of lesson `rails` with Active Record
// behind it; the exercise adds the show action and its view
const runMvc = async (lang, words) => {
  const page = await browser.newPage({ locale: lang === 'de' ? 'de-DE' : 'en-US' });
  page.on('pageerror', (e) => { console.log('[pageerror]', e.message); failures++; });
  const out = (idx) => page.evaluate((i) => document.getElementById(`cell-out-${i}`).innerText, idx);
  const until = (fn, arg, timeout = 90000) => page.waitForFunction(fn, arg, { timeout }).then(() => true, () => false);
  const codeCells = () => page.$$eval('.run-cell', (buttons) => buttons.map((b) => b.getAttribute('data-idx')));
  const outHas = (idx, re, timeout) => until(([i, src]) => new RegExp(src).test(document.getElementById(`cell-out-${i}`).innerText), [idx, re.source], timeout);
  const mbText = (idx) => page.$eval(`#cell-out-${idx} .mb-view`, (view) => view.shadowRoot.querySelector('.mb-page').innerText);
  const mbStatus = (idx) => page.$eval(`#cell-out-${idx} .mb-status`, (el) => el.textContent);

  await page.goto(`${BASE}?lang=${lang}#rails-mvc`, { waitUntil: 'domcontentloaded' });
  await page.waitForSelector('#app', { state: 'visible', timeout: 120000 });
  check(`${lang}: the MVC lesson opens`, (await page.textContent('#lessonBody h2')).includes('MVC'));
  const [boot, db, app, routes, exercise] = await codeCells();

  await page.click(`.run-cell[data-idx="${boot}"]`);
  check(`${lang}: mvc: Rails boots`, await outHas(boot, /=> "8\.\d+\.\d+"/, 180000), await out(boot));
  await page.click(`.run-cell[data-idx="${db}"]`);
  check(`${lang}: mvc: three dishes in the app's database`, await outHas(db, /=> 3(\n|$)/, 180000), await out(db));
  await page.click(`.run-cell[data-idx="${app}"]`);
  check(`${lang}: mvc: the index lists the dishes from the database`,
        await until((i) => { const v = document.querySelector(`#cell-out-${i} .mb-view`); return v && v.shadowRoot && /CHF 4.50/.test(v.shadowRoot.textContent); }, app),
        await out(app));
  const links = await page.$eval(`#cell-out-${app} .mb-view`, (view) => [...view.shadowRoot.querySelectorAll('a')].map((a) => a.getAttribute('href')));
  check(`${lang}: mvc: link_to with a model object makes the paths`, links.length === 3 && links.every((h) => new RegExp(`^/${words.resource}/\\d+$`).test(h)), links.join(' '));
  check(`${lang}: mvc: the cheapest dish comes first`, (await mbText(app)).indexOf('CHF 2.00') < (await mbText(app)).indexOf('CHF 4.50'));
  await page.$eval(`#cell-out-${app} .mb-view`, (view) => view.shadowRoot.querySelector('a').click());
  check(`${lang}: mvc: the show action is missing, says Rails`, await until((i) => document.querySelector(`#cell-out-${i} .mb-status`).textContent === '404', app) && /could not be found/.test(await mbText(app)), await mbText(app));

  await page.click(`.run-cell[data-idx="${routes}"]`);
  check(`${lang}: mvc: the resources routes`, await outHas(routes, new RegExp(`GET\\s+/${words.resource}/:id\\(\\.:format\\)\\s+${words.resource}#show`)), await out(routes));

  await page.click(`.run-cell[data-idx="${exercise}"]`);
  // the view runs without the action (Rails renders a template on its own), with @dish nil
  check(`${lang}: mvc: the starter opens the first dish without an action`, await until((i) => (document.querySelector(`#cell-out-${i} .mb-status`) || {}).textContent === '500', exercise) && /for nil/.test(await mbText(exercise)), await out(exercise));
  check(`${lang}: mvc: the starter does not pass`, !(await page.getAttribute('#chunkyChat', 'class')).includes('pass'));
  const starter = await page.evaluate((i) => window.cellEditors[i].getValue(), exercise);
  const solution = starter.replace(/<h2>[^<]*<\/h2>/, `<h2><%= @${words.ivar}.name %></h2>`)
    .replace(`# def show\n  #   @${words.ivar} = ${words.model}.find(params[:id])\n  # end`, `def show\n    @${words.ivar} = ${words.model}.find(params[:id])\n  end`);
  check(`${lang}: mvc: the solution differs from the starter`, solution !== starter && solution.includes('def show') && !solution.includes('# def show'), solution);
  await page.evaluate(([i, c]) => window.cellEditors[i].setValue(c), [exercise, solution]);
  await page.click(`.run-cell[data-idx="${exercise}"]`);
  check(`${lang}: mvc: the solution passes`, await until(() => document.getElementById('chunkyChat').className.includes('pass'), null), await out(exercise));
  check(`${lang}: mvc: the show page has the dish`, (await mbStatus(exercise)) === '200' && /CHF 4.50/.test(await mbText(exercise)) && new RegExp(words.first).test(await mbText(exercise)), await mbText(exercise));
  await page.close();
};

// lesson `rails-forms`: the mini browser sends a form - the empty name comes
// back as 422 with its message, a dish is created, the redirect is followed
// and the flash shows once (a session cookie kept by the mini browser)
const runForms = async (lang, words) => {
  const page = await browser.newPage({ locale: lang === 'de' ? 'de-DE' : 'en-US' });
  page.on('pageerror', (e) => { console.log('[pageerror]', e.message); failures++; });
  const out = (idx) => page.evaluate((i) => document.getElementById(`cell-out-${i}`).innerText, idx);
  const until = (fn, arg, timeout = 90000) => page.waitForFunction(fn, arg, { timeout }).then(() => true, () => false);
  const codeCells = () => page.$$eval('.run-cell', (buttons) => buttons.map((b) => b.getAttribute('data-idx')));
  const outHas = (idx, re, timeout) => until(([i, src]) => new RegExp(src).test(document.getElementById(`cell-out-${i}`).innerText), [idx, re.source], timeout);
  const mbText = (idx) => page.$eval(`#cell-out-${idx} .mb-view`, (view) => view.shadowRoot.querySelector('.mb-page').innerText);
  const mbStatus = (idx) => page.$eval(`#cell-out-${idx} .mb-status`, (el) => el.textContent);
  const mbUrl = (idx) => page.$eval(`#cell-out-${idx} .mb-url`, (el) => el.value);
  const mbHas = (idx, re) => until(([i, src]) => { const v = document.querySelector(`#cell-out-${i} .mb-view`); return v && v.shadowRoot && new RegExp(src).test(v.shadowRoot.textContent); }, [idx, re.source]);
  const fill = (idx, name, value) => page.$eval(`#cell-out-${idx} .mb-view`, (view, [n, v]) => { view.shadowRoot.querySelector(`input[name="${n}"]`).value = v; }, [name, value]);
  const send = (idx) => page.$eval(`#cell-out-${idx} .mb-view`, (view) => view.shadowRoot.querySelector('input[type=submit]').click());

  await page.goto(`${BASE}?lang=${lang}#rails-forms`, { waitUntil: 'domcontentloaded' });
  await page.waitForSelector('#app', { state: 'visible', timeout: 120000 });
  check(`${lang}: the forms lesson opens`, /new|create/i.test(await page.textContent('#lessonBody h2')));
  const [boot, db, app, exercise] = await codeCells();

  await page.click(`.run-cell[data-idx="${boot}"]`);
  check(`${lang}: forms: Rails boots`, await outHas(boot, /=> "8\.\d+\.\d+"/, 180000), await out(boot));
  await page.click(`.run-cell[data-idx="${db}"]`);
  check(`${lang}: forms: the dishes`, await outHas(db, /=> 3(\n|$)/, 180000), await out(db));
  await page.click(`.run-cell[data-idx="${app}"]`);
  check(`${lang}: forms: the index with the link to the form`, await mbHas(app, /CHF 4.50/), await out(app));
  await page.$eval(`#cell-out-${app} .mb-view`, (view) => [...view.shadowRoot.querySelectorAll('a')].pop().click());
  check(`${lang}: forms: the new form`, await mbHas(app, new RegExp(words.newTitle)) && (await mbUrl(app)) === `/${words.resource}/new`, await mbText(app));
  // sent empty: 422, the message, the price typed still there
  await fill(app, `${words.param}[${words.price}]`, '1.5');
  await send(app);
  check(`${lang}: forms: an empty name comes back as 422 with the message`, await mbHas(app, /can't be blank/) && (await mbStatus(app)) === '422', await mbText(app));
  check(`${lang}: forms: what was typed is still in the form`, await page.$eval(`#cell-out-${app} .mb-view`, (view, n) => view.shadowRoot.querySelector(`input[name="${n}"]`).value, `${words.param}[${words.price}]`) === '1.5');
  // a dish: created, redirect followed, the flash once
  await fill(app, `${words.param}[name]`, 'Tea');
  await send(app);
  check(`${lang}: forms: created, redirected to the dish, the flash shown`, await mbHas(app, new RegExp(`Tea ${words.notice}`)) && (await mbStatus(app)) === '200' && /^\/\w+\/\d+$/.test(await mbUrl(app)), (await mbUrl(app)) + ' ' + await mbText(app));
  const log = await page.$eval(`#cell-out-${app} .mb-log`, (el) => el.innerText);
  check(`${lang}: forms: the log has the POST, the redirect and the GET after it`, /Started POST/.test(log) && /Redirected to/.test(log) && /INSERT INTO/.test(log), log.slice(-600));
  await page.$eval(`#cell-out-${app} .mb-view`, (view) => view.shadowRoot.querySelector('a').click());
  check(`${lang}: forms: back on the index, the flash is gone and Tea is listed`, await mbHas(app, /Tea/) && !new RegExp(words.notice).test(await mbText(app)), await mbText(app));

  await page.click(`.run-cell[data-idx="${exercise}"]`);
  check(`${lang}: forms: the starter's form has no price field`, await mbHas(exercise, new RegExp(words.newTitle)) && !(await page.$eval(`#cell-out-${exercise} .mb-view`, (view, n) => !!view.shadowRoot.querySelector(`input[name="${n}"]`), `${words.param}[${words.price}]`)), await mbText(exercise));
  check(`${lang}: forms: the starter does not pass`, !(await page.getAttribute('#chunkyChat', 'class')).includes('pass'));
  const starter = await page.evaluate((i) => window.cellEditors[i].getValue(), exercise);
  const solution = starter.replace(/<%#[^%]*%>/, `<%= ${words.builder}.label :${words.price} %>\n    <%= ${words.builder}.number_field :${words.price}, step: 0.1 %>`)
    .replace(`[:name]`, `[:name, :${words.price}]`);
  check(`${lang}: forms: the solution differs from the starter`, solution !== starter && solution.includes('number_field') && solution.includes(`:name, :${words.price}]`), solution);
  await page.evaluate(([i, c]) => window.cellEditors[i].setValue(c), [exercise, solution]);
  await page.click(`.run-cell[data-idx="${exercise}"]`);
  check(`${lang}: forms: the solution passes`, await until(() => document.getElementById('chunkyChat').className.includes('pass'), null), await out(exercise));
  await fill(exercise, `${words.param}[name]`, 'Juice');
  await fill(exercise, `${words.param}[${words.price}]`, '3');
  await send(exercise);
  check(`${lang}: forms: a dish with a price through the finished form`, await mbHas(exercise, /Juice/) && /CHF 3.00/.test(await mbText(exercise)), await mbText(exercise));
  await page.close();
};

await run('en', { home: 'home', hello: 'hello', bacon: 'bacon' });
await run('de', { home: 'start', hello: 'hallo', bacon: 'speck' });
await runModel('en', { db: 'diner.db', table: 'dishes', model: 'Guest', visits: 'visits' });
await runModel('de', { db: 'imbiss.db', table: 'gerichte', model: 'Gast', visits: 'besuche' });
await runMvc('en', { resource: 'dishes', model: 'Dish', ivar: 'dish', first: 'Bacon' });
await runMvc('de', { resource: 'gerichte', model: 'Gericht', ivar: 'gericht', first: 'Speck' });
await runForms('en', { resource: 'dishes', param: 'dish', price: 'price', builder: 'form', newTitle: 'New dish', notice: 'is on the menu' });
await runForms('de', { resource: 'gerichte', param: 'gericht', price: 'preis', builder: 'formular', newTitle: 'Neues Gericht', notice: 'steht auf der Speisekarte' });
// the Japanese lessons run the English code under the Japanese interface
await run('ja', { home: 'home', hello: 'hello', bacon: 'bacon' });
await runForms('ja', { resource: 'dishes', param: 'dish', price: 'price', builder: 'form', newTitle: 'New dish', notice: 'is on the menu' });

await browser.close();
console.log(failures === 0 ? 'ALL RAILS CHECKS OK' : `${failures} failures`);
process.exit(failures === 0 ? 0 : 1);
