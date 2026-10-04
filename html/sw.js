// Offline mode: the service worker (docs/HANDOVER.md §6c). offline.js
// registers it only when the learner asks for it in the progress dialog.
//
// Online it changes nothing: every request goes to the network as before,
// so a deploy is seen on the next load. Beside that it keeps a copy of the
// whole course - the files in offline-files.txt, one consistent version -
// and answers from it when the network does not: a page opened offline
// comes from the copy as a whole, never half old and half new.
//
// The copy is checked after each online visit (at most every 10 minutes):
// a HEAD per file, and only the files whose ETag / Last-Modified changed are
// fetched again. A new copy replaces the old one only once it is complete
// and a second check saw no deploy in the meantime. One cache holds every
// file under its version ("__offline__/f/<version>/<path>"), and
// "__offline__/index.json" says which version of each file the copy is made
// of; writing that index is the switch.
"use strict";

const STORE = "chunky-offline-1";            // a new format gets a new name
const LIST = "offline-files.txt";
const RECHECK_MS = 10 * 60 * 1000;
const NAV_TIMEOUT_MS = 6000;                 // a page from the copy rather than a hanging one
// answered by the network or not at all: the backend, the bridges, the webhook
const NETWORK_ONLY = /^(api|rubygems|proxy|_deploy)(\/|$)/;
// Python for the PyCall lessons: in the copy unless the learner unticked it
// (offline.js sends the choice with every refresh)
const PYTHON = /^assets\/pyodide\//;

const base = new URL(self.registration.scope);
const INDEX_URL = new URL("__offline__/index.json", base).href;
const FILE_PREFIX = new URL("__offline__/f/", base).href;

let snapshotPromise = null;   // the index of the current copy, or null
let building = null;          // the running update, a Promise
let buildingPython = true;    // ... with Python or without
let progress = { done: 0, total: 0, bytes: 0 };
let lastError = null;
let lastCheck = 0;
let stopping = false;
const fromCopy = new Set();   // clients whose page came from the copy

// ---------- the copy ----------

function urlFor(path) {
  return new URL(path.split("/").map(encodeURIComponent).join("/"), base).href;
}
function keyFor(path, version) {
  return FILE_PREFIX + encodeURIComponent(version) + "/" + encodeURIComponent(path);
}

