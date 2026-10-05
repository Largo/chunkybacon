# Serves the course (html/) as if the turtle were integrated - without
# touching html/: four files are changed in memory on their way out.
#   /main.rb         + require_relative "turtle" (after autorun)
#   /turtle.rb       this folder's turtle.rb
#   /lessons.js      + lesson_turtle.json after "methoden" (titles not renumbered)
#   /assets/app.css  + the proposed rule for SVG pictures
# and this folder itself under /turtle/ (preview.html, examples/).
#   PORT=18106 ruby experiments/06-turtle-graphics/serve.rb
require "webrick"
require "json"

HERE = __dir__
SITE = File.expand_path("../../html", HERE)
CSS_RULE = <<~CSS

  /* turtle graphics: an SVG picture keeps its own size and stays sharp */
  .cell-image[src^="data:image/svg+xml"] { width: auto; image-rendering: auto; }
CSS

def main_rb
  File.read(File.join(SITE, "main.rb"))
      .sub(%(require_relative "autorun"\n), %(require_relative "autorun"\nrequire_relative "turtle"\n))
end

def lessons_js
  src = File.read(File.join(SITE, "lessons.js"))
  head, body = src.split("window.LESSONS_JSON = JSON.stringify(", 2)
  data = JSON.parse(body.sub(/\);\s*\z/, ""))
  at = data["lessons"].index { |l| l["id"] == "methoden" } + 1
  data["lessons"].insert(at, JSON.parse(File.read(File.join(HERE, "lesson_turtle.json"))))
  "#{head}window.LESSONS_JSON = JSON.stringify(#{JSON.pretty_generate(data)});\n"
end

OVERRIDES = {
  "/main.rb" => ["text/plain; charset=utf-8", -> { main_rb }],
  "/turtle.rb" => ["text/plain; charset=utf-8", -> { File.read(File.join(HERE, "turtle.rb")) }],
  "/lessons.js" => ["text/javascript", -> { lessons_js }],
  "/assets/app.css" => ["text/css", -> { File.read(File.join(SITE, "assets/app.css")) + CSS_RULE }]
}.freeze

WEBrick::HTTPUtils::DefaultMimeTypes.merge!("wasm" => "application/wasm", "js" => "text/javascript",
                                            "rb" => "text/plain; charset=utf-8", "svg" => "image/svg+xml",
                                            "json" => "application/json", "woff2" => "font/woff2")
server = WEBrick::HTTPServer.new(BindAddress: "127.0.0.1", Port: Integer(ENV.fetch("PORT", "18106")),
                                 AccessLog: [], Logger: WEBrick::Log.new($stderr, WEBrick::Log::WARN))
OVERRIDES.each do |path, (type, body)|
  server.mount_proc(path) do |_req, res|
    res["Content-Type"] = type
    res["Cache-Control"] = "no-cache"
    res.body = body.call
  end
end
server.mount("/turtle", WEBrick::HTTPServlet::FileHandler, HERE)
server.mount("/", WEBrick::HTTPServlet::FileHandler, SITE)
trap("INT") { server.shutdown }
server.start
