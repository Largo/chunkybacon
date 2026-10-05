# frozen_string_literal: true

module ChunkyBacon
  class << self
    # Servers started by show_browser keep the program alive after its last
    # line, until Ctrl+C - as the mini browser stayed below the cell. Tests
    # switch this off.
    attr_writer :keep_serving

    def keep_serving
      @keep_serving.nil? ? true : @keep_serving
    end

    def servers
      @servers ||= []
    end

    # Status lines (where a file went, which address a server has) go to
    # stderr, so they never mix with what the program itself puts.
    def say(message)
      $stderr.puts "[chunky] #{message}"
    end

    # "chunky-image-1.png", "chunky-image-2.png", ... per run of the program
    def next_file(stem, extension)
      @counters ||= Hash.new(0)
      @counters[stem] += 1
      File.join(output_dir, "#{stem}-#{@counters[stem]}.#{extension}")
    end

    def save(path, bytes)
      File.binwrite(path, bytes)
      say "saved #{relative(path)} (#{bytes.bytesize} B)"
      path
    end

    IMAGE_SIGNATURES = {
      "\x89PNG".b => "png", "\xFF\xD8\xFF".b => "jpg", "GIF8".b => "gif", "RIFF".b => "webp"
    }.freeze

    # "png", "jpg", "gif" or "webp" for a picture's bytes, nil for anything else
    def image_type(bytes)
      bytes = bytes.b
      IMAGE_SIGNATURES.find { |magic, _type| bytes.start_with?(magic) }&.last
    end

    def relative(path)
      path = File.expand_path(path)
      base = File.expand_path(output_dir) + File::SEPARATOR
      path.start_with?(base) ? path.delete_prefix(base) : path
    end

    def serve_until_interrupt
      return if servers.empty? || !keep_serving

      say "the server keeps running - Ctrl+C stops it"
      servers.each(&:join)
    rescue Interrupt
      $stderr.puts
    end
  end

  # The course's notebook helpers, for a program on a computer. Same names,
  # arguments and defaults as on the course page (html/main.rb); what showed
  # below the cell there is a file in the program's folder here, opened in
  # the system's viewer.
  module Helpers
    private

    # Installs a gem now, unless it is installed already, and activates it -
    # afterwards `require` finds it. true when it is there.
    def install_gem(name)
      name = name.to_s
      begin
        gem name
        return true
      rescue Gem::LoadError
        nil # not installed yet
      end
      if defined?(Bundler) && ENV["BUNDLE_GEMFILE"]
        ChunkyBacon.say "this program runs under Bundler: add gem \"#{name}\" to its Gemfile and run bundle install"
        return false
      end
      ChunkyBacon.say "installing #{name} ..."
      Gem.install(name)
      Gem::Specification.reset
      gem name
      true
    rescue Gem::Exception, SystemCallError => e
      ChunkyBacon.say "#{name} could not be installed: #{e.message}"
      false
    end

    # A picture: a ChunkyPNG image (anything with to_blob or to_data_url),
    # what PureJPEG.encode returns (anything with to_bytes), the bytes of a
    # PNG, JPEG, GIF or WebP, or the path of an image file.
    def show_image(image)
      # a path: text without a picture's signature or NUL bytes, naming a file
      if image.is_a?(String) && !ChunkyBacon.image_type(image) && !image.include?("\0") && File.file?(image)
        ChunkyBacon::Opener.open(File.expand_path(image))
        return nil
      end
      bytes = if image.respond_to?(:to_blob)
                image.to_blob
              elsif image.respond_to?(:to_data_url)
                image.to_data_url.split(",", 2).last.unpack1("m0")
              elsif image.respond_to?(:to_bytes)
                image.to_bytes
              else
                image.to_s
              end.b
      path = ChunkyBacon.save(ChunkyBacon.next_file("chunky-image", ChunkyBacon.image_type(bytes) || "png"), bytes)
      ChunkyBacon::Opener.open(path)
      nil
    end

    # A PDF: a file's path, a Prawn::Document or HexaPDF::Document/Composer,
    # or the PDF itself as a String.
    def show_pdf(pdf)
      pdf = pdf.document if defined?(HexaPDF::Composer) && pdf.is_a?(HexaPDF::Composer)
      if pdf.is_a?(String) && !pdf.b.start_with?("%PDF")
        ChunkyBacon::Opener.open(File.expand_path(pdf))
        return nil
      end
      bytes = if pdf.is_a?(String)
                pdf
              elsif pdf.respond_to?(:render)
                pdf.render
              else
                StringIO.new("".b).tap { |io| pdf.write(io) }.string
              end
      path = ChunkyBacon.save(ChunkyBacon.next_file("chunky-document", "pdf"), bytes)
      ChunkyBacon::Opener.open(path)
      nil
    end

    # A matplotlib figure, through the pycall gem (require "pycall" first):
    # the current one, or the one given. Saved as a PNG and opened, then
    # closed - as the course page shows it below the cell.
    def show_plot(figure = nil)
      raise ChunkyBacon::NotHere, "show_plot draws with matplotlib through pycall: " \
                                  "pip install matplotlib, gem install pycall, require \"pycall\"" unless defined?(PyCall)

      plt = PyCall.import_module("matplotlib.pyplot")
      figure ||= plt.gcf
      path = ChunkyBacon.next_file("chunky-plot", "png")
      begin
        figure.savefig(path)
      ensure
        plt.close(figure)
      end
      ChunkyBacon.say "saved #{ChunkyBacon.relative(path)} (#{File.size(path)} B)"
      ChunkyBacon::Opener.open(path)
      nil
    end

    # What the page offered as a download: the data saved as +name+ in the
    # program's folder. download_file "notizen.txt" names a file that is
    # there already.
    def download_file(data, name = nil)
      if name.nil?
        path = File.expand_path(data.to_s, ChunkyBacon.output_dir)
        raise Errno::ENOENT, data.to_s unless File.file?(path)

        ChunkyBacon.say "#{ChunkyBacon.relative(path)} is ready (#{File.size(path)} B)"
        return nil
      end
      data = data.to_blob if data.respond_to?(:to_blob)
      ChunkyBacon.save(File.expand_path(name.to_s, ChunkyBacon.output_dir), data.to_s.b)
      nil
    end

    # Starts the Rack app (a Sinatra/Roda class or anything with #call) on
    # this computer and opens it in the browser. The program goes on; once
    # it has finished, the server keeps running until Ctrl+C.
    def show_browser(app, path = "/")
      server = ChunkyBacon::Server.new(app).start
      if ChunkyBacon.servers.empty? && ChunkyBacon.keep_serving
        at_exit { ChunkyBacon.serve_until_interrupt }
      end
      ChunkyBacon.servers << server
      ChunkyBacon.say "#{app.respond_to?(:name) && app.name ? app.name : "the app"} runs at #{server.url(path)}"
      ChunkyBacon::Opener.open(server.url(path))
      nil
    end

    # A GET against a Rack app without any server, for experiments and
    # checks:  status, body = mock_get(MyApp, "/hello")
    def mock_get(app, path)
      status, _headers, body = ChunkyBacon::RackEnv.call(app, ChunkyBacon::RackEnv.for(path))
      [status, body]
    end

    # An IRB session, here and now (at the top level, like the page's fresh
    # one). `exit` ends it, and the program carries on.
    def show_irb
      require "irb"
      TOPLEVEL_BINDING.irb
      nil
    end

    # The files in the program's folder, as the page's file explorer showed
    # the simulated ones.
    def show_files
      base = ChunkyBacon.output_dir
      puts "#{File.basename(File.expand_path(base))}/"
      entries = Dir.glob("**/*", base: base).reject { |p| p.split("/").any? { |part| part.start_with?(".") } }.sort
      entries.first(200).each do |entry|
        depth = entry.count("/")
        full = File.join(base, entry)
        name = File.basename(entry)
        puts File.directory?(full) ? "#{"  " * (depth + 1)}#{name}/" : "#{"  " * (depth + 1)}#{name}  (#{File.size(full)} B)"
      end
      puts "  ... #{entries.size - 200} more" if entries.size > 200
      nil
    end

    # Runs the Minitest tests defined so far and clears them, like the page.
    # (In a file of its own, `require "minitest/autorun"` does the same.)
    def run_tests
      require "minitest"
      result = Minitest.run([])
      Minitest::Runnable.runnables.clear
      result
    end

    def show_three(*)
      raise ChunkyBacon::NotHere, "show_three needs the course page for now - three-rb draws with three.js " \
                                  "in the browser. On your computer, three-rb's own examples show the way."
    end

    def show_shoes(**, &)
      raise ChunkyBacon::NotHere, "On your computer, Shoes apps run with Scarpe: gem install scarpe, put " \
                                  "Shoes.app do ... end in a file and start it with: scarpe app.rb"
    end

    def show_letter(**, &)
      raise ChunkyBacon::NotHere, "show_letter needs the course page - you write on it with the mouse " \
                                  "or a finger. The model itself runs here: model.predict(Numo::DFloat[...])."
    end
  end
end

module Kernel
  include ChunkyBacon::Helpers
end
