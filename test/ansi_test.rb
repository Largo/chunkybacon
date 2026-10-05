# Terminal colours in a cell's output (html/ansi.rb), under CRuby:
#   ruby test/ansi_test.rb
require "minitest/autorun"
require_relative "../html/ansi"

class AnsiHtmlTest < Minitest::Test
  def html(text) = AnsiHtml.to_html(text)

  def test_plain_text_is_only_escaped
    assert_equal "a &lt;b&gt; &amp; c", html("a <b> & c")
  end

  def test_a_colour_and_its_reset
    assert_equal "<span class=\"ansi-fg-1\">rot</span> normal", html("\e[31mrot\e[0m normal")
  end

  def test_styles_add_up_until_reset
    assert_equal "<span class=\"ansi-fg-2 ansi-bold\">a</span><span class=\"ansi-fg-2 ansi-bold ansi-underline\">b</span>c",
                 html("\e[32;1ma\e[4mb\e[mc")
  end

  def test_bright_colours_backgrounds_and_switching_off
    assert_equal "<span class=\"ansi-fg-9 ansi-bg-4\">x</span><span class=\"ansi-bg-4\">y</span>",
                 html("\e[91;44mx\e[39my")
    assert_equal "<span class=\"ansi-bold\">a</span>b", html("\e[1ma\e[22mb")
  end

  def test_256_and_rgb_colours_are_inline_styles
    assert_equal "<span style=\"color:rgb(255,0,0)\">x</span>", html("\e[38;5;196mx")
    assert_equal "<span style=\"color:rgb(118,118,118)\">x</span>", html("\e[38;5;243mx")
    assert_equal "<span style=\"background:rgb(1,2,3)\">x</span>", html("\e[48;2;1;2;3mx")
  end

  def test_inverse_swaps_ink_and_paper
    assert_equal "<span class=\"ansi-fg-paper ansi-bg-ink\">x</span>", html("\e[7mx")
    assert_equal "<span class=\"ansi-fg-paper ansi-bg-1\">x</span>", html("\e[31;7mx")
  end

  def test_cursor_movements_are_dropped
    assert_equal "ab\n", html("a\e[2K\e[1Gb\n")
    assert_equal "ab", html("a\e[1A\e[2Kb")
    assert_equal "ab", html("a\e(Bb")
  end

  def test_what_the_escape_codes_hold_is_escaped_too
    assert_equal "<span class=\"ansi-fg-1\">&lt;b&gt;</span>", html("\e[31m<b>\e[0m")
  end
end
