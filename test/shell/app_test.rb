require_relative "harness"

# The shell end to end on the stub DOM: boot, routing, language, runs and
# what the kernel's answers do to the page.
class AppTest < Minitest::Test
  include ShellTest

  def run_button(idx) = find(".run-cell[data-idx='#{idx}']")
  def cell(idx) = run_button(idx).js_closest(".cell")
  def exercise_idx = find(".cell.exercise .run-cell").attrs["data-idx"].to_i

  # ---------- boot ----------

  def test_boot_draws_the_page
    start
    assert_equal "none", byid("spinner").props["style"]["display"]
    assert_equal "block", byid("app").props["style"]["display"]
    assert_equal "Ruby lernen mit Chunky Bacon", byid("siteTitle").text
    assert_equal 48, find_all("#lessonNav a").length
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
    start(storage: { "chunky_cell_de_hallo_1" => "2 + 2" })
    codes = calls("setCellCode")
    assert_equal ["setCellCode", "1", "2 + 2"], codes.first
    assert(codes.all? { |_, idx, _code| idx.is_a?(String) }, "a number beside a string with \\n breaks the call")
    assert_equal ["initCell", 1], calls("initCell").first
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

  def test_reset_restores_the_starter_code
    start(storage: { "chunky_cell_de_hallo_1" => "2 + 2" })
    window.calls.clear
    byid("cell-out-1").props["style"] = { "display" => "block" }
    click(byid("reset-code"))
    assert_nil window.storage["chunky_cell_de_hallo_1"]
    assert_equal ["setCellCode", "1", "1 + 1"], calls("setCellCode").first
    assert_equal "none", byid("cell-out-1").props["style"]["display"]
    assert_equal 1, calls("reset").length
  end

  def test_reset_asks_first
    start(storage: { "chunky_cell_de_hallo_1" => "2 + 2" })
    window.confirm = false
    click(byid("reset-code"))
    assert_equal "2 + 2", window.storage["chunky_cell_de_hallo_1"]
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
    assert_equal "2/48", byid("navCount").text
    assert_equal "2 von 48 fertig", byid("navCount").attrs["title"]
    assert_equal "4%", byid("navBarFill").props["style"]["width"]
    assert_equal "Lektion suchen", byid("navSearch").attrs["placeholder"]
    switch_to_english
    assert_equal "2 of 48 done", byid("navCount").attrs["title"]
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
    assert_equal 48, find_all("#lessonNav a").length
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
