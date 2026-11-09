// The JRuby lesson's Swing bonus, inside its iframe (jruby_swing.html,
// docs/HANDOVER.md §6t): boots JRuby 9.4 on CheerpJ as soon as the page
// opens - the lesson opens it only on the learner's click - then loads
// Glimmer in the background and builds one hidden window, so the first real
// window takes 1-2 s instead of 5-7 s. Four cells share one Ruby runtime
// (TOPLEVEL_BINDING): the fox with data binding, a Celsius converter, a
// JFreeChart pie from a Ruby Hash, FlatLaf's dark mode.
//
//   ?lang=de|en|ja|fr|it  the texts (the Java windows' own strings stay
//                      English for ja, fr and it - CheerpJ's Swing fonts have
//                      no CJK, and the lessons' fr/it code is en's)
//
// To the lesson (parent): {chunkySwing: "height", height} whenever the page
// grows, so the iframe needs no scroll bar of its own. For tests:
// window.swingLab = {ready(), failed(), timings, run(name), eval(code)}.
import { bootJRuby } from "./jruby_swing_boot.js";

const JARS = "assets/jruby-swing/";
const params = new URLSearchParams(location.search);
const $ = id => document.getElementById(id);

const TEXTS = {
  en: {
    start: "Starting CheerpJ, the JVM …", runtime: "Downloading the Java runtime … %d/%t",
    jar: "Loading the JRuby jar …", boot: "Booting the Ruby runtime (the slow part) …", warm: "Warming up the interpreter …",
    glimmer: "Loading Glimmer and building a hidden test window …",
    ready: "Ready: JRuby %v (Ruby %r) on Java %j, %s s after the click.",
    failed: "CheerpJ could not start: %m", offline: "CheerpJ's loader (cjrtnc.leaningtech.com) could not be loaded – offline?",
    run: "▶ Run", waiting: "waiting for JRuby …", running: "running …",
    banner: "The bottom strip of the window area is CheerpJ's own notice (its Community License asks for it). The windows can be dragged by their title bars.",
    credits: "JRuby 9.4.15 (EPL-2.0/GPL-2.0/LGPL-2.1) on <a href='https://cheerpj.com/' target='_blank' rel='noopener'>CheerpJ</a> 4.3 by Leaning Technologies (runtime from their CDN, Community License); Glimmer DSL for Swing (MIT), JFreeChart (LGPL-2.1), FlatLaf (Apache-2.0). Licenses: THIRD_PARTY_NOTICES.md.",
    cells: {
      fox: "A window is a few nested blocks. <code>observe</code> ties the label to the fox: click the button above.",
      feed: "Data binding works from Ruby's side too: change the fox here, and the window follows.",
      temp: "Your turn: type a temperature into the window's field.",
      chart: "<a href='https://www.jfree.org/jfreechart/' target='_blank' rel='noopener'>JFreeChart</a>, a Java library, draws a Ruby Hash.",
      dark: "<a href='https://www.formdev.com/flatlaf/' target='_blank' rel='noopener'>FlatLaf</a>: every window in dark mode, with one call."
    }
  },
  de: {
    start: "CheerpJ, die JVM, startet …", runtime: "Die Java-Laufzeit wird geladen … %d/%t",
    jar: "Das JRuby-Jar wird geladen …", boot: "Ruby startet (der langsame Teil) …", warm: "Der Interpreter wärmt sich auf …",
    glimmer: "Glimmer wird geladen, ein unsichtbares Testfenster gebaut …",
    ready: "Bereit: JRuby %v (Ruby %r) auf Java %j, %s s nach dem Klick.",
    failed: "CheerpJ konnte nicht starten: %m", offline: "Der Lader von CheerpJ (cjrtnc.leaningtech.com) liess sich nicht laden – offline?",
    run: "▶ Ausführen", waiting: "warte auf JRuby …", running: "läuft …",
    banner: "Der Streifen unten im Fensterbereich ist der Hinweis von CheerpJ selbst (seine Community-Lizenz verlangt ihn). Die Fenster lassen sich an der Titelleiste verschieben.",
    credits: "JRuby 9.4.15 (EPL-2.0/GPL-2.0/LGPL-2.1) auf <a href='https://cheerpj.com/' target='_blank' rel='noopener'>CheerpJ</a> 4.3 von Leaning Technologies (Laufzeit von deren CDN, Community-Lizenz); Glimmer DSL for Swing (MIT), JFreeChart (LGPL-2.1), FlatLaf (Apache-2.0). Lizenzen: THIRD_PARTY_NOTICES.md.",
    cells: {
      fox: "Ein Fenster ist ein paar verschachtelte Blöcke. <code>observe</code> bindet das Label an den Fuchs: Klick oben auf den Knopf.",
      feed: "Data Binding geht auch von Ruby aus: Ändere hier den Fuchs, und das Fenster zieht nach.",
      temp: "Du bist dran: Tipp im Fenster eine Temperatur ein.",
      chart: "<a href='https://www.jfree.org/jfreechart/' target='_blank' rel='noopener'>JFreeChart</a>, eine Java-Bibliothek, zeichnet einen Ruby-Hash.",
      dark: "<a href='https://www.formdev.com/flatlaf/' target='_blank' rel='noopener'>FlatLaf</a>: alle Fenster im Dunkelmodus, mit einem Aufruf."
    }
  },
  ja: {
    start: "JVMのCheerpJを起動しています …", runtime: "Javaのランタイムを読み込んでいます … %d/%t",
    jar: "JRubyのjarを読み込んでいます …", boot: "Rubyを起動しています（時間のかかる部分）…", warm: "インタープリターを温めています …",
    glimmer: "Glimmerを読み込み、見えないテスト用ウィンドウを作っています …",
    ready: "準備完了：Java %j上のJRuby %v（Ruby %r）、クリックから%s秒。",
    failed: "CheerpJを起動できませんでした：%m", offline: "CheerpJのローダー（cjrtnc.leaningtech.com）を読み込めませんでした。オフラインですか？",
    run: "▶ 実行", waiting: "JRubyを待っています …", running: "実行中 …",
    banner: "ウィンドウ領域の下の帯は、CheerpJ自身の表示です（Community Licenseの条件）。ウィンドウはタイトルバーでドラッグできます。",
    credits: "JRuby 9.4.15（EPL-2.0/GPL-2.0/LGPL-2.1）、Leaning Technologiesの<a href='https://cheerpj.com/' target='_blank' rel='noopener'>CheerpJ</a> 4.3（ランタイムは同社のCDNから、Community License）、Glimmer DSL for Swing（MIT）、JFreeChart（LGPL-2.1）、FlatLaf（Apache-2.0）。ライセンス：THIRD_PARTY_NOTICES.md",
    cells: {
      fox: "ウィンドウはブロックを入れ子にするだけ。<code>observe</code> がラベルをキツネに結びつけます。上のボタンを押してみてください。",
      feed: "データバインディングはRubyの側からも効きます。ここでキツネを変えると、ウィンドウもついてきます。",
      temp: "あなたの番です。ウィンドウの入力欄に温度を入れてみましょう。",
      chart: "Javaのライブラリ<a href='https://www.jfree.org/jfreechart/' target='_blank' rel='noopener'>JFreeChart</a>がRubyのHashを描きます。",
      dark: "<a href='https://www.formdev.com/flatlaf/' target='_blank' rel='noopener'>FlatLaf</a>：呼び出しひとつで、すべてのウィンドウがダークモードに。"
    }
  },
  fr: {
    start: "Démarrage de CheerpJ, la JVM …", runtime: "Téléchargement de l'environnement Java … %d/%t",
    jar: "Chargement du jar JRuby …", boot: "Démarrage de Ruby (la partie lente) …", warm: "L'interpréteur se met en route …",
    glimmer: "Chargement de Glimmer et construction d'une fenêtre de test invisible …",
    ready: "Prêt : JRuby %v (Ruby %r) sur Java %j, %s s après le clic.",
    failed: "CheerpJ n'a pas pu démarrer : %m", offline: "Le chargeur de CheerpJ (cjrtnc.leaningtech.com) n'a pas pu être chargé – hors ligne ?",
    run: "▶ Exécuter", waiting: "en attente de JRuby …", running: "en cours …",
    banner: "La bande en bas de la zone des fenêtres est la mention de CheerpJ lui-même (sa Community License l'exige). Les fenêtres se déplacent par leur barre de titre.",
    credits: "JRuby 9.4.15 (EPL-2.0/GPL-2.0/LGPL-2.1) sur <a href='https://cheerpj.com/' target='_blank' rel='noopener'>CheerpJ</a> 4.3 de Leaning Technologies (environnement depuis leur CDN, Community License) ; Glimmer DSL for Swing (MIT), JFreeChart (LGPL-2.1), FlatLaf (Apache-2.0). Licences : THIRD_PARTY_NOTICES.md.",
    cells: {
      fox: "Une fenêtre, ce sont quelques blocs imbriqués. <code>observe</code> lie le libellé au renard : cliquez sur le bouton ci-dessus.",
      feed: "La liaison de données marche aussi depuis Ruby : changez le renard ici, et la fenêtre suit.",
      temp: "À vous : tapez une température dans le champ de la fenêtre.",
      chart: "<a href='https://www.jfree.org/jfreechart/' target='_blank' rel='noopener'>JFreeChart</a>, une bibliothèque Java, dessine un Hash Ruby.",
      dark: "<a href='https://www.formdev.com/flatlaf/' target='_blank' rel='noopener'>FlatLaf</a> : toutes les fenêtres en mode sombre, en un seul appel."
    }
  },
  it: {
    start: "Avvio di CheerpJ, la JVM …", runtime: "Download del runtime Java … %d/%t",
    jar: "Caricamento del jar di JRuby …", boot: "Avvio di Ruby (la parte lenta) …", warm: "L'interprete si sta scaldando …",
    glimmer: "Caricamento di Glimmer e costruzione di una finestra di prova nascosta …",
    ready: "Pronto: JRuby %v (Ruby %r) su Java %j, %s s dopo il clic.",
    failed: "CheerpJ non è riuscito ad avviarsi: %m", offline: "Il loader di CheerpJ (cjrtnc.leaningtech.com) non si è caricato – sei offline?",
    run: "▶ Esegui", waiting: "in attesa di JRuby …", running: "in esecuzione …",
    banner: "La striscia in fondo all'area delle finestre è l'avviso di CheerpJ stesso (lo richiede la sua Community License). Le finestre si spostano trascinando la barra del titolo.",
    credits: "JRuby 9.4.15 (EPL-2.0/GPL-2.0/LGPL-2.1) su <a href='https://cheerpj.com/' target='_blank' rel='noopener'>CheerpJ</a> 4.3 di Leaning Technologies (runtime dal loro CDN, Community License); Glimmer DSL for Swing (MIT), JFreeChart (LGPL-2.1), FlatLaf (Apache-2.0). Licenze: THIRD_PARTY_NOTICES.md.",
    cells: {
      fox: "Una finestra è fatta di qualche blocco annidato. <code>observe</code> lega l'etichetta alla volpe: clicca il pulsante qui sopra.",
      feed: "Il data binding funziona anche dal lato di Ruby: cambia la volpe qui, e la finestra la segue.",
      temp: "Tocca a te: scrivi una temperatura nel campo della finestra.",
      chart: "<a href='https://www.jfree.org/jfreechart/' target='_blank' rel='noopener'>JFreeChart</a>, una libreria Java, disegna un Hash di Ruby.",
      dark: "<a href='https://www.formdev.com/flatlaf/' target='_blank' rel='noopener'>FlatLaf</a>: tutte le finestre in modalità scura, con una sola chiamata."
    }
  }
};
// the texts' language; English for one it does not know
const lang = Object.hasOwn(TEXTS, params.get("lang") || "") ? params.get("lang") : "en";
document.documentElement.lang = lang;
const TEXT = TEXTS[lang];

