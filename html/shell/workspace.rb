# The UI for storage.js (formerly workspace_ui.js): the progress dialog
# behind the header button, and the workshop's file panel. storage.js keeps
# the work - localStorage, a connected folder, the progress file - and stays
# JavaScript; this draws it. The kernel runs the workshop's programs and
# asks for the files through the window functions at the bottom. Every name
# the learner or a folder brings in goes into the page as text, never as HTML.
module ChunkyShell
  class Workspace
    include Support

    OPEN_KEY = "chunkyui_ws_open"   # no "chunky_": a view setting, not progress
    # element properties; anything else in node(...) is an attribute
    PROPS = %w[className type id textContent hidden disabled value title placeholder
               spellcheck accept multiple rows open].freeze
    RUBY_FILE = /\.rb$|^(Gemfile|Rakefile)$/
    # pictures and PDFs - data: URLs in storage.js - show instead of the
    # editor; matched against the lowercased name
    PICTURE_OR_PDF = /\.(png|jpg|jpeg|gif|webp|pdf)$/
    PDF_FILE = /\.pdf$/
    TEXT_FILES = ".rb,.txt,.csv,.tsv,.json,.md,.yml,.yaml,.erb,.html,.css,.xml"
    UPLOADS = "#{TEXT_FILES},.png,.jpg,.jpeg,.gif,.webp,.pdf"

    def initialize(app, storage = JSG.w.ChunkyStorage, bridge = JSG.w.ChunkyBridge)
      @app = app
      @s = storage
      @bridge = bridge
      @message = nil        # [text, "ok" | "error"] after an action
      @open = nil
      @editor = nil
      @dirty = false
      @save_gen = 0         # a pending debounced save runs only if still current
      @creating = false
      @renaming = nil       # the file whose name is being edited
      @name_error = ""
      @stdin = ""
      @preview_url = nil    # the Blob URL of a previewed PDF, released when it goes
    end

    def start
      wire
      render_button
      self
    end

    # ---------- helpers ----------

    # a UI string in the page's language, German when missing; %s -> arg
    def t(key, arg = nil)
      text = @app.ui[key] || @app.course.ui("de")[key] || key
      arg.nil? ? text : text.sub("%s", arg.to_s)
    end

    # node("button", { className: "x", on: { "click" => proc { ... } } }, ["label", other_node])
    def node(tag, props = {}, children = [])
      element = JSG.d.createElement(tag)
      props.each do |key, value|
        name = key.to_s
        if name == "on"
          value.each { |type, handler| listen(element, type, handler) }
        elsif PROPS.include?(name)
          element[name] = value
        else
          element.setAttribute(name, value.to_s)
        end
      end
      children.each do |child|
        next if child.nil?

        element.appendChild(child.is_a?(String) ? JSG.d.createTextNode(child) : child)
      end
      element
    end

    def listen(element, type, handler)
      element.addEventListener(type, sync: true) { |event| guard(type) { handler.call(event) } }
    end

    # replaceChildren, skipping the parts left out (nil)
    def fill(parent, children)
      parent.textContent = ""
      children.each { |child| parent.appendChild(child) unless child.nil? }
    end

    def storage_get(key)
      JSG.w.localStorage.getItem(key)
    rescue StandardError
      nil
    end

    def storage_set(key, value)
      JSG.w.localStorage.setItem(key, value)
    rescue StandardError
      nil   # a view setting only
    end

    # Promises are awaited in a Task (a sync handler must not suspend); the
    # block gets {ok, value, name, message} (ChunkyBridge.settle). settle is
    # attached at once, not in the Task: a rejection before it would count as
    # unhandled (and, while CRuby loads, as the kernel failing - bridge.js).
    def later(promise, &block)
      outcome = @bridge.settle(promise)
      ws = self
      Task.new { ws.settled(outcome, block) }
    end

    def settled(outcome, block)
      guard("storage") { block.call(outcome.await) }
    end

    # ---------- the progress dialog ----------

    def button = el("progressBtn")
    def dialog = el("progressDialog")

    def wire
      listen(button, "click", proc do
        @message = nil
        dialog.showModal
        render_dialog
      end)
      # a click on the backdrop closes it, like Escape
      listen(dialog, "click", proc { |event| dialog.close if event.target == dialog })
      ws = self
      register("chunkyWsWorkspace") { ws.storage_changed }
      register("chunkyWsStatus") { ws.status_changed }
      @s.on("workspace", JS.generic_callbacks[:chunkyWsWorkspace])
      @s.on("status", JS.generic_callbacks[:chunkyWsStatus])
      # files edited in another program come in when the tab gets focus back
      listen(JSG.w, "focus", proc { @s.files.refresh if el("wsFiles") })
      # what the kernel asks for while it runs a workshop program (main.rb)
      register("workshopOpenPath") { ws.open_path }
      register("workshopStdin") { ws.stdin }
      register("workspaceSnapshot") { ws.snapshot }
      register("workspaceWrite") { |path, text| ws.program_wrote(path, text) }
      register("workspaceDelete") { |path| ws.program_deleted(path) }
      register("workshopAfterRun") { ws.after_run }
      register("chunkyWsChange") { |_cm, change| ws.editor_changed(change) }
    end

    # a Ruby block as a JavaScript function, also as window[name]
    def register(name, &block)
      JS::Object.register_callback(name, &block)
      JSG.w[name] = JS.generic_callbacks[name.to_sym]
    end

    # HH:MM, as de-CH, en-GB and ja-JP all write it
    def clock(date) = format("%02d:%02d", date.getHours, date.getMinutes)

    def render_button
      label = el("progressLabel")
      label.textContent = t("progressButton") if label
      button.setAttribute("aria-label", t("progressButton"))
      state = @s.state
      error = @s.error
      button.classList.toggle("is-connected", state == "folder" && error.nil?)
      button.classList.toggle("needs-attention", state == "locked" || !error.nil?)
    end

    def act(promise, ok_text = nil)
      later(promise) do |result|
        if result.ok
          @message = ok_text ? [ok_text, "ok"] : nil
        else
          # closing the folder picker is not an error
          @message = result.name == "AbortError" ? nil : [t("folderError", result.message), "error"]
        end
        render_dialog
      end
    end

    def action_button(css, label, &handler)
      node("button", { type: "button", className: css, on: { "click" => handler } }, [label])
    end

    def folder_section
      return [node("p", {}, [t("folderUnsupported")])] unless @s.supported

      state = @s.state
      name = @s.folderName
      out = [node("h3", {}, [t("folderTitle")])]
      if state == "none"
        out << node("p", {}, [t("folderExplain")])
        out << node("div", { className: "pd-actions" }, [
          action_button("pd-primary", t("folderChoose")) { act(@s.connectFolder) }
        ])
      elsif state == "locked"
        out << node("p", {}, [t("folderResumeNote")])
        out << node("div", { className: "pd-actions" }, [
          action_button("pd-primary", t("folderResume", name)) { act(@s.resumeFolder) },
          action_button("pd-secondary", t("folderDisconnect")) { act(@s.disconnectFolder) }
        ])
      else
        saved = @s.savedAt
        text = "📁 #{t('folderConnected', name)}"
        text += " #{t('folderSavedAt', clock(saved))}" if saved
        out << node("p", { className: "pd-connected" }, [text])
        out << node("div", { className: "pd-actions" }, [
          action_button("pd-secondary", t("folderDisconnect")) { act(@s.disconnectFolder) }
        ])
      end
      error = @s.error
      out << node("p", { className: "pd-error" }, [t("folderError", error)]) if error
      out
    end

    def file_section
      input = node("input", { type: "file", accept: ".json,application/json", hidden: true })
      listen(input, "change", proc { load_progress(input) })
      [
        node("h3", {}, [t("fileTitle")]),
        node("p", {}, [t("fileExplain")]),
        node("div", { className: "pd-actions" }, [
          action_button("pd-secondary", t("fileDownload")) { @s.downloadProgress },
          action_button("pd-secondary", t("fileLoad")) { input.click },
          input
        ])
      ]
    end

    def load_progress(input)
      file = input.files[0]
      return unless file

      later(@s.loadProgressFile(file)) do |result|
        @message = if result.ok
                     [t(result.value ? "fileLoaded" : "fileUnchanged"), "ok"]
                   else
                     [t("fileInvalid"), "error"]
                   end
        render_dialog
      end
    end

    def render_dialog
      box = dialog
      return unless box.open

      close = node("button", { type: "button", className: "pd-close", "aria-label" => t("close"), title: t("close"),
                               on: { "click" => proc { box.close } } }, ["×"])
      message_class = @message ? "pd-message is-#{@message[1]}" : "pd-message"
      fill(box, [
        node("div", { className: "pd-head" }, [node("h2", { id: "progressTitle" }, [t("progressTitle")]), close]),
        node("p", { className: "pd-intro" }, [t("progressIntro")]),
        node("section", {}, folder_section),
        node("section", {}, file_section),
        node("p", { className: message_class, role: "status" }, [@message ? @message[0] : ""])
      ])
    end

    # the page's language changed (App#render_all)
    def language_changed
      render_button
      render_dialog
    end

    def status_changed
      render_button
      render_dialog
      render_files
    end

    # ---------- the workshop's file panel ----------

    def ruby?(path) = !(path.split("/").last.to_s =~ RUBY_FILE).nil?
    def binary?(path) = !(path.to_s.downcase =~ PICTURE_OR_PDF).nil?
    def pdf?(path) = !(path.to_s.downcase =~ PDF_FILE).nil?
    def files = @s.files.list.to_a

    def preferred(list)
      want = storage_get(OPEN_KEY)
      return want if want && list.include?(want)
      return "main.rb" if list.include?("main.rb")

      list.find { |path| ruby?(path) } || list.first
    end

    def ensure_starter
      @s.files.write("main.rb", t("wsStarter")) if files.empty?
    end

    def flush_save
      @save_gen += 1   # a pending debounced save is not needed any more
      # a picture or PDF is never the editor's text
      return unless @dirty && @open && @editor && !binary?(@open)

      @dirty = false
      @s.files.write(@open, @editor.getValue)
    end

    def open_file(path)
      flush_save
      @open = path
      return render_files if path.nil? || @editor.nil?

      storage_set(OPEN_KEY, path)
      if binary?(path)
        show_preview(path)
      else
        hide_preview
        text = @s.files.read(path)
        @editor.setValue(text.nil? ? "" : text)
        @editor.setOption("mode", ruby?(path) ? "text/x-ruby" : "text/plain")
        @editor.clearHistory
      end
      tab = el("wsTab")
      tab.textContent = path if tab
      run = JSG.d.querySelector('.run-cell[data-idx="0"]')
      if run
        run.disabled = !ruby?(path)
        run.title = ruby?(path) ? "" : t("wsNotRuby")
      end
      render_files
    end

    # A picture or PDF in place of the editor: the picture from its data:
    # URL, the PDF in the browser's own viewer from a Blob URL. A tiny
    # picture (ChunkyPNG's 8x8) is drawn bigger, pixel by pixel.
    def show_preview(path)
      box = el("wsPreview")
      return unless box

      editor_box&.classList&.add("is-preview")
      release_preview_url
      value = @s.files.read(path).to_s
      shown = if pdf?(path)
                @preview_url = @bridge.objectUrl(value)
                node("iframe", { className: "ws-pdf", title: path, src: "#{@preview_url}#view=FitH" })
              else
                picture = node("img", { alt: path, src: value })
                listen(picture, "load", proc { picture.classList.add("is-tiny") if picture.naturalWidth < 160 })
                picture
              end
      fill(box, [shown])
      box.hidden = false
    end

    # back to the editor; CodeMirror redraws what it could not measure hidden
    def hide_preview
      box = el("wsPreview")
      return unless box && !box.hidden

      release_preview_url
      box.hidden = true
      box.textContent = ""
      editor_box&.classList&.remove("is-preview")
      @editor&.refresh
    end

    def release_preview_url
      @bridge.revokeUrl(@preview_url) if @preview_url
      @preview_url = nil
    end

    def editor_box = JSG.d.querySelector(".ws-editor")

    NAME_PART = /^[A-Za-z0-9_äöüÄÖÜ][A-Za-z0-9_.\-äöüÄÖÜ]*$/
    NAMED_FILE = /\.[A-Za-z0-9]+$|^(Gemfile|Rakefile)$/

    def valid_name?(path)
      return false if path.nil? || path.empty? || path.length > 80 || path == @s.PROGRESS_FILE
      # an empty part ("a//b", "/a", "a/"), which split would drop
      return false if path.start_with?("/") || path.end_with?("/") || path.include?("//")

      parts = path.split("/")
      return false if (parts.last =~ NAMED_FILE).nil?

      parts.all? { |part| !(part =~ NAME_PART).nil? }
    end

    def create_file(raw)
      path = raw.to_s.strip
      path += ".rb" if !path.empty? && (path =~ /\.[^\/]+$/).nil?
      unless valid_name?(path)
        @name_error = t("wsBadName")
        return render_files
      end
      unless @s.files.read(path).nil?
        @name_error = t("wsExists", path)
        return render_files
      end
      @creating = false
      @name_error = ""
      @s.files.write(path, "")
      open_file(path)
      @editor.focus if @editor
    end

    # A file under a new name. Typed without an extension, it keeps its own
    # (bild -> bild.png); the open file stays open under the new name.
    def rename_file(from, raw)
      to = raw.to_s.strip
      to += extension(from) if !to.empty? && (to =~ /\.[^\/]+$/).nil?
      return stop_renaming if to == from
      unless valid_name?(to)
        @name_error = t("wsBadName")
        return render_files
      end
      unless @s.files.read(to).nil?
        @name_error = t("wsExists", to)
        return render_files
      end
      was_open = from == @open
      flush_save if was_open
      @renaming = nil
      @name_error = ""
      @s.files.rename(from, to)
      if was_open
        @open = nil   # nothing left to save under the old name
        open_file(to)
      else
        render_files
      end
    end

    # ".png" for "bilder/fuchs.png", "" for "Gemfile"
    def extension(path)
      name = path.split("/").last.to_s
      parts = name.split(".")
      parts.length > 1 ? ".#{parts.last}" : ""
    end

    def start_renaming(path)
      @renaming = path
      @creating = false
      @name_error = ""
      render_files
    end

    def stop_renaming
      @renaming = nil
      @name_error = ""
      render_files
    end

    def remove_file(path)
      return unless JSG.w.confirm(t("wsDeleteConfirm", path))

      if path == @open
        @dirty = false
        @save_gen += 1
      end
      @s.files.remove(path)
      if path == @open
        ensure_starter
        open_file(preferred(files))
      else
        render_files
      end
    end

    def upload(file_list)
      all = file_list.to_a
      picked = all.select { |file| file.size <= 1_000_000 && valid_name?(file.name) }
      ws = self
      Task.new { ws.store_uploads(picked, picked.length < all.length) }
    end

    def store_uploads(picked, skipped)
      guard("upload") do
        names = []
        picked.each do |file|
          # a picture or PDF is kept as its data: URL
          value = binary?(file.name) ? @bridge.settle(@s.files.readDataUrl(file)).await.value : file.text.await
          @bridge.settle(@s.files.write(file.name, value)).await
          names << file.name
        end
        @name_error = skipped ? t("wsBadName") : ""
        names.empty? ? render_files : open_file(names[0])
      end
    end

    def render_files
      box = el("wsFiles")
      return unless box

      list = files
      where = @s.files.kind == "folder" ? "📁 #{t('wsInFolder', @s.folderName)}" : t("wsInBrowser")
      items = list.map { |path| file_item(path) }
      picker = node("input", { type: "file", multiple: true, hidden: true, accept: UPLOADS })
      listen(picker, "change", proc { upload(picker.files) })
      fill(box, [
        node("h3", {}, [t("wsFiles")]),
        node("p", { className: "ws-where" }, [where]),
        locked_note,
        node("ul", { className: "ws-list" }, items),
        new_file_control,
        @name_error.empty? ? nil : node("p", { className: "ws-error", role: "alert" }, [@name_error]),
        node("div", { className: "ws-actions" }, [
          action_button("ws-action", t("wsUpload")) { picker.click },
          download_button,
          picker
        ])
      ])
    end

    def file_item(path)
      return rename_item(path) if path == @renaming

      current = path == @open
      node("li", { className: current ? "is-open" : "" }, [
        node("button", { type: "button", className: "ws-file", "aria-current" => current ? "true" : "false",
                         on: { "click" => proc { open_file(path) unless path == @open } } }, [path]),
        node("button", { type: "button", className: "ws-ren", "aria-label" => t("wsRename", path), title: t("wsRename", path),
                         on: { "click" => proc { start_renaming(path) } } }, ["✎"]),
        node("button", { type: "button", className: "ws-del", "aria-label" => t("wsDelete", path), title: t("wsDelete", path),
                         on: { "click" => proc { remove_file(path) } } }, ["×"])
      ])
    end

    # the name, editable: Enter renames, Escape leaves it as it was
    def rename_item(path)
      input = node("input", { type: "text", className: "ws-newname", value: path, spellcheck: false,
                              "aria-label" => t("wsRename", path) })
      listen(input, "keydown", proc do |event|
        if event.key == "Enter"
          event.preventDefault
          rename_file(path, input.value)
        elsif event.key == "Escape"
          stop_renaming
        end
      end)
      Task.new do
        sleep_ms 0
        input.focus
      end
      node("li", { className: "is-renaming" }, [input])
    end

    def locked_note
      return nil unless @s.state == "locked"

      node("p", { className: "ws-locked" }, [
        "#{t('wsLocked', @s.folderName)} ",
        action_button("ws-action", t("wsUnlock")) { later(@s.resumeFolder) { |_result| nil } }
      ])
    end

    def new_file_control
      return action_button("ws-action", t("wsNewFile")) { start_creating } unless @creating

      input = node("input", { type: "text", className: "ws-newname", placeholder: "name.rb", spellcheck: false,
                              "aria-label" => t("wsNewFile") })
      listen(input, "keydown", proc do |event|
        if event.key == "Enter"
          event.preventDefault
          create_file(input.value)
        elsif event.key == "Escape"
          @creating = false
          @name_error = ""
          render_files
        end
      end)
      Task.new do
        sleep_ms 0
        input.focus
      end
      input
    end

    def start_creating
      @creating = true
      @renaming = nil
      render_files
    end

    def download_button
      button = action_button("ws-action", t("wsDownload")) do
        flush_save
        @bridge.saveText(@open, @s.files.read(@open) || "") if @open
      end
      button.disabled = @open.nil?
      button
    end

    def render_stdin
      box = el("wsStdinBox")
      return unless box

      area = node("textarea", { id: "wsStdin", rows: 3, spellcheck: false, placeholder: t("wsStdinHint"), value: @stdin })
      listen(area, "input", proc { @stdin = area.value })
      fill(box, [node("details", { open: @stdin != "" }, [node("summary", {}, [t("wsStdin")]), area])])
    end

    # App#render_workshop, after the editor (cell 0) exists
    def mount
      flush_save
      @editor = JSG.w.cellEditors["0"]
      @creating = false
      @name_error = ""
      ensure_starter
      @editor.on("change", JS.generic_callbacks[:chunkyWsChange])
      render_stdin
      open_file(preferred(files))
    end

    # typing saves the file half a second after the last key
    def editor_changed(change)
      return if change.origin == "setValue"

      @dirty = true
      gen = (@save_gen += 1)
      ws = self
      Task.new do
        sleep_ms 500
        ws.flush_save if ws.save_pending?(gen)
      end
    end

    def save_pending?(gen) = gen == @save_gen

    # the folder came or went, or its files changed (storage.js)
    def storage_changed
      return unless el("wsFiles") && @editor

      ensure_starter
      list = files
      return open_file(preferred(list)) if @open.nil? || !list.include?(@open)

      if binary?(@open)
        show_preview(@open)
      elsif !@dirty
        text = @s.files.read(@open)
        @editor.setValue(text) if !text.nil? && text != @editor.getValue
      end
      render_files
    end

    # ---------- what the kernel asks for (main.rb, run_cell) ----------

    def open_path = @open || ""
    def stdin = @stdin
    def snapshot = JSG.w.JSON.stringify(@s.files.snapshot)

    # A file the program wrote (a picture or PDF as a data: URL); the open
    # one shows what is new - in the editor, or in the preview.
    def program_wrote(path, text)
      if path == @open && @editor && !binary?(path)
        @dirty = false
        @save_gen += 1
        @editor.setValue(text)
      end
      @s.files.write(path, text)
      show_preview(path) if path == @open && binary?(path)
      nil
    end

    def program_deleted(path)
      @s.files.remove(path)
      nil
    end

    # a run saves the file in the editor, like any IDE (unless the program
    # itself just wrote that file, which program_wrote put in the editor)
    def after_run
      @save_gen += 1
      @dirty = false
      if @open && @editor && !binary?(@open) && @s.files.read(@open) != @editor.getValue
        @s.files.write(@open, @editor.getValue)
      end
      render_files
      nil
    end
  end
end
