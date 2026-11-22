# The optional server (server/app.rb) under Rack::MockRequest - no port, no
# network (the bridges are only asked what they refuse):
#   ruby test/server_test.rb   (or, with the server's Gemfile: cd server && bundle exec ruby ../test/server_test.rb)
require "minitest/autorun"
require "json"
require "rack"
require_relative "../server/app"

class ServerTest < Minitest::Test
  APP = ChunkyServer.freeze.app
  # what moves when a lesson is put in between: the count, a lesson's place
  IDS = Course.load(File.expand_path("../html/lessons.js", __dir__)).ids
  METHODEN = IDS.index("methoden") + 1

  def get(path, method: "GET") = Rack::MockRequest.new(APP).request(method, path)

  def test_the_root_is_the_landing_page
    res = get("/")
    assert_equal 200, res.status
    assert_includes res.body, "Let&#39;s Ruby"
  end

  # a search engine follows the landing page's links to the lessons'
  # permalinks; pages.js turns them into the reader's language
  def test_the_landing_page_links_to_permalinks
    body = get("/").body
    assert_includes body, '<meta name="chunky-permalinks" content="/">'
    assert_includes body, 'href="/de/hallo" data-href="learn#hallo"'
    assert_includes body, 'href="/de" data-href="learn"'
    refute_match(/[^-]href="learn/, body)
  end

  def test_the_lesson_comes_as_html_before_the_shell_starts
    body = get("/en/methoden").body
    lesson = body[%r{<article id="lessonBody">(.*?)</article>}m, 1]
    assert_includes lesson, "<h2>"
    assert_includes lesson, "<pre><code>"
    assert_includes body, %(<a href="/en/methoden">#{METHODEN}. Methods</a>)
    assert_includes body, '<nav id="lessonNav"><ol><li><a href="/en/hallo">'
  end

  def test_a_bare_language_is_canonical_with_alternates_and_no_lesson
    body = get("/fr").body
    assert_includes body, '<link rel="canonical" href="http://example.org/fr">'
    assert_includes body, '<link rel="alternate" hreflang="it" href="http://example.org/it">'
    assert_includes body, '<article id="lessonBody"></article>'
    assert_includes body, '<a href="/fr/hallo">'
  end

  def test_the_workshop_has_the_index_but_no_lesson
    body = get("/de/werkstatt").body
    assert_includes body, '<article id="lessonBody"></article>'
    assert_includes body, '<a href="/de/hallo">'
  end

  def test_learn_stays_as_it_is
    body = get("/learn").body
    assert_includes body, '<nav id="lessonNav"></nav>'
    refute_includes body, 'rel="canonical"'
  end

  def test_the_sitemap_names_every_page_with_its_translations
    ENV["PUBLIC_ORIGIN"] = "https://letsruby.com"
    res = get("/sitemap.xml")
    assert_equal 200, res.status
    assert_equal "application/xml", res.headers["content-type"]
    body = res.body
    langs = Course.load(File.expand_path("../html/lessons.js", __dir__)).langs
    assert_equal 1 + langs.size * (IDS.size + 1), body.scan("<loc>").size
    assert_includes body, "<loc>https://letsruby.com/</loc>"
    assert_includes body, "<loc>https://letsruby.com/ja/methoden</loc>"
    assert_includes body, '<xhtml:link rel="alternate" hreflang="de" href="https://letsruby.com/de/methoden"/>'
  ensure
    ENV.delete("PUBLIC_ORIGIN")
  end

  # welcome.html counts the lessons by hand: the total (the figure and both
  # descriptions) and each curriculum card's section - from the lesson it
  # links to up to the next section - must match lessons.js
  def test_the_landing_page_counts_the_lessons_of_lessons_js
    html = File.read(File.expand_path("../html/welcome.html", __dir__), encoding: "UTF-8")
    assert_includes html, "<strong>#{IDS.size}</strong>"
    assert_includes html, "#{IDS.size} Lektionen von den Grundlagen"
    assert_includes html, "#{IDS.size} lessons from your first line"

    lessons = Course.load(File.expand_path("../html/lessons.js", __dir__)).instance_variable_get(:@lessons)
    starts = lessons.each_index.select { |i| lessons[i]["section"] }
    cards = html.scan(%r{<a class="card [^"]*" href="learn#([^"]+)">\s*<div class="count"><span data-l="de">(\d+) }m)
    assert_equal 5, cards.size
    cards.each do |id, count|
      first = IDS.index(id)
      assert_includes starts, first, "#{id} starts a section"
      size = (starts.find { |i| i > first } || IDS.size) - first
      assert_equal size, count.to_i, "the card for #{id}"
    end
  end

  def test_robots_txt_names_the_sitemap
    body = get("/robots.txt").body
    assert_includes body, "Sitemap: https://letsruby.com/sitemap.xml"
  end

  def test_the_course_page_announces_permalinks
    res = get("/learn")
    assert_equal 200, res.status
    assert_includes res.body, '<base href="/">'
    assert_includes res.body, '<meta name="chunky-permalinks" content="/">'
    assert_operator res.body.index("<base"), :<, res.body.index("assets/fonts/fonts.css"), "<base> before the first relative URL"
  end

  def test_a_lesson_permalink_is_titled_for_its_lesson
    res = get("/de/methoden")
    assert_equal 200, res.status
    assert_includes res.body, '<html lang="de">'
    assert_includes res.body, "<title>#{METHODEN}. Methoden – Let&#39;s Ruby</title>"
    assert_includes res.body, %(<meta property="og:title" content="#{METHODEN}. Methoden – Let&#39;s Ruby">)
    assert_includes res.body, '<link rel="canonical" href="http://example.org/de/methoden">'
    assert_includes res.body, '<link rel="alternate" hreflang="ja" href="http://example.org/ja/methoden">'
    assert_includes res.body, '<meta name="chunky-permalinks" content="/">'
  end

  def test_public_origin_names_the_canonical_address
    ENV["PUBLIC_ORIGIN"] = "https://letsruby.com/"
    body = get("/en/methoden").body
    assert_includes body, %(<link rel="canonical" href="https://letsruby.com/en/methoden">)
    assert_includes body, %(<meta property="og:url" content="https://letsruby.com/en/methoden">)
    assert_includes body, %(<link rel="alternate" hreflang="de" href="https://letsruby.com/de/methoden">)
  ensure
    ENV.delete("PUBLIC_ORIGIN")
  end

  def test_the_description_is_the_lessons_first_paragraph
    description = get("/en/methoden").body[/<meta name="description" content="([^"]*)"/, 1]
    refute_includes description, "<"
    refute_includes description, "Lerne die Programmiersprache", "not the German default"
    assert_operator description.length, :<=, 160
  end

  # "lesson {{nr:gems}}" in lessons.js: the preview says the number
  def test_a_reference_in_the_description_is_numbered
    gems = JSON.parse(get("/api/lessons").body).index { |lesson| lesson["id"] == "gems" } + 1
    description = get("/en/jpeg").body[/<meta name="description" content="([^"]*)"/, 1]
    assert_includes description, "In lesson #{gems} you painted"
  end

  def test_the_workshop_and_a_bare_language
    assert_includes get("/en/werkstatt").body, "<title>Workshop – Let&#39;s Ruby</title>"
    res = get("/ja")
    assert_equal 200, res.status
    assert_includes res.body, '<html lang="ja">'
  end

  # every language of the course (lessons.js's ui: de, en, ja, fr, it) has
  # its permalinks, and each page names all of them as alternates
  def test_every_course_language_has_permalinks
    langs = Course.load(File.expand_path("../html/lessons.js", __dir__)).langs
    langs.each do |lang|
      res = get("/#{lang}/methoden")
      assert_equal 200, res.status, lang
      assert_includes res.body, %(<html lang="#{lang}">), lang
      assert_includes res.body, %(<link rel="canonical" href="http://example.org/#{lang}/methoden">), lang
      langs.each { |other| assert_includes res.body, %(<link rel="alternate" hreflang="#{other}" href="http://example.org/#{other}/methoden">), "#{lang} -> #{other}" }
      assert_equal 200, get("/#{lang}").status, lang
    end
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
    assert_equal IDS.size, lessons.length
    methoden = lessons.find { |lesson| lesson["id"] == "methoden" }
    assert_equal "#{METHODEN}. Methods", methoden["titles"]["en"]
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