// The Java windows' words: Swing's fonts here have Latin letters only
const W = lang === "de"
  ? { cls: "Fuchs", obj: "fuchs", attr: "speck", label: "Speck", button: "Füttere den Fuchs", celsius: "Celsius:", title: "Was der Fuchs frisst",
      snacks: '{ "Speck" => 12, "Äpfel" => 3, "Käse" => 5 }', dark: "Dunkelmodus an" }
  : { cls: "Fox", obj: "fox", attr: "bacon", label: "Bacon", button: "Feed the fox", celsius: "Celsius:", title: "What the fox eats",
      snacks: '{ "Bacon" => 12, "Apples" => 3, "Cheese" => 5 }', dark: "Dark mode on" };

const CELLS = [
  { name: "fox", code: `require "glimmer-cheerpj"   # Glimmer DSL for Swing, packed for the browser
include Glimmer

class ${W.cls}
  attr_accessor :${W.attr}
  def initialize = @${W.attr} = 0
end
${W.obj} = ${W.cls}.new

jframe("Chunky Bacon") {
  location 10, 10
  jpanel {
    @label = jlabel("${W.label}: 0")
    jbutton("${W.button}") {
      on_action_performed { ${W.obj}.${W.attr} += 1 }
    }
  }
}.show

observe(${W.obj}, :${W.attr}) { |n| @label.text = "${W.label}: #{n}" }
${W.obj}` },
  { name: "feed", code: `${W.obj}.${W.attr} += 10` },
  { name: "temp", code: `jframe("Celsius -> Fahrenheit") {
  location 10, 175
  jpanel {
    jlabel("${W.celsius}")
    @celsius = j_text_field("20", 5) {
      on_key_released do
        c = @celsius.text.to_f
        @fahrenheit.text = "#{(c * 9 / 5 + 32).round(1)} F"
      end
    }
    @fahrenheit = jlabel("68.0 F")
  }
}.show` },
  { name: "chart", code: `java_import org.jfree.chart.ChartFactory
java_import org.jfree.chart.ChartPanel
java_import org.jfree.data.general.DefaultPieDataset

snacks = ${W.snacks}
data = DefaultPieDataset.new
snacks.each { |food, n| data.set_value(food, n) }

chart = ChartFactory.create_pie_chart("${W.title}", data)
frame = javax.swing.JFrame.new("JFreeChart")
frame.add(ChartPanel.new(chart))
frame.set_bounds(250, 10, 340, 300)
frame.visible = true` },
  { name: "dark", code: `com.formdev.flatlaf.FlatDarkLaf.setup
java.awt.Window.windows.each do |w|
  javax.swing.SwingUtilities.update_component_tree_ui(w)
end
"${W.dark}"` }
];