// what identifies a file's version without its bytes; W/ only marks the
// ETag of a response nginx compressed on the fly
function versionOf(response) {
  const etag = response.headers.get("ETag");
  if (etag) return "e" + etag.replace(/^W\//, "");
  const modified = response.headers.get("Last-Modified");
  return modified ? "m" + modified : null;
}

async function digest(blob) {
  const hash = await crypto.subtle.digest("SHA-256", await blob.arrayBuffer());
  return Array.from(new Uint8Array(hash).slice(0, 12), (b) => b.toString(16).padStart(2, "0")).join("");
}

async function loadSnapshot() {
  if (!snapshotPromise) {
    snapshotPromise = (async () => {
      if (!(await caches.has(STORE))) return null;
      const response = await (await caches.open(STORE)).match(INDEX_URL);
      return response ? response.json() : null;
    })().catch(() => null);
  }
  return snapshotPromise;
}

async function copyOf(path) {
  const snapshot = await loadSnapshot();
  const entry = snapshot && snapshot.files[path];
  if (!entry) return null;
  return (await caches.open(STORE)).match(keyFor(path, entry.v));
}

async function fetchList(python) {
  const response = await fetch(urlFor(LIST), { cache: "no-cache" });
  if (!response.ok) throw new Error(LIST + ": HTTP " + response.status);
  const files = (await response.text()).split("\n").map((line) => line.trim())
    .filter((line) => line !== "" && !line.startsWith("#") && (python || !PYTHON.test(line)));
  return [""].concat(files);   // "" is the page as the site answers "./"
}

async function headVersion(path) {
  try {
    const response = await fetch(urlFor(path), { method: "HEAD", cache: "no-store" });
    return response.ok ? versionOf(response) : null;
  } catch (e) {
    return null;
  }
}

// runs fn over items, `limit` at a time; stops at the first error
async function pool(items, limit, fn) {
  const results = new Array(items.length);
  let next = 0;
  async function worker() {
    while (next < items.length) {
      if (stopping) throw new Error("stopped");
      const i = next++;
      results[i] = await fn(items[i], i);
    }
  }
  await Promise.all(Array.from({ length: Math.min(limit, items.length) }, worker));
  return results;
}

async function store(cache, path) {
  const response = await fetch(urlFor(path), { cache: "no-cache" });
  if (response.status === 404) return null;   // listed but gone: offline-files.txt is out of date
  if (!response.ok) throw new Error(path + ": HTTP " + response.status);
  const blob = await response.blob();
  const version = versionOf(response) || "d" + await digest(blob);
  // the body is stored decoded, so no Content-Encoding / Content-Length
  const headers = new Headers({ "X-Chunky-Size": String(blob.size) });
  ["Content-Type", "ETag", "Last-Modified"].forEach((name) => {
    if (response.headers.get(name)) headers.set(name, response.headers.get(name));
  });
  await cache.put(keyFor(path, version), new Response(blob, { status: 200, headers: headers }));
  progress.bytes += blob.size;
  return { v: version, size: blob.size };
}

async function update(python) {
  const list = await fetchList(python);
  const cache = await caches.open(STORE);
  const old = await loadSnapshot();
  let files = {};
  for (let attempt = 0; attempt < 3; attempt++) {
    const versions = await pool(list, 8, headVersion);
    files = {};
    const todo = [];
    await pool(list, 8, async (path, i) => {
      const version = versions[i];
      const hit = version && await cache.match(keyFor(path, version));
      if (hit) files[path] = { v: version, size: Number(hit.headers.get("X-Chunky-Size")) || 0 };
      else todo.push(path);
    });
    progress = { done: 0, total: todo.length, bytes: 0 };
    tell();
    await pool(todo, 4, async (path) => {
      const entry = await store(cache, path);
      if (entry) files[path] = entry;
      progress.done += 1;
      tell();
    });
    // a deploy while this ran would leave a mix: check once more
    const again = await pool(list, 8, headVersion);
    const moved = list.filter((path, i) => again[i] && files[path] && again[i] !== files[path].v);
    if (moved.length === 0) break;
    if (attempt === 2) throw new Error("the site changed while it was being saved: " + moved.slice(0, 3).join(", "));
  }

  const same = old && Object.keys(files).length === Object.keys(old.files).length &&
    Object.keys(files).every((path) => old.files[path] && old.files[path].v === files[path].v);
  if (!same) {
    const bytes = Object.values(files).reduce((sum, entry) => sum + entry.size, 0);
    const index = { savedAt: Date.now(), bytes: bytes, count: Object.keys(files).length, files: files };
    await cache.put(INDEX_URL, new Response(JSON.stringify(index), { headers: { "Content-Type": "application/json" } }));
    snapshotPromise = Promise.resolve(index);
    // the files no copy refers to any more
    const keep = new Set(Object.keys(files).map((path) => keyFor(path, files[path].v)));
    for (const request of await cache.keys()) {
      if (request.url.startsWith(FILE_PREFIX) && !keep.has(request.url)) await cache.delete(request);
    }
  }
}

function refresh(force, python) {
  // the box ticked or unticked while a copy is being made: another one after it
  if (building) return python === buildingPython ? building : building.then(() => refresh(true, python));
  if (!force && Date.now() - lastCheck < RECHECK_MS) return Promise.resolve();
  lastCheck = Date.now();
  progress = { done: 0, total: 0, bytes: 0 };
  buildingPython = python;
  building = update(python).then(() => { lastError = null; }, (error) => {
    lastError = error && error.message ? error.message : String(error);
    console.warn("offline copy not updated:", lastError);
  }).finally(() => {
    building = null;
    tell();
  });
  tell();
  return building;
}

// ---------- what the page sees (offline.js) ----------

async function status(clientId) {
  const snapshot = await loadSnapshot();
  return {
    type: "status",
    state: snapshot ? "ready" : (building ? "loading" : (lastError ? "error" : "empty")),
    // a newer copy is being downloaded (not just checked for)
    updating: Boolean(building && snapshot && progress.total > 0),
    done: progress.done, total: progress.total, bytes: progress.bytes,
    savedAt: snapshot ? snapshot.savedAt : null,
    size: snapshot ? snapshot.bytes : 0,
    count: snapshot ? snapshot.count : 0,
    error: lastError,
    fromCopy: fromCopy.has(clientId)
  };
}

async function tell() {
  const windows = await self.clients.matchAll({ type: "window", includeUncontrolled: true });
  for (const client of windows) client.postMessage(await status(client.id));
}

async function stop() {
  stopping = true;
  if (building) await building;
  await caches.delete(STORE);
  snapshotPromise = null;
  lastError = null;
  lastCheck = 0;
  progress = { done: 0, total: 0, bytes: 0 };
  stopping = false;
}

self.addEventListener("message", (event) => {
  const data = event.data || {};
  const source = event.source;
  let work = Promise.resolve();
  if (data.type === "refresh") work = refresh(Boolean(data.force), data.python !== false);
  if (data.type === "disable") work = stop().then(() => source.postMessage({ type: "disabled" }));
  if (data.type === "status") work = status(source.id).then((s) => source.postMessage(s));
  event.waitUntil(work);
});

// ---------- answering requests ----------

function pathOf(url) {
  if (url.origin !== base.origin || !url.pathname.startsWith(base.pathname)) return null;
  try {
    return decodeURIComponent(url.pathname.slice(base.pathname.length));
  } catch (e) {
    return null;
  }
}

// what a page asking for something the copy lacks gets while offline:
// index.html's fetch helpers turn it into "ERROR offline" for main.rb
function offlineAnswer() {
  return new Response("offline", {
    status: 503,
    headers: { "Content-Type": "text/plain; charset=utf-8", "X-Chunky-Offline": "1" }
  });
}

function withTimeout(promise, ms) {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error("timeout")), ms);
    promise.then((value) => { clearTimeout(timer); resolve(value); },
      (error) => { clearTimeout(timer); reject(error); });
  });
}

