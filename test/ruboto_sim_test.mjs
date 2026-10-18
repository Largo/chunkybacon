// The simulated phone's Android semantics (docs/HANDOVER.md §6u), on the real
// jruby.js under Node through test/ruboto_node.mjs: the lifecycle orders of
// Android 14 (save after stop, Back on the first screen, Back from a second
// screen, finish in onCreate, a rotation while stopped), dialogs that die with
// their activity, the menu's answer, a Spinner's first selection, the clock
// moving with every input, inputs for a replaced app, a failed rerun, a class
// inside an activity, two activities in one cell, a later cell reopening an
// activity, the Bundle's types. About a minute.
//   node test/ruboto_sim_test.mjs
import { execFileSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
let failures = 0;
const check = (name, cond, detail) => {
  console.log(`${cond ? "PASS" : "FAIL"} ${name}${cond || detail === undefined ? "" : `\n      ${JSON.stringify(detail).slice(0, 600)}`}`);
  if (!cond) failures++;
};

// runs: [{code} | {phone: event} | {reset: true}] -> the answers
function play(runs) {
  const out = execFileSync("node", [path.join(here, "ruboto_node.mjs")],
                           { input: JSON.stringify({ runs }), maxBuffer: 64 << 20 });
  return JSON.parse(out.toString());
}
const value = answer => answer.ok ? answer.result : `ERROR ${answer.error && answer.error.class}: ${answer.error && answer.error.message}`;
const tap = text => ({ code: `phone.tap(${JSON.stringify(text)}); nil` });
const log = { code: "phone.log" };
const texts = { code: "phone.texts" };

const W = "require 'ruboto/widget'\nruboto_import_widgets :LinearLayout, :TextView, :Button, :Spinner\n";
const LOGGED = name => `
  def onStart; super; android.util.Log.d('${name}', 'onStart'); end
  def onRestart; super; android.util.Log.d('${name}', 'onRestart'); end
  def onResume; super; android.util.Log.d('${name}', 'onResume'); end
  def onPause; super; android.util.Log.d('${name}', 'onPause'); end
  def onStop; super; android.util.Log.d('${name}', 'onStop'); end
  def onDestroy; super; android.util.Log.d('${name}', 'onDestroy'); end
  def onSaveInstanceState(b); super; android.util.Log.d('${name}', 'onSaveInstanceState'); end
`;
const lines = answer => JSON.parse(answer.result).map(l => l.replace(/^[A-Z]\//, ""));

// 1. Android 9+: onSaveInstanceState after onStop; Home saves too
{
  const a = play([
    { code: `${W}class OrderActivity\n  def onCreate(b); super; android.util.Log.d('A', "onCreate #{b ? 'bundle' : 'nil'}"); self.content_view = text_view(text: 'x'); end\n${LOGGED("A")}end\n` },
    { phone: { action: "rotate" } }, log,
    { phone: { action: "home" } }, log
  ]);
  const rotated = lines(a[2]).join(" | ");
  check("rotation: onPause, onStop, onSaveInstanceState, onDestroy, onCreate with the bundle",
        /A: onPause \| A: onStop \| A: onSaveInstanceState \| A: onDestroy \| A: onCreate bundle/.test(rotated), rotated);
  const home = lines(a[4]).slice(-3).join(" | ");
  check("Home: onPause, onStop, onSaveInstanceState", home === "A: onPause | A: onStop | A: onSaveInstanceState", home);
}

// 2. Back on the first screen moves the app to the background (Android 12+);
//    Back on a second screen ends it, in Android's order
{
  const a = play([
    { code: `${W}class RootActivity\n  def onCreate(b); super; self.content_view = button(text: 'open', on_click_listener: proc { start_ruboto_activity('ChildActivity') { def onCreate(b); super; self.content_view = text_view(text: 'child'); end; def onPause; super; android.util.Log.d('C', 'onPause'); end; def onStop; super; android.util.Log.d('C', 'onStop'); end; def onDestroy; super; android.util.Log.d('C', 'onDestroy'); end } }); end\n${LOGGED("R")}end\n` },
    { phone: { action: "back" } }, log, { code: "[phone.screen['home'], RubotoSim.stack.map(&:name)]" },
    { phone: { action: "launch" } }, tap("open"), { code: "phone.texts" },
    { phone: { action: "back" } }, log, texts
  ]);
  const back1 = lines(a[2]).join(" | ");
  check("Back on the first screen: to the background, no onDestroy", !/R: onDestroy/.test(back1) && /R: onStop/.test(back1), back1);
  check("...the home screen shows, the activity still alive behind it", value(a[3]) === '[true, ["RootActivity"]]', value(a[3]));
  check("the second screen opens", value(a[6]) === '["child"]', value(a[6]));
  const back2 = lines(a[8]).join(" | ");
  check("Back on a second screen: C pauses, R comes back, then C stops and ends",
        /C: onPause \| R: onRestart \| R: onStart \| R: onResume \| C: onStop \| C: onDestroy/.test(back2), back2);
  check("...and the first screen shows again", value(a[9]) === '["open"]', value(a[9]));
}

// 3. finish() in onCreate: straight to onDestroy
{
  const a = play([
    { code: `${W}class QuitActivity\n  def onCreate(b); super; finish; end\n${LOGGED("Q")}end\n` }, log,
    { code: "phone.screen['home']" }
  ]);
  const l = lines(a[1]).join(" | ");
  check("finish() in onCreate: onDestroy, no onStart/onResume", l === "Q: onDestroy", l);
  check("...and the home screen shows", value(a[2]) === "true", value(a[2]));
}

// 4. a rotation while stopped: the activity is made anew when it comes back
{
  const a = play([
    { code: `${W}class TurnActivity\n  def onCreate(b); super; android.util.Log.d('T', "onCreate #{b ? b.getInt('n') : 'nil'}"); @n = b ? b.getInt('n') : 5; self.content_view = text_view(text: @n.to_s); end\n  def onSaveInstanceState(o); super; o.putInt('n', @n + 1); end\nend\n` },
    { phone: { action: "home" } }, { phone: { action: "rotate" } }, { phone: { action: "launch" } }, log, texts,
    { code: "phone.screen.dig('device', 'orientation')" }
  ]);
  const l = lines(a[4]).join(" | ");
  check("rotated on Home, then launched: a new onCreate with the saved state", /T: onCreate nil \| T: onCreate 6/.test(l), l);
  check("...showing it, in landscape", value(a[5]) === '["6"]' && value(a[6]) === '"landscape"', [value(a[5]), value(a[6])]);
}

// 5. a dialog dies with its activity; the menu shows only for true
{
  const a = play([
    { code: `${W}class DialogActivity\n  def onCreate(b); super; self.content_view = button(text: 'ask', on_click_listener: proc { android.app.AlertDialog::Builder.new(self).set_title('Sure?').set_positive_button('Yes', nil).show }); end\n  def onCreateOptionsMenu(m); m.add('Never'); false; end\nend\n` },
    tap("ask"), { code: "phone.screen.dig('device', 'dialog', 'title')" },
    { phone: { action: "rotate" } }, { code: "[phone.screen.dig('device', 'dialog'), phone.log.grep(/leaked window/).size, phone.activity['menu']]" }
  ]);
  check("the dialog shows", value(a[2]) === '"Sure?"', value(a[2]));
  check("a rotation takes it away, and logcat says it leaked; a menu answering false is not shown",
        value(a[4]) === "[nil, 1, nil]", value(a[4]));
}

// 6. a Spinner reports its first item after the layout
{
  const a = play([
    { code: `${W}class PickActivity\n  def onCreate(b); super; self.content_view = linear_layout(orientation: :vertical) { @label = text_view(text: '-'); spinner(list: ['Bern', 'Basel'], on_item_selected_listener: proc { |p, v, pos, id| @label.text = "picked #{p.selected_item}" }) }; end\nend\n` },
    texts
  ]);
  check("a Spinner's first item is reported as selected", JSON.parse(a[1].result)[0] === "picked Bern", value(a[1]));
}

// 7. the clock moves with every input; an input for a replaced app is ignored
{
  const a = play([
    { code: `${W}class TimerActivity\n  def onCreate(b); super; @n = 0; @h = android.os.Handler.new(android.os.Looper.main_looper); @t = proc { @n += 1; @label.text = @n.to_s; @h.postDelayed(@t, 1000) }.to_java(java.lang.Runnable); self.content_view = linear_layout { @label = text_view(text: '0'); button(text: 'tap', on_click_listener: proc { }) }; @h.postDelayed(@t, 1000); end\nend\n` },
    { code: "phone.screen['install']" },
    { phone: { action: "none", ms: 1100 } }, { phone: { action: "none", ms: 1100 } }, texts,
    { code: `${W}class OtherActivity\n  def onCreate(b); super; self.content_view = text_view(text: 'other'); end\nend\n` },
    { phone: { action: "rotate", install: 1 } }, { code: "phone.screen.dig('device', 'orientation')" }
  ]);
  check("inputs carry the time: two inputs 1.1 s apart fire the 1 s timer twice", JSON.parse(a[4].result)[0] === "2", value(a[4]));
  check("an input stamped for the replaced app does nothing", value(a[7]) === '"portrait"', value(a[7]));
}

// 8. a failed rerun keeps the running app's script; a class inside an activity is not one
{
  const good = `${W}class KeepActivity\n  def onCreate(b); super; self.content_view = text_view(text: 'good'); end\nend\n`;
  const a = play([
    { code: good },
    { code: `${W}class KeepActivity\n  def onCreate(b); super; self.content_view = text_view(text: 'broken'); end\nend\nraise 'after the class'\n` },
    { phone: { action: "rotate" } }, texts,
    { code: `${W}class NestActivity\n  class Item\n    def to_s = 'item'\n  end\n\n  def onCreate(b); super; self.content_view = text_view(text: "nest #{Item.new}"); end\nend\n` },
    { code: "[phone.app, phone.texts]" }
  ]);
  check("the failed rerun raised", !a[1].ok, value(a[1]));
  check("...and a rotation of the running app still runs its good script", value(a[3]) === '["good"]', value(a[3]));
  check("a class inside the activity is not taken for it", value(a[5]) === '["NestActivity", ["nest item"]]', value(a[5]));
}

// 9. two activities in one cell; a later cell reopening an activity lasts through a rotation
{
  const a = play([
    { code: `${W}class FirstActivity\n  NAME = 'first'\n  def onCreate(b); super; self.content_view = button(text: NAME, on_click_listener: proc { start_ruboto_activity('SecondActivity') }); end\nend\n\nclass SecondActivity\n  NAME = 'second'\n  def onCreate(b); super; self.content_view = text_view(text: NAME); end\nend\n` },
    tap("first"), texts, { phone: { action: "rotate" } }, texts, { phone: { action: "back" } }, texts,
    { code: `${W}class ReopenActivity\n  def onCreate(b); super; self.content_view = text_view(text: label); end\n  def label = 'old'\nend\n` },
    { code: "class ReopenActivity\n  def label = 'new'\nend\n" },
    { phone: { action: "rotate" } }, texts
  ]);
  check("the second activity of a cell starts", value(a[2]) === '["second"]', value(a[2]));
  check("...survives a rotation", value(a[4]) === '["second"]', value(a[4]));
  check("...and Back returns to the first", value(a[6]) === '["first"]', value(a[6]));
  check("a method a later cell redefines lasts through a rotation", value(a[10]) === '["new"]', value(a[10]));
}

console.log(failures ? `${failures} FAILED` : "ALL PASS");
process.exit(failures ? 1 : 0);
