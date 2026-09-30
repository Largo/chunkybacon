require_relative "harness"

# html/shell/workspace.rb: the progress dialog and the workshop's file panel
# on the stub DOM, with storage.js as a Hash-backed fake (stubs/js.rb).
class WorkspaceTest < Minitest::Test
  include ShellTest

  def fs = window.fs
  def editor = window.editors["0"]
  def dialog = byid("progressDialog")
  def button_labelled(text, within = doc) = within.descendants.find { |n| n.tag == "button" && n.text == text }
  def kernel_calls(name, *args) = window.props[name].call(*args)

  # the workshop, with these files in the browser's storage
  def workshop(storage: {}, files: {})
    start(hash: "#werkstatt", storage: storage) { fs.files.merge!(files) }
  end

  # ---------- the progress dialog ----------

  def test_the_header_button
    start
    assert_equal "Fortschritt", byid("progressLabel").text
    assert_equal "Fortschritt", byid("progressBtn").attrs["aria-label"]
    refute_includes byid("progressBtn").attrs["class"].to_s, "needs-attention"
  end

  def test_the_button_follows_the_language
    start
    byid("langSelect").props["value"] = "en"
    JS.fire(byid("langSelect").wrap, "change")
    assert_equal "Progress", byid("progressLabel").text
  end

  def test_a_locked_folder_asks_for_attention
    start { fs.state = "locked" }
    assert_includes byid("progressBtn").attrs["class"], "needs-attention"
  end

  def test_the_dialog_without_folder_access_offers_the_file
    start
    click(byid("progressBtn"))
    assert dialog.props["open"]
    text = dialog.text
    assert_includes text, "Dein Fortschritt"
    assert_includes text, "Hier geht es mit einer Datei", "no File System Access here"
    click(button_labelled("Datei herunterladen", dialog))
    assert_equal [["downloadProgress"]], fs.calls
  end

  def test_loading_a_progress_file
    start
    click(byid("progressBtn"))
    input = dialog.descendants.find { |n| n.tag == "input" && n.props["type"] == "file" }
    input.props["files"] = [{ "name" => "progress.json" }]
    JS.fire(input.wrap, "change")
    assert_equal "loadProgressFile", fs.calls.last.first
    message = dialog.js_querySelector(".pd-message")
    assert_includes message.attrs["class"], "is-ok"
    assert_equal "Fortschritt geladen.", message.text
  end

  def test_a_file_that_is_no_progress_file
    start { fs.load_result = JS::Promise.reject("not a progress file") }
    click(byid("progressBtn"))
    input = dialog.descendants.find { |n| n.tag == "input" && n.props["type"] == "file" }
    input.props["files"] = [{ "name" => "x.json" }]
    JS.fire(input.wrap, "change")
    message = dialog.js_querySelector(".pd-message")
    assert_includes message.attrs["class"], "is-error"
    assert_includes message.text, "keine Fortschrittsdatei"
  end

  def test_close_and_backdrop
    start
    click(byid("progressBtn"))
    click(dialog.js_querySelector(".pd-close"))
    refute dialog.props["open"]
    click(byid("progressBtn"))
    JS.fire(dialog.wrap, "click", "target" => dialog)
    refute dialog.props["open"]
  end

  # ---------- the workshop ----------

  def test_the_workshop_starts_with_a_main_rb
    workshop
    assert_includes fs.files["main.rb"], "Werkstatt"
    assert_equal fs.files["main.rb"], editor.js_getValue
    assert_equal "main.rb", byid("wsTab").text
    assert_equal "in diesem Browser", find(".ws-where").text
    assert_equal "main.rb", find("#wsFiles li.is-open .ws-file").text
    assert_empty JS.console_errors
  end

  def test_the_last_open_file_opens_again
    workshop(storage: { "chunkyui_ws_open" => "a.rb" }, files: { "a.rb" => "1", "main.rb" => "2" })
    assert_equal "a.rb", byid("wsTab").text
    assert_equal "1", editor.js_getValue
  end

  def test_new_file_gets_rb_and_opens
    workshop
    click(button_labelled("+ Neue Datei"))
    input = find(".ws-newname")
    input.props["value"] = "rechner"
    assert JS.fire(input.wrap, "keydown", "key" => "Enter")
    assert_equal "", fs.files["rechner.rb"]
    assert_equal "rechner.rb", byid("wsTab").text
    assert_nil find(".ws-newname")
  end

  def test_bad_and_taken_names
    workshop
    click(button_labelled("+ Neue Datei"))
    find(".ws-newname").props["value"] = "a b"
    JS.fire(find(".ws-newname").wrap, "keydown", "key" => "Enter")
    assert_includes find(".ws-error").text, "Buchstaben"
    find(".ws-newname").props["value"] = "main.rb"
    JS.fire(find(".ws-newname").wrap, "keydown", "key" => "Enter")
    assert_includes find(".ws-error").text, "gibt es schon"
  end

  def test_names
    workshop
    ws = @app.instance_variable_get(:@workspace)
    %w[spiel.rb daten/liste.txt Gemfile bär.rb].each { |ok| assert ws.valid_name?(ok), ok }
    ["a b.rb", "a", "/a.rb", "a//b.rb", "a/", "chunkybacon-progress.json", "x" * 81 + ".rb"].each do |bad|
      refute ws.valid_name?(bad), bad
    end
  end

  def test_typing_saves_the_file
    workshop
    editor.type("puts 42")
    assert_equal "puts 42", fs.files["main.rb"]
  end

  def test_a_non_ruby_file_cannot_run
    workshop(files: { "notiz.txt" => "Speck", "main.rb" => "1" })
    click(find_all("#wsFiles .ws-file").find { |b| b.text == "notiz.txt" })
    run = find('.run-cell[data-idx="0"]')
    assert run.props["disabled"]
    assert_includes run.props["title"], ".rb"
  end

  def test_deleting_the_open_file_goes_back_to_main
    workshop(storage: { "chunkyui_ws_open" => "a.rb" }, files: { "a.rb" => "1", "main.rb" => "2" })
    click(find("#wsFiles li.is-open .ws-del"))
    assert_nil fs.files["a.rb"]
    assert_equal "main.rb", byid("wsTab").text
  end

  def test_download_the_open_file
    workshop
    click(button_labelled("Herunterladen"))
    assert_equal "main.rb", calls("saveText").last[1]
  end

  def test_stdin_box
    workshop
    area = byid("wsStdin")
    area.props["value"] = "Isi\n"
    JS.fire(area.wrap, "input")
    assert_equal "Isi\n", kernel_calls("workshopStdin")
  end

  # ---------- what the kernel asks for during a run ----------

  def test_the_kernel_reads_the_project
    workshop(files: { "main.rb" => "puts 1", "lib/a.rb" => "x" })
    assert_equal "main.rb", kernel_calls("workshopOpenPath")
    assert_equal({ "lib/a.rb" => "x", "main.rb" => "puts 1" }, JSON.parse(kernel_calls("workspaceSnapshot")))
  end

  def test_what_a_program_writes_and_deletes
    workshop(files: { "main.rb" => "puts 1", "notiz.txt" => "x" })
    kernel_calls("workspaceWrite", "aus/ergebnis.txt", "Isi: 42")
    kernel_calls("workspaceWrite", "main.rb", "puts 2\n")
    kernel_calls("workspaceDelete", "notiz.txt")
    assert_equal "Isi: 42", fs.files["aus/ergebnis.txt"]
    assert_equal "puts 2\n", editor.js_getValue, "the open file shows what the program wrote"
    assert_nil fs.files["notiz.txt"]
  end

  def test_a_run_saves_the_editor
    workshop
    editor.instance_variable_set(:@value, "puts :changed")   # typed, not yet saved
    kernel_calls("workshopAfterRun")
    assert_equal "puts :changed", fs.files["main.rb"]
    assert_includes byid("wsFiles").text, "main.rb"
  end

  def test_files_changed_elsewhere_come_in
    workshop
    fs.files["extern.rb"] = "puts :extern"
    fs.emit("workspace")
    assert_includes byid("wsFiles").text, "extern.rb"
  end
end
