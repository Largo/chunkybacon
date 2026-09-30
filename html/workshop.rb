# The workshop (Werkstatt): the learner's own programs, beside the lessons.
# Its files live wherever storage.js keeps them - in this browser or in a
# folder on the learner's computer - and come over as one snapshot per run.
# For the run they become the virtual filesystem (SandboxFS), so a program
# can File.read and File.write its project's files and require_relative its
# other .rb files, and gets reads what the learner typed as input. Whatever
# the program wrote or deleted goes back to storage.js afterwards; the
# lessons get their own virtual files back.
module Workshop
  class << self
    # Swaps the project's files in; +file+ is the one in the editor, with
    # +code+ as it stands there (maybe not saved yet).
    def prepare(snapshot, file, code)
      @lesson_files = SandboxFS.store.dup
      @before = snapshot.merge(file => code)
      SandboxFS.store.replace(@before.transform_values(&:dup))
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

    # What the run changed, as [[path, text or nil], ...] - nil for a deleted
    # file. Binary data and odd paths stay out: they are still offered as
    # downloads, but storage.js keeps text files with plain names.
    def finish
      after = SandboxFS.store.dup
      SandboxFS.store.replace(@lesson_files || {})
      changes = after.filter_map do |path, data|
        next if @before[path] == data || !storable?(path)
        text = data.to_s.dup.force_encoding(Encoding::UTF_8)
        [path, text] if text.valid_encoding?
      end
      changes + (@before.keys - after.keys).filter_map { |path| [path, nil] if storable?(path) }
    end

    # require_relative from a project file, for a project file: evaluated
    # once per run in a fresh top-level scope, as a real require would.
    def require_relative(path, caller_path)
      return nil unless @running
      target = resolve(path, caller_path)
      return nil unless target && SandboxFS.store.key?(target)
      return false if @loaded.include?(target)

      @loaded << target
      eval(SandboxFS.store[target], eval("proc { binding }.call", TOPLEVEL_BINDING), target)
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

    def storable?(path)
      path.split("/").all? { |part| part.match?(/\A[\p{L}\p{N}_][\p{L}\p{N}_.\-]*\z/) }
    end
  end
end
