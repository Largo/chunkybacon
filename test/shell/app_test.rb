require_relative "harness"

# The shell end to end on the stub DOM: boot, routing, language, runs and
# what the kernel's answers do to the page.
class AppTest < Minitest::Test
  include ShellTest

  def run_button(idx) = find(".run-cell[data-idx='#{idx}']")
  def cell(idx) = run_button(idx).js_closest(".cell")
  def exercise_idx = find(".cell.exercise .run-cell").attrs["data-idx"].to_i
  # where the code of cell idx (lesson hallo's "1 + 1" by default) is saved
  def saved_key(idx = 1, starter = "1 + 1", id = "hallo") = ChunkyShell::Store.code_key("de", id, idx, starter)

  # ---------- boot ----------

  def test_boot_draws_the_page
    start
    assert_equal "none", byid("spinner").props["style"]["display"]
    assert_equal "block", byid("app").props["style"]["display"]
    assert_equal "Ruby lernen mit Chunky Bacon", byid("siteTitle").text
    assert_equal 55, find_all("#lessonNav a").length
    assert_equal "hallo", find("#lessonNav a.active").attrs["data-id"]
    assert_equal "Hallo, Welt!", find("#lessonBody h2").text
    assert_equal 3, find_all("#lessonBody .cell").length
    assert_equal "Aufgabe", find(".cell.exercise").attrs["data-label"]
    assert_equal "1. Hallo, Welt! – Ruby lernen mit Chunky Bacon", doc.props["title"]
    assert_includes bubble, "Chunky Bacon"
    assert_empty JS.console_errors
  end

  def test_boot_names_the_lesson_in_the_url_and_tells_the_bridge
    start
    assert_equal "#hallo", window.location["hash"]
    assert_equal [["setState", "de", "hallo", false]], calls("setState")
    assert_equal 1, calls("shellReady").length
  end

  def test_editors_get_their_code_as_strings
    start(storage: { saved_key => "2 + 2" })
    codes = calls("setCellCode")
    assert_equal ["setCellCode", "1", "2 + 2"], codes.first
    assert(codes.all? { |_, idx, _code| idx.is_a?(String) }, "a number beside a string with \\n breaks the call")
    inits = calls("initCell")
    assert_equal "1", inits.first[1]
    assert(inits.all? { |_, idx, _label, _hint| idx.is_a?(String) })
  end

  def test_editors_are_named_and_say_how_to_leave_them
    start
    _, _, label, hint = calls("initCell").first
    assert_equal "Code, Zelle 1", label, "the first code cell, not cell index 1"
    assert_includes hint, "Escape, dann Tab"
    assert_equal "Code, Zelle 2", calls("initCell")[1][2]
  end

  def test_gem_chips_come_from_the_cache_manifest
    start
    assert_includes byid("gemsList").text, "chunky_png ⚡"
  end

  def test_kernel_status_until_the_kernel_is_up
    start
    status = byid("kernelStatus")
    refute status.props["hidden"]
    assert_includes status.text, "Ruby wird geladen"
    assert_includes doc.js_get("body").attrs["class"], "kernel-loading"
    fire("chunky:kernel-ready")
    assert status.props["hidden"]
    refute_includes doc.js_get("body").attrs["class"].to_s, "kernel-loading"
  end

  def test_a_kernel_that_never_comes_says_so_and_frees_the_cells
    start
    click(run_button(1))
    fire("chunky:kernel-failed", { "reason" => "CompileError" })
    status = byid("kernelStatus")
    assert_includes status.text, "nicht geladen"
    assert_includes status.attrs["class"], "is-failed"
    refute_includes doc.js_get("body").attrs["class"].to_s, "kernel-loading"
    refute_includes cell(1).attrs["class"], "running"
    refute run_button(1).props["disabled"]
    assert_equal "fail", bubble_state
    click(run_button(1))
    assert_equal 1, calls("run").length, "no run is asked for any more"
  end

  def test_the_url_wins_over_the_stored_lesson
    start(hash: "#variablen", storage: { "chunky_current" => "rechnen" })
    assert_equal "variablen", find("#lessonNav a.active").attrs["data-id"]
  end

  def test_a_bare_url_brings_back_the_stored_lesson
    start(storage: { "chunky_current" => "rechnen" })
    assert_equal "rechnen", find("#lessonNav a.active").attrs["data-id"]
    assert_equal "#rechnen", window.location["hash"]
  end

  # ---------- navigation ----------

  def test_index_click_opens_a_lesson
    start
    link = find('#lessonNav a[data-id="variablen"]')
    assert click(link), "the link's own navigation is prevented #{JS.console_errors.inspect}"
    assert_equal "variablen", find("#lessonNav a.active").attrs["data-id"]
    assert_equal "variablen", window.location["hash"]
    assert_equal "variablen", window.storage["chunky_current"]
    assert_equal ["setState", "de", "variablen", false], calls("setState").last
  end

  def test_modified_clicks_are_left_to_the_browser
    start
    refute click(find('#lessonNav a[data-id="variablen"]'), ctrlKey: true)
    assert_equal "hallo", find("#lessonNav a.active").attrs["data-id"]
  end

  def test_hashchange_routes_and_bad_ids_are_corrected
    start
    window.location["hash"] = "#variablen"
    fire("hashchange")
    assert_equal "variablen", find("#lessonNav a.active").attrs["data-id"]
    window.location["hash"] = "#nonsense"
    fire("hashchange")
    assert_equal "#variablen", window.location["hash"]
  end

  def test_workshop
    start(hash: "#werkstatt")
    refute_nil byid("wsFiles")
    assert_includes byid("wsFiles").text, "main.rb", "the file panel is filled (workspace.rb)"
    assert byid("reset-code").props["hidden"]
    assert_includes doc.js_get("body").attrs["class"], "in-workshop"
    assert_equal ["setState", "de", "", true], calls("setState").last
    assert_nil find("#lessonNav a.active")
    assert_includes byid("workshopLink").attrs["class"], "active"
    assert_equal ["initCell", "0", "Werkstatt"], calls("initCell").last[0, 3]
  end

  def test_language_switch
    start
    byid("langSelect").props["value"] = "en"
    JS.fire(byid("langSelect").wrap, "change")
    assert_equal "Learn Ruby with Chunky Bacon", byid("siteTitle").text
    assert_equal "en", doc.js_get("documentElement").attrs["lang"]
    assert_equal "en", window.storage["chunky_lang"]
    assert_equal ["setState", "en", "hallo", false], calls("setState").last
  end

  def test_japanese
    start(storage: { "chunky_lang" => "ja" })
    assert_equal "ja", doc.js_get("documentElement").attrs["lang"]
    assert_includes find(".run-cell").text, "実行"
  end

  # bridge.js decides (?lang=, last choice, browser languages); its word
  # beats what localStorage held
  def test_the_language_bridge_js_picked
    start(storage: { "chunky_lang" => "de" }) { window.props["ChunkyBridge"]["lang"] = "en" }
    assert_equal "en", doc.js_get("documentElement").attrs["lang"]
    assert_equal "Learn Ruby with Chunky Bacon", byid("siteTitle").text
  end

  def test_unknown_stored_language_falls_back_to_german
    start(storage: { "chunky_lang" => "xx" })
    assert_equal "de", doc.js_get("documentElement").attrs["lang"]
  end

  def test_a_loaded_progress_file_is_shown
    start
    window.storage["chunky_lang"] = "en"
    window.storage["chunky_done"] = '["hallo"]'
    fire("chunky-progress-loaded")
    assert_equal "Learn Ruby with Chunky Bacon", byid("siteTitle").text
    assert_includes find('#lessonNav a[data-id="hallo"]').attrs["class"], "done"
  end

  # ---------- running ----------

  def test_run_shows_the_running_look_and_asks_the_bridge
    start
    click(run_button(1))
    assert_includes cell(1).attrs["class"], "running"
    assert run_button(1).props["disabled"]
    refute_nil run_button(1).js_querySelector(".run-fox")
    assert_equal [["run", 1]], calls("run")
    assert_includes bubble, "Chunky", "a queued run says nothing yet"
  end

  def test_code_with_sequel_loads_sqlite_before_it_runs
    start
    click(run_button(1))
    assert_empty calls("ensureSqlite"), "plain Ruby needs no SQLite"
    fire("chunky:ran", { "idx" => 1, "outcome" => "ok", "elapsed" => 0.1, "auto" => false, "own" => 0.1 })
    window.props["cellEditors"]["1"].js_setValue('DB = Sequel.sqlite("zeit.db")')
    click(run_button(1))
    assert_equal ["ensureSqlite", "run"], window.calls.map(&:first).select { |name| %w[ensureSqlite run].include?(name) }.last(2)
  end

  def test_a_second_click_while_running_is_ignored
    start
    click(run_button(1))
    click(run_button(1))
    assert_equal 1, calls("run").length
  end

  def test_ran_settles_the_cell
    start
    click(run_button(1))
    fire("chunky:ran", { "idx" => 1, "outcome" => "ok", "elapsed" => 1.54, "auto" => false, "own" => 1.54 })
    refute_includes cell(1).attrs["class"], "running"
    refute run_button(1).props["disabled"]
    assert_equal "▶ Ausführen", run_button(1).text
    assert_equal "1,5 s", cell(1).js_querySelector(".run-time").text
    click(run_button(1))
    assert_equal 2, calls("run").length, "it can run again"
  end

  def test_an_error_shakes_and_an_exercise_error_speaks
    start
    idx = exercise_idx
    click(run_button(idx))
    fire("chunky:ran", { "idx" => idx, "outcome" => "error", "elapsed" => 0.2, "auto" => false, "own" => 0.2 })
    assert_includes cell(idx).attrs["class"], "shake"
    assert_equal "fail", bubble_state
    assert_includes bubble, "Fehler"
  end

  def test_a_failed_check_gives_the_hint
    start
    idx = exercise_idx
    fire("chunky:ran", { "idx" => idx, "outcome" => "fail", "elapsed" => 0.2, "auto" => false, "own" => 0.2 })
    assert_equal "fail", bubble_state
    assert_includes bubble, "💡"
  end

  def test_a_passed_check_marks_the_lesson_and_links_the_next
    start
    idx = exercise_idx
    fire("chunky:ran", { "idx" => idx, "outcome" => "pass", "elapsed" => 0.2, "auto" => false, "own" => 0.2 })
    assert_equal "pass", bubble_state
    assert_equal '["hallo"]', window.storage["chunky_done"]
    assert_includes find('#lessonNav a[data-id="hallo"]').attrs["class"], "done"
    assert_includes cell(idx).attrs["class"], "celebrate"
    link = byid("nextLessonLink")
    assert click(link)
    assert_equal "rechnen", find("#lessonNav a.active").attrs["data-id"]
  end

  def test_the_last_lesson_passed_says_all_done
    ids = JS.global[:LESSONS][:lessons].to_a.map { |lesson| lesson[:id] }
    start(storage: { "chunky_done" => JSON.generate(ids) })
    idx = exercise_idx
    fire("chunky:ran", { "idx" => idx, "outcome" => "pass", "elapsed" => 0.2, "auto" => false, "own" => 0.2 })
    assert_includes bubble, "Koans"
  end

  def test_alt_r_runs_the_exercise
    start
    assert JS.fire(JS.window, "keydown", "altKey" => true, "key" => "r")
    assert_equal [["run", exercise_idx]], calls("run")
  end

  # ---------- keyboard and screen readers (experiments/10-accessibility) ----------

  def active = doc.js_get("activeElement")
  def ran_event(idx, outcome, auto: false) = { "idx" => idx, "outcome" => outcome, "elapsed" => 0.1, "auto" => auto, "own" => 0.1 }

  def test_run_from_the_keyboard_gives_the_focus_back_to_run
    start
    run_button(1).js_focus
    click(run_button(1))
    assert_equal "BODY", active.tag.upcase, "a disabled button loses the focus (the stub does what Chrome does)"
    fire("chunky:ran", ran_event(1, "ok"))
    assert active.equal?(run_button(1)), "the next Tab goes on from Run, not from the top"
  end

  def test_focus_that_moved_on_during_a_run_stays_where_it_went
    start
    run_button(1).js_focus
    click(run_button(1))
    byid("navSearch").js_focus
    fire("chunky:ran", ran_event(1, "ok"))
    assert active.equal?(byid("navSearch"))
    click(run_button(1))   # a click with the mouse: the focus was not on Run
    fire("chunky:ran", ran_event(1, "ok"))
    assert active.equal?(byid("navSearch"))
  end

  def test_a_run_is_announced_with_its_output_and_chunkys_verdict
    start
    click(run_button(1))
    byid("cell-out-1").js_set("textContent", "=> 2")
    fire("chunky:ran", ran_event(1, "ok"))
    assert_equal "Zelle 1 ausgeführt: => 2", byid("runStatus").text
    idx = exercise_idx
    byid("cell-out-#{idx}").js_set("textContent", "NameError")
    fire("chunky:ran", ran_event(idx, "error"))
    assert_equal "Zelle 3 mit Fehler: NameError #{bubble}", byid("runStatus").text, "the third code cell, whatever its index"
    fire("chunky:ran", ran_event(idx, "pass"))
    assert_includes byid("runStatus").text, "Lektion 1 von 55"
    byid("cell-out-1").js_set("textContent", "x" * 400)
    fire("chunky:ran", ran_event(1, "ok"))
    assert_equal "Zelle 1 ausgeführt: #{'x' * 280} …", byid("runStatus").text, "long output is shortened"
  end

  def test_an_explained_error_is_announced_by_its_headline
    start
    click(run_button(1))
    byid("cell-out-1").js_set("innerHTML", '<pre class="cell-stdout">こんにちは</pre>' \
                                           '<div class="friendly-error" lang="de"><div class="friendly-title">Meintest du upcase?</div>' \
                                           '<pre class="friendly-snippet">&gt; 2 | name.upcse</pre><p class="friendly-body">String hat keine Methode upcse.</p>' \
                                           '<details class="friendly-original"><summary>Rubys Meldung</summary><pre>NoMethodError</pre></details></div>')
    fire("chunky:ran", ran_event(1, "error"))
    assert_equal "Zelle 1 mit Fehler: こんにちはMeintest du upcase?", byid("runStatus").text,
                 "what it printed, then the headline - not the code frame or Ruby's message"
  end

  def test_a_picture_is_announced_by_its_alt_text
    start
    click(run_button(1))
    byid("cell-out-1").js_set("innerHTML", '<img class="cell-image" alt="a → #1, b → #1." src="data:image/svg+xml;base64,PHN2Zy8+"/>' \
                                           '<img class="cell-image" alt="" src="data:image/png;base64,iVBORw0K"/>')
    fire("chunky:ran", ran_event(1, "ok"))
    assert_equal "Zelle 1 ausgeführt: a → #1, b → #1.", byid("runStatus").text,
                 "show_objects' words; a plain picture (alt=\"\") adds nothing"
  end

  def test_a_sound_is_announced_by_its_players_name
    start
    click(run_button(1))
    byid("cell-out-1").js_set("innerHTML", '<div class="cell-audio"><img class="cell-wave" alt="" src="data:image/svg+xml;base64,PHN2Zy8+"/>' \
                                           '<audio controls src="blob:x" aria-label="Ein Klang, 2,0 Sekunden"></audio></div>')
    fire("chunky:ran", ran_event(1, "ok"))
    assert_equal "Zelle 1 ausgeführt: Ein Klang, 2,0 Sekunden", byid("runStatus").text,
                 "show_audio's player by its name; the wave's picture (alt=\"\") adds nothing"
  end

  def test_a_game_is_announced_by_its_name_not_its_grid
    start
    click(run_button(1))
    byid("cell-out-1").js_set("innerHTML", '<pre class="cell-stdout">los</pre>' \
                                           '<div class="game-widget" role="application" aria-label="Spiel mit 20 × 15 Feldern">' \
                                           '<div class="game-grid"><div>🦊</div><div>🥓</div></div>' \
                                           '<div class="game-overlay">Klick oder Leertaste zum Spielen</div></div>')
    fire("chunky:ran", ran_event(1, "ok"))
    assert_equal "Zelle 1 ausgeführt: los Spiel mit 20 × 15 Feldern", byid("runStatus").text,
                 "show_game by its name; its emoji grid and veil are left out"
  end

  def test_a_live_run_is_not_announced
    start
    fire("chunky:ran", ran_event(1, "ok", auto: true))
    assert_equal "", byid("runStatus").text
  end

  def test_run_buttons_are_named_with_their_cell
    start
    assert_equal "Zelle 1 ausführen", run_button(1).attrs["aria-label"]
    assert_equal "Alt+R", run_button(exercise_idx).attrs["aria-keyshortcuts"]
    assert_nil run_button(1).attrs["aria-keyshortcuts"]
  end

  # ---------- ⏯ step through ("stepper": true, stepper.js) ----------

  def step_button(idx) = find(".step-cell[data-idx='#{idx}']")

  def test_step_buttons_only_where_the_lesson_asks_for_them
    start(hash: "#schleifen")
    assert_equal %w[1 3 5], find_all(".step-cell").map { |b| b.attrs["data-idx"] }, "every code cell, the exercise too"
    assert_equal "⏯ Schritt für Schritt", step_button(3).text
    assert_equal "Schritt für Schritt durch Zelle 2", step_button(3).attrs["aria-label"], "the visible words, and the cell"
    assert step_button(3).js_closest(".cell-toolbar"), "in the toolbar, beside ▶"
    click(find('#lessonNav a[data-id="hallo"]'))
    assert_empty find_all(".step-cell"), "not in a lesson without the flag"
    click(byid("workshopLink"))
    assert_empty find_all(".step-cell"), "nor in the workshop"
    assert_empty JS.console_errors
  end

  def test_step_buttons_speak_the_language
    start(hash: "#schleifen", storage: { "chunky_lang" => "en" })
    assert_equal "⏯ Step through", step_button(1).text
    assert_equal "Step through cell 1", step_button(1).attrs["aria-label"]
  end

  def test_step_asks_the_bridge_for_a_recorded_run
    start(hash: "#schleifen")
    click(step_button(3))
    assert_equal [["step", 3]], calls("step")
    assert_empty calls("run"), "one run, the recorded one"
    assert_includes cell(3).attrs["class"], "running"
    assert run_button(3).props["disabled"]
    assert step_button(3).props["disabled"], "no second ⏯ while it runs"
    click(run_button(3))
    assert_empty calls("run"), "nor ▶"
    fire("chunky:ran", ran_event(3, "ok"))
    refute step_button(3).props["disabled"]
    refute run_button(3).props["disabled"]
  end

  # stepper.js puts the stepper on top of the output before the kernel
  # answers; the keyboard goes to its slider, and the status line reads the
  # run's output without it
  def test_after_step_the_focus_is_on_the_slider
    start(hash: "#schleifen")
    step_button(3).js_focus
    click(step_button(3))
    byid("cell-out-3").js_set("innerHTML", '<div class="stepper" role="group"><p class="step-say">Zeile 1 ist dran.</p>' \
                                           '<input class="step-slider" type="range"></div>' \
                                           '<pre class="cell-stdout">Streifen Nummer 1</pre>')
    fire("chunky:ran", ran_event(3, "ok"))
    assert active.equal?(find("#cell-out-3 .step-slider")), "the arrow keys walk the run at once"
    assert_equal "Zelle 2 ausgeführt: Streifen Nummer 1", byid("runStatus").text
  end

  def test_step_without_a_recording_gives_the_focus_back_to_step
    start(hash: "#schleifen")
    click(step_button(1))
    fire("chunky:ran", ran_event(1, "error"))   # nothing on the page: a syntax error
    assert active.equal?(step_button(1))
  end

  def test_a_lesson_change_puts_the_focus_on_its_heading
    start
    assert_equal "BODY", active.tag.upcase, "not on the first load"
    click(find('#lessonNav a[data-id="variablen"]'))
    assert_equal "h2", active.tag
    assert_equal "-1", active.attrs["tabindex"]
    fire("chunky:ran", ran_event(exercise_idx, "pass"))
    byid("chunkyText").js_focus
    click(byid("nextLessonLink"))
    assert_equal "h2", active.tag, "also after the bubble's next-lesson link"
    click(byid("workshopLink"))
    assert_equal "Werkstatt", active.text
  end

  def test_the_skip_link_goes_to_the_lesson
    start
    assert_equal "Zur Lektion springen", byid("skipLink").text
    assert click(byid("skipLink")), "its #lessonBody never reaches the router"
    assert_equal "Hallo, Welt!", active.text
    assert_equal "#hallo", window.location["hash"]
  end

  def test_language_select_mascot_and_skip_link_speak_the_language
    start
    assert_equal "Sprache", byid("langLabel").text
    assert_equal "Chunky Bacon, der Fuchs", byid("mascot").attrs["alt"]
    switch_to_english
    assert_equal "Language", byid("langLabel").text
    assert_equal "Language", byid("langSelect").attrs["title"]
    assert_equal "Chunky Bacon, the fox", byid("mascot").attrs["alt"]
    assert_equal "Skip to the lesson", byid("skipLink").text
    assert_equal "Run cell 1", run_button(1).attrs["aria-label"]
  end

  def test_reset_restores_the_starter_code
    start(storage: { saved_key => "2 + 2" })
    window.calls.clear
    byid("cell-out-1").props["style"] = { "display" => "block" }
    click(byid("reset-code"))
    assert_nil window.storage[saved_key]
    assert_equal ["setCellCode", "1", "1 + 1"], calls("setCellCode").first
    assert_equal "none", byid("cell-out-1").props["style"]["display"]
    assert_equal 1, calls("reset").length
  end

  def test_reset_asks_first
    start(storage: { saved_key => "2 + 2" })
    window.confirm = false
    click(byid("reset-code"))
    assert_equal "2 + 2", window.storage[saved_key]
  end

  # ---------- saved code ----------

  def test_a_run_saves_the_code_under_the_cells_fingerprint
    start
    window.props["chunkySaveCode"].call("1", "3 + 3\n")   # main.rb's run_cell
    assert_equal "3 + 3\n", window.storage[saved_key]
    window.props["chunkySaveCode"].call("0", "prose")      # not a code cell
    assert_equal 1, window.storage.keys.grep(/^chunky_cell_/).length
  end

  def test_the_workshop_saves_no_cell_code
    start(hash: "#werkstatt")
    window.props["chunkySaveCode"].call("0", "puts 1")
    assert_empty window.storage.keys.grep(/^chunky_cell_/)
  end

  def test_code_saved_for_another_cell_is_not_shown
    # a cell moved to index 1, or its starter changed: another fingerprint
    start(storage: { saved_key(1, "puts 'the old cell'") => "2 + 2" })
    assert_equal ["setCellCode", "1", "1 + 1"], calls("setCellCode").first
  end

  def test_code_saved_before_fingerprints_is_shown_in_its_cell
    exercise = "x = 1"
    start(hash: "#hashes", storage: { "chunky_cell_de_hashes_3" => exercise, "chunky_cell_de_hashes_1" => "demo" })
    assert_equal 5, exercise_idx
    shown = calls("setCellCode").to_h { |_, idx, code| [idx, code] }
    assert_equal exercise, shown["5"], "the old exercise code, in the exercise"
    assert_equal "demo", shown["1"]
    refute_equal exercise, shown["3"], "not in the new demo cell"
    refute window.storage.key?("chunky_cell_de_hashes_3")
  end

  def test_a_loaded_progress_file_with_old_keys_lands_in_the_right_cells
    start(hash: "#arrays")
    window.calls.clear
    window.storage["chunky_cell_de_arrays_7"] = "fruechte = []"   # an old file's exercise code
    fire("chunky-progress-loaded")
    assert_equal ["setCellCode", "9", "fruechte = []"], calls("setCellCode").find { |_, idx, _| idx == "9" }
    refute_equal "fruechte = []", calls("setCellCode").find { |_, idx, _| idx == "7" }[2]
  end

  def test_a_new_lesson_forgets_running_cells
    start
    click(run_button(1))
    click(find('#lessonNav a[data-id="hallo"]'))
    click(run_button(1))
    assert_equal 2, calls("run").length
  end

  # ---------- the sidebar ----------

  def body_classes = doc.js_get("body").attrs["class"].to_s.split
  def toggle = byid("sidebarToggle")

  def type_search(text)
    byid("navSearch").props["value"] = text
    JS.fire(byid("navSearch").wrap, "input")
  end

  def test_sidebar_head_counts_the_course
    start(storage: { "chunky_done" => '["hallo","rechnen"]' })
    assert_equal "Lektionen", byid("navTitle").text
    assert_equal "2/55", byid("navCount").text
    assert_equal "2 von 55 fertig", byid("navCount").attrs["title"]
    assert_equal "3%", byid("navBarFill").props["style"]["width"]
    assert_equal "Lektion suchen", byid("navSearch").attrs["placeholder"]
    switch_to_english
    assert_equal "2 of 55 done", byid("navCount").attrs["title"]
  end

  def switch_to_english
    byid("langSelect").props["value"] = "en"
    JS.fire(byid("langSelect").wrap, "change")
  end

  def test_a_click_on_the_name_inside_a_row_opens_the_lesson
    start
    assert click(find('#lessonNav a[data-id="hashes"] .name')), "the link's default is prevented"
    assert_equal "hashes", find("#lessonNav a.active").attrs["data-id"]
  end

  def test_wide_screen_toggle_puts_the_sidebar_away_and_remembers
    start
    assert_equal "true", toggle.attrs["aria-expanded"]
    click(toggle)
    assert_includes body_classes, "sidebar-closed"
    assert_equal "false", toggle.attrs["aria-expanded"]
    assert_equal "closed", window.storage["chunkyui_sidebar"]
    start(storage: { "chunkyui_sidebar" => "closed" })
    assert_includes body_classes, "sidebar-closed", "still away after a reload"
    click(toggle)
    refute_includes body_classes, "sidebar-closed"
    assert_equal "open", window.storage["chunkyui_sidebar"]
  end

  def test_phone_drawer_opens_and_goes_away_with_a_lesson_a_tap_or_escape
    start { window.narrow = true }
    assert_equal "false", toggle.attrs["aria-expanded"]
    click(toggle)
    assert_includes body_classes, "sidebar-open"
    assert_equal "true", toggle.attrs["aria-expanded"]
    assert_nil window.storage["chunkyui_sidebar"], "a drawer is not remembered"
    click(find('#lessonNav a[data-id="arrays"]'))
    refute_includes body_classes, "sidebar-open"
    click(toggle)
    click(find("#lessonBody"))
    refute_includes body_classes, "sidebar-open", "a tap beside the drawer"
    click(toggle)
    click(byid("navSearch"))
    assert_includes body_classes, "sidebar-open", "a tap inside it keeps it out"
    JS.fire(JS.window, "keydown", "key" => "Escape")
    refute_includes body_classes, "sidebar-open"
    assert toggle.props["focused"], "the keyboard goes back to the button"
  end

  def test_an_open_drawer_is_modal
    start { window.narrow = true }
    column = find(".column")
    refute column.props["inert"]
    click(toggle)
    assert column.props["inert"], "the page behind the scrim leaves the tab order"
    assert doc.js_get("activeElement").equal?(byid("workshopLink")), "the keyboard goes into the drawer"
    click(find('#lessonNav a[data-id="arrays"]'))
    refute column.props["inert"]
    assert_equal "h2", doc.js_get("activeElement").tag
    click(toggle)
    assert column.props["inert"]
    JS.fire(JS.window, "keydown", "key" => "Escape")
    refute column.props["inert"], "Escape gives the page back"
  end

  def test_group_folds_in_place_and_stays_folded
    start
    head = find('#lessonNav .nav-group-head[data-group="three"]')
    click(head)
    assert_includes find('#lessonNav section[data-group="three"]').attrs["class"], "closed"
    assert_equal "false", head.attrs["aria-expanded"]
    assert_equal "three", window.storage["chunkyui_nav_closed"]
    assert_equal "hallo", find("#lessonNav a.active").attrs["data-id"], "no lesson opened"
    start(storage: { "chunkyui_nav_closed" => "three" })
    assert_includes find('#lessonNav section[data-group="three"]').attrs["class"], "closed"
  end

  def test_a_lesson_reached_in_a_folded_group_unfolds_it
    start(hash: "#bigdecimal", storage: { "chunkyui_nav_closed" => "hallo,three" })
    fire("chunky:ran", { "idx" => exercise_idx, "outcome" => "pass", "elapsed" => 0.1, "auto" => false, "own" => 0.1 })
    click(byid("nextLessonLink"))
    assert_equal "three", find("#lessonNav a.active").attrs["data-id"]
    refute_includes find('#lessonNav section[data-group="three"]').attrs["class"], "closed"
    assert_equal "hallo", window.storage["chunkyui_nav_closed"]
  end

  def test_search_filters_escape_clears_enter_opens
    start
    type_search("PDF")
    assert_equal ["pdf"], find_all("#lessonNav a").map { |a| a.attrs["data-id"] }
    type_search("xyz")
    assert_equal "Keine Lektion passt.", find("#lessonNav .nav-none").text
    type_search("regex")
    assert JS.fire(byid("navSearch").wrap, "keydown", "key" => "Enter")
    assert_equal "tl-parsing", find("#lessonNav a.active").attrs["data-id"]
    assert JS.fire(byid("navSearch").wrap, "keydown", "key" => "Escape")
    assert_equal "", byid("navSearch").props["value"]
    assert_equal 55, find_all("#lessonNav a").length
  end

  # ---------- gems ----------

  def test_installed_gems_from_the_kernel
    start
    fire("chunky:gems", { "installed" => '{"chunky_png":"1.4.0","paint":"2.3"}' })
    text = byid("gemsList").text
    assert_includes text, "chunky_png ✓"
    assert_includes text, "paint ✓"
  end

  def test_chip_and_typed_install
    start
    click(find('#gemsList [data-gem="roda"]'))
    assert_equal ["install", "roda"], calls("install").last
    assert_includes bubble, "Ruby wird geladen", "the kernel is not up yet"
    byid("gemNameInput").props["value"] = " paint "
    click(byid("gemInstallBtn"))
    assert_equal ["install", "paint"], calls("install").last
  end

  def test_install_outcome_in_the_bubble
    start
    fire("chunky:installed", { "name" => "paint", "ok" => true, "message" => "paint 2.3" })
    assert_equal "pass", bubble_state
    assert_includes bubble, "paint 2.3 installiert"
    fire("chunky:installed", { "name" => "x", "ok" => false, "message" => "<b>nope</b>" })
    assert_equal "fail", bubble_state
    assert_includes byid("chunkyText").js_get("innerHTML"), "&lt;b&gt;"
  end
end
