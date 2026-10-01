# frozen_string_literal: true

# The optional server (app.rb): cd server && bundle install && bundle exec puma -p 8012
require_relative "app"

# text compressed on the fly; the wasm runtimes come as their .gz copies
use Rack::Deflater, include: %w[text/html text/css text/javascript application/json text/plain
                               text/x-script.ruby image/svg+xml]
run ChunkyServer.freeze.app
