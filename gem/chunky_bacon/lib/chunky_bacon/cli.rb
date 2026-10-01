# frozen_string_literal: true

require "rbconfig"

module ChunkyBacon
  # The `chunkybacon` command.
  class CLI
    HELP = <<~TEXT
      Usage: chunkybacon [command]

        (no command)        Chunky shouts
        run [FILE] [ARGS]   runs FILE (main.rb if not given) with the course's
                            helpers loaded - show_image, show_browser,
                            download_file, ... - like the workshop's Run button
        version             the version of chunky_bacon
        help                this text

      The course: https://github.com/Largo/chunkybacon
    TEXT

    def initialize(out: $stdout, err: $stderr)
      @out = out
      @err = err
    end

    # the exit status
    def call(args)
      command, *rest = args
      case command
      when nil
        ChunkyBacon.shout(@out)
        0
      when "run"
        run(rest)
      when "version", "--version", "-v"
        @out.puts VERSION
        0
      when "help", "--help", "-h"
        @out.puts HELP
        0
      else
        @err.puts "chunkybacon: unknown command #{command.inspect}\n\n#{HELP}"
        1
      end
    end

    private

    # In a child Ruby, so the program has the terminal - input for gets,
    # Ctrl+C - and its exit status is the command's.
    def run(args)
      file = args.first || "main.rb"
      unless File.file?(file)
        others = Dir["*.rb"].sort
        hint = others.empty? ? "" : " - there is #{others.join(", ")}: chunkybacon run #{others.first}"
        @err.puts "chunkybacon: no #{file} here#{hint}"
        return 1
      end
      lib = File.expand_path("..", __dir__)
      system(RbConfig.ruby, "-I", lib, "-r", "chunky_bacon", file, *args.drop(1))
      $?.exitstatus || 1
    end
  end
end
