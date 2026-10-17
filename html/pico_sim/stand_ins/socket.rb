# The sockets under PicoRuby's own Net::HTTP (vendor/net-http/), simulated
# (docs/HANDOVER.md §6r). They are nested in Net::HTTP because the vendored
# client finds TCPSocket, SSLSocket and SSLContext lexically there first -
# so CRuby's ::TCPSocket never meets them in the check harness.
#
# A socket collects what the client writes; its first read hands the
# request to PicoSim.host.http (the worker's sync XHR, or a canned answer)
# and replays a raw HTTP/1.1 response: the status line, the headers and the
# body with a Content-Length - or, for hosts that answer a Pico in chunks
# (CHUNKED_HOSTS, from what the research saw), re-chunked into 100..200
# byte pieces with Transfer-Encoding: chunked, which 4.0.3's client hands
# on undecoded. Without a Wi-Fi link there is no socket ("no network").

module Net
  class HTTP
    CHUNKED_HOSTS = ["api.open-meteo.com", "api.coingecko.com"]
    REASONS = { 200 => "OK", 201 => "Created", 204 => "No Content", 301 => "Moved Permanently",
                302 => "Found", 304 => "Not Modified", 400 => "Bad Request", 401 => "Unauthorized",
                403 => "Forbidden", 404 => "Not Found", 429 => "Too Many Requests",
                500 => "Internal Server Error", 503 => "Service Unavailable" }

    class SSLContext
      VERIFY_NONE = 0
      VERIFY_PEER = 1
      attr_accessor :verify_mode, :ca_file

      def initialize
        @verify_mode = VERIFY_PEER
      end
    end

    class TCPSocket
      def initialize(host, port, ssl = false)
        unless CYW43.link_up__
          raise IOError.new("no network")
        end
        @host = host
        @port = port
        @ssl = ssl
        @out = ""
        @in = nil
        @pos = 0
        @closed = false
      end

      def write(data)
        @out << data.to_s
        data.to_s.bytesize
      end

      def readpartial(n)
        fetch__ if @in.nil?
        raise EOFError.new("end of file reached") if @pos >= @in.bytesize
        chunk = @in.byteslice(@pos, n)
        @pos += chunk.bytesize
        chunk
      end

      def read(n = nil)
        fetch__ if @in.nil?
        if n.nil?
          rest = @in.byteslice(@pos, @in.bytesize - @pos) || ""
          @pos = @in.bytesize
          return rest
        end
        return nil if @pos >= @in.bytesize
        chunk = @in.byteslice(@pos, n)
        @pos += chunk.bytesize
        chunk
      end

      def close
        @closed = true
        nil
      end

      def closed? = @closed

      # the request line, the headers and the body the client wrote
      def fetch__
        head_end = @out.index("\r\n\r\n") || @out.bytesize
        lines = @out[0, head_end].split("\r\n")
        method, path = lines[0].to_s.split(" ")
        headers = {}
        (lines[1..-1] || []).each do |line|
          colon = line.index(":")
          headers[line[0, colon].downcase] = line[(colon + 1)..-1].strip if colon
        end
        body = @out[(head_end + 4)..-1] || ""
        default = @ssl ? 443 : 80
        host = @port == default ? @host : "#{@host}:#{@port}"
        url = "#{@ssl ? 'https' : 'http'}://#{host}#{path}"
        answer = PicoSim.host.http(method.to_s, url, JSON.generate(headers), body).to_s
        status, head, text = HTTP.split_answer__(answer)
        canned = head["x-chunky-canned"] == "1"
        PicoSim.world.http_log({ "m" => method.to_s, "url" => url, "status" => status, "canned" => canned,
                                 "body" => PicoSim.utf8(text.byteslice(0, PicoSim::HTTP_BODY_CAP) || "") })
        PicoSim.world.event("log", "#{method} #{url} #{status}#{canned ? ' (canned)' : ''}")
        raise IOError.new("no answer from #{@host}") if status == 0
        @in = PicoSim.binary(HTTP.raw_response__(status, head, text, HTTP::CHUNKED_HOSTS.include?(@host)))
      end
    end

    class SSLSocket < TCPSocket
      def self.open(host, port, ctx = nil)
        new(host, port, true)
      end
    end

    # "status\nname: value\n...\n\nbody" (picoruby_worker.js's http)
    def self.split_answer__(answer)
      first = answer.index("\n") || answer.size
      status = answer[0, first].to_i
      rest = answer[(first + 1)..-1] || ""
      blank = rest.index("\n\n")
      head_text = blank ? rest[0, blank] : rest
      body = blank ? (rest[(blank + 2)..-1] || "") : ""
      head = {}
      head_text.split("\n").each do |line|
        colon = line.index(":")
        head[line[0, colon].strip.downcase] = line[(colon + 1)..-1].strip if colon
      end
      [status, head, body]
    end

    def self.raw_response__(status, head, body, chunked)
      out = "HTTP/1.1 #{status} #{REASONS[status] || 'Status'}\r\n"
      head.each do |name, value|
        next if name == "content-length" || name == "transfer-encoding" || name == "content-encoding" ||
                name == "connection" || name == "x-chunky-canned"
        out << "#{name}: #{value}\r\n"
      end
      out << "connection: close\r\n"
      if chunked
        out << "transfer-encoding: chunked\r\n\r\n"
        rng = PicoSim::Rng.new(7)
        pos = 0
        while pos < body.bytesize
          size = 100 + rng.int(101)
          piece = body.byteslice(pos, size)
          out << "#{piece.bytesize.to_s(16)}\r\n" << piece << "\r\n"
          pos += piece.bytesize
        end
        out << "0\r\n\r\n"
      else
        out << "content-length: #{body.bytesize}\r\n\r\n" << body
      end
      out
    end
  end
end
