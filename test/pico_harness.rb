# The check harness of the Pico lessons (docs/HANDOVER.md §6r): for each
# lesson with "pico", in de, en and ja, the exercise's starter must fail
# its check and every known solution pass - run under CRuby on the Pico
# simulator (html/pico_sim/, test/pico_cruby_host.rb), with the cell's tabs
# as files to require and its bench script, and the check given `output`,
# `result` (a PicoRubyCells::Value, as the page hands it over), `code` and
# `board` (PicoRubyCells::Board of the world's summary).
#
#   ruby test/pico_harness.rb                    # the pico lessons of html/lessons.js
#   ruby test/pico_harness.rb tmp/pico-lessons/pico-blink.json [more.json]
#                                                # lessons in files of their own
#   options: --demos (also run the demo cells, under CRuby: a smoke test -
#            test/pico_wasm_test.mjs runs them on PicoRuby), --lang=en,
#            --only=id,id
#
# A lesson file is one lesson object as in html/lessons.js, plus its
# solutions: {"id": ..., "engine": "picoruby", "pico": {...}, "de": {...},
# "en": {...}, "ja": {...}, "solutions": {"de": [...], "en": [...]}} (ja
# runs en's). A solution is the main file's code, or {"code": ..., "tabs":
# {"dechunk.rb": "..."}} for one that also changes an editable tab. Such a
# file is linted first (test/pico_lint.rb: tabs, board, bench, parity).
# For the lessons in html/lessons.js the solutions come from
# test/check_harness.rb's SOLUTIONS (which runs this for them, solutions on
# stdin with --stdin).
#
# Each language runs in a process of its own: top-level defs and classes
# outlive a run (an English solution's def would let the Japanese starter
# pass), as in check_harness.rb.
require "json"
require "stringio"
require "open3"
require "rbconfig"
require_relative "pico_lint"

