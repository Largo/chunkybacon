# Dev server for the embed prototype: html/ with site/ laid over it, so
# embed.html, embed.js & co. sit next to main.rb and ruby+stdlib.wasm as
# they would after integration. Gzips like tools/dev_server.rb (nginx).
#
#   PORT=18109 ruby experiments/09-embed-cell/serve_embed.rb
#
# What it adds for the embed (and what production would need, NOTES.md):
#   - embed.html gets  Content-Security-Policy: sandbox allow-scripts ...
#     - the page runs in an opaque origin, whoever opens it (an iframe with or
#     without a sandbox attribute, a plain link). ?nosandbox turns it off,
#     for comparison; ?csp=strict adds a fetch/connect policy on top.
#   - every file gets Access-Control-Allow-Origin: * - an opaque origin's
#     fetches (ruby+stdlib.wasm, main.rb, the gem cache) are cross-origin.
# No rubygems/ruby-lang bridges: gems come from html/gems/cache only.
require "webrick"
require "zlib"
require "time"

HERE = __dir__
LAYERS = [File.join(HERE, "site"), File.expand_path("../../html", HERE)].freeze
PORT = Integer(ENV.fetch("PORT", "18109"))

MIME = {
  "html" => "text/html; charset=utf-8", "js" => "text/javascript; charset=utf-8",
  "mjs" => "text/javascript", "css" => "text/css; charset=utf-8", "rb" => "text/plain; charset=utf-8",
  "json" => "application/json", "wasm" => "application/wasm", "svg" => "image/svg+xml",
  "woff2" => "font/woff2", "png" => "image/png", "gem" => "application/octet-stream",
  "txt" => "text/plain; charset=utf-8", "csv" => "text/plain; charset=utf-8"
}.freeze
NO_CACHE = /\.(html|rb|js|css|json)\z/i
GZIP = /\.(html|rb|js|css|json|svg|wasm)\z/i

SANDBOX = "sandbox allow-scripts allow-popups allow-popups-to-escape-sandbox allow-downloads"
STRICT = "default-src 'self'; script-src 'self' 'wasm-unsafe-eval' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; " \
         "img-src 'self' data: blob:; font-src 'self'; connect-src 'self'; frame-src blob:; " \
         "form-action 'none'; base-uri 'none'"

class EmbedSite < WEBrick::HTTPServlet::AbstractServlet
  def do_GET(req, res)
    path = req.path == "/" ? "/demo/host.html" : req.path
    file = find(path)
    return not_found(res) unless file

    ext = File.extname(file).delete(".").downcase
    res["Content-Type"] = MIME.fetch(ext, "application/octet-stream")
    res["Access-Control-Allow-Origin"] = "*"
    res["Timing-Allow-Origin"] = "*"   # transfer sizes for the measurements
    res["Cache-Control"] = file.match?(NO_CACHE) ? "no-cache" : "max-age=3600"
    # validators, as nginx sends them: a revalidation is a 304
    mtime = File.mtime(file).httpdate
    res["Last-Modified"] = mtime
    if req["If-Modified-Since"] == mtime && !file.end_with?("embed.html")
      res.status = 304
      return
    end
    if File.basename(file) == "embed.html" && !req.query_string.to_s.include?("nosandbox")
      policy = [SANDBOX]
      policy << STRICT if req.query_string.to_s.include?("csp=strict")
      res["Content-Security-Policy"] = policy.join("; ")
    end
    body = File.binread(file)
    if file.match?(GZIP) && req["Accept-Encoding"].to_s.include?("gzip")
      packed = "#{file}.gz"
      body = File.file?(packed) && File.mtime(packed) >= File.mtime(file) ? File.binread(packed) : Zlib.gzip(body, level: 6)
      res["Content-Encoding"] = "gzip"
      res["Vary"] = "Accept-Encoding"
    end
    res.body = body
  end
  alias do_HEAD do_GET

  private

  def find(path)
    clean = path.split("/").reject { |part| part.empty? || part == "." || part == ".." }
    LAYERS.each do |root|
      file = File.join(root, *clean)
      return file if File.file?(file)
    end
    nil
  end

  def not_found(res)
    res.status = 404
    res["Content-Type"] = "text/plain"
    res["Access-Control-Allow-Origin"] = "*"
    res.body = "404"
  end
end

server = WEBrick::HTTPServer.new(BindAddress: "127.0.0.1", Port: PORT,
                                 AccessLog: [[$stdout, "%h \"%r\" %s %b"]])
server.mount("/", EmbedSite)
trap("INT") { server.shutdown }
trap("TERM") { server.shutdown }
$stdout.sync = true
puts "embed prototype: http://127.0.0.1:#{PORT}/demo/host.html"
server.start
