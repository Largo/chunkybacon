# Serves this experiment's folder (preview.html) on 127.0.0.1:18104.
#   ruby experiments/04-friendly-errors/tools/serve_preview.rb
require "webrick"

server = WEBrick::HTTPServer.new(BindAddress: "127.0.0.1", Port: 18104,
                                 DocumentRoot: File.expand_path("..", __dir__))
trap("INT") { server.shutdown }
server.start
