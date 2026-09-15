# RackPlayground: run Rack apps (Sinatra, Roda, plain #call objects)
# without any server by synthesizing a Rack env - this is what powers the
# mini browser widget and the route checks in the web lessons.
require 'stringio'

module RackPlayground
  def self.env_for(path)
    path = "/" + path.to_s.sub(%r{\Ahttps?://[^/]*}, "").sub(%r{\A/+}, "")
    path, query = path.split("?", 2)
    {
      "REQUEST_METHOD" => "GET",
      "SCRIPT_NAME" => "",
      "PATH_INFO" => path,
      "QUERY_STRING" => query.to_s,
      "SERVER_NAME" => "localhost",
      "SERVER_PORT" => "80",
      "HTTP_HOST" => "localhost",
      "SERVER_PROTOCOL" => "HTTP/1.1",
      "rack.url_scheme" => "http",
      "rack.input" => StringIO.new(""),
      "rack.errors" => StringIO.new
    }
  end

  # Performs a GET against the app; returns [status, headers_hash, body_string].
  def self.get(app, path)
    status, headers, body = app.call(env_for(path))
    chunks = []
    body.each { |chunk| chunks << chunk.to_s }
    body.close if body.respond_to?(:close)
    headers = headers.to_h if headers.respond_to?(:to_h)
    [status.to_i, headers, chunks.join]
  end
end

module Kernel
  # Simple GET against a Rack app, for experiments and exercise checks:
  #   status, body = mock_get(MyApp, "/hello")
  def mock_get(app, path)
    status, _headers, body = RackPlayground.get(app, path)
    [status, body]
  end
end
