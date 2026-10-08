# frozen_string_literal: true

# chunky_bacon: the companion gem of "Learn Ruby with Chunky Bacon", the Ruby
# course that runs in the browser (https://chunkybacon.idogawa.com).
#
# On your own computer, `require "chunky_bacon"` gives a program the helpers
# the course's notebook cells and workshop have - show_image, show_browser,
# download_file and friends - so a program written in the browser runs
# unchanged with plain Ruby (or with `chunkybacon run`, which loads them for
# you). In the browser the page brings its own helpers; there the gem only
# adds the fox.
require_relative "chunky_bacon/version"
require_relative "chunky_bacon/fox"

module ChunkyBacon
  # A helper that needs the browser (for now), called on a computer.
  class NotHere < StandardError; end

  class << self
    # true inside the course's page (ruby.wasm), false on a computer
    def browser?
      RUBY_PLATFORM.start_with?("wasm")
    end

    # where show_image, show_pdf and download_file put their files: the
    # folder the program runs in, like the downloads below a cell
    attr_writer :output_dir

    def output_dir
      @output_dir || Dir.pwd
    end
  end
end

unless ChunkyBacon.browser?
  require_relative "chunky_bacon/opener"
  require_relative "chunky_bacon/rack_env"
  require_relative "chunky_bacon/server"
  require_relative "chunky_bacon/helpers"
  # show_objects: html/object_graph.rb of the course, the same file
  require_relative "chunky_bacon/object_graph"
  # turtle { forward 100 }: html/turtle.rb of the course, the same file
  require_relative "chunky_bacon/turtle"
end
