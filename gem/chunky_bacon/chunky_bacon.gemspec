# frozen_string_literal: true

require_relative "lib/chunky_bacon/version"

Gem::Specification.new do |spec|
  spec.name = "chunky_bacon"
  spec.version = ChunkyBacon::VERSION
  spec.authors = ["Andi Idogawa"]
  spec.email = ["web@idogawa.com"]

  spec.summary = "The Chunky Bacon Ruby course's helpers on your own computer - and a fox that shouts."
  spec.description = <<~TEXT.tr("\n", " ").strip
    The companion gem of "Ruby lernen mit Chunky Bacon", an interactive Ruby course
    that runs in the browser. require "chunky_bacon" gives a program the course's
    helpers - show_image, show_pdf, show_browser, download_file, mock_get, show_irb,
    show_files, run_tests, install_gem - so code written in the course runs unchanged
    with plain Ruby; `chunkybacon run` starts a program with them loaded. Pure Ruby,
    no dependencies.
  TEXT
  spec.homepage = "https://github.com/Largo/chunkybacon"
  # the code MIT, the fox drawing (lib/chunky_bacon/fox.txt) CC BY-SA 4.0
  spec.licenses = ["MIT", "CC-BY-SA-4.0"]
  spec.required_ruby_version = ">= 3.1"

  spec.metadata = {
    "homepage_uri" => spec.homepage,
    "source_code_uri" => "https://github.com/Largo/chunkybacon/tree/main/gem/chunky_bacon",
    "changelog_uri" => "https://github.com/Largo/chunkybacon/blob/main/gem/chunky_bacon/CHANGELOG.md",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir["lib/**/*.{rb,txt}", "exe/*"] + %w[README.md CHANGELOG.md LICENSE LICENSE-ASSETS]
  spec.bindir = "exe"
  spec.executables = ["chunkybacon"]
end
