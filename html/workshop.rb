# The workshop (Werkstatt): the learner's own programs, beside the lessons.
# Its files live wherever storage.js keeps them - in this browser or in a
# folder on the learner's computer - and come over as one snapshot per run.
# For the run they become the virtual filesystem (SandboxFS), so a program
# can File.read and File.write its project's files and require_relative its
# other .rb files, and gets reads what the learner typed as input. Whatever
# the program wrote or deleted goes back to storage.js afterwards - text as
# text, pictures and PDFs as data: URLs, which the workshop previews; the
# lessons get their own virtual files back.
require "fileutils"

module Workshop
  # The binary files a project keeps: storage.js holds them as data: URLs,
  # a run gets their bytes. Pictures and PDFs show below the editor after a
  # run; a SQLite database (Sequel.sqlite("x.db"), sqlite3_sqljs.rb) is
  # kept, not shown. Other binary data a program writes is offered as a
  # download only.
  PREVIEW_TYPES = {
    ".png" => "image/png", ".jpg" => "image/jpeg", ".jpeg" => "image/jpeg",
    ".gif" => "image/gif", ".webp" => "image/webp", ".pdf" => "application/pdf"
  }.freeze
  BINARY_TYPES = PREVIEW_TYPES.merge(
    ".db" => "application/vnd.sqlite3", ".sqlite" => "application/vnd.sqlite3", ".sqlite3" => "application/vnd.sqlite3"
  ).freeze
  # bigger ones stay downloads: the browser's localStorage holds a few MB
  MAX_BINARY = 1_000_000

  class << self
    # Swaps the project's files in; +file+ is the one in the editor, with
    # +code+ as it stands there (maybe not saved yet).
    def prepare(snapshot, file, code)
      @lesson_files = SandboxFS.store.dup
      @before = snapshot.merge(file => code).to_h { |path, value| [path, decode(path, value)] }
      SandboxFS.store.replace(@before.transform_values(&:dup))
      # Pictures and PDFs also as real files: File.binread and File.open, and
      # so ChunkyPNG and Prawn reading them, go past SandboxFS.
      @before.each { |path, bytes| write_real(path, bytes) if binary?(path) }
      @loaded = [file]
    end

    # Runs the block as the program +file+ would run: $0 names it (so
    # `if __FILE__ == $0` works) and gets reads +input+.
    def with_io(file, input)
      old_stdin, old_name = $stdin, $PROGRAM_NAME
      $stdin = StringIO.new(input.to_s)
      $PROGRAM_NAME = file
      @running = true
      yield
    ensure
      $stdin = old_stdin
      $PROGRAM_NAME = old_name
      @running = false
    end

    # What the run changed, as [[path, value or nil], ...]: a text file as
    # text, a picture or PDF as a data: URL, nil for a deleted file.
    # +changes+ are FileWatch's [path, bytes] for every file the program
    # wrote, through SandboxFS or onto the real filesystem. Other binary data,
    # big files and odd paths stay out: they are still offered as downloads.
    def finish(changes)
      after = SandboxFS.store.dup
      SandboxFS.store.replace(@lesson_files || {})
      kept = changes.filter_map { |path, bytes| keep(path, bytes) }
      kept + (@before.keys - after.keys).filter_map { |path| [path, nil] if storable?(path) }
    end

    # the project's files, by name - a live run's time limit counts their lines
    def paths = (@before || {}).keys

    # the pictures and PDFs among +changes+, to show below the editor
    def previews(changes)
      changes.select { |path, bytes| PREVIEW_TYPES.key?(File.extname(path.to_s).downcase) && bytes.bytesize <= MAX_BINARY }
    end

    def binary?(path)
      BINARY_TYPES.key?(File.extname(path.to_s).downcase)
    end

    def pdf?(path)
      File.extname(path.to_s).downcase == ".pdf"
    end

    def data_url(path, bytes)
      "data:#{BINARY_TYPES.fetch(File.extname(path).downcase)};base64,#{[bytes].pack('m0')}"
    end

    # require_relative from a project file, for a project file: evaluated
    # once per run in a fresh top-level scope, as a real require would.
    def require_relative(path, caller_path)
      return nil unless @running
      target = resolve(path, caller_path)
      return nil unless target && SandboxFS.store.key?(target)
      return false if @loaded.include?(target)

      @loaded << target
      eval(SandboxFS.store[target], TopLevel.binding(target), target)
      true
    end

    # "helper" required from "lib/main.rb" -> "lib/helper.rb"
    def resolve(path, caller_path)
      path = "#{path}.rb" unless path.end_with?(".rb")
      File.expand_path(path, "/#{File.dirname(caller_path)}").delete_prefix("/")
    end

    # The first frame of +error+ in another project file, as "helper.rb:3" -
    # an error in the open file is marked in the editor instead.
    def location(error, file)
      return nil if error.is_a?(SyntaxError)   # its message names file and line

      (error.backtrace || []).each do |frame|
        path, line = frame.split(":", 3)
        return "#{path}:#{line}" if path != file && @before&.key?(path)
      end
      nil
    end

    private

    # a picture or PDF arrives as a data: URL; a text file as itself
    def decode(path, value)
      return value unless binary?(path) && value.to_s.start_with?("data:") && value.include?(";base64,")

      value.split(",", 2).last.unpack1("m0")
    end

    def keep(path, bytes)
      return nil unless storable?(path)

      if binary?(path)
        [path, data_url(path, bytes)] if bytes.bytesize <= MAX_BINARY
      else
        text = bytes.to_s.dup.force_encoding(Encoding::UTF_8)
        [path, text] if text.valid_encoding?
      end
    end

    def write_real(path, bytes)
      full = File.join(Dir.pwd, path)
      FileUtils.mkdir_p(File.dirname(full))
      File.binwrite(full, bytes)
    rescue SystemCallError
      nil # a program reading it with File.binread fails as it would anyway
    end

    def storable?(path)
      path.split("/").all? { |part| part.match?(/\A[\p{L}\p{N}_][\p{L}\p{N}_.\-]*\z/) }
    end
  end
end
