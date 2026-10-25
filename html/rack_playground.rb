# RackPlayground: run Rack apps (Sinatra, Roda, plain #call objects)
# without any server by synthesizing a Rack env - this is what powers the
# mini browser widget and the route checks in the web lessons.
require 'stringio'
require 'uri'

module RackPlayground
  # A Rack env for one request. GET by default; a form's POST brings a
  # urlencoded body (rack.input) and its content type; the mini browser
  # sends the cookies its app set (a Rails session, the flash).
  def self.env_for(path, method: "GET", body: nil, content_type: nil, cookie: nil)
    path = "/" + path.to_s.sub(%r{\Ahttps?://[^/]*}, "").sub(%r{\A/+}, "")
    path, query = path.split("?", 2)
    input = (body || "").to_s.b
    env = {
      "REQUEST_METHOD" => method.to_s.upcase,
      "SCRIPT_NAME" => "",
      "PATH_INFO" => path,
      "QUERY_STRING" => query.to_s,
      "SERVER_NAME" => "localhost",
      "SERVER_PORT" => "80",
      "HTTP_HOST" => "localhost",
      "REMOTE_ADDR" => "127.0.0.1",
      "SERVER_PROTOCOL" => "HTTP/1.1",
      "rack.url_scheme" => "http",
      "rack.input" => StringIO.new(input),
      "rack.errors" => StringIO.new
    }
    env["CONTENT_LENGTH"] = input.bytesize.to_s unless input.empty?
    env["CONTENT_TYPE"] = content_type if content_type
    env["HTTP_COOKIE"] = cookie if cookie && !cookie.empty?
    env
  end

  # One request against the app; returns [status, headers_hash, body_string].
  def self.request(app, path, **options)
    status, headers, body = app.call(env_for(path, **options))
    chunks = []
    body.each { |chunk| chunks << chunk.to_s }
    body.close if body.respond_to?(:close)
    headers = headers.to_h if headers.respond_to?(:to_h)
    [status.to_i, headers, chunks.join]
  end

  # Performs a GET against the app; returns [status, headers_hash, body_string].
  def self.get(app, path) = request(app, path)

  # A form's POST: +params+ a Hash ({ "dish[name]" => "Tea" }) or the
  # urlencoded body as a String.
  def self.post(app, path, params = {})
    body = params.is_a?(String) ? params : URI.encode_www_form(params)
    request(app, path, method: "POST", body: body, content_type: "application/x-www-form-urlencoded")
  end
end

module Kernel
  # Simple GET against a Rack app, for experiments and exercise checks:
  #   status, body = mock_get(MyApp, "/hello")
  def mock_get(app, path)
    status, _headers, body = RackPlayground.get(app, path)
    [status, body]
  end

  # A form's POST against a Rack app, for checks of the web lessons:
  #   status, body, location = mock_post(MyApp, "/dishes", "dish[name]" => "Tea")
  # location is where a redirect sends the browser next (nil otherwise).
  def mock_post(app, path, params = {})
    status, headers, body = RackPlayground.post(app, path, params)
    [status, body, headers["location"] || headers["Location"]]
  end
end
