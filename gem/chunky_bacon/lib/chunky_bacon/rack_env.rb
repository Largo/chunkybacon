# frozen_string_literal: true

require "stringio"

module ChunkyBacon
  # Rack environments without a Rack server - what mock_get hands an app,
  # and what ChunkyBacon::Server builds from a real HTTP request. Mirrors the
  # course page's RackPlayground (html/rack_playground.rb), so an app answers
  # here as it does in the lesson.
  module RackEnv
    # "speisekarte", "/a?b=1", "http://localhost/x" -> "/speisekarte" etc.
    def self.normalize(path)
      "/" + path.to_s.sub(%r{\Ahttps?://[^/]*}, "").sub(%r{\A/+}, "")
    end

    def self.for(path, method: "GET", headers: {}, body: "", host: "localhost", port: 80)
      path, query = normalize(path).split("?", 2)
      env = {
        "REQUEST_METHOD" => method.to_s.upcase,
        "SCRIPT_NAME" => "",
        "PATH_INFO" => path,
        "QUERY_STRING" => query.to_s,
        "SERVER_NAME" => host,
        "SERVER_PORT" => port.to_s,
        "HTTP_HOST" => port.to_i == 80 ? host : "#{host}:#{port}",
        "SERVER_PROTOCOL" => "HTTP/1.1",
        "rack.url_scheme" => "http",
        "rack.input" => StringIO.new(body.to_s.b),
        "rack.errors" => $stderr
      }
      headers.each do |name, value|
        key = name.to_s.upcase.tr("-", "_")
        case key
        when "CONTENT_TYPE", "CONTENT_LENGTH" then env[key] = value.to_s
        else env["HTTP_#{key}"] = value.to_s
        end
      end
      env
    end

    # Calls the app; returns [status, headers, body as one String].
    def self.call(app, env)
      status, headers, body = app.call(env)
      chunks = []
      body.each { |chunk| chunks << chunk.to_s }
      body.close if body.respond_to?(:close)
      [status.to_i, headers.respond_to?(:to_h) ? headers.to_h : headers, chunks.join]
    end
  end
end
