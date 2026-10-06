require_relative "harness"

# Course (lesson data through the bridge), Store (localStorage) and View
# (the HTML strings) on the real course from test/lessons.json.
class CourseStoreViewTest < Minitest::Test
  include ShellTest

  def setup
    fresh_page
    @course = ChunkyShell::Course.new(JS.global[:LESSONS])
  end

  # ---------- Course ----------

  def test_course_has_every_lesson_and_language
    assert_equal 57, @course.size
    assert_equal "hallo", @course.id(0)
    assert_equal %w[de en ja], @course.langs
    assert_equal 1, @course.index("rechnen")
    assert_nil @course.index("nonsense")
  end

  def test_titles_per_language
    assert_equal "1. Hallo, Welt!", @course.title(0, "de")
    assert_equal "1. Hello, World!", @course.title(0, "en")
    assert @course.title(0, "ja").start_with?("1.")
  end

  def test_sections_only_where_the_index_starts_one
    assert_equal "Grundkurs", @course.section(0, "de")
    assert_equal "Basics", @course.section(0, "en")
    assert_nil @course.section(1, "de")
    assert_empty JS.console_errors, "optional fields are read without a 'Method not found'"
  end

  def test_cells_are_js_objects_with_fields
    cells = @course.cells(0, "de")
    assert_equal %w[h c h c h x], cells.map(&:t) if cells.length == 6
    exercise = cells.find { |c| c.t == "x" }
    refute_nil exercise.check
    refute_nil exercise.hint
  end

  # ---------- Store ----------

  def test_get_answers_the_default_for_empty_and_null
    assert_equal "d", ChunkyShell::Store.get("chunky_x", "d")
    window.storage["chunky_x"] = ""
    assert_equal "d", ChunkyShell::Store.get("chunky_x", "d")
    window.storage["chunky_x"] = "null"
    assert_equal "d", ChunkyShell::Store.get("chunky_x", "d")
    window.storage["chunky_x"] = "v"
    assert_equal "v", ChunkyShell::Store.get("chunky_x", "d")
  end

  def test_done_ids_survive_garbage
    assert_equal [], ChunkyShell::Store.done_ids
    ["{", "5", "\"x\"", "{}"].each do |junk|
      window.storage["chunky_done"] = junk
      assert_equal [], ChunkyShell::Store.done_ids, junk
    end
  end

  def test_mark_done_once
    ChunkyShell::Store.mark_done("hallo")
    ChunkyShell::Store.mark_done("hallo")
    ChunkyShell::Store.mark_done("rechnen")
    assert_equal '["hallo","rechnen"]', window.storage["chunky_done"]
  end

  # ---------- saved code: fingerprints and the keys from before ----------

  def store = ChunkyShell::Store
  def starter(id, idx, lang = "de") = @course.cells(@course.index(id), lang)[idx].code
  def saved_key(id, idx, lang = "de") = store.code_key(lang, id, idx, starter(id, idx, lang))

  def test_code_key_carries_the_starters_fingerprint
    assert_equal "chunky_cell_de_hallo_3@#{store.fingerprint('1 + 1')}", store.code_key("de", "hallo", 3, "1 + 1")
    refute_equal store.code_key("de", "hallo", 3, "1 + 1"), store.code_key("de", "hallo", 3, "1 + 2")
  end

  def test_the_fingerprint_never_changes
    # every learner's saved code is filed under these: a change to the
    # function hides it all. PicoRuby.wasm 4.0.3 gave the same (probed).
    assert_equal "0", store.fingerprint("")
    assert_equal "1t", store.fingerprint("A")
    assert_equal "mryzrl", store.fingerprint("puts \"Grüsse 日本\"\n# x")
    assert_equal "rj9cd", store.fingerprint("1 + 1")
  end

  def test_old_keys_move_to_their_cells_fingerprint
    window.storage["chunky_cell_de_hallo_1"] = "2 + 2"
    window.storage["chunky_cell_en_rechnen_1"] = "3 * 3"
    store.migrate_code_keys(@course)
    assert_equal "2 + 2", window.storage[saved_key("hallo", 1)]
    assert_equal "3 * 3", window.storage[saved_key("rechnen", 1, "en")]
    assert_empty window.storage.keys.grep(/^chunky_cell_.*_[0-9]+$/), "the old keys are removed"
  end

  def test_old_keys_of_the_three_lessons_that_gained_cells_shift_by_two
    # id => [the exercise's old index, its index now, a demo before the new cells]
    moved = { "arrays" => [7, 9, 5], "hashes" => [3, 5, 1], "klassen" => [3, 5, 1] }
    moved.each do |id, (old, _now, before)|
      %w[de en ja].each do |lang|
        window.storage["chunky_cell_#{lang}_#{id}_#{old}"] = "exercise #{id} #{lang}"
        window.storage["chunky_cell_#{lang}_#{id}_#{before}"] = "demo #{id} #{lang}"
      end
    end
    store.migrate_code_keys(@course)
    moved.each do |id, (_old, now, before)|
      %w[de en ja].each do |lang|
        cells = @course.cells(@course.index(id), lang)
        assert_equal "x", cells[now].t, "#{id} #{lang}: the exercise is cell #{now}"
        assert_equal "exercise #{id} #{lang}", window.storage[saved_key(id, now, lang)], "#{id} #{lang}"
        assert_equal "demo #{id} #{lang}", window.storage[saved_key(id, before, lang)], "#{id} #{lang}: before the new cells"
        assert_equal "c", cells[now - 2].t
        assert_nil window.storage[saved_key(id, now - 2, lang)], "#{id} #{lang}: the new demo starts empty"
      end
    end
    assert_equal 18, window.storage.keys.length
  end

  def test_old_keys_without_a_cell_stay_as_they_are
    keys = %w[chunky_cell_de_nonsense_1 chunky_cell_xx_hallo_1 chunky_cell_de_hallo_0 chunky_cell_de_hallo_99]
    keys.each { |key| window.storage[key] = "kept" }
    store.migrate_code_keys(@course)
    assert_equal keys.sort, window.storage.keys.sort
  end

  def test_where_both_keys_exist_the_newer_stays
    new_key = saved_key("hallo", 1)
    window.storage[new_key] = "new"
    window.storage["chunky_cell_de_hallo_1"] = "old"
    window.storage["chunkysync_times"] = %({"#{new_key}": 2000, "chunky_cell_de_hallo_1": 1000})
    store.migrate_code_keys(@course)
    assert_equal "new", window.storage[new_key]
    refute window.storage.key?("chunky_cell_de_hallo_1")

    window.storage["chunky_cell_de_hallo_1"] = "from a newer file"
    window.storage["chunkysync_times"] = %({"#{new_key}": 2000, "chunky_cell_de_hallo_1": 3000})
    store.migrate_code_keys(@course)
    assert_equal "from a newer file", window.storage[new_key]
  end

  def test_unreadable_change_times_keep_the_fingerprinted_code
    new_key = saved_key("hallo", 1)
    window.storage[new_key] = "new"
    window.storage["chunky_cell_de_hallo_1"] = "old"
    window.storage["chunkysync_times"] = "{broken"
    store.migrate_code_keys(@course)
    assert_equal "new", window.storage[new_key]
  end

  # ---------- View ----------

  def test_nav_links_sections_and_marks
    html = ChunkyShell::View.nav_html(@course, "de", "rechnen", ["hallo"], "#", [], "", "keine", "%d von %d fertig")
    assert_equal 57, html.scan("<a ").length
    assert_equal 3, html.scan("<section ").length
    assert_includes html, %(<span class="nav-group-name">Grundkurs</span>)
    assert_includes html, %(<span class="nav-group-count" title="1 von 19 fertig" aria-label="1 von 19 fertig">1/19</span>)
    assert_includes html, %(<a class="lesson done" href="#hallo" data-id="hallo"><span class="num">1</span><span class="name">Hallo, Welt!</span></a>)
    assert_includes html, %(<a class="lesson active" href="#rechnen" data-id="rechnen" aria-current="page"><span class="num">2</span>)
    assert_includes html, %(<span class="name">Entry &amp; Timesheet</span>)
  end

  def test_nav_groups_are_named_by_their_first_lesson
    groups = ChunkyShell::View.nav_groups(@course, "en")
    assert_equal [["hallo", "Basics", 19], ["three", "Side trips", 22], ["tl-collections", "Advanced: timelog", 16]],
                 groups.map { |key, name, list| [key, name, list.length] }
  end

  def test_nav_folded_group_keeps_its_head
    html = ChunkyShell::View.nav_html(@course, "de", "hallo", [], "#", ["three"])
    assert_includes html, %(<section class="nav-group closed" data-group="three">)
    assert_includes html, %(data-group="three" aria-expanded="false")
    assert_includes html, %(<section class="nav-group" data-group="hallo">)
  end

  def test_nav_search_shows_what_matches_in_open_groups
    html = ChunkyShell::View.nav_html(@course, "de", "hallo", [], "#", ["tl-collections"], " minitest ", "keine")
    assert_equal 1, html.scan("<a ").length
    assert_includes html, %(data-id="tl-minitest")
    assert_includes html, %(<section class="nav-group" data-group="tl-collections">), "a hit opens its group"
    # the number is part of the title, and a section's name finds its lessons
    assert_includes ChunkyShell::View.nav_html(@course, "de", "hallo", [], "#", [], "14").to_s, %(data-id="gems")
    assert_equal 22, ChunkyShell::View.nav_html(@course, "de", "hallo", [], "#", [], "ausflüge").scan("<a ").length
    assert_equal %(<p class="nav-none">keine</p>), ChunkyShell::View.nav_html(@course, "de", "hallo", [], "#", [], "zzz", "keine")
  end

  def test_lesson_markup_is_what_css_kernel_and_tests_expect
    html = ChunkyShell::View.lesson_html(@course.cells(0, "de"), "Aufgabe", "▶ Ausführen")
    assert_includes html, %(<div class="lessonText"><h2>Hallo, Welt!</h2>)
    assert_includes html, %(<textarea title="code" id="cell-code-1"></textarea>)
    assert_includes html, %(<button type="button" class="run-cell" data-idx="1">▶ Ausführen</button>)
    assert_includes html, %(<div class="cell-out" id="cell-out-1" style="display:none"></div>)
    assert_match(/<div class="cell exercise" data-label="Aufgabe">/, html)
  end

  # ⏯ is for the Basics lessons whose cells are plain Ruby (lessons.js
  # "stepper": true) - not gems, servers or the network, not the IRB
  def test_the_lessons_with_a_stepper
    flagged = @course.ids.each_index.select { |idx| @course.stepper?(idx) }.map { |idx| @course.id(idx) }
    assert_equal %w[variablen strings wenn schleifen arrays hashes methoden turtle klassen module], flagged
    side_trips = @course.ids.each_index.find { |idx| idx.positive? && @course.section(idx, "de") }
    assert(flagged.all? { |id| @course.index(id) < side_trips }, "the Basics only")
  end

  def test_step_buttons_beside_run_but_not_beside_an_irb
    step = ["⏯ Step through", "Step through cell %d"]
    html = ChunkyShell::View.lesson_html(@course.cells(@course.index("schleifen"), "en"), "Task", "▶ Run", "", "Run cell %d", step)
    assert_includes html, %(<button type="button" class="step-cell" data-idx="3" aria-label="Step through cell 2">⏯ Step through</button>) +
                          %(<button type="button" class="run-cell" data-idx="3" aria-label="Run cell 2">▶ Run</button>)
    assert_equal 3, html.scan("step-cell").length
    irb = ChunkyShell::View.lesson_html(@course.cells(@course.index("irb"), "en"), "Task", "▶ Run", "", "Run cell %d", step)
    assert_equal 1, irb.scan("step-cell").length, "the exercise, not show_irb's cell"
    refute_includes ChunkyShell::View.lesson_html(@course.cells(0, "en"), "Task", "▶ Run"), "step-cell"
  end

  def test_run_buttons_named_by_their_code_cell
    html = ChunkyShell::View.lesson_html(@course.cells(0, "en"), "Task", "▶ Run", "", "Run cell %d")
    assert_includes html, %(data-idx="1" aria-label="Run cell 1">▶ Run</button>)
    assert_match(/aria-label="Run cell 3" aria-keyshortcuts="Alt\+R">/, html, "the exercise, its shortcut")
    refute_includes html, "Run cell 4"
  end

  def test_workshop_frame
    html = ChunkyShell::View.workshop_html("Werkstatt", "Intro", "Run")
    %w[wsFiles wsTab cell-code-0 wsStdinBox cell-out-0].each { |id| assert_includes html, %(id="#{id}") }
  end

  def test_gem_chips
    html = ChunkyShell::View.gems_html(%w[chunky_png roda], { "roda" => "3.1" }, "cached")
    assert_includes html, %(class="gem-chip" data-gem="chunky_png" title="cached">chunky_png ⚡)
    assert_includes html, %(class="gem-chip installed" data-gem="roda" title="3.1">roda ✓)
    assert_includes ChunkyShell::View.gems_html(["<x>"], {}, "t"), "&lt;x&gt;"
  end

  def test_run_time
    assert_equal "< 0.1 s", ChunkyShell::View.run_time(0.04, "en")
    assert_equal "1.5 s", ChunkyShell::View.run_time(1.54, "en")
    assert_equal "1,5 s", ChunkyShell::View.run_time(1.54, "de")
  end

  def test_passed_bubble
    ui = @course.ui("de")
    next_html = ChunkyShell::View.passed_html("Super!", ui, 0, 37, "rechnen", false)
    assert_includes next_html, "Lektion 1 von 37"
    assert_includes next_html, %(<a href="#rechnen" id="nextLessonLink">)
    assert_includes ChunkyShell::View.passed_html("Super!", ui, 36, 37, nil, true), "alle Lektionen"
    assert_equal "Super!", ChunkyShell::View.passed_html("Super!", ui, 36, 37, nil, false)
  end
end