// ---------- the status line ----------
const t0 = performance.now();
const T = { glimmer: null };
let stage = TEXT.start;
let state = "boot";   // boot | ready | failed
const bar = $("bar").firstElementChild;
function tick() {
  if (state !== "boot") return;
  $("msg").textContent = `${stage} (${Math.round((performance.now() - t0) / 1000)} s)`;
}
function status(text, percent) {
  stage = text;
  if (percent != null) bar.style.width = `${percent}%`;
  tick();
}
const timer = setInterval(tick, 500);
$("banner-note").textContent = TEXT.banner;
$("credits").innerHTML = TEXT.credits;

// ---------- the cells ----------
const cellEls = {};
for (const cell of CELLS) {
  const el = document.createElement("div");
  el.className = "cell";
  el.dataset.name = cell.name;
  el.innerHTML = `<p>${TEXT.cells[cell.name]}</p><textarea spellcheck="false" autocapitalize="off" rows="${cell.code.split("\n").length}"></textarea>` +
    `<div class="bar"><button type="button">${TEXT.run}</button><span class="t"></span></div><pre class="out"></pre><pre class="res"></pre>`;
  el.querySelector("textarea").value = cell.code;
  el.querySelector("button").addEventListener("click", () => runCell(cell.name));
  $("cells").append(el);
  cellEls[cell.name] = el;
}

