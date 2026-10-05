# The site (html/ of this worktree) with the matplotlib experiment laid over
# it, without changing a file in html/:
#
#   PORT=18101 ruby experiments/01-matplotlib-charts/serve.rb
#
#   /pycall.rb                    -> this folder's pycall.rb (the bridge + matplotlib)
#   /assets/pyodide/pyodide-lock.json, the new wheels
#                                 -> vendor/ (vendor_matplotlib.rb --fetch)
#   /lessons.js                   -> html/lessons.js + lesson_matplotlib.json after "numpy"
#   /assets/app.css               -> html/assets/app.css + plot.css
#
# Static files only (no rubygems bridge): enough for the PyCall lessons.
require "webrick"
require "json"
require "zlib"

HERE = __dir__
ROOT = File.expand_path("../../html", HERE)
VENDOR = File.join(HERE, "vendor")
PORT = Integer(ENV.fetch("PORT", "18101"))

MIME = WEBrick::HTTPUtils::DefaultMimeTypes.merge(
  "wasm" => "application/wasm", "js" => "text/javascript", "mjs" => "text/javascript",
  "rb" => "text/plain; charset=utf-8", "json" => "application/json", "whl" => "application/zip",
  "gem" => "application/octet-stream", "woff2" => "font/woff2", "svg" => "image/svg+xml"
)

def lessons_js
  source = File.read(File.join(ROOT, "lessons.js"))
  head, body = source.split("window.LESSONS_JSON = JSON.stringify(", 2)
  data = JSON.parse(body.sub(/\);\s*\z/, ""))
  lesson = JSON.parse(File.read(File.join(HERE, "lesson_matplotlib.json")))
  at = data["lessons"].index { |l| l["id"] == "numpy" }
  data["lessons"].insert(at + 1, lesson)
  "#{head}window.LESSONS_JSON = JSON.stringify(#{JSON.pretty_generate(data)});\n"
end

OVERRIDES = {
  "/pycall.rb" => -> { File.read(File.join(HERE, "pycall.rb")) },
  "/lessons.js" => -> { lessons_js },
  "/assets/app.css" => -> { File.read(File.join(ROOT, "assets/app.css")) + "\n" + File.read(File.join(HERE, "plot.css")) },
  "/assets/pyodide/pyodide-lock.json" => -> { File.read(File.join(VENDOR, "pyodide-lock.json")) }
}.freeze

class SiteHandler < WEBrick::HTTPServlet::FileHandler
  GZIP = /\.(html|rb|js|mjs|css|json|svg|wasm)\z/i

  def do_GET(req, res)
    res["Cache-Control"] = "no-cache"
    if (override = OVERRIDES[req.path])
      res.status = 200
      res["Content-Type"] = MIME.fetch(File.extname(req.path).delete_prefix("."), "application/octet-stream")
      res.body = override.call
    elsif req.path.start_with?("/assets/pyodide/") && File.file?(vendored = File.join(VENDOR, File.basename(req.path)))
      res.status = 200
      res["Content-Type"] = MIME["whl"]
      res.body = File.binread(vendored)
    else
      super
    end
    gzip(req, res) if res.status == 200 && req.path.match?(GZIP) && req["Accept-Encoding"].to_s.include?("gzip")
  end

  # as tools/dev_server.rb: the .gz next to the file (gzip_static), or on the fly
  def gzip(req, res)
    file = File.expand_path(File.join(ROOT, req.path))
    plain = res.body.respond_to?(:read) ? res.body.read : res.body.to_s
    res.body.close if res.body.respond_to?(:close)
    packed = !OVERRIDES.key?(req.path) && File.file?("#{file}.gz") && File.mtime("#{file}.gz") >= File.mtime(file)
    res.body = packed ? File.binread("#{file}.gz") : Zlib.gzip(plain, level: 6)
    res["Content-Encoding"] = "gzip"
    res["Content-Length"] = res.body.bytesize.to_s
    res["Vary"] = "Accept-Encoding"
  end
end

server = WEBrick::HTTPServer.new(BindAddress: "127.0.0.1", Port: PORT, DocumentRoot: ROOT, MimeTypes: MIME,
                                 AccessLog: [[$stdout, "%h \"%r\" %s %b"]])
server.mount("/", SiteHandler, ROOT)
trap("INT") { server.shutdown }
trap("TERM") { server.shutdown }
$stdout.sync = true
puts "matplotlib experiment: http://127.0.0.1:#{PORT}/ (#{ROOT} + #{HERE})"
server.start
