require_relative "harness"

# html/shell/cheatsheet.rb: the cheat sheet beside the lesson - opening and
# closing, the sections from lessons.js, search, lesson links, Escape.
class CheatsheetTest < Minitest::Test
  include ShellTest

  def panel = byid("cheatsheet")
  def button = byid("cheatBtn")
  def open? = doc.js_get("body").attrs["class"].to_s.split.include?("cheat-open")
  def sections = find_all("#cheatBody .cheat-section")
  def sheet_data = window.props["LESSONS"]["cheatsheet"]

  def type(text)
    byid("cheatSearch").props["value"] = text
    JS.fire(byid("cheatSearch").wrap, "input")
  end

  def escape = JS.fire(JS.window, "keydown", "key" => "Escape")

  def test_the_header_button_and_a_closed_sheet
    start
    assert_equal "Spickzettel", byid("cheatLabel").text
    assert_equal "false", button.attrs["aria-expanded"]
    assert panel.js_get("hidden")
    refute open?
    assert_empty sections, "nothing is drawn before the sheet is opened"
    assert_empty JS.console_errors
  end

  def test_the_button_opens_every_section
    start
    click(button)
    assert open?
    refute panel.js_get("hidden")
    assert_equal "true", button.attrs["aria-expanded"]
    assert_equal "Ruby-Spickzettel", byid("cheatTitle").text
    assert_equal sheet_data.length, sections.length
    assert_equal sheet_data.length, find_all("#cheatToc .cheat-chip").length
    assert_equal "Grundlagen", find("#cheat-basics .cheat-name").text
    # the code column is escaped text, the explanation the course's own html
    assert_includes byid("cheatBody").html, "<code>puts &quot;Hallo!&quot;</code>"
    assert_includes byid("cheatBody").html, "Text ausgeben"
    assert byid("cheatSearch").props["focused"], "a wide screen takes the keyboard into the search field"
    assert_equal "open", window.storage["chunkyui_cheat"]
    click(button)
    refute open?
    assert_nil window.storage["chunkyui_cheat"]
    assert_empty JS.console_errors
  end

  def test_sections_name_their_lessons_and_link_the_docs
    start
    click(button)
    links = find_all("#cheat-strings a.cheat-lesson")
    assert_equal ["strings"], links.map { |a| a.attrs["data-id"] }
    assert_equal ["4"], links.map(&:text)
    assert_equal "#strings", links.first.attrs["href"]
    docs = find_all("#cheat-strings .cheat-docs a")
    assert_includes docs.map { |a| a.attrs["href"] }, "https://docs.ruby-lang.org/en/4.0/String.html"
    assert(docs.all? { |a| a.attrs["target"] == "_blank" })
  end

  def test_a_lesson_number_opens_that_lesson_and_keeps_a_docked_sheet
    start
    click(button)
    prevented = click(find("#cheat-hashes a.cheat-lesson"))
    assert prevented
    assert_equal "hashes", find("#lessonNav a.active").attrs["data-id"]
    assert open?, "beside the lesson the sheet stays out"
  end

  def test_on_a_phone_it_lies_over_the_page_and_a_lesson_closes_it
    start { window.narrow = true }
    click(button)
    assert open?
    assert byid("cheatClose").props["focused"], "no keyboard popping up on a phone"
    assert_nil window.storage["chunkyui_cheat"], "a phone does not bring it back over the next page"
    click(find("#cheat-loops a.cheat-lesson"))
    assert_equal "schleifen", find("#lessonNav a.active").attrs["data-id"]
    refute open?
  end

  def test_search_filters_rows_and_sections
    start
    click(button)
    type("gsub")
    assert_equal ["cheat-strings", "cheat-regexp"], sections.map { |s| s.attrs["id"] }
    assert_equal 1, find_all("#cheat-strings tr").length
    assert_equal 2, find_all("#cheatToc .cheat-chip").length
    type("Hashes")
    assert_equal sheet_data.find { |s| s["id"] == "hashes" }["rows"].length, find_all("#cheat-hashes tr").length,
                 "a section's name finds all its rows"
    type("zzz")
    assert_equal "Nichts gefunden.", find("#cheatBody .cheat-none").text
    type("")
    assert_equal sheet_data.length, sections.length
  end

  def test_escape_empties_the_search_then_closes
    start
    click(button)
    type("gsub")
    doc.focused = byid("cheatSearch")
    escape
    assert_equal "", byid("cheatSearch").props["value"]
    assert_equal sheet_data.length, sections.length
    assert open?
    escape
    refute open?
    assert button.props["focused"], "the keyboard goes back to the button"
  end

  def test_escape_in_a_cell_leaves_a_docked_sheet_alone
    start
    click(button)
    doc.focused = nil # the keyboard is in a cell, outside the sheet
    escape
    assert open?
  end

  def test_the_close_button
    start
    click(button)
    click(byid("cheatClose"))
    refute open?
    assert panel.js_get("hidden")
  end

  def test_a_link_in_a_lesson_opens_it
    start
    link = find("#lessonBody .cheat-link")
    refute_nil link, "lesson 1 points to the cheat sheet"
    click(link)
    assert open?
  end

  def test_a_link_naming_a_section_jumps_there
    start
    byid("lessonBody").js_set("innerHTML", %(<p><button type="button" class="cheat-link" data-cheat="hashes">x</button></p>))
    click(find("#lessonBody .cheat-link"))
    assert open?
    assert byid("cheat-hashes").props["scrolledTo"]
  end

  def test_a_chip_jumps_to_its_section
    start
    click(button)
    click(find("#cheatToc .cheat-chip[data-cheat='time']"))
    assert byid("cheat-time").props["scrolledTo"]
  end

  def test_it_comes_back_open_on_a_wide_screen
    start(storage: { "chunkyui_cheat" => "open" })
    assert open?
    refute byid("cheatSearch").props["focused"], "coming back does not take the keyboard"
    refute_empty sections
  end

  def test_the_language_switch_redraws_it
    start
    click(button)
    byid("langSelect").props["value"] = "en"
    JS.fire(byid("langSelect").wrap, "change")
    assert_equal "Cheat sheet", byid("cheatLabel").text
    assert_equal "Ruby cheat sheet", byid("cheatTitle").text
    assert_equal "Basics", find("#cheat-basics .cheat-name").text
    assert_includes find("#cheat-strings .cheat-lessons").text, "Lesson"
    byid("langSelect").props["value"] = "ja"
    JS.fire(byid("langSelect").wrap, "change")
    ja = find_all("#cheat-strings .cheat-docs a").map { |a| a.attrs["href"] }
    assert_includes ja, "https://docs.ruby-lang.org/ja/latest/class/String.html", "Japanese links Rurima"
    assert_empty JS.console_errors
  end

  def test_view_matches_are_case_blind_and_html_is_escaped
    sections = [{ id: "s", title: "Strings", lessons: [], docs: [],
                  rows: [["a < b", "less", "a < b less"], ["Up", "<code>x</code>", "up <code>x</code>"]] }]
    html = ChunkyShell::Cheatsheet.body_html(sections, "UP", "Lektion", "Doku", "nichts")
    assert_includes html, "<code>Up</code>"
    refute_includes html, "a &lt; b"
    all = ChunkyShell::Cheatsheet.body_html(sections, "", "Lektion", "Doku", "nichts")
    assert_includes all, "<code>a &lt; b</code>"
    assert_includes all, "<td><code>x</code></td>"
  end

  def test_a_longer_example_stands_above_its_explanation
    assert_equal %(<tr class="cheat-wide"><td colspan="2"><code>if x\n  y\nend</code><div>text</div></td></tr>),
                 ChunkyShell::Cheatsheet.row_html(["if x\n  y\nend", "text", ""])
    assert_includes ChunkyShell::Cheatsheet.row_html(["x" * 21, "long", ""]), %(class="cheat-wide")
    assert_equal %(<tr><td><code>x = 5</code></td><td>short</td></tr>), ChunkyShell::Cheatsheet.row_html(["x = 5", "short", ""])
  end
end