// the iframe as tall as this page (jruby_lab.js sets it)
function postHeight() {
  if (parent === window) return;
  parent.postMessage({ chunkySwing: "height", height: document.documentElement.scrollHeight }, location.origin);
}
new ResizeObserver(postHeight).observe(document.body);

// ---------- the boot ----------
const STAGES = [[/Downloading the Java runtime\.\.\. (\d+)\/(\d+)/, m => TEXT.runtime.replace("%d", m[1]).replace("%t", m[2])],
                [/^Starting CheerpJ/, () => TEXT.start], [/^Loading the JRuby jar/, () => TEXT.jar],
                [/^Booting the Ruby runtime/, () => TEXT.boot], [/^Warming up/, () => TEXT.warm]];
const booted = (async () => {
  if (typeof window.cheerpjInit !== "function") throw new Error(TEXT.offline);
  const ruby = await bootJRuby({
    jar: `${JARS}jruby-complete-9.4.15.0.jar`,
    patchJar: `${JARS}cheerpj-patch.jar`,
    classpath: [`${JARS}glimmer-swing-gems.jar`, `${JARS}flatlaf-3.7.2.jar`, `${JARS}jfreechart-1.5.6.jar`],
    display: "#display",
    onStatus: (text, percent) => {
      const known = STAGES.find(([re]) => re.test(text));
      if (known) status(known[1](text.match(known[0])), Math.min(percent, 85));
    }
  });
  Object.assign(T, ruby.timings);
  T.jrubyReady = Math.round(performance.now() - t0);
  status(TEXT.glimmer, 92);
  // a hidden window with what the cells use: Swing's and Glimmer's classes
  // load now, while the learner reads
  const warm = await ruby.eval(`require "glimmer-cheerpj"
include Glimmer
jframe("warm-up") { jpanel { jlabel("a"); jbutton("b") { on_action_performed { } }; j_text_field("1", 3) { on_key_released { } } } }
[JRUBY_VERSION, RUBY_VERSION, java.lang.System.get_property("java.version")].join(" ")`);
  if (!warm.ok) throw new Error(warm.result);
  T.glimmer = warm.ms;
  T.ready = Math.round(performance.now() - t0);
  const [v, r, j] = warm.result.replace(/^=> "|"$/g, "").split(" ");
  state = "ready";
  clearInterval(timer);
  $("status").classList.add("ready");
  $("msg").textContent = TEXT.ready.replace("%v", v).replace("%r", r).replace("%j", j).replace("%s", (T.ready / 1000).toFixed(0));
  return ruby;
})();
booted.catch(e => {
  state = "failed";
  clearInterval(timer);
  $("status").classList.add("failed");
  $("msg").textContent = TEXT.failed.replace("%m", String((e && e.message) || e));
  console.error("JRuby on CheerpJ:", e);
});

async function runCell(name) {
  const el = cellEls[name];
  const button = el.querySelector("button");
  const time = el.querySelector(".t");
  button.disabled = true;
  if (state === "boot") time.textContent = TEXT.waiting;
  try {
    const ruby = await booted;
    time.textContent = TEXT.running;
    const answer = await ruby.eval(el.querySelector("textarea").value);
    el.querySelector(".out").textContent = answer.out.replace(/\n$/, "");
    const res = el.querySelector(".res");
    res.textContent = answer.result;
    res.className = answer.ok ? "res" : "err";
    time.textContent = answer.ms < 1000 ? `${answer.ms} ms` : `${(answer.ms / 1000).toFixed(1)} s`;
    return answer;
  } catch (e) {
    time.textContent = "";
    return { ok: false, out: "", result: String((e && e.message) || e) };
  } finally {
    button.disabled = false;
    postHeight();
  }
}

window.swingLab = {
  ready: () => state === "ready", failed: () => state === "failed", timings: T,
  run: runCell, eval: async code => (await booted).eval(code)
};
