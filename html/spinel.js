// The Spinel lesson below the cell (spinel.rb: spinel(code), show_spinel_irb).
// Spinel (github.com/matz/spinel) compiles Ruby ahead of time: here its
// compiler and clang are WebAssembly in a worker (spinel-worker.js), the
// program runs in a worker of its own (spinel-run-worker.js), and this file
// draws what happens - the steps with their times, the program's output,
// the C it was compiled through, the module to download, and how it compares
// with CRuby, which ran the same code in the kernel.
//
//   ChunkySpinel.ensure()                      start loading (~27 MB, once)
//   ChunkySpinel.mount(node, json)             a program: {source, cruby, labels, lang}
//   ChunkySpinel.irb(node, json, complete)     IRB; complete(src) -> "ok" | "more" | "error <message>"
(function () {
  'use strict';
  var S = window.ChunkySpinel = { state: 'idle', version: null, error: null, progress: null };
  var RUN_LIMIT = 10;   // seconds a program may run
  var worker = null, seq = 0, pending = {}, watchers = [];

  function notify() { watchers = watchers.filter(function (fn) { return fn() !== false; }); }

  S.ensure = function () {
    if (worker) return;
    S.state = 'loading';
    S.error = null;
    worker = new Worker(new URL('spinel-worker.js', document.baseURI), { type: 'module' });
    worker.onmessage = function (event) {
      var m = event.data;
      if (m.type === 'progress') { S.progress = m; notify(); }
      else if (m.type === 'ready') { S.state = 'ready'; S.version = m.version; notify(); }
      else if (m.type === 'failed') {
        S.state = 'failed';
        S.error = m.error;
        worker.terminate();
        worker = null;   // the next ensure() tries again
        Object.keys(pending).forEach(function (id) { pending[id]({ ok: false, stage: 'load', messages: m.error }); delete pending[id]; });
        notify();
      } else if (m.type === 'built' && pending[m.id]) { pending[m.id](m); delete pending[m.id]; }
    };
    worker.onerror = function (event) {
      worker.onmessage({ data: { type: 'failed', error: event.message || 'the worker did not start' } });
    };
    worker.postMessage({ type: 'load' });
  };

  // the shell's name for it, beside ensureHerb (shell/app.rb)
  window.ensureSpinel = function () { S.ensure(); };

  // Ruby -> a module: { ok, stage, c, wasm, messages, ms }
  S.build = function (source) {
    S.ensure();
    return new Promise(function (resolve) {
      var id = ++seq;
      pending[id] = resolve;
      worker.postMessage({ type: 'build', id: id, source: source });
    });
  };

  // runs a module in a worker of its own: { code, stdout, stderr, ms, stopped, crashed }
  S.run = function (wasm, options) {
    options = options || {};
    return new Promise(function (resolve) {
      var runner = new Worker(new URL('spinel-run-worker.js', document.baseURI), { type: 'module' });
      var stdout = '', stderr = '', started = performance.now();
      var finish = function (result) {
        clearTimeout(timer);
        runner.terminate();
        result.stdout = stdout;
        result.stderr = (result.stderr || stderr).replace(/\/work\//g, '').trim();
        if (result.ms === undefined) result.ms = performance.now() - started;
        resolve(result);
      };
      var timer = setTimeout(function () { finish({ code: -1, stopped: true }); }, (options.limit || RUN_LIMIT) * 1000);
      runner.onmessage = function (event) {
        var m = event.data;
        if (m.type === 'out') {
          if (m.fd === 1) stdout += m.text; else stderr += m.text;
          if (options.onOut) options.onOut(m.fd, m.text);
          if (options.alive && !options.alive()) finish({ code: -1, stopped: true });
        } else if (m.type === 'done') finish({ code: m.code, ms: m.ms });
        else if (m.type === 'crashed') finish({ code: -1, crashed: m.error });
      };
      runner.onerror = function (event) { finish({ code: -1, crashed: event.message || 'the program did not start' }); };
      runner.postMessage({ wasm: wasm, stdin: options.stdin || '' }, []);
    });
  };

  // ------------------------------------------------------------ helpers

  function el(tag, cls, text) {
    var node = document.createElement(tag);
    if (cls) node.className = cls;
    if (text !== undefined) node.textContent = text;
    return node;
  }
  function fill(template, value) { return String(template).replace(/%s/, value); }
  function seconds(ms, lang) {
    if (ms < 1000) return Math.max(1, Math.round(ms)) + ' ms';
    return new Intl.NumberFormat(lang, { maximumFractionDigits: 1, minimumFractionDigits: 1 }).format(ms / 1000) + ' s';
  }
  function size(bytes, lang) {
    return new Intl.NumberFormat(lang, { maximumFractionDigits: 1 }).format(bytes / 1024) + ' KB';
  }

  // the loading line: what is fetched, how far
  function loadingText(labels, lang) {
    var p = S.progress;
    if (p && p.part === 'clang' && p.total) {
      return labels.load + ' – ' + Math.round(100 * p.done / p.total) + ' %';
    }
    return labels.load + ' …';
  }

  // waits for the toolchain, keeping +line+ up to date; false when it failed
  function whenReady(line, labels, lang, alive) {
    S.ensure();
    if (S.state === 'ready') return Promise.resolve(true);
    return new Promise(function (resolve) {
      var update = function () {
        if (!alive()) { resolve(false); return false; }
        if (S.state === 'ready') { resolve(true); return false; }
        if (S.state === 'failed') { resolve(false); return false; }
        line.textContent = loadingText(labels, lang);
        return true;
      };
      if (update()) watchers.push(update);
    });
  }

  function failedText(labels) {
    return navigator.onLine === false ? labels.offline : fill(labels.failed, S.error || '?');
  }

  // ---------------------------------------------------------- a program

  S.mount = function (node, json) {
    var opts = JSON.parse(json), labels = opts.labels, lang = opts.lang;
    var alive = function () { return node.isConnected; };
    var box = el('section', 'spinel-box');
    box.setAttribute('aria-label', labels.title);
    var head = el('div', 'spinel-head');
    head.appendChild(el('span', 'spinel-name', 'Spinel'));
    var version = el('span', 'spinel-version');
    head.appendChild(version);
    box.appendChild(head);
    var steps = el('ol', 'spinel-steps');
    box.appendChild(steps);
    var status = el('p', 'spinel-status');
    status.setAttribute('role', 'status');
    box.appendChild(status);
    node.appendChild(box);

    function step(text) {
      var li = el('li', 'spinel-step is-busy');
      li.appendChild(el('span', 'spinel-step-name', text));
      var time = el('span', 'spinel-step-time', '…');
      li.appendChild(time);
      steps.appendChild(li);
      return {
        done: function (ms, ok) {
          li.classList.remove('is-busy');
          li.classList.add(ok === false ? 'is-failed' : 'is-done');
          time.textContent = ms === null ? '' : seconds(ms, lang);
        }
      };
    }
    function problem(title, text) {
      var div = el('div', 'spinel-problem');
      div.appendChild(el('strong', null, title));
      if (text) div.appendChild(el('pre', null, text));
      box.appendChild(div);
    }

    var loading = step(labels.load);
    var loadStarted = performance.now();
    whenReady(steps.lastChild.firstChild, labels, lang, alive).then(function (ok) {
      if (!alive()) return;
      steps.lastChild.firstChild.textContent = labels.load;
      if (!ok) {
        loading.done(null, false);
        status.textContent = failedText(labels);
        problem(failedText(labels));
        return;
      }
      // already there: the line says so without a time
      loading.done(performance.now() - loadStarted < 50 ? null : performance.now() - loadStarted);
      version.textContent = S.version;
      var compiling = step(labels.compile);
      status.textContent = labels.compile + ' …';
      var linking = null;
      S.build(opts.source).then(function (built) {
        if (!alive()) return;
        compiling.done(built.ms && built.ms.spinel, built.stage !== 'spinel');
        if (built.stage === 'spinel' || built.stage === 'load') {
          status.textContent = labels.refused;
          problem(labels.refused, built.messages);
          if (built.stage === 'spinel') compare(null);
          return;
        }
        linking = step(labels.link);
        linking.done(built.ms.clang, built.ok);
        if (built.c) {
          var details = el('details', 'spinel-c');
          details.appendChild(el('summary', null, fill(labels.showC, size(built.c.length, lang))));
          details.appendChild(el('pre', null, built.c));
          box.appendChild(details);
        }
        if (!built.ok) {
          status.textContent = labels.ccFailed;
          problem(labels.ccFailed, built.messages);
          return;
        }
        var running = step(labels.run);
        status.textContent = labels.run + ' …';
        var out = el('pre', 'spinel-out cell-stdout');
        box.insertBefore(out, box.querySelector('.spinel-c'));
        S.run(built.wasm, {
          alive: alive,
          onOut: function (fd, text) { if (fd === 1) out.textContent += text; }
        }).then(function (ran) {
          if (!alive()) return;
          running.done(ran.ms, ran.code === 0);
          if (!out.textContent) out.remove();
          if (ran.stopped) problem(fill(labels.stopped, RUN_LIMIT));
          else if (ran.crashed) problem(fill(labels.crashed, ran.crashed));
          else if (ran.code !== 0) problem(fill(labels.exit, ran.code), ran.stderr);
          var download = el('a', 'cell-download spinel-download', fill(labels.download, size(built.wasm.byteLength, lang)));
          download.href = URL.createObjectURL(new Blob([built.wasm], { type: 'application/wasm' }));
          download.download = 'main.wasm';
          download.title = labels.downloadTitle;
          box.appendChild(download);
          compare(ran);
        });
      });
    });

    // what CRuby printed when it ran the same code (spinel.rb), beside Spinel's
    function compare(ran) {
      var cruby = opts.cruby;
      if (!cruby) return;
      var row = el('p', 'spinel-compare');
      var same = !!ran && !cruby.error && ran.code === 0 && cruby.output === ran.stdout;
      if (cruby.error) row.textContent = fill(labels.crubyError, cruby.error);
      // Spinel refused it: what CRuby, the interpreter, makes of it
      else if (!ran) {
        row.textContent = labels.crubyOnly;
        row.appendChild(el('pre', 'cell-stdout', cruby.output));
        row.classList.add('is-cruby');
        box.appendChild(row);
        return;
      }
      else if (same) row.textContent = fill(labels.same, seconds(cruby.ms, lang));
      else {
        row.textContent = fill(labels.differs, seconds(cruby.ms, lang));
        row.appendChild(el('pre', 'cell-stdout', cruby.output));
      }
      row.classList.add(same ? 'is-same' : 'is-different');
      box.appendChild(row);
      status.textContent = row.textContent.split('\n')[0];
    }
  };

  // ---------------------------------------------------------------- IRB

  S.irb = function (node, json, complete) {
    var opts = JSON.parse(json), labels = opts.labels, lang = opts.lang;
    var alive = function () { return node.isConnected; };
    var term = el('div', 'spinel-term');
    term.setAttribute('role', 'group');
    term.setAttribute('aria-label', labels.irbTitle);
    var history = el('div', 'spinel-term-history');
    history.setAttribute('role', 'log');
    history.setAttribute('aria-live', 'polite');
    history.appendChild(el('div', 'spinel-term-note', labels.irbNote));
    var row = el('div', 'spinel-term-line');
    var prompt = el('span', 'spinel-term-prompt');
    prompt.setAttribute('aria-hidden', 'true');
    var input = el('input', 'spinel-term-input');
    input.spellcheck = false;
    input.autocomplete = 'off';
    input.setAttribute('aria-label', labels.irbInput);
    row.appendChild(prompt);
    row.appendChild(input);
    term.appendChild(history);
    term.appendChild(row);
    node.appendChild(term);

    var number = 1, buffer = [], past = [], back = 0, session = null, busy = false;
    var promptText = function () {
      var n = String(number);
      while (n.length < 3) n = '0' + n;
      return 'spinel(main):' + n + ':' + buffer.length + (buffer.length ? '*' : '>');
    };
    prompt.textContent = promptText();
    var say = function (cls, text) {
      var div = el(cls === 'out' ? 'pre' : 'div', 'spinel-term-' + cls, text);
      history.appendChild(div);
      history.scrollTop = history.scrollHeight;
      return div;
    };

    var line = say('note', '');
    whenReady(line, labels, lang, alive).then(function (ok) {
      if (!alive()) return;
      line.textContent = ok ? fill(labels.irbReady, S.version) : failedText(labels);
    });
    import(new URL('spinel-build.js', document.baseURI).href).then(function (module) {
      session = new module.SpinelIrb({ build: S.build });
    });

    input.addEventListener('keydown', function (event) {
      if (event.key === 'ArrowUp' || event.key === 'ArrowDown') {
        if (!past.length) return;
        event.preventDefault();
        back = Math.max(0, Math.min(past.length, back + (event.key === 'ArrowUp' ? 1 : -1)));
        input.value = back ? past[past.length - back] : '';
        return;
      }
      if (event.key !== 'Enter' || busy) return;
      event.preventDefault();
      var text = input.value;
      input.value = '';
      back = 0;
      say('echo', promptText() + ' ' + text);
      if (/^\s*(exit|quit)\s*$/.test(text) && !buffer.length) { say('note', labels.irbExit); return; }
      if (text.trim()) past.push(text);
      buffer.push(text);
      var source = buffer.join('\n');
      var verdict = String(complete(source) || 'ok');
      if (verdict === 'more') { prompt.textContent = promptText(); return; }
      buffer = [];
      if (verdict.indexOf('error') === 0) {
        say('error', verdict.slice(6));
        number++;
        prompt.textContent = promptText();
        return;
      }
      if (!source.trim()) { prompt.textContent = promptText(); return; }
      busy = true;
      input.disabled = true;
      var wait = say('note', labels.irbBusy);
      var started = performance.now();
      (session ? Promise.resolve() : new Promise(function (r) { var t = setInterval(function () { if (session) { clearInterval(t); r(); } }, 50); }))
        .then(function () { return session.submit(source, function (wasm) { return S.run(wasm, { alive: alive }).then(function (ran) { return ran; }); }); })
        .then(function (r) {
          if (!alive()) return;
          wait.remove();
          if (r.output) say('out', r.output);
          if (r.ok) say('result', '=> ' + r.value);
          else say('error', r.stage === 'spinel' ? labels.refused + '\n' + r.messages : (r.messages || ''));
          var ms = r.ms || {};
          say('time', [ms.spinel, ms.clang, ms.run].filter(function (x) { return x !== undefined; })
            .map(function (x) { return seconds(x, lang); }).join(' + ') + ' (' + seconds(performance.now() - started, lang) + ')');
          number++;
        })
        .catch(function (error) { say('error', String((error && error.message) || error)); })
        .then(function () {
          busy = false;
          input.disabled = false;
          prompt.textContent = promptText();
          if (alive()) input.focus();
        });
    });
  };
})();
