# frozen_string_literal: true

require "test_helper"

# What `gem build` packs: the fox ships with its license.
class GemspecTest < Minitest::Test
  GEM_DIR = File.expand_path("..", __dir__)
  SPEC = Dir.chdir(GEM_DIR) { Gem::Specification.load("chunky_bacon.gemspec") }

  def test_the_fox_and_both_licenses_ship
    %w[lib/chunky_bacon/fox.txt LICENSE LICENSE-ASSETS exe/chunkybacon].each do |file|
      assert_includes SPEC.files, file
    end
  end

  def test_the_code_is_mit_the_fox_cc_by_sa
    assert_equal ["MIT", "CC-BY-SA-4.0"], SPEC.licenses
  end

  def test_the_version_is_the_gems
    assert_equal ChunkyBacon::VERSION, SPEC.version.to_s
  end
end
