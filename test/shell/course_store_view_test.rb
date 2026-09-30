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
    assert_equal 38, @course.size
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

  def test_code_key_is_the_kernels
    # main.rb writes these keys when it runs a cell (code_key there)
    assert_equal "chunky_cell_de_hallo_3", ChunkyShell::Store.code_key("de", "hallo", 3)
  end

  # ---------- View ----------

  def test_nav_links_sections_and_marks
    html = ChunkyShell::View.nav_html(@course, "de", "rechnen", ["hallo"])
    assert_equal 38, html.scan("<a ").length
    assert_includes html, %(<div class="nav-section">Grundkurs</div>)
    assert_includes html, %(<a class="done" href="#hallo" data-id="hallo">1. Hallo, Welt!</a>)
    assert_match(/<a class="active" href="#rechnen" data-id="rechnen">2\./, html)
  end

  def test_lesson_markup_is_what_css_kernel_and_tests_expect
    html = ChunkyShell::View.lesson_html(@course.cells(0, "de"), "Aufgabe", "▶ Ausführen")
    assert_includes html, %(<div class="lessonText"><h2>Hallo, Welt!</h2>)
    assert_includes html, %(<textarea title="code" id="cell-code-1"></textarea>)
    assert_includes html, %(<button type="button" class="run-cell" data-idx="1">▶ Ausführen</button>)
    assert_includes html, %(<div class="cell-out" id="cell-out-1" style="display:none"></div>)
    assert_match(/<div class="cell exercise" data-label="Aufgabe">/, html)
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
