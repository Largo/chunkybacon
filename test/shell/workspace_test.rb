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

  # ---------- offline (offline.js) ----------

  def offline = window.offline
  def offline_text = dialog.js_querySelector(".pd-offline").text

  def open_dialog(&setup)
    start(&setup)
    click(byid("progressBtn"))
  end

  def test_python_in_the_copy_is_a_checkbox
    open_dialog { offline.state = "ready" }
    box = dialog.js_querySelector(".pd-check input")
    assert_equal true, box.props["checked"], "ticked unless unticked"
    assert_includes offline_text, "Python mitnehmen"
    box.props["checked"] = false
    JS.fire(box.wrap, "change")
    assert_equal [["setPython", false]], offline.calls
  end

  def test_python_left_out_stays_unticked
    open_dialog { offline.python = false }
    refute dialog.js_querySelector(".pd-check input").props["checked"]
  end

  def test_offline_is_off_until_asked_for
    open_dialog
    assert_includes offline_text, "Offline lernen"
    assert_includes offline_text, "87 MB Speicherplatz (ohne Python 20 und 44 MB)"
    click(button_labelled("Auf diesem Gerät speichern", dialog))
    assert_equal [["enable"]], offline.calls
  end

  def test_offline_where_the_browser_cannot
    open_dialog { offline.supported = false }
    assert_includes offline_text, "geht in diesem Browser nicht"
    assert_nil button_labelled("Auf diesem Gerät speichern", dialog)
  end

  def test_saving_counts_files_without_redrawing
    open_dialog do
      offline.state = "loading"
      offline.total = 40
      offline.done = 12
    end
    busy = dialog.js_querySelector(".pd-offline .pd-busy")
    assert_equal "Wird gespeichert … 12/40", busy.text
    offline.done = 13
    offline.emit("status")
    assert_same busy, dialog.js_querySelector(".pd-offline .pd-busy"), "the same element, so focus stays"
    assert_equal "Wird gespeichert … 13/40", busy.text
    offline.state = "ready"
    offline.emit("status")
    assert_includes offline_text, "Stand: 01.10.26, 15:30"
  end

  def test_a_saved_copy_and_deleting_it
    open_dialog do
      offline.state = "ready"
      offline.from_copy = true
    end
    assert_includes offline_text, "✓ Auf diesem Gerät gespeichert"
    assert_includes offline_text, "Du bist gerade offline"
    click(button_labelled("Kopie löschen (44 MB)", dialog))
    assert_equal [["disable"]], offline.calls
  end

  def test_a_failed_copy_offers_another_try
    open_dialog do
      offline.state = "error"
      offline.error = "QuotaExceededError"
    end
    assert_includes offline_text, "konnte nicht gespeichert werden: QuotaExceededError"
    click(button_labelled("Nochmals versuchen", dialog))
    assert_equal [["enable"]], offline.calls
  end

  def test_offline_in_english
    open_dialog { offline.state = "ready" }
    byid("langSelect").props["value"] = "en"
    JS.fire(byid("langSelect").wrap, "change")
    assert_includes offline_text, "Saved on this device – works offline too. As of 10/1/26, 3:30 PM"
    assert button_labelled("Delete the copy (44 MB)", dialog)
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

  # ---------- renaming ----------

  def file_button(path) = find_all("#wsFiles .ws-file").find { |b| b.text == path }
  def rename_button(path) = find_all("#wsFiles .ws-ren").find { |b| b.attrs["aria-label"].include?(path) }

  # the rename input for +path+, given +name+ and +key+
  def rename(path, name, key = "Enter")
    click(rename_button(path))
    input = find(".ws-newname")
    assert_equal path, input.props["value"], "the input starts with the current name"
    input.props["value"] = name
    JS.fire(input.wrap, "keydown", "key" => key)
  end

  PNG = "data:image/png;base64,iVBORw0KGgo="
  PDF = "data:application/pdf;base64,JVBERi0xLjQ="

  def test_rename_keeps_the_extension_when_none_is_typed
    workshop(files: { "a.rb" => "1", "main.rb" => "2", "bild.png" => PNG })
    rename("a.rb", "rechner")
    assert_equal "1", fs.files["rechner.rb"]
    refute fs.files.key?("a.rb")
    rename("bild.png", "fuchs")
    assert_equal PNG, fs.files["fuchs.png"]
    assert_nil find(".ws-newname")
    assert file_button("fuchs.png")
  end

  def test_renaming_the_open_file_keeps_it_open
    workshop
    editor.type("puts 3")
    rename("main.rb", "start.rb")
    assert_equal "puts 3", fs.files["start.rb"]
    refute fs.files.key?("main.rb")
    assert_equal "start.rb", byid("wsTab").text
    assert_equal "start.rb", window.storage["chunkyui_ws_open"]
    assert_equal "puts 3", editor.js_getValue
  end

  def test_rename_refuses_taken_and_bad_names_and_escape_keeps_the_old_one
    workshop(files: { "a.rb" => "1", "main.rb" => "2" })
    rename("a.rb", "main.rb")
    assert_includes find(".ws-error").text, "gibt es schon"
    assert find(".ws-newname"), "still renaming"
    find(".ws-newname").props["value"] = "a b.rb"
    JS.fire(find(".ws-newname").wrap, "keydown", "key" => "Enter")
    assert_includes find(".ws-error").text, "Buchstaben"
    JS.fire(find(".ws-newname").wrap, "keydown", "key" => "Escape")
    assert_nil find(".ws-newname")
    assert_equal({ "a.rb" => "1", "main.rb" => "2" }, fs.files)
  end

  # ---------- pictures and PDFs ----------

  def test_a_picture_shows_instead_of_the_editor
    workshop(files: { "main.rb" => "puts 1", "bild.png" => PNG })
    click(file_button("bild.png"))
    assert_equal PNG, find("#wsPreview img").attrs["src"]
    refute byid("wsPreview").props["hidden"]
    assert_includes find(".ws-editor").attrs["class"], "is-preview"
    assert_equal "bild.png", byid("wsTab").text
    assert find('.run-cell[data-idx="0"]').props["disabled"]
    assert_equal "puts 1", editor.js_getValue, "the editor keeps its text"
    kernel_calls("workshopAfterRun")
    assert_equal PNG, fs.files["bild.png"], "a run does not save the editor over the picture"
    assert_empty JS.console_errors
  end

  # 12288 bytes: three SQLite pages of 4096, as base64
  DATABASE = "data:application/vnd.sqlite3;base64,#{'A' * 16384}"

  def test_a_database_is_described_instead_of_the_editor
    workshop(files: { "main.rb" => "1", "zeit.db" => DATABASE })
    click(file_button("zeit.db"))
    text = find("#wsPreview p.ws-database").text
    assert_includes text, "SQLite-Datenbank (12 KB)"
    assert_includes text, "Sequel.sqlite"
    assert_nil find_all("#wsPreview img").first, "not drawn as a picture"
    assert_includes find(".ws-editor").attrs["class"], "is-preview"
    kernel_calls("workshopAfterRun")
    assert_equal DATABASE, fs.files["zeit.db"], "a run does not save the editor over the database"
  end

  def test_a_database_can_be_uploaded
    workshop
    picker = find_all("#wsFiles input").find { |input| input.props["multiple"] }
    accept = picker.props["accept"].to_s
    %w[.db .sqlite .sqlite3].each { |ext| assert_includes accept.split(","), ext }
  end

  def test_a_tiny_picture_is_drawn_bigger
    workshop(files: { "main.rb" => "1", "bild.png" => PNG })
    click(file_button("bild.png"))
    picture = find("#wsPreview img")
    picture.props["naturalWidth"] = 8
    JS.fire(picture.wrap, "load")
    assert_includes picture.attrs["class"].to_s, "is-tiny"
  end

  def test_a_pdf_shows_in_the_browsers_viewer_and_goes_again
    workshop(files: { "main.rb" => "1", "karte.pdf" => PDF })
    click(file_button("karte.pdf"))
    src = find("#wsPreview iframe").attrs["src"]
    assert_match(/\Ablob:preview-\d+#view=FitH\z/, src)
    assert_equal PDF, calls("objectUrl").last[1]
    click(file_button("main.rb"))
    assert byid("wsPreview").props["hidden"]
    refute_includes find(".ws-editor").attrs["class"].to_s, "is-preview"
    assert_equal src.delete_suffix("#view=FitH"), calls("revokeUrl").last[1], "the Blob URL is released"
    assert editor.props["refreshed"], "CodeMirror redraws after being hidden"
    assert_equal "1", editor.js_getValue
  end

  def test_a_picture_the_program_writes_shows_at_once
    workshop(storage: { "chunkyui_ws_open" => "bild.png" }, files: { "main.rb" => "1", "bild.png" => PNG })
    fresh = "data:image/png;base64,TkVX"
    kernel_calls("workspaceWrite", "bild.png", fresh)
    assert_equal fresh, fs.files["bild.png"]
    assert_equal fresh, find("#wsPreview img").attrs["src"]
    refute editor.js_getValue.start_with?("data:"), "the picture never goes into the editor"
  end

  def test_download_a_picture_as_what_it_is
    workshop(storage: { "chunkyui_ws_open" => "bild.png" }, files: { "main.rb" => "1", "bild.png" => PNG })
    click(button_labelled("Herunterladen"))
    assert_equal ["saveText", "bild.png", PNG], calls("saveText").last
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
