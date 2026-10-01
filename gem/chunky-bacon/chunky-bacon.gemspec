# frozen_string_literal: true

# An alias, like chunkybacon: `gem install chunky-bacon` installs chunky_bacon,
# `require "chunky-bacon"` loads it - so the dashed spelling finds the real
# gem instead of someone else's. It needs no new release when chunky_bacon
# has one.
Gem::Specification.new do |spec|
  spec.name = "chunky-bacon"
  spec.version = "0.1.1"
  spec.authors = ["Andi Idogawa"]
  spec.email = ["web@idogawa.com"]

  spec.summary = "An alias for the chunky_bacon gem."
  spec.description = "Installing chunky-bacon installs chunky_bacon, and requiring chunky-bacon " \
                     "loads it. Use whichever name you like; they are the same library."
  spec.homepage = "https://chunkybacon.idogawa.com"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata = {
    "homepage_uri" => spec.homepage,
    "source_code_uri" => "https://github.com/Largo/chunkybacon/tree/main/gem/chunky-bacon",
    "rubygems_mfa_required" => "true"
  }

  spec.files = %w[lib/chunky-bacon.rb README.md LICENSE]
  spec.add_dependency "chunky_bacon", ">= 0.1"
end
