# The optional server (server/app.rb) under Rack::MockRequest - no port, no
# network (the bridges are only asked what they refuse):
#   ruby test/server_test.rb   (or, with the server's Gemfile: cd server && bundle exec ruby ../test/server_test.rb)
require "minitest/autorun"
require "json"
require "rack"
require_relative "../server/app"

class ServerTest < Minitest::Test
  APP = ChunkyServer.freeze.app

  def get(path, method: "GET") = Rack::MockRequest.new(APP).request(method, path)

  def test_the_root_page_announces_permalinks
    res = get("/")
    assert_equal 200, res.status
    assert_includes res.body, '<base href="/">'
    assert_includes res.body, '<meta name="chunky-permalinks" content="/">'
    assert_operator res.body.index("<base"), :<, res.body.index("assets/fonts/fonts.css"), "<base> before the first relative URL"
  end

  def test_a_lesson_permalink_is_titled_for_its_lesson
    res = get("/de/methoden")
    assert_equal 200, res.status
    assert_includes res.body, '<html lang="de">'
    assert_includes res.body, "<title>9. Methoden – Ruby lernen mit Chunky Bacon</title>"
    assert_includes res.body, '<meta property="og:title" content="9. Methoden – Ruby lernen mit Chunky Bacon">'
    assert_includes res.body, '<link rel="canonical" href="http://example.org/de/methoden">'
    assert_includes res.body, '<link rel="alternate" hreflang="ja" href="http://example.org/ja/methoden">'
    assert_includes res.body, '<meta name="chunky-permalinks" content="/">'
  end

  def test_the_description_is_the_lessons_first_paragraph
    description = get("/en/methoden").body[/<meta name="description" content="([^"]*)"/, 1]
    refute_includes description, "<"
    refute_includes description, "Lerne die Programmiersprache", "not the German default"
    assert_operator description.length, :<=, 160
  end

  def test_the_workshop_and_a_bare_language
    assert_includes get("/en/werkstatt").body, "<title>Workshop – Learn Ruby with Chunky Bacon</title>"
    res = get("/ja")
    assert_equal 200, res.status
    assert_includes res.body, '<html lang="ja">'
  end

  def test_unknown_languages_and_lessons_are_404
    %w[/xx/methoden /de/gibts-nicht /de/methoden/mehr /assets].each do |path|
      res = get(path)
      assert_equal 404, res.status, path
      assert_includes res.body, "This page does not exist", path
    end
  end

  def test_files_come_as_they_are
    res = get("/assets/app.css")
    assert_equal 200, res.status
    assert_equal "text/css", res["content-type"]
    assert_equal "no-cache", res["cache-control"]
    raw = get("/index.html")
    refute_includes raw.body, "chunky-permalinks", "the file itself stays the static site's page"
  end

  def test_the_wasm_runtime_comes_gzipped_with_its_type
    res = Rack::MockRequest.new(APP).request("HEAD", "/ruby+stdlib.wasm", "HTTP_ACCEPT_ENCODING" => "gzip")
    assert_equal 200, res.status
    assert_equal "application/wasm", res["content-type"]
    assert_equal "gzip", res["content-encoding"]
  end

  def test_the_lessons_as_json
    res = get("/api/lessons")
    assert_equal 200, res.status
    lessons = JSON.parse(res.body)
    assert_equal 58, lessons.length
    methoden = lessons.find { |lesson| lesson["id"] == "methoden" }
    assert_equal "9. Methods", methoden["titles"]["en"]
  end

  def test_the_bridges_refuse_other_paths_and_methods
    assert_equal 403, get("/rubygems/api/v1/dependencies").status
    assert_equal 403, get("/rubygems/").status
    assert_equal 403, get("/rubygems/gems/chunky_png-1.4.0.gem", method: "POST").status
  end

  # as nginx/default.conf: only for the course's own pages (a page on the
  # host asked); asked without one, they answer before going out
  def test_the_bridges_refuse_requests_from_other_pages
    [nil, "http://evil.test/", "http://example.org.evil.test/"].each do |referer|
      env = referer ? { "HTTP_REFERER" => referer } : {}
      %w[/rubygems/gems/chunky_png-1.4.0.gem /rubygems/api/v1/gems/rake.json /proxy/ruby-lang/en/].each do |path|
        res = Rack::MockRequest.new(APP).get(path, env)
        assert_equal 403, res.status, "#{path} from #{referer.inspect}"
        assert_equal "same-origin", res["cross-origin-resource-policy"]
      end
    end
  end
end
