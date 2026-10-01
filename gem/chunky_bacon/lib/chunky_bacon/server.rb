# frozen_string_literal: true

require "socket"

module ChunkyBacon
  # The smallest web server that lets a browser click through a Rack app -
  # what show_browser starts on a computer, where the lesson page had its
  # mini browser. One app, 127.0.0.1 only (nothing outside this computer
  # reaches it), one request at a time, no keep-alive. For a real app, use a
  # real server: rackup with puma, falcon, webrick.
  class Server
    REASONS = { 200 => "OK", 201 => "Created", 204 => "No Content", 301 => "Moved Permanently",
                302 => "Found", 303 => "See Other", 304 => "Not Modified", 400 => "Bad Request",
                401 => "Unauthorized", 403 => "Forbidden", 404 => "Not Found",
                405 => "Method Not Allowed", 422 => "Unprocessable Content",
                500 => "Internal Server Error" }.freeze

    attr_reader :app, :port

    # port 0: whichever port is free
    def initialize(app, port: 0)
      @app = app
      @tcp = TCPServer.new("127.0.0.1", port)
      @port = @tcp.addr[1]
    end

    def url(path = "/")
      "http://127.0.0.1:#{port}#{RackEnv.normalize(path)}"
    end

    def start
      @thread = Thread.new do
        loop { handle(@tcp.accept) }
      rescue IOError, Errno::EBADF
        nil # stopped
      end
      self
    end

    def join
      @thread&.join
    end

    def stop
      @tcp.close unless @tcp.closed?
      @thread&.join(1)
      nil
    end

    private

    def handle(socket)
      line = socket.gets
      return if line.nil?

      method, target = line.split(" ", 3)
      headers = {}
      while (header = socket.gets) && !header.strip.empty?
        name, value = header.split(":", 2)
        headers[name.strip.downcase] = value.to_s.strip
      end
      body = headers["content-length"] ? socket.read(headers["content-length"].to_i).to_s : ""
      env = RackEnv.for(target, method: method, headers: headers, body: body, host: "127.0.0.1", port: port)
      status, response_headers, response_body = respond(env)
      write(socket, status, response_headers, response_body)
    rescue IOError, SystemCallError
      nil # the browser went away
    ensure
      socket.close unless socket.closed?
    end

    # The app's answer - an error in the app becomes a 500 page that names
    # it, like the error below a cell.
    def respond(env)
      RackEnv.call(app, env)
    rescue StandardError => e
      warn "#{e.class}: #{e.message}"
      [500, { "content-type" => "text/plain; charset=utf-8" }, "#{e.class}: #{e.message}\n"]
    end

    def write(socket, status, headers, body)
      socket.write("HTTP/1.1 #{status} #{REASONS.fetch(status, "Status")}\r\n")
      headers.each do |name, value|
        next if %w[connection content-length transfer-encoding].include?(name.to_s.downcase)

        Array(value).each { |v| v.to_s.split("\n").each { |part| socket.write("#{name}: #{part}\r\n") } }
      end
      socket.write("content-length: #{body.bytesize}\r\nconnection: close\r\n\r\n")
      socket.write(body)
    end
  end
end
