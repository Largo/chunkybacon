# The real page with show_game, without touching html/: files in site/
# (main.rb, index.html, game.rb, game.js) are served in place of html/'s,
# everything else comes from html/. No gem bridges (the game needs none).
#
#   PORT=18108 ruby experiments/08-game-loop/serve.rb   # http://127.0.0.1:18108/
require "webrick"

HTML = File.expand_path("../../html", __dir__)
SITE = File.expand_path("site", __dir__)
EXP = __dir__   # examples/ for the tests: /examples/snake.rb
PORT = Integer(ENV.fetch("PORT", "18108"))

MIME = WEBrick::HTTPUtils::DefaultMimeTypes.merge(
  "wasm" => "application/wasm", "js" => "text/javascript", "mjs" => "text/javascript",
  "rb" => "text/plain; charset=utf-8", "json" => "application/json",
  "gem" => "application/octet-stream", "woff2" => "font/woff2", "svg" => "image/svg+xml"
)

class Overlay < WEBrick::HTTPServlet::AbstractServlet
  def do_GET(req, res)
    rel = WEBrick::HTTPUtils.unescape(req.path)
    rel += "index.html" if rel.end_with?("/")
    file = [SITE, HTML, EXP].map { |root| File.expand_path(File.join(root, rel)) }
                       .find { |f| [SITE, HTML, EXP].any? { |r| f.start_with?(r) } && File.file?(f) }
    raise WEBrick::HTTPStatus::NotFound unless file

    res["Content-Type"] = WEBrick::HTTPUtils.mime_type(file, MIME)
    res["Cache-Control"] = "no-cache"
    res.body = File.binread(file)
  end
  alias do_HEAD do_GET
end

server = WEBrick::HTTPServer.new(BindAddress: "127.0.0.1", Port: PORT, AccessLog: [],
                                 Logger: WEBrick::Log.new($stderr, WEBrick::Log::WARN))
server.mount("/", Overlay)
trap("INT") { server.shutdown }
puts "show_game prototype on http://127.0.0.1:#{PORT}/"
server.start
