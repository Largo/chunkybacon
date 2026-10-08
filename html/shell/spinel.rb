# The Spinel lesson below the cell (lesson 45): what happens to a program
# that main.rb's spinel(code) hands over - the steps with their times, its
# output, the C it was compiled through, the module to download, CRuby's
# output of the same code beside it - and IRB on Spinel (show_spinel_irb).
#
# The compiling is done in workers, Ruby on PicoRuby.wasm too (html/spinel/,
# started through spinel/boot.js): one compiler for the page, fetched when
# the lesson opens (preload), and a worker per run of a program, stopped
# when its time is up. The kernel reaches this through two window functions,
# with plain strings: chunkySpinelMount(id, source, output, error, ms) and
# chunkySpinelIrb(id), id being the element it put below the cell.
module ChunkyShell
  # IRB on a compiler. A compiled program has no eval: every input is
  # compiled together with the inputs before it into a program of its own and
  # run from the start, and only what the new input printed is shown - what
  # the earlier ones print comes again, before a marker. Plain Ruby
  # (test/shell/spinel_test.rb).
  class SpinelSession
    MARK = "\u0001"    # what follows was printed by the new input
    VALUE = "\u0002"   # what follows is its value, inspected
    PRINT_MARK = "print \"\\u0001\"\n"
    PRINT_VALUE = "print \"\\u0002\"\n"
    DEF = /^\s*def\s+(self\.)?([A-Za-z_][A-Za-z0-9_]*[?!=]?|[-+*\/%<>=!~^&|\[\]]+)/
    CLASS = /^\s*(class|module)\s/

    attr_reader :lines

    def initialize
      @lines = []   # the inputs that compiled and ran
    end

    # The program for an input, and the line of it the input starts on. A
    # definition answers as IRB does without being run for a value (a
    # method: its name, a class or module: nil); anything else is wrapped in
    # parentheses - no new scope, so a local it assigns is the program's.
    def program(input)
      head = ""
      @lines.each { |line| head += "#{line}\n" }
      head += PRINT_MARK
      first = head.split("\n").length + 1
      # the first line decides (^ is a line's start in CRuby, the input's in
      # PicoRuby, whose regexps are JavaScript's)
      opening = input.split("\n").first.to_s
      match = opening.match(DEF)
      return ["#{head}#{input}\n#{PRINT_VALUE}p :#{match[2]}\n", first] if match
      return ["#{head}#{input}\n#{PRINT_VALUE}p nil\n", first] if opening.match(CLASS)

      ["#{head}__irb_value = (\n#{input}\n)\n#{PRINT_VALUE}p __irb_value\n", first + 1]
    end

    # "main.rb:12: ..." about the program -> "(irb):1: ..." about the input
    def self.renumber(text, first)
      text.to_s.gsub(/main\.rb:[0-9]+/) do |found|
        line = found.sub("main.rb:", "").to_i - first + 1
        "(irb):#{line < 1 ? 1 : line}"
      end
    end

    # what a run of program(input) said: {"ok", "output", "value", "messages"};
    # the input joins the session when it ran to its end
    def outcome(input, first, code, stdout, stderr)
      mark = stdout.index(MARK)
      value = mark ? stdout.index(VALUE, mark + 1) : nil
      if code != 0 || value.nil?
        output = mark ? stdout[mark + 1, (value || stdout.length) - mark - 1] : ""
        message = stderr.to_s.empty? ? "exit #{code}" : stderr
        return { "ok" => false, "output" => output, "messages" => SpinelSession.renumber(message, first) }
      end
      @lines << input
      text = stdout[value + 1, stdout.length]
      text = text[0, text.length - 1] if text.end_with?("\n")
      { "ok" => true, "output" => stdout[mark + 1, value - mark - 1], "value" => text }
    end
  end

  class SpinelUI
    include Support

    RUN_LIMIT = 10   # seconds a program may run
    BOOT = "spinel/boot.js"

    def initialize(app)
      @app = app
      @worker = nil      # the compiler's
      @up = false        # its Ruby runs: requests may go out
      @outbox = []
      @state = "idle"    # loading, ready, failed
      @version = nil
      @error = nil
      @progress = nil    # [part, done, total]
      @pending = {}      # request id => the block that takes the answer
      @seq = 0
      @watchers = []     # blocks that follow the loading; false: done
    end

    def start
      ui = self
      window = JSG.w
      JS::Object.register_callback("chunkySpinelMount") do |id, source, output, error, ms|
        ui.guard("spinel") { ui.mount(id, source, output, error, ms) }
        nil
      end
      window["chunkySpinelMount"] = JS.generic_callbacks[:chunkySpinelMount]
      JS::Object.register_callback("chunkySpinelIrb") do |id|
        ui.guard("spinel irb") { ui.irb(id) }
        nil
      end
      window["chunkySpinelIrb"] = JS.generic_callbacks[:chunkySpinelIrb]
      self
    end

    # ---------- helpers ----------

    def t(key, arg = nil)
      text = @app.ui[key] || key
      arg.nil? ? text : text.sub("%s", arg.to_s)
    end

    def lang = @app.lang

    def tag(name, cls = nil, text = nil)
      node = JSG.d.createElement(name)
      node.className = cls if cls
      node.textContent = text if text
      node
    end

    def now = JSG.w.performance.now

    def seconds(ms)
      return "#{ms < 1 ? 1 : ms.round} ms" if ms < 1000

      View.run_time(ms / 1000.0, lang)
    end

    def kilobytes(bytes)
      text = format("%.1f KB", bytes / 1024.0)
      lang == "de" ? text.tr(".", ",") : text
    end

    def options(type)
      object = JSG.w.Object.new
      object[:type] = type
      object
    end

    def message(fields)
      object = JSG.w.Object.new
      fields.each { |key, value| object[key] = value }
      object
    end

    def worker(role)
      JSG.w.Worker.new(JSG.w.URL.new("#{BOOT}?role=#{role}", JSG.d.baseURI).href, options("module"))
    end

    # ---------- the compiler's worker ----------

    # the shell's lesson render calls this for the lesson that compiles
    def preload
      return if @worker

      @state = "loading"
      @error = nil
      @up = false
      ui = self
      @worker = worker("compiler")
      @worker.addEventListener("message", sync: true) { |event| guard("spinel") { ui.from_compiler(event[:data]) } }
      @worker.addEventListener("error", sync: true) { |event| guard("spinel") { ui.failed(event[:message].to_s) } }
    end

    def from_compiler(data)
      type = data[:type].to_s
      if type == "up"
        @up = true
        @worker.postMessage(message("type" => "load"))
        @outbox.each { |item| @worker.postMessage(message(item)) }
        @outbox = []
      elsif type == "progress"
        @progress = [data[:part].to_s, data[:done], data[:total]]
        notify
      elsif type == "ready"
        @state = "ready"
        @version = data[:version].to_s
        notify
      elsif type == "failed"
        failed(data[:error].to_s)
      elsif type == "built" || type == "parsed"
        done = @pending.delete(data[:id])
        done.call(answer(data)) if done
      end
    end

    def answer(data)
      { "ok" => data[:ok] == true, "stage" => data[:stage], "c" => data[:c], "wasm" => data[:wasm],
        "messages" => data[:messages].to_s, "ms_spinel" => data[:ms_spinel], "ms_clang" => data[:ms_clang],
        "verdict" => data[:verdict].to_s }
    end

    # the next preload tries again; who waited hears why
    def failed(error)
      @state = "failed"
      @error = error.empty? ? "?" : error
      @worker.terminate if @worker
      @worker = nil
      waiting = @pending
      @pending = {}
      waiting.each do |_id, done|
        done.call({ "ok" => false, "stage" => "load", "messages" => @error, "verdict" => "error #{@error}" })
      end
      notify
    end

    def notify
      @watchers = @watchers.select { |watcher| watcher.call }
    end

    # build or parse +source+; the block gets the answer (a Hash)
    def request(type, source, &done)
      preload
      @seq += 1
      @pending[@seq] = done
      item = { "type" => type, "id" => @seq, "source" => source }
      @up ? @worker.postMessage(message(item)) : @outbox << item
    end

    # the block gets true once Spinel is there, false when it failed or the
    # node left the page; +line+ shows how far the loading is meanwhile
    def when_ready(line, alive, &done)
      preload
      return done.call(true) if @state == "ready"

      ui = self
      # called on every change of the loading; true: keep calling
      watcher = lambda do
        if !alive.call || ui.failed?
          done.call(false)
          false
        elsif ui.ready?
          done.call(true)
          false
        else
          line.textContent = ui.loading_text
          true
        end
      end
      @watchers << watcher if watcher.call
    end

    def ready? = @state == "ready"
    def failed? = @state == "failed"
    attr_reader :version

    def loading_text
      if @progress && @progress[0] == "clang" && @progress[2].to_i > 0
        "#{t("spinelLoad")} – #{(100.0 * @progress[1] / @progress[2]).round} %"
      else
        "#{t("spinelLoad")} …"
      end
    end

    def failed_text
      JSG.w.navigator.onLine == false ? t("spinelOffline") : t("spinelFailed", @error || "?")
    end

    # ---------- a run ----------

    # Runs a module in a worker of its own; the block gets {"code", "stdout",
    # "stderr", "ms", "stopped", "crashed"}. out.call(fd, text) as it prints.
    def run(wasm, alive, out = nil, &done)
      runner = worker("run")
      started = now
      printed = { 1 => [], 2 => [] }
      over = false
      ui = self
      finish = lambda do |result|
        next if over

        over = true
        runner.terminate
        result["stdout"] = printed[1].join
        result["stderr"] = printed[2].join.gsub("/work/", "").strip
        result["ms"] ||= ui.now - started
        done.call(result)
      end
      runner.addEventListener("message", sync: true) do |event|
        guard("spinel run") do
          data = event[:data]
          type = data[:type].to_s
          if type == "up"
            runner.postMessage(message("wasm" => wasm, "stdin" => ""))
          elsif type == "out"
            fd = data[:fd]
            printed[fd == 1 ? 1 : 2] << data[:text].to_s
            out.call(fd, data[:text].to_s) if out
            finish.call({ "code" => -1, "stopped" => true }) unless alive.call
          elsif type == "done"
            finish.call({ "code" => data[:code], "ms" => data[:ms] })
          elsif type == "crashed" || type == "failed"
            finish.call({ "code" => -1, "crashed" => (data[:error] || "?").to_s })
          end
        end
      end
      limit = RUN_LIMIT * 1000
      Task.new do
        sleep_ms(limit)
        finish.call({ "code" => -1, "stopped" => true })
      end
    end

    # ---------- a program (spinel(code)) ----------

    def mount(id, source, cruby_output, cruby_error, cruby_ms)
      node = el(id.to_s)
      return if node.nil?

      program = { "source" => source.to_s, "output" => cruby_output.to_s, "error" => cruby_error.to_s,
                  "ms" => cruby_ms.to_s.to_f }
      box = tag("section", "spinel-box")
      box.setAttribute("aria-label", t("spinelTitle"))
      head = tag("div", "spinel-head")
      head.appendChild(tag("span", "spinel-name", "Spinel"))
      version = tag("span", "spinel-version")
      head.appendChild(version)
      box.appendChild(head)
      steps = tag("ol", "spinel-steps")
      box.appendChild(steps)
      status = tag("p", "spinel-status")
      status.setAttribute("role", "status")
      box.appendChild(status)
      node.appendChild(box)
      widget = { "node" => node, "box" => box, "steps" => steps, "status" => status, "version" => version,
                 "program" => program }
      ui = self
      alive = -> { JSG.truthy?(node.isConnected) }
      widget["alive"] = alive
      loading = step(widget, t("spinelLoad"))
      started = now
      when_ready(loading["name"], alive) do |ok|
        ui.guard("spinel") { ui.loaded(widget, loading, ok, started) }
      end
    end

    # one line of the steps: its name, and its time once done
    def step(widget, name)
      item = tag("li", "spinel-step is-busy")
      label = tag("span", "spinel-step-name", name)
      time = tag("span", "spinel-step-time", "…")
      item.appendChild(label)
      item.appendChild(time)
      widget["steps"].appendChild(item)
      { "item" => item, "name" => label, "time" => time }
    end

    def done(line, ms, ok = true)
      line["item"].classList.remove("is-busy")
      line["item"].classList.add(ok ? "is-done" : "is-failed")
      line["time"].textContent = ms.nil? ? "" : seconds(ms)
    end

    def problem(widget, title, text = nil)
      div = tag("div", "spinel-problem")
      div.appendChild(tag("strong", nil, title))
      div.appendChild(tag("pre", nil, text)) if text && !text.empty?
      widget["box"].appendChild(div)
    end

    def loaded(widget, loading, ok, started)
      return unless widget["alive"].call

      loading["name"].textContent = t("spinelLoad")
      unless ok
        done(loading, nil, false)
        widget["status"].textContent = failed_text
        problem(widget, failed_text)
        return
      end
      waited = now - started
      done(loading, waited < 50 ? nil : waited)
      widget["version"].textContent = @version.to_s
      compiling = step(widget, t("spinelCompile"))
      widget["status"].textContent = "#{t("spinelCompile")} …"
      ui = self
      request("build", widget["program"]["source"]) do |built|
        ui.guard("spinel") { ui.built(widget, compiling, built) }
      end
    end

    def built(widget, compiling, built)
      return unless widget["alive"].call

      stage = built["stage"].to_s
      done(compiling, built["ms_spinel"], stage != "spinel" && stage != "load")
      if stage == "spinel" || stage == "load"
        widget["status"].textContent = t("spinelRefused")
        problem(widget, t("spinelRefused"), built["messages"])
        compare(widget, nil) if stage == "spinel"
        return
      end
      linking = step(widget, t("spinelLink"))
      done(linking, built["ms_clang"], built["ok"])
      c = built["c"].to_s
      unless c.empty?
        details = tag("details", "spinel-c")
        details.appendChild(tag("summary", nil, t("spinelShowC", kilobytes(c.length))))
        details.appendChild(tag("pre", nil, c))
        widget["box"].appendChild(details)
        widget["c"] = details
      end
      unless built["ok"]
        widget["status"].textContent = t("spinelCcFailed")
        problem(widget, t("spinelCcFailed"), built["messages"])
        return
      end
      running = step(widget, t("spinelRun"))
      widget["status"].textContent = "#{t("spinelRun")} …"
      out = tag("pre", "spinel-out cell-stdout")
      widget["c"] ? widget["box"].insertBefore(out, widget["c"]) : widget["box"].appendChild(out)
      ui = self
      wasm = built["wasm"]
      printer = ->(fd, text) { out.appendChild(JSG.d.createTextNode(text)) if fd == 1 }
      run(wasm, widget["alive"], printer) do |ran|
        ui.guard("spinel") { ui.ran(widget, running, out, wasm, ran) }
      end
    end

    def ran(widget, running, out, wasm, ran)
      return unless widget["alive"].call

      done(running, ran["ms"], ran["code"] == 0)
      out.remove if out.textContent.to_s.empty?
      if ran["stopped"]
        problem(widget, t("spinelStopped", RUN_LIMIT))
      elsif ran["crashed"]
        problem(widget, t("spinelCrashed", ran["crashed"]))
      elsif ran["code"] != 0
        problem(widget, t("spinelExit", ran["code"]), ran["stderr"])
      end
      parts = JSG.w.Array.new
      parts.push(wasm)
      blob = JSG.w.Blob.new(parts, options("application/wasm"))
      link = tag("a", "cell-download spinel-download", t("spinelDownload", kilobytes(wasm[:length].to_i)))
      link.href = JSG.w.URL.createObjectURL(blob)
      link.setAttribute("download", "main.wasm")
      link.title = t("spinelDownloadTitle")
      widget["box"].appendChild(link)
      compare(widget, ran)
    end

    # what CRuby printed when it ran the same code (main.rb), beside Spinel's;
    # without a run (Spinel refused) what CRuby made of it
    def compare(widget, ran)
      cruby = widget["program"]
      row = tag("p", "spinel-compare")
      same = !ran.nil? && cruby["error"].empty? && ran["code"] == 0 && cruby["output"] == ran["stdout"]
      if !cruby["error"].empty?
        row.textContent = t("spinelCrubyError", cruby["error"])
      elsif ran.nil?
        row.textContent = t("spinelCrubyOnly")
        row.appendChild(tag("pre", "cell-stdout", cruby["output"]))
        row.classList.add("is-cruby")
        widget["box"].appendChild(row)
        return
      elsif same
        row.textContent = t("spinelSame", seconds(cruby["ms"]))
      else
        row.textContent = t("spinelDiffers", seconds(cruby["ms"]))
        row.appendChild(tag("pre", "cell-stdout", cruby["output"]))
      end
      row.classList.add(same ? "is-same" : "is-different")
      widget["box"].appendChild(row)
      widget["status"].textContent = row.textContent.to_s.split("\n").first.to_s
    end

    # ---------- IRB (show_spinel_irb) ----------

    def irb(id)
      node = el(id.to_s)
      return if node.nil?

      term = tag("div", "spinel-term")
      term.setAttribute("role", "group")
      term.setAttribute("aria-label", t("spinelIrbTitle"))
      history = tag("div", "spinel-term-history")
      history.setAttribute("role", "log")
      history.setAttribute("aria-live", "polite")
      history.appendChild(tag("div", "spinel-term-note", t("spinelIrbNote")))
      row = tag("div", "spinel-term-line")
      prompt = tag("span", "spinel-term-prompt")
      prompt.setAttribute("aria-hidden", "true")
      input = tag("input", "spinel-term-input")
      input.spellcheck = false
      input.setAttribute("autocomplete", "off")
      input.setAttribute("aria-label", t("spinelIrbInput"))
      row.appendChild(prompt)
      row.appendChild(input)
      term.appendChild(history)
      term.appendChild(row)
      node.appendChild(term)
      alive = -> { JSG.truthy?(node.isConnected) }
      irb = { "history" => history, "prompt" => prompt, "input" => input, "alive" => alive, "number" => 1,
              "buffer" => [], "past" => [], "back" => 0, "session" => SpinelSession.new, "busy" => false }
      irb_prompt(irb)
      ready = irb_say(irb, "note", "")
      ui = self
      when_ready(ready, alive) do |ok|
        ready.textContent = ok ? ui.t("spinelIrbReady", ui.version) : ui.failed_text if alive.call
      end
      input.addEventListener("keydown", sync: true) { |event| guard("spinel irb") { ui.irb_key(irb, event) } }
    end

    def irb_prompt(irb)
      depth = irb["buffer"].length
      irb["prompt"].textContent = format("spinel(main):%03d:%d%s", irb["number"], depth, depth > 0 ? "*" : ">")
    end

    def irb_say(irb, kind, text)
      line = tag(kind == "out" ? "pre" : "div", "spinel-term-#{kind}", text)
      history = irb["history"]
      history.appendChild(line)
      history.scrollTop = history.scrollHeight
      line
    end

    def irb_key(irb, event)
      key = event.key.to_s
      input = irb["input"]
      if key == "ArrowUp" || key == "ArrowDown"
        past = irb["past"]
        return if past.empty?

        event.preventDefault
        back = irb["back"] + (key == "ArrowUp" ? 1 : -1)
        back = 0 if back < 0
        back = past.length if back > past.length
        irb["back"] = back
        input.value = back > 0 ? past[past.length - back] : ""
        return
      end
      return unless key == "Enter" && !irb["busy"]

      event.preventDefault
      text = input.value.to_s
      input.value = ""
      irb["back"] = 0
      irb_say(irb, "echo", "#{irb["prompt"].textContent} #{text}")
      if irb["buffer"].empty? && (text.strip == "exit" || text.strip == "quit")
        irb_say(irb, "note", t("irbExitNote"))
        return
      end
      irb["past"] << text unless text.strip.empty?
      irb["buffer"] << text
      source = irb["buffer"].join("\n")
      if source.strip.empty?
        irb["buffer"] = []
        return irb_prompt(irb)
      end

      irb_busy(irb, true)
      ui = self
      request("parse", source) { |answer| ui.guard("spinel irb") { ui.irb_parsed(irb, source, answer["verdict"]) } }
    end

    def irb_busy(irb, busy)
      irb["busy"] = busy
      irb["input"].disabled = busy
      irb["input"].focus if !busy && irb["alive"].call
    end

    # Spinel's own parser said whether the input is complete
    def irb_parsed(irb, source, verdict)
      return unless irb["alive"].call

      if verdict == "more"
        irb_prompt(irb)
        return irb_busy(irb, false)
      end
      irb["buffer"] = []
      if verdict.start_with?("error")
        irb_say(irb, "error", verdict.sub("error ", ""))
        irb["number"] += 1
        irb_prompt(irb)
        return irb_busy(irb, false)
      end
      irb_prompt(irb)
      wait = irb_say(irb, "note", t("spinelIrbBusy"))
      program, first = irb["session"].program(source)
      started = now
      ui = self
      request("build", program) do |built|
        ui.guard("spinel irb") { ui.irb_built(irb, source, first, built, wait, started) }
      end
    end

    def irb_built(irb, source, first, built, wait, started)
      return unless irb["alive"].call
      unless built["ok"]
        refused = built["stage"] == "spinel" ? "#{t("spinelRefused")}\n" : ""
        return irb_answer(irb, { "ok" => false, "messages" => refused + SpinelSession.renumber(built["messages"], first) },
                          [built["ms_spinel"], built["ms_clang"]], wait, started)
      end

      ui = self
      run(built["wasm"], irb["alive"]) do |ran|
        ui.guard("spinel irb") do
          result = if ran["stopped"] then { "ok" => false, "messages" => ui.t("spinelStopped", RUN_LIMIT) }
                   elsif ran["crashed"] then { "ok" => false, "messages" => ui.t("spinelCrashed", ran["crashed"]) }
                   else irb["session"].outcome(source, first, ran["code"], ran["stdout"], ran["stderr"])
                   end
          ui.irb_answer(irb, result, [built["ms_spinel"], built["ms_clang"], ran["ms"]], wait, started)
        end
      end
    end

    def irb_answer(irb, result, times, wait, started)
      return unless irb["alive"].call

      wait.remove
      output = result["output"].to_s
      output = output[0, output.length - 1] if output.end_with?("\n")   # a <pre> shows it as a blank line
      irb_say(irb, "out", output) unless output.empty?
      result["ok"] ? irb_say(irb, "result", "=> #{result["value"]}") : irb_say(irb, "error", result["messages"].to_s)
      parts = []
      times.each { |ms| parts << seconds(ms) unless ms.nil? }
      irb_say(irb, "time", "#{parts.join(" + ")} (#{seconds(now - started)})")
      irb["number"] += 1
      irb_prompt(irb)
      irb_busy(irb, false)
    end
  end
end
