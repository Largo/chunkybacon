# frozen_string_literal: true

# No viewer or browser opens during tests, and servers do not keep the test
# process alive at its end.
ENV["CHUNKYBACON_OPEN"] = "0"

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "chunky_bacon"
require "minitest/autorun"
require "tmpdir"
require "fileutils"

ChunkyBacon.keep_serving = false

# Every test in a folder of its own; helpers save their files there.
module InTmpDir
  def setup
    super
    @dir = Dir.mktmpdir("chunky_bacon")
    ChunkyBacon.output_dir = @dir
  end

  def teardown
    ChunkyBacon.output_dir = nil
    FileUtils.remove_entry(@dir)
    super
  end

  # a helper's stdout and stderr, as [out, err]
  def helper_output(&block)
    capture_io(&block)
  end
end
