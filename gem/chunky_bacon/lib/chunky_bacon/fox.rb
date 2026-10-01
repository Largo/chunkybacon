# frozen_string_literal: true

module ChunkyBacon
  # Chunky, the course's fox, holding up a strip of bacon and shouting - the
  # same original character as the site's mascot (html/assets/chunky.svg),
  # in plain ASCII so any terminal shows it. The drawing is fox.txt next to
  # this file; like the course's other content it is licensed CC BY-SA 4.0
  # (LICENSE-ASSETS), while this code is MIT.
  FOX = File.read(File.expand_path("fox.txt", __dir__), encoding: "UTF-8").gsub("\r\n", "\n").freeze

  # Puts the fox on +io+ (the terminal unless told otherwise).
  def self.shout(io = $stdout)
    io.puts FOX
    nil
  end
end
