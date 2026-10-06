# Local stand-in for the nginx container (docker-compose.yml + nginx.conf)
# on machines without Docker: serves html/ plus the same same-origin bridges
# to rubygems.org and ruby-lang.org, with the same headers and rules as
# nginx/default.conf, so the browser tests exercise them.
#
# Same safety properties as nginx.conf: upstream hosts are hardcoded, only
# the path is forwarded, only GET/HEAD, on rubygems only the two path
# shapes the gem installer uses, and only for the course's own pages (the
# Referer's host is the host asked). Listens on 127.0.0.1 only. No rate
# limit or disk cache - it is a dev server.
#
#   ruby tools/dev_server.rb             # http://127.0.0.1:8011/
#   PORT=18011 ruby tools/dev_server.rb
#   FRAME_ANCESTORS="http://blog.test:*" ruby tools/dev_server.rb
#       # who may frame embed.html (default as nginx: https://idogawa.com);
#       # test/embed_test.mjs needs its made-up blog.test here

require "webrick"
require "net/http"
require "uri"
require "zlib"

ROOT = File.expand_path("../html", __dir__)
PORT = Integer(ENV.fetch("PORT", "8011"))

MIME = WEBrick::HTTPUtils::DefaultMimeTypes.merge(
  "wasm" => "application/wasm",
  "js"   => "text/javascript",
  "mjs"  => "text/javascript",
  "rb"   => "text/plain; charset=utf-8",
  "json" => "application/json",
  "gem"  => "application/octet-stream",
  "woff2" => "font/woff2",
  "svg"  => "image/svg+xml"
)