// a 5xx is the server (or the proxy in front of it) being away: the copy
// answers it like a network error
function failed(response) {
  if (response.status >= 500) throw new Error("HTTP " + response.status);
  return response;
}

// a page from the copy says so (offline.js reads it before the kernel starts)
async function marked(response) {
  if (!(response.headers.get("Content-Type") || "").startsWith("text/html")) return response;
  const html = (await response.text())
    .replace('<meta charset="UTF-8">', (charset) => charset + '\n    <meta name="chunky-offline-copy" content="1">');
  return new Response(html, { status: 200, headers: response.headers });
}

async function navigate(event, path) {
  if (!(await loadSnapshot())) return fetch(event.request);
  try {
    return failed(await withTimeout(fetch(event.request), NAV_TIMEOUT_MS));
  } catch (error) {
    // a file of the course as itself; any other address is the page, which
    // routes by itself (with the server's permalinks, if the copy has them)
    const copy = (path && await copyOf(path)) || await copyOf("");
    if (!copy) throw error;
    fromCopy.add(event.resultingClientId);
    return marked(copy);
  }
}

async function resource(event, path) {
  // a page from the copy takes all of its files from the copy too
  if (fromCopy.has(event.clientId)) {
    const copy = await copyOf(path);
    if (copy) return copy;
  }
  try {
    return failed(await fetch(event.request));
  } catch (error) {
    const copy = await copyOf(path);
    if (copy) {
      fromCopy.add(event.clientId);
      return copy;
    }
    if (!(await loadSnapshot())) throw error;
    return offlineAnswer();
  }
}

self.addEventListener("fetch", (event) => {
  const request = event.request;
  if (request.method !== "GET") return;
  const path = pathOf(new URL(request.url));
  if (path === null || path.startsWith("__offline__/")) return;
  if (NETWORK_ONLY.test(path)) {
    event.respondWith(fetch(request).catch(() => offlineAnswer()));
  } else if (request.mode === "navigate") {
    event.respondWith(navigate(event, path));
  } else {
    event.respondWith(resource(event, path));
  }
});

self.addEventListener("install", () => self.skipWaiting());
self.addEventListener("activate", (event) => {
  event.waitUntil((async () => {
    // copies in an older format
    for (const name of await caches.keys()) {
      if (name.startsWith("chunky-offline-") && name !== STORE) await caches.delete(name);
    }
    await self.clients.claim();
  })());
});