module PicoHarness
  ROOT = File.expand_path("..", __dir__)
  HTML = File.join(ROOT, "html")
  LANGS = %w[de en ja].freeze
  SOLUTION_LANG = { "ja" => "en" }.freeze

  module_function

  def options(argv)
    opts = { files: [], demos: false, langs: LANGS, only: nil, stdin: false }
    argv.each do |arg|
      case arg
      when "--demos" then opts[:demos] = true
      when "--stdin" then opts[:stdin] = true
      when /\A--lang=(.+)\z/ then opts[:langs] = Regexp.last_match(1).split(",")
      when /\A--only=(.+)\z/ then opts[:only] = Regexp.last_match(1).split(",")
      when /\A--/ then abort "unknown option #{arg}"
      else opts[:files] << arg
      end
    end
    opts
  end

  # [[lesson, {"de" => [...], "en" => [...]}], ...]
  def lessons(opts, stdin_text = nil)
    if opts[:files].any?
      opts[:files].map do |file|
        data = JSON.parse(File.read(file))
        abort "#{file}: not a lesson object (no id)" unless data.is_a?(Hash) && data["id"]
        [data.reject { |k, _| k == "solutions" }, data["solutions"] || {}, file]
      end
    else
      course = JSON.parse(File.read(lessons_json))
      picked = course["lessons"].select { |l| l["pico"] }
      picked = picked.select { |l| opts[:only].include?(l["id"]) } if opts[:only]
      solutions = if stdin_text
        JSON.parse(stdin_text)
      else
        dump_solutions(picked.map { |l| l["id"] })
      end
      picked.map { |l| [l, solutions[l["id"]] || {}, "html/lessons.js"] }
    end
  end

  def lessons_json
    path = ENV.fetch("HARNESS_JSON", File.join(__dir__, "lessons.json"))
    unless File.exist?(path)
      system("node", File.join(__dir__, "make_lessons_json.js"), out: File::NULL) or abort "node test/make_lessons_json.js failed"
    end
    path
  end

  def dump_solutions(ids)
    return {} if ids.empty?

    out, status = Open3.capture2(RbConfig.ruby, File.join(__dir__, "check_harness.rb"), "--dump-solutions", ids.join(","))
    abort "check_harness.rb --dump-solutions failed" unless status.success?
    JSON.parse(out)
  end

  # ---------- one language, in this process ----------

  def run_lang(lang, items, opts)
    require_relative "pico_cruby_host"
    require_relative "../html/picoruby_cells"
    PicoCRuby.load_sim
    PicoRubyCells.font_source = -> { File.read(File.join(HTML, "pico/lib/font5x7.rb")) }
    Object.send(:define_method, :show_irb) { nil } unless Object.private_method_defined?(:show_irb)
    failures = 0
    checked = 0
    items.each do |lesson, solutions, _file|
      cells = lesson.dig(lang, "cells") || []
      if opts[:demos]
        cells.each_with_index do |cell, ci|
          next unless cell["t"] == "c" && cell["engine"] != "cruby"

          run = run_cell(lesson, lang, cell, cell["code"].to_s, nil)
          expected = cell["raises"]
          if expected ? run[:error]&.class&.name != expected : run[:error]
            puts "FAIL #{lesson['id']}/#{lang}: demo cell #{ci} #{expected ? "should raise #{expected}, " : ''}" \
                 "#{run[:error] ? "raised #{run[:error].class}: #{run[:error].message}" : 'ran without error'}"
            failures += 1
          end
        end
      end
      ex_at = cells.index { |c| c["t"] == "x" }
      next if ex_at.nil?

      exercise = cells[ex_at]
      list = solutions[SOLUTION_LANG.fetch(lang, lang)] || []
      if list.empty?
        puts "FAIL #{lesson['id']}/#{lang}: no solutions"
        failures += 1
      end
      variants = [["starter", exercise["code"].to_s, nil]] +
                 list.each_with_index.map { |s, i| ["solution#{i + 1}", s.is_a?(Hash) ? s["code"].to_s : s.to_s, s.is_a?(Hash) ? s["tabs"] : nil] }
      variants.each do |label, code, tab_codes|
        checked += 1
        run = run_cell(lesson, lang, exercise, code, tab_codes)
        if run[:error] && label != "starter"
          puts "FAIL #{lesson['id']}/#{lang} (#{label}): raised #{run[:error].class}: #{run[:error].message}"
          puts "  #{run[:error].backtrace.first(3).join("\n  ")}" if ENV["HARNESS_TRACE"]
          failures += 1
          next
        end
        passed = check(exercise["check"].to_s, run, code)
        if label == "starter" && passed
          puts "FAIL #{lesson['id']}/#{lang}: starter code already passes check!"
          failures += 1
        elsif label != "starter" && !passed
          puts "FAIL #{lesson['id']}/#{lang} (#{label}): does not pass check"
          puts "  output: #{run[:output][0, 300].inspect}" if ENV["HARNESS_TRACE"]
          failures += 1
        end
      end
    end
    puts failures.zero? ? "ALL PICO CHECKS OK (#{items.size} lessons, #{lang}, #{checked} runs)" : "#{failures} pico failures (#{lang})"
    failures.zero?
  end

  def tabs_for(cell, tab_codes, lang)
    (cell["tabs"] || []).map do |tab|
      code = if tab_codes && tab_codes[tab["name"]]
        tab_codes[tab["name"]]
      elsif tab.key?("src")
        File.read(File.join(HTML, tab["src"]))
      else
        tab["code"].to_s
      end
      { "name" => tab["name"], "code" => code }
    end
  end

  # the cell's code as the worker runs it: a fresh board (its parts, its
  # bench), the tabs in a directory to require from, a binding of its own
  def run_cell(lesson, lang, cell, code, tab_codes)
    PicoCRuby.start
    PicoCRuby.write_tabs(tabs_for(cell, tab_codes, lang))
    board = cell["board"]
    config = { "board" => (lesson.dig("pico", "board") || "pico2w"), "parts" => board ? Array(board["parts"]) : [],
               "bench" => cell["bench"] || [], "reset" => true }
    PicoSim.setup(config)
    bind = RubyVM::InstructionSequence.compile("proc { binding }.call", "picoruby.rb").eval
    old = $stdout
    buffer = StringIO.new
    $stdout = buffer
    result = nil
    error = nil
    begin
      result = eval(code, bind, "picoruby.rb")
    rescue Exception => e # rubocop:disable Lint/RescueException - the cell's error is its answer
      error = e
    ensure
      summary = begin
        PicoCRuby.finish
      rescue StandardError
        ""
      end
      $stdout = old
    end
    { result: result, output: buffer.string, error: error, summary: board ? summary : "" }
  end

  def check(source, run, code)
    bind = RubyVM::InstructionSequence.compile("proc { binding }.call", "check.rb").eval
    bind.local_variable_set(:output, run[:output])
    bind.local_variable_set(:result, run[:error] ? nil : PicoRubyCells.value(run[:result].inspect))
    bind.local_variable_set(:code, code)
    bind.local_variable_set(:board, PicoRubyCells.board(run[:summary]))
    !!eval(source, bind, "check.rb")
  rescue Exception # rubocop:disable Lint/RescueException - a check that raises fails
    false
  end

  # ---------- the files' lint, then one process per language ----------

  def lint(items)
    errors = 0
    items.each do |lesson, solutions, file|
      next if file == "html/lessons.js" # lint_lessons.rb has them

      PicoLint.findings(lesson, ROOT).each do |sev, code, where, message|
        puts "#{sev == 'ERROR' ? 'FAIL' : sev} #{file}: #{where} [#{code}] #{message}"
        errors += 1 if sev == "ERROR"
      end
      LANGS.each do |lang|
        cells = lesson.dig(lang, "cells")
        if !cells.is_a?(Array)
          puts "FAIL #{file}: no #{lang} cells"
          errors += 1
        elsif cells.count { |c| c["t"] == "x" } != 1
          puts "FAIL #{file}: #{lang} has #{cells.count { |c| c['t'] == 'x' }} exercise (x) cells, expected 1"
          errors += 1
        end
        (cells || []).each_with_index do |cell, ci|
          [cell["code"], cell["check"]].compact.each do |src|
            res = Prism.parse(src, scopes: [%i[output result code board]])
            res.errors.each do |e|
              puts "FAIL #{file}: #{lesson['id']}/#{lang}/#{ci} line #{e.location.start_line}: #{e.message}"
              errors += 1
            end
          end
        end
      end
      %w[de en].each do |lang|
        next if (solutions[lang] || []).any?

        puts "FAIL #{file}: no solutions for #{lang} (\"solutions\": {\"#{lang}\": [...]})"
        errors += 1
      end
    end
    errors
  end

  def main(argv)
    opts = options(argv)
    if (lang = ENV["PICO_HARNESS_LANG"])
      items = Marshal.load($stdin.read) # rubocop:disable Security/MarshalLoad - our own parent process
      exit(run_lang(lang, items, opts) ? 0 : 1)
    end
    items = lessons(opts, opts[:stdin] ? $stdin.read : nil)
    if items.empty?
      puts "no Pico lessons to check"
      exit 0
    end
    errors = lint(items)
    flags = argv.select { |a| a.start_with?("--") && a != "--stdin" }
    results = opts[:langs].map do |lang|
      IO.popen({ "PICO_HARNESS_LANG" => lang }, [RbConfig.ruby, __FILE__, *flags], "w") { |io| io.write(Marshal.dump(items)) }
      $?.success?
    end
    exit(errors.zero? && results.all? ? 0 : 1)
  end
end

PicoHarness.main(ARGV) if $PROGRAM_NAME == __FILE__
