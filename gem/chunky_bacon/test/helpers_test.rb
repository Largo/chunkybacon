# frozen_string_literal: true

require "test_helper"

class HelpersTest < Minitest::Test
  include InTmpDir

  PNG = "\x89PNG\r\n\x1A\n".b + "rest of a picture".b
  PDF = "%PDF-1.4\n% a tiny document\n".b
  JPEG = "\xFF\xD8\xFF\xE0\x00\x10JFIF".b + "rest of a photo".b

  # what PureJPEG.encode returns
  Encoder = Struct.new(:bytes) do
    def to_bytes = bytes
  end

  # what a ChunkyPNG image offers
  Picture = Struct.new(:bytes) do
    def to_blob = bytes
  end

  def test_helpers_are_private_like_puts
    assert Object.private_method_defined?(:show_image)
    refute Object.public_method_defined?(:show_image)
  end

  def test_download_file_saves_the_data_in_the_programs_folder
    _, err = helper_output { download_file "Speck!\n", "notiz.txt" }
    assert_equal "Speck!\n", File.read(File.join(@dir, "notiz.txt"))
    assert_includes err, "saved notiz.txt (7 B)"
  end

  def test_download_file_takes_anything_with_to_blob
    helper_output { download_file Picture.new(PNG), "bild.png" }
    assert_equal PNG, File.binread(File.join(@dir, "bild.png"))
  end

  def test_download_file_names_a_file_that_is_there
    File.write(File.join(@dir, "liste.txt"), "Eier")
    _, err = helper_output { download_file "liste.txt" }
    assert_includes err, "liste.txt is ready (4 B)"
    assert_raises(Errno::ENOENT) { download_file "fehlt.txt" }
  end

  def test_show_image_saves_numbered_pngs
    helper_output do
      show_image PNG
      show_image Picture.new(PNG)
    end
    files = Dir.children(@dir).sort
    assert_equal 2, files.size
    assert(files.all? { |f| f.match?(/\Achunky-image-\d+\.png\z/) })
    files.each { |f| assert_equal PNG, File.binread(File.join(@dir, f)) }
  end

  def test_show_image_saves_a_jpeg_as_jpg
    helper_output do
      show_image Encoder.new(JPEG)
      show_image JPEG
    end
    files = Dir.children(@dir).sort
    assert_equal 2, files.size
    assert(files.all? { |f| f.match?(/\Achunky-image-\d+\.jpg\z/) })
    files.each { |f| assert_equal JPEG, File.binread(File.join(@dir, f)) }
  end

  def test_show_image_with_a_path_saves_nothing_new
    path = File.join(@dir, "fuchs.png")
    File.binwrite(path, PNG)
    helper_output { show_image path }
    assert_equal ["fuchs.png"], Dir.children(@dir)
  end

  # the course's boxes and arrows (lessons 7, 8, 11), as an SVG file
  def test_show_objects_saves_an_svg
    breakfast = ["egg", "toast"]
    _, err = helper_output { assert_nil show_objects(breakfast: breakfast, same: breakfast) }
    files = Dir.children(@dir)
    assert_equal 1, files.size
    assert_match(/\Achunky-image-\d+\.svg\z/, files.first)
    svg = File.read(File.join(@dir, files.first))
    assert svg.start_with?("<svg")
    assert_includes svg, "breakfast"
    assert_includes err, "saved #{files.first}"
  end

  # the course's turtle graphics (lesson 10), as an SVG file
  def test_turtle_saves_an_svg
    t = nil
    _, err = helper_output { t = turtle { 4.times { forward 100; right 90 } } }
    assert t.regular_polygon?(4, 100)
    files = Dir.children(@dir)
    assert_equal 1, files.size
    assert_match(/\Achunky-image-\d+\.svg\z/, files.first)
    assert File.read(File.join(@dir, files.first)).start_with?("<svg")
    assert_includes err, "saved #{files.first}"
  end

  def test_show_pdf_saves_the_document
    helper_output { show_pdf PDF }
    pdfs = Dir.children(@dir).grep(/\Achunky-document-\d+\.pdf\z/)
    assert_equal 1, pdfs.size
    assert_equal PDF, File.binread(File.join(@dir, pdfs.first))
  end

  def test_show_audio_saves_a_wav_and_writes_samples_as_one
    wav = "RIFF".b + "\x24\x00\x00\x00WAVE".b
    helper_output { show_audio wav }
    helper_output { show_audio [0.0, 1.0, -1.0, 2.0], rate: 8000 }
    sounds = Dir.children(@dir).grep(/\Achunky-sound-\d+\.wav\z/).sort
    assert_equal 2, sounds.size
    assert_equal wav, File.binread(File.join(@dir, sounds.first))
    written = File.binread(File.join(@dir, sounds.last))
    assert_equal ["RIFF", 44, "WAVE", 1, 8000, 16], written.unpack("a4Va4x8vx2Vx6v")
    assert_equal [0, 32_767, -32_767, 32_767], written.byteslice(44..).unpack("s<*"), "clamped to -1..1"
  end

  def test_mock_get_answers_like_the_course_page
    app = ->(env) { [200, { "content-type" => "text/plain" }, ["#{env["PATH_INFO"]}?#{env["QUERY_STRING"]}"]] }
    assert_equal [200, "/hallo?name=Isi"], mock_get(app, "hallo?name=Isi")
    assert_equal [200, "/x?"], mock_get(app, "http://localhost/x")
  end

  def test_show_files_lists_the_folder
    Dir.mkdir(File.join(@dir, "daten"))
    File.write(File.join(@dir, "main.rb"), "puts 1")
    File.write(File.join(@dir, "daten", "liste.txt"), "Speck")
    File.write(File.join(@dir, ".versteckt"), "x")
    out, = helper_output { show_files }
    assert_includes out, "main.rb  (6 B)"
    assert_includes out, "  daten/"
    assert_includes out, "    liste.txt  (5 B)"
    refute_includes out, ".versteckt"
  end

  def test_install_gem_with_a_gem_that_is_there
    assert install_gem("minitest")
  end

  # what the pycall gem gives for matplotlib.pyplot, as far as show_plot uses it
  class FakePyplot
    attr_reader :closed

    Figure = Struct.new(:label) do
      def savefig(path) = File.binwrite(path, PNG + label)
    end

    def initialize = @closed = []
    def gcf = Figure.new("current")
    def close(figure) = @closed << figure
  end

  def with_fake_pycall(plt)
    pycall = Object.const_set(:PyCall, Module.new)
    pycall.define_singleton_method(:import_module) { |name| name == "matplotlib.pyplot" ? plt : raise(name) }
    yield
  ensure
    Object.send(:remove_const, :PyCall)
  end

  def test_show_plot_saves_the_figure_as_a_png_and_closes_it
    plt = FakePyplot.new
    fig = FakePyplot::Figure.new("given")
    with_fake_pycall(plt) { helper_output { show_plot fig; show_plot } }
    files = Dir.children(@dir).sort_by { |f| f[/\d+/].to_i }
    assert(files.all? { |f| f.match?(/\Achunky-plot-\d+\.png\z/) })
    assert_equal [PNG + "given", PNG + "current"], files.map { |f| File.binread(File.join(@dir, f)) }
    assert_equal %w[given current], plt.closed.map(&:label)
  end

  def test_show_plot_closes_the_figure_when_saving_fails
    plt = FakePyplot.new
    broken = FakePyplot::Figure.new("broken")
    def broken.savefig(_path) = raise(IOError, "disk full")
    with_fake_pycall(plt) { assert_raises(IOError) { show_plot broken } }
    assert_equal %w[broken], plt.closed.map(&:label)
  end

  def test_show_plot_without_pycall_says_what_to_do
    error = assert_raises(ChunkyBacon::NotHere) { show_plot }
    assert_includes error.message, "gem install pycall"
  end

  def test_show_three_and_show_shoes_say_what_to_do
    error = assert_raises(ChunkyBacon::NotHere) { show_three(:scene, :camera) }
    assert_includes error.message, "three-rb"
    error = assert_raises(ChunkyBacon::NotHere) { show_shoes(width: 300) { para "hi" } }
    assert_includes error.message, "scarpe app.rb"
  end

  def test_show_game_says_what_to_do
    error = assert_raises(ChunkyBacon::NotHere) { show_game(width: 16, height: 12) { |g| g.every(0.15) {} } }
    assert_includes error.message, "ruby2d"
  end
end
