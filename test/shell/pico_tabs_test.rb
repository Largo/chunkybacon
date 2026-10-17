require_relative "harness"

# A Pico lesson's cells with several files ("tabs") and a board (design
# §2.2, §2.3; docs/HANDOVER.md §6r): the tab list's markup, an editor per
# tab, read-only ones, saved code per editable tab and its reset - on a
# made-up lesson put into the course before the shell starts.
class PicoTabsTest < Minitest::Test
  include ShellTest

  STARTER = "require \"epd2in13\"\n"
  HELPER = "def dechunk(s)\n  s\nend\n"

  def pico_lesson
    cell = { "t" => "c", "code" => STARTER, "board" => { "parts" => ["epd213"] },
             "tabs" => [{ "name" => "epd2in13.rb", "src" => "pico/lib/en/epd2in13.rb" },
                        { "name" => "dechunk.rb", "code" => HELPER, "readonly" => false },
                        { "name" => "notes.rb", "code" => "# fixed\n" }] }
    lesson = { "id" => "pico-tabs", "engine" => "picoruby", "live" => false, "pico" => { "board" => "pico2w" } }
    %w[de en ja].each do |lang|
      lesson[lang] = { "title" => "Tabs", "cells" => [{ "t" => "h", "html" => "<p>x</p>" }, cell,
                                                       { "t" => "c", "code" => "1 + 1" }] }
    end
    lesson
  end

  def open_pico(storage: {})
    start(hash: "#pico-tabs", storage: storage) { window.props["LESSONS"]["lessons"] << pico_lesson }
  end

  def test_tab_list_markup
    html = ChunkyShell::View.cell_html(3, false, "Task", "▶ Run", "", "", "",
                                       [["app.rb", false], ["epd2in13.rb", true], ["dechunk.rb", false]], true,
                                       ["Files", "read-only"])
    assert_includes html, %(<div class="cell-tabs" role="tablist" aria-label="Files">)
    assert_includes html, %(id="cell-tab-3-0" data-idx="3" data-k="0" data-name="app.rb" data-readonly="false" aria-selected="true" aria-controls="cell-panel-3-0" tabindex="0")
    assert_includes html, %(aria-selected="false" aria-controls="cell-panel-3-1" tabindex="-1" aria-label="epd2in13.rb, read-only")
    assert_includes html, %(<span class="cell-tab-lock" aria-hidden="true">🔒</span>epd2in13.rb)
    assert_includes html, %(<textarea title="app.rb" id="cell-code-3"></textarea>)
    assert_includes html, %(id="cell-panel-3-2" aria-labelledby="cell-tab-3-2" hidden><textarea title="dechunk.rb" id="cell-code-3-2">)
    assert_includes html, %(<div class="pico-slot" id="pico-slot-3" hidden></div>)
    plain = ChunkyShell::View.cell_html(3, false, "Task", "▶ Run")
    refute_includes plain, "cell-tabs"
    refute_includes plain, "pico-slot"
  end

  def test_tab_key_has_the_tab_starter_and_is_not_migrated
    key = ChunkyShell::Store.tab_key("en", "pico-wifi", 4, "dechunk.rb", HELPER)
    assert_equal "#{ChunkyShell::Store.code_key('en', 'pico-wifi', 4, HELPER)}~dechunk.rb", key
    assert_includes key, "@"
    fresh_page(storage: { key => "x" })
    ChunkyShell::Store.migrate_code_keys(ChunkyShell::Course.new(JS.global[:LESSONS]))
    assert_equal "x", window.storage[key]
  end

  def test_render_makes_an_editor_per_tab
    open_pico
    inits = calls("initCell").map { |c| c[1] }
    assert_equal %w[1 1-1 1-2 1-3 2], inits
    assert_equal %w[1-1 1-3], calls("initCellReadonly").map { |c| c[1] }
    assert_equal [["setCellTabSrc", "1", "1", "pico/lib/en/epd2in13.rb"]], calls("setCellTabSrc")
    # an inline tab clears its key: a driver fetch of another lesson must
    # not land in its editor (review finding)
    assert_equal [["clearCellTabSrc", "1", "2"], ["clearCellTabSrc", "1", "3"]], calls("clearCellTabSrc")
    assert_includes calls("setCellCode"), ["setCellCode", "1-2", HELPER]
    assert_equal 1, calls("ensurePicoBoard").size
    # the static benches, once the cells are drawn (pico_board.js previews)
    assert_equal 1, calls("picoBoardPreviews").size
    assert_operator window.calls.index { |c| c[0] == "picoBoardPreviews" }, :>, window.calls.rindex { |c| c[0] == "initCell" }
    assert find("#pico-slot-1")
    assert find(".cell-tab[data-name='dechunk.rb']")
    assert_empty JS.console_errors
  end

  def test_a_saved_tab_comes_back_and_reset_restores_it
    key = ChunkyShell::Store.tab_key("de", "pico-tabs", 1, "dechunk.rb", HELPER)
    open_pico(storage: { key => "def dechunk(s) = s.strip\n" })
    assert_includes calls("setCellCode"), ["setCellCode", "1-2", "def dechunk(s) = s.strip\n"]
    @app.save_tab(1, "dechunk.rb", "def mine; end\n")
    assert_equal "def mine; end\n", window.storage[key]
    # a read-only tab is never saved
    @app.save_tab(1, "notes.rb", "changed")
    @app.save_tab(1, "epd2in13.rb", "changed")
    refute(window.storage.keys.any? { |k| k.end_with?("~notes.rb", "~epd2in13.rb") })
    @app.reset_lesson
    refute window.storage.key?(key)
    assert_equal ["setCellCode", "1-2", HELPER], calls("setCellCode").last(3).find { |c| c[1] == "1-2" }
  end
end
