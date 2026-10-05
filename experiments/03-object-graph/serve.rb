# A static server for trying show_objects in the real page without touching
# shared files: html/ at /, this folder at /og/. A cell can then load the
# prototype with  require_relative "og/object_graph"  (main.rb's
# require_relative falls back to fetching the file from the page's base URL).
#
#   PORT=18103 ruby experiments/03-object-graph/serve.rb
require "webrick"

ROOT = File.expand_path("../../html", __dir__)
HERE = __dir__
PORT = Integer(ENV.fetch("PORT", "18103"))
MIME = WEBrick::HTTPUtils::DefaultMimeTypes.merge(
  "wasm" => "application/wasm", "js" => "text/javascript", "mjs" => "text/javascript",
  "rb" => "text/plain; charset=utf-8", "json" => "application/json", "svg" => "image/svg+xml",
  "woff2" => "font/woff2"
)

class NoCache < WEBrick::HTTPServlet::FileHandler
  def do_GET(req, res)
    res["Cache-Control"] = "no-cache"
    super
  end
end

server = WEBrick::HTTPServer.new(BindAddress: "127.0.0.1", Port: PORT, DocumentRoot: ROOT,
                                 MimeTypes: MIME, AccessLog: [[$stdout, "%h \"%r\" %s %b"]])
server.mount("/", NoCache, ROOT)
server.mount("/og", NoCache, HERE)
trap("INT") { server.shutdown }
trap("TERM") { server.shutdown }
$stdout.sync = true
puts "show_objects test server: http://127.0.0.1:#{PORT}/ and /og/"
server.start
