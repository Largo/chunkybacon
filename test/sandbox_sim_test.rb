# The virtual filesystem behind File/Dir for relative paths (html/sandbox_sim.rb):
#   ruby test/sandbox_sim_test.rb
require "minitest/autorun"
require_relative "../html/sandbox_sim"

class SandboxSimTest < Minitest::Test
  def setup = SandboxFS.reset!

  # a cell's __dir__ is ".", so File.join(__dir__, name) makes "./name"
  def test_dot_slash_is_the_same_file
    File.write("./quittung.txt", "Speck 2.50")
    assert_equal "Speck 2.50", File.read("quittung.txt")
    assert File.exist?("./quittung.txt")
  end

  def test_a_glob_finds_files_with_or_without_dot_slash
    File.write("./quittung.txt", "Speck 2.50")
    assert_includes Dir.glob("*.txt"), "quittung.txt"
    assert_includes Dir.glob("./*.txt"), "./quittung.txt", "as on a disk, the prefix stays"
    assert_equal Dir.glob("*.txt").map { |f| "./#{f}" }, Dir.glob("./*.txt")
  end
end
