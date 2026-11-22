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
  COURSE = Course.load(File.expand_path("../html/lessons.js", __dir__))
  IDS = COURSE.ids
  # /ja/メソッド as it goes over the wire
  JA_METHODEN = "%E3%83%A1%E3%82%BD%E3%83%83%E3%83%89"
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
    body = get("/en/methods").body
    lesson = body[%r{<article id="lessonBody">(.*?)</article>}m, 1]
    assert_includes lesson, "<h2>"
    assert_includes lesson, "<pre><code>"
    assert_includes body, %(<a href="/en/methods">#{METHODEN}. Methods</a>)
    assert_includes body, '<nav id="lessonNav"><ol><li><a href="/en/hello-world">'
  end

  def test_a_bare_language_is_canonical_with_alternates_and_no_lesson
    body = get("/fr").body
    assert_includes body, '<link rel="canonical" href="http://example.org/fr">'
    assert_includes body, '<link rel="alternate" hreflang="it" href="http://example.org/it">'
    assert_includes body, '<article id="lessonBody"></article>'
    assert_includes body, '<a href="/fr/bonjour-le-monde">'
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
    assert_includes body, "<loc>https://letsruby.com/ja/#{JA_METHODEN}</loc>"
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
    assert_includes res.body, %(<link rel="alternate" hreflang="ja" href="http://example.org/ja/#{JA_METHODEN}">)
    assert_includes res.body, '<meta name="chunky-permalinks" content="/">'
  end

  def test_public_origin_names_the_canonical_address
    ENV["PUBLIC_ORIGIN"] = "https://letsruby.com/"
    body = get("/en/methods").body
    assert_includes body, %(<link rel="canonical" href="https://letsruby.com/en/methods">)
    assert_includes body, %(<meta property="og:url" content="https://letsruby.com/en/methods">)
    assert_includes body, %(<link rel="alternate" hreflang="de" href="https://letsruby.com/de/methoden">)
  ensure
    ENV.delete("PUBLIC_ORIGIN")
  end

  def test_the_description_is_the_lessons_first_paragraph
    description = get("/en/methods").body[/<meta name="description" content="([^"]*)"/, 1]
    refute_includes description, "<"
    refute_includes description, "Lerne die Programmiersprache", "not the German default"
    assert_operator description.length, :<=, 160
  end

  # "lesson {{nr:gems}}" in lessons.js: the preview says the number
  def test_a_reference_in_the_description_is_numbered
    gems = JSON.parse(get("/api/lessons").body).index { |lesson| lesson["id"] == "gems" } + 1
    description = get("/en/jpeg-photos-with-pure-jpeg").body[/<meta name="description" content="([^"]*)"/, 1]
    assert_includes description, "In lesson #{gems} you painted"
  end

  def test_the_workshop_and_a_bare_language
    assert_includes get("/en/workshop").body, "<title>Workshop – Let&#39;s Ruby</title>"
    res = get("/ja")
    assert_equal 200, res.status
    assert_includes res.body, '<html lang="ja">'
  end

  # every language of the course (lessons.js's ui: de, en, ja, fr, it) has
  # its permalinks, and each page names all of them as alternates
  def test_every_course_language_has_permalinks
    langs = COURSE.langs
    langs.each do |lang|
      res = get("/#{COURSE.path(lang, "methoden")}")
      assert_equal 200, res.status, lang
      assert_includes res.body, %(<html lang="#{lang}">), lang
      assert_includes res.body, %(<link rel="canonical" href="http://example.org/#{COURSE.path(lang, "methoden")}">), lang
      langs.each { |other| assert_includes res.body, %(<link rel="alternate" hreflang="#{other}" href="http://example.org/#{COURSE.path(other, "methoden")}">), "#{lang} -> #{other}" }
      assert_equal 200, get("/#{lang}").status, lang
    end
  end

  # the slugs in each language: German keeps the ids; Japanese in its script
  def test_a_lesson_has_its_word_in_each_language
    {"/de/variablen" => "3. Variablen", "/en/variables" => "3. Variables", "/fr/variables" => "3. Variables",
     "/it/variabili" => "3. Variabili", "/ja/%E5%A4%89%E6%95%B0" => "3. 変数",
     "/ja/#{JA_METHODEN}" => "#{METHODEN}. メソッド"}.each do |path, title|
      res = get(path)
      assert_equal 200, res.status, path
      assert_includes res.body, "<title>#{title} – Let&#39;s Ruby</title>", path
    end
    assert_includes get("/ja/#{JA_METHODEN}").body, %(<link rel="canonical" href="http://example.org/ja/#{JA_METHODEN}">)
    assert_includes get("/fr/atelier").body, "<title>Atelier – Let&#39;s Ruby</title>"
  end

  # the links already out there - and indexed - name a lesson by its id in
  # every language: they move to the word for good
  def test_an_id_in_another_language_moves_to_its_slug
    {"/en/variablen" => "/en/variables", "/ja/methoden" => "/ja/#{JA_METHODEN}",
     "/fr/hallo" => "/fr/bonjour-le-monde", "/it/werkstatt" => "/it/laboratorio"}.each do |from, to|
      res = get(from)
      assert_equal 301, res.status, from
      assert_equal to, res.headers["location"], from
    end
    assert_equal 200, get("/de/variablen").status, "German keeps its ids"
  end

  # every lesson has a slug in every language but German (ruby tools/lesson_slugs.rb),
  # unique in its language and never another lesson's id - that old link
  # would open the wrong lesson
  def test_every_slug_is_there_unique_and_no_other_lessons_id
    pages = IDS + [Course::WORKSHOP_ID]
    COURSE.langs.each do |lang|
      slugs = pages.map { |id| COURSE.slug(lang, id) }
      assert_equal slugs.uniq, slugs, lang
      pages.each do |id|
        slug = COURSE.slug(lang, id)
        refute_includes slug, "/", "#{lang} #{id}"
        other = pages.index(slug)
        assert(other.nil? || pages[other] == id, "#{lang}: #{id}'s slug #{slug} is another lesson's id")
        assert(lang == "de" || slug != id || slug.match?(/\A[a-z0-9-]+\z/), "#{lang} #{id}")
      end
    end
    assert system("ruby", File.expand_path("../tools/lesson_slugs.rb", __dir__), "--check", out: File::NULL),
           "lessons without slugs: ruby tools/lesson_slugs.rb"
  end

  def test_landing_page_links_follow_the_language_by_slug
    paths = JSON.parse(get("/").body[%r{<script type="application/json" id="chunky-paths">(.*?)</script>}, 1])
    assert_equal "en/hello-world", paths["en"]["hallo"]
    assert_equal "de/hallo", paths["de"]["hallo"]
    assert_equal "ja/hello-world", paths["ja"]["hallo"]
  end

  def test_unknown_languages_and_lessons_are_404
    %w[/xx/methoden /de/gibts-nicht /de/methoden/mehr /assets /en/variables-nope /ja/%FF].each do |path|
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
