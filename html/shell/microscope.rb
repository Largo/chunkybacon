# The expert lessons' step-through views, drawn by the shell (PicoRuby):
# main.rb's show_yarv, show_lookup and show_gc (html/microscope.rb, CRuby)
# compute what Ruby did; mount_microscope makes an empty element below the
# cell and calls chunkyMicroscope(id, kind, json), which lands here.
#
#   kind "yarv"  the cell's code compiled by YARV, one instruction per step:
#                the source line, the running frame's instruction sequence
#                with ▶ at its pc, and the VM stack as YARV lays it out
#                (vm_push_frame): per control frame its locals, the three
#                env slots ep points at, then its operands; a block's ep
#                leads to the env it reads
#   kind "flip"  pictures CRuby drew (method lookup, mark and sweep), one
#                per step
#
# The step data can be hundreds of KB: JavaScript parses it (JSON.parse in
# PicoRuby takes seconds, docs/PICORUBY_SHELL.md §5 #3), Ruby reads the
# fields of the step it shows. A step's sentence comes as [key, args...];
# its template is the ui string "msc" + Key in the page's language.
module ChunkyShell
  class MicroscopeUI
    include Support

    def initialize(app)
      @app = app
    end

    def start
      ui = self
      JS::Object.register_callback("chunkyMicroscope") do |id, kind, json|
        ui.guard("microscope") { ui.mount(id.to_s, kind.to_s, json.to_s) }
        nil
      end
      JSG.w["chunkyMicroscope"] = JS.generic_callbacks[:chunkyMicroscope]
      self
    end

    def mount(id, kind, json)
      node = JSG.d.getElementById(id)
      return unless node

      data = JSG.w.JSON.parse(json)
      view = MicroscopeView.new(self, node, kind, data)
      view.build
      view
    end

    def t(key, fallback = nil)
      text = @app.ui[key]
      text.nil? || text.to_s.empty? ? (fallback || key) : text.to_s
    end

    # "%s" filled in order with +args+
    def fill(template, args)
      out = template.to_s
      args.each { |arg| out = out.sub("%s", arg.nil? ? "" : arg.to_s) }
      out
    end

    def sentence(note)
      list = note.to_a
      return "" if list.empty?

      key = list[0].to_s
      template = t("msc" + key[0].upcase + key[1, key.length], key + " %s %s %s %s")
      fill(template, list[1, list.length])
    end

    def tag(name, cls = nil, text = nil)
      node = JSG.d.createElement(name)
      node.className = cls if cls
      node.textContent = text if text
      node
    end
  end

  # one widget below a cell: its controls, its steps
  class MicroscopeView
    def initialize(ui, node, kind, data)
      @ui = ui
      @node = node
      @kind = kind
      @data = data
      @steps = kind == "yarv" ? data[:steps].to_a : data[:frames].to_a
      @at = 0
      @playing = false
      @previous = {}
    end

    def build
      @node.className = @kind == "yarv" ? "msc-box msc-yarv" : "msc-box msc-flip"
      if @kind == "yarv"
        head = @ui.tag("div", "msc-head")
        head.appendChild(@ui.tag("span", "msc-title", @ui.t("mscYarvTitle", "YARV, step by step")))
        head.appendChild(@ui.tag("span", "msc-sub", "ruby.wasm · CRuby 4.0.0 · wasm32"))
        @node.appendChild(head)
      end
      @node.appendChild(controls)
      @note = @ui.tag("p", "msc-note")
      @note.setAttribute("aria-live", "polite")
      @node.appendChild(@note)
      if @kind == "yarv"
        grid = @ui.tag("div", "msc-grid")
        @src = @ui.tag("div", "msc-panel msc-src")
        @insns = @ui.tag("div", "msc-panel msc-insns")
        @stack = @ui.tag("div", "msc-panel msc-stack")
        grid.appendChild(@src)
        grid.appendChild(@insns)
        grid.appendChild(@stack)
        @node.appendChild(grid)
        @out = @ui.tag("pre", "msc-out")
        @node.appendChild(@out)
        @lines = @data[:source].to_s.split("\n")
        @seqs = @data[:seqs].to_a
        @output = @data[:output].to_s
      else
        @pic = @ui.tag("div", "msc-pic")
        @node.appendChild(@pic)
      end
      go(0)
    end

    # ---------- controls: ⏮ ◀ slider ▶ ⏭ ⏵ ----------

    def button(text, label)
      b = @ui.tag("button", "msc-btn", text)
      b.setAttribute("type", "button")
      b.setAttribute("aria-label", label)
      b
    end

    def controls
      view = self
      ui = @ui
      bar = @ui.tag("div", "msc-controls")
      first = button("⏮", @ui.t("mscFirst", "First step"))
      back = button("◀", @ui.t("mscPrev", "Back"))
      @range = @ui.tag("input", "msc-range")
      @range.setAttribute("type", "range")
      @range.setAttribute("min", "0")
      @range.setAttribute("max", (@steps.length - 1).to_s)
      @range.setAttribute("aria-label", @ui.t("mscSlider", "Step"))
      forth = button("▶", @ui.t("mscNext", "Next step"))
      last = button("⏭", @ui.t("mscLast", "Last step"))
      @play = button("⏵ #{@ui.t("mscPlay", "Play")}", @ui.t("mscPlay", "Play"))
      @play.className = "msc-btn msc-play"
      @count = @ui.tag("span", "msc-count")
      [first, back, @range, forth, last, @play, @count].each { |n| bar.appendChild(n) }
      first.addEventListener("click", sync: true) { ui.guard("msc") { view.stop; view.go(0) } }
      back.addEventListener("click", sync: true) { ui.guard("msc") { view.stop; view.go(view.at - 1) } }
      forth.addEventListener("click", sync: true) { ui.guard("msc") { view.stop; view.go(view.at + 1) } }
      last.addEventListener("click", sync: true) { ui.guard("msc") { view.stop; view.go(view.total - 1) } }
      @range.addEventListener("input", sync: true) { ui.guard("msc") { view.stop; view.go(view.slider) } }
      @play.addEventListener("click", sync: true) { ui.guard("msc") { view.toggle } }
      bar
    end

    def at = @at
    def total = @steps.length
    def slider = @range.value.to_s.to_i

    def stop
      @playing = false
      @play.textContent = "⏵ #{@ui.t("mscPlay", "Play")}"
    end

    def toggle
      if @playing
        stop
        return
      end
      go(0) if @at >= total - 1
      @playing = true
      @play.textContent = "⏸ #{@ui.t("mscPause", "Pause")}"
      view = self
      Task.new { view.play_loop }
    end

    # ⏵: a step every 650 ms (1.5 s when the reader asked for less motion)
    def play_loop
      calm = JSG.w.matchMedia("(prefers-reduced-motion: reduce)").matches == true
      while @playing
        sleep_ms(calm ? 1500 : 650)
        break unless @playing && @node.isConnected == true

        if @at >= total - 1
          stop
          break
        end
        @ui.guard("msc play") { go(@at + 1) }
      end
    end

    def go(index)
      index = 0 if index < 0
      index = total - 1 if index > total - 1
      @at = index
      @range.value = index.to_s
      label = @ui.fill(@ui.t("mscStep", "Step %s of %s"), [index + 1, total])
      @count.textContent = label
      @range.setAttribute("aria-valuetext", label)
      step = @steps[index]
      @note.textContent = @ui.sentence(step[:note])
      @kind == "yarv" ? show_yarv(step) : show_picture(step)
    end

    def show_picture(step)
      @pic.innerHTML = step[:html].to_s
      svg = @pic.querySelector("svg")
      return unless svg

      svg.setAttribute("role", "img")
      svg.setAttribute("aria-label", @note.textContent.to_s)
    end

    # ---------- YARV ----------

    def show_yarv(step)
      frames = step[:frames].to_a
      done = frames.empty?
      key = step[:note].to_a[0].to_s
      @note.className = done ? (key == "done" ? "msc-note is-done" : "msc-note is-warn") : "msc-note"
      show_source(step[:line])
      show_insns(step[:seq], step[:pc])
      show_stack(frames)
      @out.textContent = @output[0, step[:out].to_i]
      @out.hidden = @output.empty?
      @out.setAttribute("data-label", @ui.t("mscOutput", "Output"))
    end

    def show_source(line)
      @src.textContent = ""
      @src.appendChild(@ui.tag("div", "msc-h", @ui.t("mscSource", "Source")))
      @lines.each_with_index do |text, n|
        row = @ui.tag("div", line == n + 1 ? "msc-line is-now" : "msc-line")
        row.appendChild(@ui.tag("span", "msc-ln", (n + 1).to_s))
        row.appendChild(@ui.tag("code", nil, text.empty? ? " " : text))
        @src.appendChild(row)
      end
    end

    def show_insns(ref, pc)
      @insns.textContent = ""
      title = @ui.t("mscInsns", "Instructions")
      seq = ref.nil? ? nil : @seqs[ref]
      @insns.appendChild(@ui.tag("div", "msc-h", seq ? "#{title}: #{seq[:name]}" : title))
      return unless seq

      now = nil
      seq[:insns].to_a.each_with_index do |text, n|
        row = @ui.tag("div", n == pc ? "msc-insn is-now" : "msc-insn")
        row.appendChild(@ui.tag("span", "msc-pc", n == pc ? "▶" : ""))
        row.appendChild(@ui.tag("span", "msc-ln", format("%04d", n)))
        row.appendChild(@ui.tag("code", nil, text.to_s))
        @insns.appendChild(row)
        now = row if n == pc
      end
      return unless now && @insns.scrollHeight > @insns.clientHeight

      top = now.offsetTop - @insns.clientHeight / 2
      @insns.scrollTop = top < 0 ? 0 : top
    end

    # the top of the stack at the top: the frames from the newest down,
    # each with its operands, its env (ep points at the flags) and locals
    def show_stack(frames)
      @stack.textContent = ""
      @stack.appendChild(@ui.tag("div", "msc-h", @ui.t("mscStack", "VM stack")))
      seen = {}
      i = frames.length - 1
      while i >= 0
        frame = frames[i]
        top = i == frames.length - 1
        @stack.appendChild(frame_box(frame, top, seen))
        i -= 1
      end
      if frames.empty?
        same = @data[:same] == true
        @stack.appendChild(@ui.tag("div", "msc-cell msc-cnote", same ? "✓ #{@data[:real]}" : @data[:real].to_s))
      end
      @previous = seen
    end

    def frame_box(frame, top, seen)
      kind = frame[:kind].to_s
      box = @ui.tag("div", top ? "msc-frame msc-#{kind} is-top" : "msc-frame msc-#{kind}")
      head = @ui.tag("div", "msc-fhead")
      head.appendChild(@ui.tag("span", "msc-fname", frame[:name].to_s))
      head.appendChild(@ui.tag("span", "msc-fkind", kind == "cfunc" ? @ui.t("mscCfunc", "C function") : kind))
      box.appendChild(head)
      unless frame[:ep].nil?
        to = if frame[:epLive] == true
               @ui.fill(@ui.t("mscEpTo", "ep[-1] → the env of %s"), [frame[:epName]])
             else
               @ui.fill(@ui.t("mscEpHeap", "ep[-1] → the env of %s, now on the heap"), [frame[:epName]])
             end
        box.appendChild(@ui.tag("div", "msc-ep", "↳ #{to}"))
      end
      if kind == "cfunc"
        box.appendChild(@ui.tag("div", "msc-cell msc-cnote", @ui.t("mscCfuncNote", "runs in C: no YARV instructions")))
        return box
      end
      id = frame[:id].to_s
      ops = frame[:ops].to_a
      o = ops.length - 1
      while o >= 0
        value = ops[o].to_s
        key = "#{id}:op#{o}"
        cell = @ui.tag("div", @previous[key] == value ? "msc-cell msc-op" : "msc-cell msc-op is-new")
        cell.appendChild(@ui.tag("span", "msc-k", top && o == ops.length - 1 ? "sp →" : ""))
        cell.appendChild(@ui.tag("code", nil, value))
        box.appendChild(cell)
        seen[key] = value
        o -= 1
      end
      [["flags", "ep →"], ["specval", ""], ["me/cref", ""]].each do |name, mark|
        cell = @ui.tag("div", "msc-cell msc-env")
        cell.appendChild(@ui.tag("span", "msc-k", mark))
        cell.appendChild(@ui.tag("span", nil, name))
        box.appendChild(cell)
      end
      locals = frame[:locals].to_a
      l = locals.length - 1
      while l >= 0
        pair = locals[l].to_a
        name = pair[0].to_s
        value = pair[1].to_s
        key = "#{id}:#{name}"
        changed = !@previous[key].nil? && @previous[key] != value
        cell = @ui.tag("div", changed ? "msc-cell msc-local is-new" : "msc-cell msc-local")
        cell.appendChild(@ui.tag("span", "msc-k", name))
        cell.appendChild(@ui.tag("code", nil, value))
        box.appendChild(cell)
        seen[key] = value
        l -= 1
      end
      box.appendChild(@ui.tag("div", "msc-self", "self = #{frame[:self]}"))
      box
    end
  end
end
