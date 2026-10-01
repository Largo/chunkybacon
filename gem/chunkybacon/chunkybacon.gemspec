# frozen_string_literal: true

# An alias, like rubyllm for ruby_llm: `gem install chunkybacon` installs
# chunky_bacon, `require "chunkybacon"` loads it. It needs no new release when
# chunky_bacon has one.
Gem::Specification.new do |spec|
  spec.name = "chunkybacon"
  spec.version = "0.1.1"
  spec.authors = ["Andi Idogawa"]
  spec.email = ["web@idogawa.com"]

  spec.summary = "An alias for the chunky_bacon gem."
  spec.description = "Installing chunkybacon installs chunky_bacon, and requiring chunkybacon " \
                     "loads it. Use whichever name you like; they are the same library."
  spec.homepage = "https://chunkybacon.idogawa.com"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata = {
    "homepage_uri" => spec.homepage,
    "source_code_uri" => "https://github.com/Largo/chunkybacon/tree/main/gem/chunkybacon",
    "rubygems_mfa_required" => "true"
  }

  spec.files = %w[lib/chunkybacon.rb README.md LICENSE]
  spec.add_dependency "chunky_bacon", ">= 0.1"
end
