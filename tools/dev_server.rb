# Local stand-in for the nginx container (docker-compose.yml + nginx.conf)
# on machines without Docker: serves html/ plus the same same-origin bridges
# to rubygems.org and ruby-lang.org.
#
# Same safety properties as nginx.conf: upstream hosts are hardcoded, only
# the path is forwarded, only GET/HEAD, and on rubygems only the two path
# shapes the gem installer uses. Listens on 127.0.0.1 only. No rate limit
# or disk cache - it is a dev server.
#
#   ruby tools/dev_server.rb             # http://127.0.0.1:8011/
#   PORT=18011 ruby tools/dev_server.rb

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

# Static files; the app's own code and data revalidate on every load.
class SiteHandler < WEBrick::HTTPServlet::FileHandler
  NO_CACHE = /(\.(html|rb|js|css|json)|\/)\z/i
  GZIP = /\.(html|rb|js|css|json|svg|wasm)\z/i

  def do_GET(req, res)
    res["Cache-Control"] = "no-cache" if req.path.match?(NO_CACHE)
    super
    gzip(req, res) if res.status == 200 && req.path.match?(GZIP) && req["Accept-Encoding"].to_s.include?("gzip")
  end

  # As nginx.conf: the .gz next to the file when there is one (gzip_static),
  # otherwise compressed on the fly.
  def gzip(req, res)
    file = File.expand_path(File.join(ROOT, req.path))
    plain = res.body.respond_to?(:read) ? res.body.read : res.body.to_s
    res.body.close if res.body.respond_to?(:close)
    packed = file.start_with?(ROOT) && File.file?("#{file}.gz")
    res.body = packed ? File.binread("#{file}.gz") : Zlib.gzip(plain, level: 6)
    res["Content-Encoding"] = "gzip"
    res["Content-Length"] = res.body.bytesize.to_s
    res["Vary"] = "Accept-Encoding"
  end
end

# GET/HEAD bridge to one hardcoded https host. `strip` is removed from the
# front of the request path; the rest is forwarded unchanged.
class Bridge < WEBrick::HTTPServlet::AbstractServlet
  PASS_HEADERS = %w[content-type last-modified etag].freeze

  def initialize(server, host, strip)
    super(server)
    @host = host
    @strip = strip
  end

  def do_GET(req, res)
    path = req.unparsed_uri.delete_prefix(@strip)
    path = "/#{path}" unless path.start_with?("/")
    upstream = Net::HTTP.start(@host, 443, use_ssl: true, open_timeout: 10, read_timeout: 60) do |http|
      klass = req.request_method == "HEAD" ? Net::HTTP::Head : Net::HTTP::Get
      http.request(klass.new(path, "User-Agent" => "chunkybacon-dev"))
    end
    res.status = upstream.code.to_i
    PASS_HEADERS.each { |h| res[h] = upstream[h] if upstream[h] }
    res.body = upstream.body.to_s
  rescue StandardError => e
    res.status = 502
    res["Content-Type"] = "text/plain"
    res.body = "bridge to #{@host} failed: #{e.class}: #{e.message}"
  end

  alias do_HEAD do_GET
end

class Forbidden < WEBrick::HTTPServlet::AbstractServlet
  def service(_req, res)
    res.status = 403
    res["Content-Type"] = "text/plain"
    res.body = "403 Forbidden"
  end
end

server = WEBrick::HTTPServer.new(
  BindAddress: "127.0.0.1",
  Port: PORT,
  DocumentRoot: ROOT,
  MimeTypes: MIME,
  AccessLog: [[$stdout, "%h \"%r\" %s %b"]]
)

server.mount("/", SiteHandler, ROOT)
server.mount("/proxy/ruby-lang", Bridge, "www.ruby-lang.org", "/proxy/ruby-lang")
server.mount("/rubygems", Forbidden)
server.mount("/rubygems/api/v1/gems", Bridge, "rubygems.org", "/rubygems")
server.mount("/rubygems/gems", Bridge, "rubygems.org", "/rubygems")

trap("INT") { server.shutdown }
trap("TERM") { server.shutdown }
puts "chunkybacon dev server: http://127.0.0.1:#{PORT}/ (serving #{ROOT})"
$stdout.sync = true
server.start
