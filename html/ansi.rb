# Terminal colours in a cell's output. Programs written for the terminal -
# pastel, tty-table, a test runner - colour their text with ANSI escape
# codes: "\e[31m" turns red on, "\e[0m" off again. A terminal draws them;
# here the output is HTML, so AnsiHtml turns them into spans (app.css has
# the 16 standard colours, picked to read well on the page's light paper;
# the 256 and RGB ones become inline styles) and drops the codes that move
# the cursor, which a page cannot follow.
#
#   AnsiHtml.to_html("\e[1;31mFehler\e[0m: x")
#   # => "<span class=\"ansi-fg-1 ansi-bold\">Fehler</span>: x"
module AnsiHtml
  # every escape sequence: CSI ("\e[" ... a letter) and the rarer
  # two-character ones ("\e(B", "\e7")
  ESCAPE = /\e\[([0-9;:?]*)([@-~])|\e[()][A-Za-z0-9]|\e[78=>]/

  # xterm's 6x6x6 colour cube and grey ramp (codes 16-255)
  def self.xterm_rgb(code)
    if code < 232
      code -= 16
      levels = [0, 95, 135, 175, 215, 255]
      [levels[code / 36], levels[(code / 6) % 6], levels[code % 6]]
    else
      grey = 8 + (code - 232) * 10
      [grey, grey, grey]
    end
  end

  def self.escape(text)
    text.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
  end

  # The text as HTML: escaped, with a span wherever a style is on
  def self.to_html(text)
    return escape(text) unless text.include?("\e")

    style = {}
    html = +""
    position = 0
    text.scan(ESCAPE) do
      match = Regexp.last_match
      html << span(text[position...match.begin(0)], style)
      position = match.end(0)
      apply(style, match[1].to_s) if match[2] == "m"
    end
    html << span(text[position..], style)
  end

  # Select Graphic Rendition: what "\e[...m" switches on and off
  def self.apply(style, params)
    codes = params.split(/[;:]/).map(&:to_i)
    codes = [0] if codes.empty?
    until codes.empty?
      code = codes.shift
      case code
      when 0 then style.clear
      when 1 then style[:bold] = true
      when 2 then style[:faint] = true
      when 3 then style[:italic] = true
      when 4 then style[:underline] = true
      when 7 then style[:inverse] = true
      when 9 then style[:strike] = true
      when 21 then style.delete(:bold)
      when 22
        style.delete(:bold)
        style.delete(:faint)
      when 23 then style.delete(:italic)
      when 24 then style.delete(:underline)
      when 27 then style.delete(:inverse)
      when 29 then style.delete(:strike)
      when 30..37 then style[:fg] = code - 30
      when 90..97 then style[:fg] = code - 90 + 8
      when 40..47 then style[:bg] = code - 40
      when 100..107 then style[:bg] = code - 100 + 8
      when 39 then style.delete(:fg)
      when 49 then style.delete(:bg)
      when 38, 48
        key = code == 38 ? :fg : :bg
        case codes.shift
        when 5 then style[key] = codes.shift.to_i
        when 2 then style[key] = codes.shift(3).map(&:to_i)
        end
      end
    end
  end

  def self.span(part, style)
    return "" if part.nil? || part.empty?
    return escape(part) if style.empty?

    fg = style[:fg]
    bg = style[:bg]
    fg, bg = (bg || :paper), (fg || :ink) if style[:inverse]
    classes = []
    css = []
    [[fg, "fg", "color"], [bg, "bg", "background"]].each do |value, kind, property|
      case value
      when :paper, :ink then classes << "ansi-#{kind}-#{value}"
      when Integer
        if value < 16
          classes << "ansi-#{kind}-#{value}"
        else
          css << "#{property}:rgb(#{xterm_rgb(value).join(',')})"
        end
      when Array then css << "#{property}:rgb(#{value.map { |v| v.clamp(0, 255) }.join(',')})"
      end
    end
    %i[bold faint italic underline strike].each { |flag| classes << "ansi-#{flag}" if style[flag] }
    attributes = classes.empty? ? "" : " class=\"#{classes.join(' ')}\""
    attributes += " style=\"#{css.join(';')}\"" unless css.empty?
    "<span#{attributes}>#{escape(part)}</span>"
  end
end
