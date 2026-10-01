# frozen_string_literal: true

module ChunkyBacon
  # Opens a file or a URL with whatever the system uses for it - the image
  # viewer, the PDF reader, the browser. CHUNKYBACON_OPEN=0 turns it off
  # (tests, CI, a machine without a desktop); the file is saved either way.
  module Opener
    def self.enabled?
      ENV["CHUNKYBACON_OPEN"] != "0"
    end

    # true when a viewer was started
    def self.open(target)
      return false unless enabled?

      pid = Process.spawn(*command(target.to_s), out: File::NULL, err: File::NULL)
      Process.detach(pid)
      true
    rescue SystemCallError
      false
    end

    def self.command(target)
      if Gem.win_platform?
        # `start` is a cmd built-in; its first quoted argument is a window
        # title. cmd reads & | < > ^ as operators unless escaped - Ruby only
        # quotes an argument that has a space, and inside quotes the escape
        # would be taken literally.
        target = target.gsub(/[&|<>^]/) { |c| "^#{c}" } unless target.include?(" ")
        ["cmd", "/c", "start", "", target]
      elsif RUBY_PLATFORM.include?("darwin")
        ["open", target]
      else
        ["xdg-open", target]
      end
    end
  end
end
