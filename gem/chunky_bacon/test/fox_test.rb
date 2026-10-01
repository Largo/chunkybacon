# frozen_string_literal: true

require "test_helper"

class FoxTest < Minitest::Test
  def test_chunky_shouts
    out, = capture_io { ChunkyBacon.shout }
    assert_includes out, "CHUNKY BACON!"
    assert_equal ChunkyBacon::FOX, out
  end

  def test_the_fox_is_plain_ascii
    assert ChunkyBacon::FOX.ascii_only?, "every terminal must show it"
  end

  def test_on_a_computer_not_in_the_browser
    refute ChunkyBacon.browser?
  end
end
