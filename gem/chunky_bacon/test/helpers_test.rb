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

  def test_show_pdf_saves_the_document
    helper_output { show_pdf PDF }
    pdfs = Dir.children(@dir).grep(/\Achunky-document-\d+\.pdf\z/)
    assert_equal 1, pdfs.size
    assert_equal PDF, File.binread(File.join(@dir, pdfs.first))
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

  def test_show_three_and_show_shoes_say_what_to_do
    error = assert_raises(ChunkyBacon::NotHere) { show_three(:scene, :camera) }
    assert_includes error.message, "three-rb"
    error = assert_raises(ChunkyBacon::NotHere) { show_shoes(width: 300) { para "hi" } }
    assert_includes error.message, "scarpe app.rb"
  end
end