# The headers and rules of nginx/default.conf (test/dev_server_test.rb
# checks that the two say the same).
module CourseRules
  # embed.html runs sandboxed, and only https://idogawa.com may frame it
  FRAME_ANCESTORS = ENV.fetch("FRAME_ANCESTORS", "https://idogawa.com")
  EMBED_CSP = "sandbox allow-scripts allow-popups allow-popups-to-escape-sandbox allow-downloads; " \
              "frame-ancestors #{FRAME_ANCESTORS}; default-src 'self'; " \
              "script-src 'self' 'wasm-unsafe-eval' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; " \
              "img-src 'self' data: blob:; media-src 'self' data: blob:; font-src 'self'; " \
              "connect-src 'self'; frame-src blob:; form-action 'none'; base-uri 'none'"

  # $chunky_bridge_ok: "<Referer>|<host asked>" - the Referer's host name
  # must be the host the request was sent to (ports aside)
  BRIDGE_REFERER = %r{^https?://([^/:|]+)(:[0-9]+)?/[^|]*\|\1$}i

  # nginx's $host: the Host header without its port (not WEBrick's
  # req.host, which would believe an X-Forwarded-Host)
  def self.bridge_ok?(req)
    host = req["Host"].to_s.sub(/:[0-9]*\z/, "")
    "#{req['Referer']}|#{host}".match?(BRIDGE_REFERER)
  end
end

# Static files; the app's own code and data revalidate on every load. Every
# file may be read cross-origin (the sandboxed embed's origin is "null");
# embed.html itself comes sandboxed.
class SiteHandler < WEBrick::HTTPServlet::FileHandler
  NO_CACHE = /(\.(html|rb|js|css|json)|\/)\z/i
  GZIP = /\.(html|rb|js|css|json|svg|wasm)\z/i

  def do_GET(req, res)
    res["Cache-Control"] = "no-cache" if req.path.match?(NO_CACHE)
    if req.path == "/embed.html"
      res["Content-Security-Policy"] = CourseRules::EMBED_CSP
    else
      res["Access-Control-Allow-Origin"] = "*"
    end
    super
    gzip(req, res) if res.status == 200 && req.path.match?(GZIP) && req["Accept-Encoding"].to_s.include?("gzip")
  end

  # As nginx.conf: the .gz next to the file when there is one (gzip_static),
  # otherwise compressed on the fly. A .gz older than its file is stale (the
  # file was edited since tools/compress_assets.rb), so it is not used.
  def gzip(req, res)
    file = File.expand_path(File.join(ROOT, req.path))
    plain = res.body.respond_to?(:read) ? res.body.read : res.body.to_s
    res.body.close if res.body.respond_to?(:close)
    packed = file.start_with?(ROOT) && File.file?("#{file}.gz") && File.mtime("#{file}.gz") >= File.mtime(file)
    res.body = packed ? File.binread("#{file}.gz") : Zlib.gzip(plain, level: 6)
    res["Content-Encoding"] = "gzip"
    res["Content-Length"] = res.body.bytesize.to_s
    res["Vary"] = "Accept-Encoding"
  end
end

# GET/HEAD bridge to one hardcoded https host. `strip` is removed from the
# front of the request path; the rest is forwarded unchanged. With `shape`,
# only a request URI matching it is forwarded (WEBrick mounts match by
# prefix, so /rubygems/gems/x.gem/more would otherwise get through). Only
# the course's own pages may use it (CourseRules.bridge_ok?), and no other
# site's page may load its answer (Cross-Origin-Resource-Policy).
class Bridge < WEBrick::HTTPServlet::AbstractServlet
  PASS_HEADERS = %w[content-type last-modified etag].freeze

  def initialize(server, host, strip, shape = nil)
    super(server)
    @host = host
    @strip = strip
    @shape = shape
  end

  def do_GET(req, res)
    res["Cross-Origin-Resource-Policy"] = "same-origin"
    return Forbidden.new(@server).service(req, res) unless CourseRules.bridge_ok?(req)
    return Forbidden.new(@server).service(req, res) if @shape && !req.unparsed_uri.match?(@shape)

    path = req.unparsed_uri.delete_prefix(@strip)
    path = "/#{path}" unless path.start_with?("/")
    upstream = fetch(path, req.request_method == "HEAD")
    res.status = upstream.code.to_i
    PASS_HEADERS.each { |h| res[h] = upstream[h] if upstream[h] }
    res.body = upstream.body.to_s
  rescue StandardError => e
    res.status = 502
    res["Content-Type"] = "text/plain"
    res.body = "bridge to #{@host} failed: #{e.class}: #{e.message}"
  end

  alias do_HEAD do_GET

  private

  def fetch(path, head)
    Net::HTTP.start(@host, 443, use_ssl: true, open_timeout: 10, read_timeout: 60) do |http|
      klass = head ? Net::HTTP::Head : Net::HTTP::Get
      http.request(klass.new(path, "User-Agent" => "chunkybacon-dev"))
    end
  end
end

class Forbidden < WEBrick::HTTPServlet::AbstractServlet
  def service(_req, res)
    res.status = 403
    res["Content-Type"] = "text/plain"
    res.body = "403 Forbidden"
  end
end

# html/ and the bridges on +server+ (test/dev_server_test.rb mounts them on
# its own, with a bridge that does not go out)
def mount_course(server, bridge = Bridge)
  server.mount("/", SiteHandler, ROOT)
  server.mount("/proxy/ruby-lang", bridge, "www.ruby-lang.org", "/proxy/ruby-lang")
  server.mount("/rubygems", Forbidden)
  # the two requests the gem installer makes (browser_gems.rb): a gem's
  # info as JSON, and a .gem file
  server.mount("/rubygems/api/v1/gems", bridge, "rubygems.org", "/rubygems", %r{\A/rubygems/api/v1/gems/[\w.-]+\.json\z})
  server.mount("/rubygems/gems", bridge, "rubygems.org", "/rubygems", %r{\A/rubygems/gems/[\w.-]+\.gem\z})
end

if $PROGRAM_NAME == __FILE__
  server = WEBrick::HTTPServer.new(
    BindAddress: "127.0.0.1",
    Port: PORT,
    DocumentRoot: ROOT,
    MimeTypes: MIME,
    AccessLog: [[$stdout, "%h \"%r\" %s %b"]]
  )
  mount_course(server)

  trap("INT") { server.shutdown }
  trap("TERM") { server.shutdown }
  puts "chunkybacon dev server: http://127.0.0.1:#{PORT}/ (serving #{ROOT}; embed.html framed by #{CourseRules::FRAME_ANCESTORS})"
  $stdout.sync = true
  server.start
end
