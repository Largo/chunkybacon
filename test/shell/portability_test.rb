require "minitest/autorun"
require "prism"

# What the unit tests cannot notice: the shell runs on PicoRuby.wasm 4.0.3,
# which lacks parts of CRuby. Everything here was probed in Chrome
# (docs/PICORUBY_SHELL.md); these scans keep it out of html/shell/*.rb.
# Each scan is also run on a sample of bad code, so a scan that stopped
# seeing anything would fail too.
class PortabilityTest < Minitest::Test
  SHELL_DIR = ENV.fetch("SHELL_DIR", File.expand_path("../../html/shell", __dir__))

  # NoMethodError in PicoRuby (CRuby has them)
  MISSING_METHODS = %i[
    find_index sort_by group_by each_slice each_cons sum each_with_object min_by max_by
    filter_map count zip scan drop tally catch throw with_index with_object lazy
  ].freeze
  # NameError in PicoRuby
  MISSING_CONSTANTS = %i[Struct Enumerator Set Date].freeze
  # ruby.wasm's, not PicoRuby's (the jsg gem needs them)
  RUBY_WASM_ONLY = %w[Null Undefined True False].freeze
  # without a block these return an enumerator, which needs fibers
  ENUMERATING = %i[each each_with_index map times each_char chars each_line upto step select reject].freeze
  # called without a receiver inside a Task: fine, whatever self is
  TASK_SAFE = %i[sleep_ms raise loop format puts p rand].freeze

  BAD_SAMPLE = <<~'RUBY'
    require "singleton"
    S = Struct.new(:a)
    x = [1, 2].sort_by { |a| a }.sum
    r = /\Aabc\z/
    t = "k=v"[/=(\w)/]
    y = $1
    z = [1].each_with_index.map { |a, i| a + i }
    JSG.w.probe({ a: 1 }, :sym)
    n = JS::Null
    Task.new { render_gems_panel; @names = [] }
  RUBY

  SCANS = %i[regexp_escapes match_globals missing_methods missing_constants blockless_enumerators
             requires js_arguments task_self].freeze

  def shell_sources
    Dir[File.join(SHELL_DIR, "*.rb")].sort.map { |f| [File.basename(f), File.read(f)] }
  end

  def each_node(node, &block)
    return unless node

    yield node
    node.compact_child_nodes.each { |child| each_node(child, &block) }
  end

  def offenses(sources)
    list = []
    sources.each do |name, source|
      result = Prism.parse(source)
      assert result.success?, "#{name}: #{result.errors.map(&:message).join(', ')}"
      each_node(result.value) do |node|
        message = yield(node)
        list << "#{name}:#{node.location.start_line}: #{message}" if message
      end
    end
    list
  end

  # ---------- the scans ----------

  def regexp_escapes(node)
    return unless node.is_a?(Prism::RegularExpressionNode) || node.is_a?(Prism::InterpolatedRegularExpressionNode)

    "#{node.slice}: \\A \\z \\Z \\h do not exist in JavaScript RegExp - use ^ $" if node.slice.match?(/\\[AzZh]/)
  end

  def match_globals(node)
    case node
    when Prism::NumberedReferenceReadNode, Prism::BackReferenceReadNode
      "#{node.slice} is never set in PicoRuby - use String#match and m[1]"
    when Prism::RegularExpressionNode
      "#{node.slice}: named captures do not work" if node.slice.include?("(?<")
    when Prism::CallNode
      if node.name == :[] && node.receiver && node.arguments&.arguments&.any?(Prism::RegularExpressionNode)
        "#{node.slice}: String#[] takes no regexp in PicoRuby"
      end
    end
  end

  def missing_methods(node)
    "#{node.name} is missing in PicoRuby" if node.is_a?(Prism::CallNode) && MISSING_METHODS.include?(node.name)
  end

  def missing_constants(node)
    case node
    when Prism::ConstantReadNode
      "#{node.name} does not exist in PicoRuby" if MISSING_CONSTANTS.include?(node.name)
    when Prism::ConstantPathNode
      "#{node.slice} is ruby.wasm's, not PicoRuby's" if node.parent&.slice == "JS" && RUBY_WASM_ONLY.include?(node.name.to_s)
    end
  end

  def blockless_enumerators(node)
    return unless node.is_a?(Prism::CallNode) && node.receiver.is_a?(Prism::CallNode)

    inner = node.receiver
    return unless ENUMERATING.include?(inner.name) && inner.block.nil?

    "#{inner.name}.#{node.name}: an enumerator without a block needs fibers"
  end

  def requires(node)
    return unless node.is_a?(Prism::CallNode) && %i[require require_relative load].include?(node.name) && node.receiver.nil?

    arg = node.arguments&.arguments&.first
    name = arg.is_a?(Prism::StringNode) ? arg.unescaped : arg&.slice
    return if node.name == :require && %w[js json].include?(name)

    "#{node.name} #{name}: PicoRuby has no filesystem; only js and json are built in"
  end

  # Hash, Array and Symbol arguments to a JavaScript call raise TypeError in
  # PicoRuby; calls on a chain that starts at JSG or JS are JavaScript calls.
  # (Keyword options such as sync: true are PicoRuby's own, and allowed.)
  def js_arguments(node)
    return unless node.is_a?(Prism::CallNode) && node.arguments && node.receiver
    return if %i[[] []=].include?(node.name)   # el[:prop] is a property, not a call

    root = node.receiver
    root = root.receiver while root.is_a?(Prism::CallNode) && root.receiver
    return unless root.is_a?(Prism::ConstantReadNode) && %i[JSG JS].include?(root.name)

    bad = node.arguments.arguments.find { |a| a.is_a?(Prism::HashNode) || a.is_a?(Prism::ArrayNode) || a.is_a?(Prism::SymbolNode) }
    "#{node.name}: #{bad.type} argument - PicoRuby passes only strings, numbers, booleans and nil" if bad
  end

  # A Task's block runs with another self: no implicit receiver, no ivars.
  def task_self(node)
    return unless node.is_a?(Prism::CallNode) && node.name == :new && node.receiver&.slice == "Task" && node.block

    used = []
    each_node(node.block.body) do |n|
      used << n.slice if n.is_a?(Prism::InstanceVariableReadNode) || n.is_a?(Prism::InstanceVariableWriteNode)
      used << n.name.to_s if n.is_a?(Prism::CallNode) && n.receiver.nil? && !TASK_SAFE.include?(n.name)
    end
    "Task block uses #{used.uniq.join(', ')} without a receiver - self is not the one it was written in" unless used.empty?
  end

  # ---------- the shell passes them ----------

  SCANS.each do |scan|
    define_method("test_shell_passes_#{scan}") do
      found = offenses(shell_sources) { |node| send(scan, node) }
      assert_empty found, found.join("\n")
    end

    define_method("test_#{scan}_finds_bad_code") do
      found = offenses([["sample.rb", BAD_SAMPLE]]) { |node| send(scan, node) }
      refute_empty found, "#{scan} no longer finds anything in the bad sample"
    end
  end

  def test_the_manifest_lists_every_shell_file_once
    listed = File.readlines(File.join(SHELL_DIR, "manifest.txt"), chomp: true)
                 .map(&:strip).reject { |l| l.empty? || l.start_with?("#") }
    assert_equal listed.uniq, listed, "listed twice"
    assert_equal shell_sources.map(&:first).sort, listed.sort
    assert_equal "jsg.rb", listed.first, "the sugar comes before its first use"
    assert_equal "boot.rb", listed.last, "boot.rb starts the page: last"
  end
end
