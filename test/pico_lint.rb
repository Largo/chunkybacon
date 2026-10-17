# frozen_string_literal: true

# The rules of the Pico lessons' cell fields (docs/HANDOVER.md §6r, design
# §2.1): tabs, main, board, bench, a cell's engine and the lesson's pico.
# Used by test/lint_lessons.rb (group "pico") and by test/pico_harness.rb,
# which also checks a lesson in a JSON file of its own before it goes into
# html/lessons.js.
#
#   PicoLint.findings(lesson, root) # => [[severity, code, where, message], ...]
require "prism"
require "json"

module PicoLint
  LANGS = %w[de en ja].freeze
  BOARDS = %w[pico picow pico2 pico2w].freeze
  # the parts of html/pico_sim/devices (PicoSim::PARTS) and the GPIOs they
  # take (test/pico_sim_test.rb checks this table against the simulator)
  PART_PINS = {
    "led15" => [15], "button14" => [14], "light26" => [26], "temp" => [], "buzzer16" => [16],
    "envsensor" => [20, 21], "epd213" => [8, 9, 10, 11, 12, 13],
    "picogo" => [2, 3, 4, 14, 15, 16, 17, 18, 19, 20, 21, 22, 26], "camera" => [], "wifi" => [], "laptop" => [],
    "rgbled" => [6], "lcd114" => [2, 3, 8, 9, 10, 11, 12, 13, 15, 16, 17, 18, 20]
  }.freeze
  # parts whose inputs an exercise's check depends on: it needs a bench
  INPUT_PARTS = %w[button14 light26 envsensor picogo laptop camera lcd114].freeze
  ARENAS = %w[open wall60 box].freeze
  # the Pico-LCD-1.14's keys A, B and its joystick (a bench can press them)
  LCD_KEYS = [15, 17, 2, 3, 16, 18, 20].freeze
  BENCH_ACTIONS = %w[set press release arena ble wifi].freeze
  # what the worker writes to /lib itself (picoruby_worker_core.js STUBS)
  STUBS = %w[gpio pwm adc i2c spi pio cyw43 network ble hcsr04 camera socket net/http env].freeze
  TAB_NAME = %r{\A[a-z0-9_][a-z0-9_/.-]*\.rb\z}

  module_function

  def findings(lesson, root)
    out = []
    add = ->(sev, code, where, msg) { out << [sev, code, where, msg] }
    id = lesson["id"].to_s
    pico = lesson["pico"]
    if pico
      add.("ERROR", "pico-engine", id, 'a lesson with "pico" needs "engine": "picoruby"') unless lesson["engine"] == "picoruby"
      add.("ERROR", "pico-board", id, "pico.board must be one of #{BOARDS.join(', ')}") unless pico.is_a?(Hash) && BOARDS.include?(pico["board"].to_s)
      add.("WARN", "pico-live", id, 'a Pico lesson is "live": false (a run flashes the board)') unless lesson["live"] == false
    end
    per_lang = {}
    LANGS.each do |lang|
      cells = lesson.dig(lang, "cells")
      next unless cells.is_a?(Array)

      per_lang[lang] = cells
      cells.each_with_index do |cell, ci|
        where = "#{id}/#{lang}/#{ci}"
        cell_findings(lesson, cell, where, root, add)
      end
    end
    parity(lesson, per_lang, root, add)
    out
  end

  def code_cell?(cell) = %w[c x].include?(cell["t"])

  def cell_findings(lesson, cell, where, root, add)
    fields = %w[tabs main board bench engine]
    present = fields.select { |f| cell.key?(f) }
    if !code_cell?(cell) && present.any?
      add.("ERROR", "pico-field", where, "#{present.join(', ')} on a #{cell['t']} cell (only c and x cells)")
      return
    end
    if present.any? { |f| f != "engine" } && lesson["engine"] != "picoruby"
      add.("ERROR", "pico-field", where, "#{present.join(', ')} only in a lesson with \"engine\": \"picoruby\"")
    end
    if cell.key?("engine")
      add.("ERROR", "cell-engine", where, 'a cell\'s engine can only be "cruby"') unless cell["engine"] == "cruby"
      add.("ERROR", "cell-engine", where, 'a "cruby" cell belongs in a PicoRuby lesson') unless lesson["engine"] == "picoruby"
      add.("ERROR", "cell-engine", where, 'a "cruby" cell has no board or tabs') if cell["board"] || cell["tabs"]
    end
    if cell.key?("main") && !cell["main"].to_s.match?(TAB_NAME)
      add.("ERROR", "tab-name", where, "main #{cell['main'].inspect} is not a file name ending in .rb")
    end
    tabs(cell, where, root, add) if cell.key?("tabs")
    board = cell["board"]
    if cell.key?("board")
      board_findings(board, where, add)
    elsif cell.key?("bench")
      add.("ERROR", "bench", where, "a bench without a board")
    end
    bench_findings(cell["bench"], board, where, add) if cell.key?("bench")
    if cell["t"] == "x" && board.is_a?(Hash) && (Array(board["parts"]) & INPUT_PARTS).any? && Array(cell["bench"]).empty?
      add.("WARN", "bench-missing", where, "an exercise with #{(Array(board['parts']) & INPUT_PARTS).join(', ')} needs a bench script, or its check depends on the learner's clicks")
    end
  end

  def tabs(cell, where, root, add)
    list = cell["tabs"]
    unless list.is_a?(Array) && list.all? { |t| t.is_a?(Hash) }
      add.("ERROR", "tabs", where, "tabs must be an Array of {name, src|code}")
      return
    end
    names = list.map { |t| t["name"].to_s }
    main = (cell["main"] || "app.rb").to_s
    names.tally.each { |n, k| add.("ERROR", "tab-name", where, "tab #{n} appears #{k} times") if k > 1 }
    list.each do |tab|
      name = tab["name"].to_s
      add.("ERROR", "tab-name", where, "tab name #{name.inspect}: lower-case file name ending in .rb") unless name.match?(TAB_NAME) && !name.include?("..")
      add.("ERROR", "tab-name", where, "tab #{name} has the main file's name") if name == main
      add.("ERROR", "tab-name", where, "tab #{name} would hide the simulator's require stub #{name}") if STUBS.include?(name.sub(/\.rb\z/, ""))
      if tab.key?("src") == tab.key?("code")
        add.("ERROR", "tab-source", where, "tab #{name}: exactly one of src (a file under html/) or code")
      elsif tab.key?("src")
        add.("ERROR", "tab-source", where, "tab #{name}: html/#{tab['src']} does not exist") unless File.file?(File.join(root, "html", tab["src"].to_s))
        add.("ERROR", "tab-readonly", where, "tab #{name}: a src tab is read-only (no \"readonly\": false)") if tab["readonly"] == false
      end
      unknown = tab.keys - %w[name src code readonly]
      add.("WARN", "tab-key", where, "tab #{name}: unknown key(s) #{unknown.join(', ')}") if unknown.any?
    end
  end

  def board_findings(board, where, add)
    unless board.is_a?(Hash) && board["parts"].is_a?(Array)
      add.("ERROR", "board", where, 'board must be {"parts": [...]}')
      return
    end
    unknown = board.keys - %w[parts]
    add.("WARN", "board-key", where, "board: unknown key(s) #{unknown.join(', ')}") if unknown.any?
    used = {}
    board["parts"].each do |part|
      pins = PART_PINS[part]
      if pins.nil?
        add.("ERROR", "board-part", where, "unknown part #{part.inspect} (known: #{PART_PINS.keys.join(', ')})")
        next
      end
      pins.each do |pin|
        if used[pin]
          add.("ERROR", "board-pins", where, "#{part} and #{used[pin]} both use GP#{pin}")
        else
          used[pin] = part
        end
      end
    end
    board["parts"].tally.each { |p, k| add.("ERROR", "board-part", where, "part #{p} twice") if k > 1 }
  end

  def bench_findings(bench, board, where, add)
    unless bench.is_a?(Array)
      add.("ERROR", "bench", where, "bench must be an Array of events")
      return
    end
    parts = board.is_a?(Hash) ? Array(board["parts"]) : []
    bench.each_with_index do |event, i|
      at = "bench[#{i}]"
      unless event.is_a?(Hash) && event["at"].is_a?(Numeric) && event["at"] >= 0
        add.("ERROR", "bench", where, "#{at}: needs \"at\" (ms since the run started, >= 0)")
        next
      end
      actions = event.keys - %w[at]
      unless actions.size == 1 && BENCH_ACTIONS.include?(actions[0])
        add.("ERROR", "bench", where, "#{at}: one of #{BENCH_ACTIONS.join(', ')} besides at, not #{actions.inspect}")
        next
      end
      value = event[actions[0]]
      case actions[0]
      when "press", "release"
        pressable = (value == 14 && parts.include?("button14")) || (LCD_KEYS.include?(value) && parts.include?("lcd114"))
        add.("ERROR", "bench", where, "#{at}: no button on GP#{value}") unless pressable
      when "arena"
        add.("ERROR", "bench", where, "#{at}: arena #{value.inspect} (known: #{ARENAS.join(', ')})") unless ARENAS.include?(value)
        add.("ERROR", "bench", where, "#{at}: an arena without the picogo part") unless parts.include?("picogo")
      when "set"
        add.("ERROR", "bench", where, "#{at}: set takes {key: value}") unless value.is_a?(Hash) && !value.empty?
      when "ble"
        add.("ERROR", "bench", where, "#{at}: ble takes connect, disconnect or a line") unless value.is_a?(String) && !value.empty?
      when "wifi"
        add.("ERROR", "bench", where, "#{at}: wifi takes on or off") unless %w[on off].include?(value)
      end
    end
  end

  # tabs, board and bench are the same in de, en and ja; a tab's code too,
  # but for its comments
  def parity(lesson, per_lang, root, add)
    return unless per_lang.size == LANGS.size && per_lang.values.map(&:size).uniq.size == 1

    per_lang["en"].each_index do |ci|
      cells = LANGS.to_h { |g| [g, per_lang[g][ci]] }
      next unless cells.values.all? { |c| c.is_a?(Hash) && code_cell?(c) }

      where = "#{lesson['id']}/#{ci}"
      %w[board bench main engine].each do |field|
        values = cells.transform_values { |c| c[field] }
        add.("ERROR", "pico-parity", where, "#{field} differs: #{values.map { |g, v| "#{g}=#{v.to_json}" }.join(' ')}") if values.values.uniq.size > 1
      end
      shapes = cells.transform_values { |c| Array(c["tabs"]).map { |t| [t["name"], t.key?("src"), t["readonly"] != false || t.key?("src")] } }
      if shapes.values.uniq.size > 1
        add.("ERROR", "pico-parity", where, "tabs differ (names, order, src/inline, readonly) between languages")
        next
      end
      Array(cells["en"]["tabs"]).each_index do |ti|
        codes = cells.transform_values { |c| tab_code(c["tabs"][ti], root) }
        next if codes.values.any?(&:nil?)

        bare = codes.transform_values { |code| strip_comments(code) }
        add.("ERROR", "pico-parity", where, "tab #{cells['en']['tabs'][ti]['name']}: the code differs beyond comments between languages") if bare.values.uniq.size > 1
      end
    end
  end

  def tab_code(tab, root)
    return tab["code"].to_s if tab.key?("code")

    path = File.join(root, "html", tab["src"].to_s)
    File.file?(path) ? File.read(path) : nil
  end

  def strip_comments(code)
    result = Prism.parse(code)
    out = code.b.dup
    result.comments.reverse_each do |c|
      loc = c.location
      out[loc.start_offset...loc.end_offset] = ""
    end
    out.force_encoding("UTF-8").lines.map(&:rstrip).reject(&:empty?).join("\n")
  end
end
