# The dev server's rules (tools/dev_server.rb), which are nginx's
# (nginx/default.conf): the bridges serve only the course's own pages,
# embed.html comes sandboxed, static files may be read cross-origin. And
# that the two files say the same - there is no nginx here to run `nginx -t`
# or a request against, so its map pattern and its headers are read out of
# the file and compared. No network: the bridge answers for rubygems.org.
#   ruby test/dev_server_test.rb
require "minitest/autorun"
require "net/http"
ENV.delete("FRAME_ANCESTORS")   # the production default, as in nginx
require_relative "../tools/dev_server"

class DevServerTest < Minitest::Test
  NGINX = File.read(File.expand_path("../nginx/default.conf", __dir__))

  # a bridge that answers itself instead of asking rubygems.org
  class LocalBridge < Bridge
    Answer = Struct.new(:code, :body, :headers) do
      def [](name) = headers[name]
    end

    private

    def fetch(path, _head)
      Answer.new("200", "upstream #{path}", { "content-type" => "application/json" })
    end
  end

  def self.server
    @server ||= begin
      server = WEBrick::HTTPServer.new(BindAddress: "127.0.0.1", Port: 0, MimeTypes: MIME,
                                       Logger: WEBrick::Log.new(File::NULL), AccessLog: [])
      mount_course(server, LocalBridge)
      Thread.new { server.start }
      Minitest.after_run { server.shutdown }
      server
    end
  end

  def port = self.class.server.config[:Port]

  def get(path, headers = {})
    Net::HTTP.start("127.0.0.1", port) { |http| http.get(path, headers) }
  end

  def own_page = "http://127.0.0.1:#{port}/de/methoden"

  # ---------- the bridges ----------

  def test_a_bridge_refuses_a_request_without_a_referer
    res = get("/rubygems/api/v1/gems/rake.json")
    assert_equal "403", res.code
    assert_equal "same-origin", res["Cross-Origin-Resource-Policy"]
  end

  def test_a_bridge_refuses_another_sites_page
    %w[http://evil.test/ http://127.0.0.1.evil.test/ http://evil.test/?from=http://127.0.0.1/].each do |referer|
      assert_equal "403", get("/rubygems/api/v1/gems/rake.json", "Referer" => referer).code, referer
      assert_equal "403", get("/proxy/ruby-lang/en/", "Referer" => referer).code, referer
    end
  end

  def test_a_bridge_serves_the_courses_own_pages
    res = get("/rubygems/api/v1/gems/rake.json", "Referer" => own_page)
    assert_equal "200", res.code
    assert_equal "upstream /api/v1/gems/rake.json", res.body
    assert_equal "same-origin", res["Cross-Origin-Resource-Policy"]
    assert_nil res["Access-Control-Allow-Origin"], "same-origin only: no CORS"
    assert_equal "200", get("/rubygems/gems/chunky_png-1.4.0.gem", "Referer" => own_page).code
    # another port of the same host is the same host (nginx's $host has none)
    assert_equal "200", get("/proxy/ruby-lang/en/", "Referer" => "http://127.0.0.1:1/").code
  end

  def test_the_courses_own_pages_get_only_the_two_rubygems_shapes
    assert_equal "403", get("/rubygems/gems/chunky_png-1.4.0.gem/more", "Referer" => own_page).code
    assert_equal "403", get("/rubygems/api/v1/dependencies", "Referer" => own_page).code
  end

  # ---------- the files ----------

  def test_static_files_may_be_read_cross_origin
    res = get("/main.rb")
    assert_equal "200", res.code
    assert_equal "*", res["Access-Control-Allow-Origin"]
    assert_nil res["Content-Security-Policy"]
  end

  def test_the_embed_comes_sandboxed_and_framed_only_by_idogawa_com
    res = get("/embed.html")
    assert_equal "200", res.code
    csp = res["Content-Security-Policy"]
    assert csp.start_with?("sandbox allow-scripts allow-popups allow-popups-to-escape-sandbox allow-downloads;"), csp
    refute_includes csp, "allow-same-origin"
    assert_includes csp, "frame-ancestors https://idogawa.com;"
    assert_equal "no-cache", res["Cache-Control"]
  end

  # ---------- nginx/default.conf says the same ----------

  def nginx_map(variable)
    NGINX[/^map "\$http_referer\|\$host" \$#{variable} \{\n(.*?)^\}/m, 1] or flunk "no map for $#{variable}"
  end

  def test_nginx_matches_the_referer_as_the_dev_server_does
    body = nginx_map("chunky_bridge_ok")
    assert_includes body, "default 0;"
    patterns = body.scan(/^\s*"~\*(.*)" 1;$/).flatten
    assert_equal [CourseRules::BRIDGE_REFERER.source], patterns
    assert CourseRules::BRIDGE_REFERER.casefold?, "~* is case-insensitive"
  end

  # The pattern, as PCRE (nginx) and Onigmo (Ruby) both read it
  def test_the_referer_pattern
    ok = ->(referer, host) { "#{referer}|#{host}".match?(CourseRules::BRIDGE_REFERER) }
    course = "chunkybacon.idogawa.com"
    assert ok.("https://chunkybacon.idogawa.com/de/methoden", course)
    assert ok.("https://chunkybacon.idogawa.com:443/", course)
    assert ok.("https://CHUNKYBACON.idogawa.com/", course)
    assert ok.("http://192.0.2.7:8011/#methoden", "192.0.2.7")   # at an address, with a port
    refute ok.("", course), "no Referer"
    refute ok.("https://idogawa.com/blog/", course), "the blog is another host"
    refute ok.("https://evil.example/", course)
    refute ok.("https://chunkybacon.idogawa.com.evil.example/", course)
    refute ok.("https://evil.example/?u=https://chunkybacon.idogawa.com/", course)
    refute ok.("https://chunkybacon.idogawa.com@evil.example/", course)
    refute ok.("https://chunkybacon.idogawa.com", course), "a browser always sends a path"
    refute ok.("http://192.0.2.7:8011/", "192.0.2.70")
  end

  def test_nginx_guards_every_bridge
    %w[/proxy/ruby-lang/ /rubygems/api/v1/gems/ /rubygems/gems/].each do |path|
      block = NGINX[/location \^~ #{Regexp.escape(path)} \{\n(.*?)\n    \}/m, 1] or flunk "no location #{path}"
      assert_includes block, "if ($chunky_bridge_ok = 0) { return 403; }", path
      assert_includes block, "add_header Cross-Origin-Resource-Policy same-origin always;", path
      assert_includes block, "limit_req zone=proxylimit", path
      refute_includes block, "add_header Access-Control-Allow-Origin", path
      assert_includes block, "proxy_hide_header Access-Control-Allow-Origin;", "#{path}: not even upstream's"
    end
    assert_match(/location \^~ \/rubygems\/ \{\n\s*return 403;/, NGINX)
  end

  def test_nginx_sends_the_embeds_headers_as_the_dev_server_does
    block = NGINX[/location = \/embed\.html \{\n(.*?)\n    \}/m, 1] or flunk "no location = /embed.html"
    csp = block[/add_header Content-Security-Policy "([^"]*)" always;/, 1]
    assert_equal CourseRules::EMBED_CSP, csp
    assert_includes block, 'add_header Cache-Control "no-cache";'
  end

  def test_nginx_lets_static_files_be_read_cross_origin
    server = NGINX[/^server \{\n(.*?)^    location/m, 1]
    assert_includes server, 'add_header Access-Control-Allow-Origin "*";', "server level"
    app_code = NGINX[/location ~\* \\\.\(html\|rb\|m\?js\|css\|json\)\$ \{\n(.*?)\n    \}/m, 1] or flunk "no app-code location"
    assert_includes app_code, 'add_header Access-Control-Allow-Origin "*";', "its own add_header drops the server's"
  end
end
