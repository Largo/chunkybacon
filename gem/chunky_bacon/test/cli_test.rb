# frozen_string_literal: true

require "test_helper"
require "open3"
require "rbconfig"

class CLITest < Minitest::Test
  include InTmpDir

  EXE = File.expand_path("../exe/chunkybacon", __dir__)

  # the installed command, as a learner would type it, in the test's folder
  def chunkybacon(*args, input: "")
    Open3.capture3({ "CHUNKYBACON_OPEN" => "0" }, RbConfig.ruby, EXE, *args, stdin_data: input, chdir: @dir)
  end

  def test_without_a_command_chunky_shouts
    out, _err, status = chunkybacon
    assert status.success?
    assert_includes out, "CHUNKY BACON!"
  end

  def test_version_and_help
    assert_equal "#{ChunkyBacon::VERSION}\n", chunkybacon("version").first
    assert_includes chunkybacon("help").first, "run [FILE]"
  end

  def test_an_unknown_command_is_an_error
    _out, err, status = chunkybacon("bake")
    refute status.success?
    assert_includes err, "unknown command \"bake\""
  end

  # a program from the workshop: gets, File, a helper - no require needed
  def test_run_starts_main_rb_with_the_helpers
    File.write(File.join(@dir, "main.rb"), <<~RUBY)
      name = gets.chomp
      puts "Hallo, \#{name}!"
      download_file "Speck fuer \#{name}", "gruss.txt"
    RUBY
    out, err, status = chunkybacon("run", input: "Isi\n")
    assert status.success?, err
    assert_equal "Hallo, Isi!\n", out
    assert_equal "Speck fuer Isi", File.read(File.join(@dir, "gruss.txt"))
    assert_includes err, "saved gruss.txt"
  end

  def test_run_another_file_with_arguments_and_its_exit_status
    File.write(File.join(@dir, "spiel.rb"), "puts ARGV.join(',')\nexit 3")
    out, _err, status = chunkybacon("run", "spiel.rb", "a", "b")
    assert_equal "a,b\n", out
    assert_equal 3, status.exitstatus
  end

  def test_run_without_main_rb_points_to_what_is_there
    File.write(File.join(@dir, "rechner.rb"), "puts 1")
    _out, err, status = chunkybacon("run")
    refute status.success?
    assert_includes err, "no main.rb here"
    assert_includes err, "chunkybacon run rechner.rb"
  end

  def test_run_tests_runs_what_the_program_defined
    File.write(File.join(@dir, "main.rb"), <<~RUBY)
      require "minitest"
      class SpeckTest < Minitest::Test
        def test_speck = assert_equal(3, 1 + 2)
      end
      exit(run_tests ? 0 : 1)
    RUBY
    out, err, status = chunkybacon("run")
    assert status.success?, out + err
    assert_match(/1 runs, 1 assertions, 0 failures/, out)
  end
end
