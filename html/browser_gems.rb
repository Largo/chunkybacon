# BrowserGems: runtime installation of pure-Ruby gems for ruby.wasm,
# in the spirit of irb.wasm and Evil Martians' Ruby Next playground.
# A .gem file is a tar archive (metadata.gz + data.tar.gz); we fetch it,
# unpack it in Ruby (Zlib + a minimal tar reader) and write its lib/ to the
# wasm filesystem (writable memory) on $LOAD_PATH, so `require`,
# require_relative, autoload, __dir__ and Dir globs all behave as on disk.
# Native (C extension) gems cannot work at runtime - they would have to be
# compiled into the wasm binary itself (the TutorialKit.rb approach). The
# one big exception is nokogiri: the cache holds nokogiri-pure (Nokogiri
# with its C extension, libxml2, libxslt and gumbo ported to Ruby), built
# under the name "nokogiri" so every gem depending on nokogiri gets it.
#
# Environment-agnostic: the host injects fetch_binary/fetch_text lambdas
# (sync XHR in the browser, File.read in the offline test harness).
require 'json'
require 'zlib'

module BrowserGems
  class NativeGemError < StandardError; end
  class NotFoundError < StandardError; end

  # gems whose C extension is optional acceleration with a pure-Ruby
  # fallback in lib/ - safe to install despite having an extconf.rb
  PURE_FALLBACK_GEMS = %w[racc].freeze

  # well-known native gems: fail fast with a clear error before downloading -
  # unless builtin? finds them (compiled in, or a shim: main.rb serves
  # numo/narray in pure Ruby, so Rumale's gems install)
  NATIVE_GEMS = %w[
    sqlite3 pg mysql2 ffi byebug debug bcrypt puma eventmachine
    nio4r websocket-driver msgpack oj yajl-ruby curb typhoeus redcarpet
    commonmarker sassc grpc google-protobuf rmagick vips json-c openssl
    strscan js numo-narray numo-narray-alt
  ].freeze

  # native runtime dependencies a gem declares but can do without: skipped
  # when installing that gem, because it falls back to pure Ruby. ruby_pptx
  # uses Nokogiri when it loads and REXML otherwise; jsg needs ruby_wasm (the
  # build tool) only for its `jsg` command, not in the browser.
  OPTIONAL_NATIVE_DEPS = { "ruby_pptx" => %w[nokogiri], "jsg" => %w[ruby_wasm] }.freeze

  # gems replaced by a pure-Ruby stand-in providing the same require: a
  # dependency on bigdecimal (C extension, absent from the wasm image)
  # installs bigdecimal-pure, whose lib/bigdecimal.rb is BigDecimal on
  # Rational
  SUBSTITUTES = { "bigdecimal" => "bigdecimal-pure" }.freeze

  # installed gems live here, one <name>-<version>/lib per gem
  ROOT = "/browser_gems"

  # Minimal stand-ins for stdlib that is missing in ruby.wasm (WASI has no
  # network sockets). Enough for gems like ipaddr/sinatra to LOAD; anything
  # actually touching the network raises a clear error.
  SHIMS = {
    "socket.rb" => <<~'RUBY',
      class SocketError < StandardError; end unless defined?(SocketError)
      class BasicSocket; end unless defined?(BasicSocket)
      class Socket < BasicSocket
        AF_UNSPEC = 0
        AF_INET = 2
        AF_INET6 = 10
        PF_UNSPEC = 0
        PF_INET = 2
        PF_INET6 = 10
        SOCK_STREAM = 1
        SOCK_DGRAM = 2
        def self.gethostname = "localhost"
        def self.method_missing(name, *_args)
          raise NotImplementedError, "Socket.#{name} is unavailable in the browser (no sockets in WASI)"
        end
        def self.respond_to_missing?(_name, _priv = false) = true
      end
      class IPSocket < BasicSocket
        def self.getaddress(_host) = "127.0.0.1"
      end
      class TCPSocket < IPSocket; end
      class UDPSocket < IPSocket; end
    RUBY
    # Minimal Net::HTTP with the familiar stdlib API, backed by a pluggable
    # transport (the browser wires it to synchronous XHR). The REAL net/http
    # must keep failing its builtin require (io/wait is absent in this wasm
    # build) so this shim wins - do NOT shim io/wait.
    "net/http.rb" => <<~'RUBY',
      require 'uri'
      class SocketError < StandardError; end unless defined?(SocketError)
      require 'timeout'
      module Net
        class HTTPError < StandardError; end unless defined?(Net::HTTPError)
        # the exception classes of net/protocol, which gems name in rescues
        class ProtocolError < StandardError; end unless defined?(Net::ProtocolError)
        class OpenTimeout < Timeout::Error; end unless defined?(Net::OpenTimeout)
        class ReadTimeout < Timeout::Error; end unless defined?(Net::ReadTimeout)
        class WriteTimeout < Timeout::Error; end unless defined?(Net::WriteTimeout)
        class HTTPBadResponse < StandardError; end unless defined?(Net::HTTPBadResponse)
        class HTTPHeaderSyntaxError < StandardError; end unless defined?(Net::HTTPHeaderSyntaxError)

        class HTTPResponse
          MESSAGES = { 200 => "OK", 201 => "Created", 204 => "No Content",
                       301 => "Moved Permanently", 302 => "Found",
                       304 => "Not Modified", 400 => "Bad Request",
                       403 => "Forbidden", 404 => "Not Found",
                       429 => "Too Many Requests",
                       500 => "Internal Server Error" }.freeze

          attr_reader :code, :message, :body, :uri

          def initialize(status, body, headers, uri)
            @code = status.to_s
            @message = MESSAGES[status] || ""
            @body = body
            @headers = headers || {}
            @uri = uri
          end

          def [](key)
            @headers[key.to_s.downcase]
          end

          def content_type
            self["content-type"].to_s.split(";").first
          end

          def read_body
            yield @body if block_given?
            @body
          end

          def each_header(&block) = @headers.each(&block)
          alias each each_header

          def to_hash
            @headers.transform_values { |v| [v] }
          end

          def value
            return nil if is_a?(HTTPSuccess)
            raise HTTPError, "#{@code} #{@message}"
          end
        end

        class HTTPSuccess < HTTPResponse; end
        class HTTPRedirection < HTTPResponse; end
        class HTTPClientError < HTTPResponse; end
        class HTTPServerError < HTTPResponse; end

        class HTTP
          class << self
            attr_accessor :transport

            def get_response(uri, *_rest)
              uri = URI(uri.to_s)
              raise SocketError, "no HTTP transport configured" unless transport
              status, headers, body = transport.call("GET", uri)
              klass = case status
                      when 200..299 then HTTPSuccess
                      when 300..399 then HTTPRedirection
                      when 400..499 then HTTPClientError
                      else HTTPServerError
                      end
              klass.new(status, body, headers, uri)
            end

            def get(uri_or_host, path = nil, _port = nil)
              uri = path ? URI("http://#{uri_or_host}#{path}") : URI(uri_or_host.to_s)
              get_response(uri).body
            end

            def start(host, port = nil, *_rest, **opts, &block)
              http = new(host, port)
              http.use_ssl = opts[:use_ssl] if opts.key?(:use_ssl)
              http.start(&block)
            end
          end

          # the object API (Net::HTTP.new(...).request(Net::HTTP::Get.new(path)))
          # that most HTTP-using gems are written against; GET and HEAD only,
          # like the transport behind it
          attr_reader :address, :port
          attr_accessor :use_ssl, :open_timeout, :read_timeout, :write_timeout,
                        :verify_mode, :ca_file, :cert_store, :keep_alive_timeout
          alias use_ssl? use_ssl

          def initialize(address, port = nil, *_proxy)
            @address = address
            @port = port || 80
            @use_ssl = @port == 443
          end

          def start
            return self unless block_given?
            yield self
          end

          def started? = true
          def finish; end

          def request(req, _body = nil)
            unless %w[GET HEAD].include?(req.method)
              raise NotImplementedError, "#{req.method} requests are unavailable in the browser playground (GET and HEAD only)"
            end
            scheme = use_ssl ? "https" : "http"
            default_port = use_ssl ? 443 : 80
            host = port == default_port ? address : "#{address}:#{port}"
            response = HTTP.get_response(URI("#{scheme}://#{host}#{req.path}"))
            yield response if block_given?
            response
          end

          def get(path, headers = nil, &block)
            request(Get.new(path, headers), &block)
          end

          def head(path, headers = nil)
            request(Head.new(path, headers))
          end

          def post(path, _data = nil, headers = nil) = request(Post.new(path, headers))
          def put(path, _data = nil, headers = nil) = request(Put.new(path, headers))
          def patch(path, _data = nil, headers = nil) = request(Patch.new(path, headers))
          def delete(path, headers = nil) = request(Delete.new(path, headers))

          class Request
            attr_reader :method, :path

            def initialize(path, headers = nil)
              path = path.request_uri if path.respond_to?(:request_uri)
              @path = path.to_s
              @method = self.class::METHOD
              @headers = {}
              (headers || {}).each { |k, v| self[k] = v }
            end

            def [](key) = @headers[key.to_s.downcase]
            def []=(key, value)
              @headers[key.to_s.downcase] = value
            end
            def each_header(&block) = @headers.each(&block)
            def basic_auth(*); end
            def body=(_body); end
          end

          class Get < Request; METHOD = "GET"; end
          class Head < Request; METHOD = "HEAD"; end
          class Post < Request; METHOD = "POST"; end
          class Put < Request; METHOD = "PUT"; end
          class Patch < Request; METHOD = "PATCH"; end
          class Delete < Request; METHOD = "DELETE"; end
          class Options < Request; METHOD = "OPTIONS"; end
        end
      end
    RUBY
    "net/https.rb" => "require 'net/http'\n",
    # stdlib resolv needs io/wait; there is no DNS in the browser anyway.
    # Enough for gems that load it up front (ssrf_filter, so premailer).
    "resolv.rb" => <<~'RUBY'
      class Resolv
        class ResolvError < StandardError; end
        class ResolvTimeout < ResolvError; end

        def self.getaddress(name)
          raise ResolvError, "no DNS for #{name} in the browser (WASI has no sockets)"
        end

        def self.getaddresses(_name) = []
        def self.each_address(_name) = nil

        def self.getname(address)
          raise ResolvError, "no DNS for #{address} in the browser (WASI has no sockets)"
        end

        class DNS
          def self.open(*) = yield(new)
          def getresources(*) = []
          def getaddresses(*) = []
          def close; end
        end
      end
    RUBY
  }.freeze

  # Source appended to specific gem files after install - for small
  # browser-compat fixes that keep the taught API untouched.
  POST_INSTALL_PATCHES = {
    # Lacci looks for the CHANGELOG.md of a git checkout to report its build,
    # and prints a line when it cannot find one. A gem install never has that
    # file, and in the notebook the line lands in the lesson's output, so the
    # lookup is short-circuited to the same "no release" answer it would
    # otherwise reach - quietly.
    "lacci" => {
      "lib/shoes/changelog.rb" => <<~'RUBY'
        class Shoes
          class Changelog
            def get_latest_release_info
              { RELEASE_NAME: nil, RELEASE_BUILD_DATE: nil, RELEASE_ID: nil, REVISION: nil }
            end
          end
        end
      RUBY
    }
  }.freeze

  class << self
    attr_accessor :fetch_binary, :fetch_text, :cache_base, :proxy_base
    # the offline harnesses point this at a temp dir, so gems are not
    # written to the real filesystem root; set it before installing anything
    attr_writer :root

    def root
      @root || ROOT
    end

    def installed
      @installed ||= {}
    end

    # the shims: the only code still evaluated from memory, as a fallback
    # for stdlib that fails to load
    def files
      @files ||= { "(shims)" => SHIMS.dup }
    end

    def loaded
      @loaded ||= {}
    end

    def manifest
      @manifest ||= begin
        text = fetch_text.call("#{cache_base}/manifest.json")
        text ? JSON.parse(text) : {}
      rescue StandardError
        {}
      end
    end

    # Installs a gem (latest version) plus its runtime dependencies.
    # Sources: the local cache first, then rubygems.org via the proxy.
    # Returns the installed version string. A NativeGemError names the gem
    # that actually has C code, which may be a dependency.
    def install(name, seen = {})
      name = name.to_s.strip
      return installed[name] if installed[name]
      if (substitute = SUBSTITUTES[name])
        return installed[name] = install(substitute, seen)
      end
      if NATIVE_GEMS.include?(name)
        return installed[name] = "builtin" if builtin?(name)
        raise NativeGemError, name
      end
      return if seen[name]
      seen[name] = true

      if (entry = manifest[name])
        runtime_deps(name, entry["deps"] || []).each { |dep| install(dep, seen) }
        bytes = fetch_binary.call("#{cache_base}/#{entry["file"]}")
        raise NotFoundError, name unless bytes
        install_from_bytes(name, entry["version"], bytes)
      else
        info_text = fetch_text.call("#{proxy_base}/api/v1/gems/#{name}.json")
        raise NotFoundError, name unless info_text
        info = JSON.parse(info_text)
        version = info["version"]
        deps = (info.dig("dependencies", "runtime") || []).map { |d| d["name"] }
        runtime_deps(name, deps).each { |dep| install(dep, seen) }
        bytes = fetch_binary.call("#{proxy_base}/gems/#{name}-#{version}.gem")
        raise NotFoundError, name unless bytes
        install_from_bytes(name, version, bytes)
      end
    end

    def install_from_bytes(name, version, gem_bytes)
      outer = untar(gem_bytes)
      data = outer["data.tar.gz"] or raise NotFoundError, "#{name} (bad .gem file)"
      inner = untar(Zlib.gunzip(data))
      if !PURE_FALLBACK_GEMS.include?(name) && inner.keys.any? { |k| k.end_with?("extconf.rb") }
        return installed[name] = "builtin" if builtin?(name)
        raise NativeGemError, name
      end

      # the whole gem, not just lib/: some read data next to it
      # (unicode-display_width's data/)
      patches = POST_INSTALL_PATCHES[name] || {}
      gem_dir = File.join(root, "#{name}-#{version}")
      require 'fileutils'
      inner.each do |path, content|
        content = content + patches[path] if patches[path]
        target = File.join(gem_dir, path)
        FileUtils.mkdir_p(File.dirname(target))
        File.binwrite(target, content)
      end
      require_paths(outer["metadata.gz"]).reverse_each do |dir|
        lib_dir = File.join(gem_dir, dir)
        $LOAD_PATH.unshift(lib_dir) unless $LOAD_PATH.include?(lib_dir)
      end
      installed[name] = version
    end

    # A gem's load paths from its gemspec - "lib" for most, but not all
    # (concurrent-ruby's is lib/concurrent-ruby). Read from the YAML text
    # directly: loading it would need Gem::Specification.
    def require_paths(metadata_gz)
      yaml = metadata_gz ? Zlib.gunzip(metadata_gz) : ""
      block = yaml[/^require_paths:\n((?:- .*\n)+)/, 1].to_s
      paths = block.lines.map { |l| l.sub(/\A- /, "").strip.delete_prefix('"').delete_suffix('"') }
      paths.empty? ? ["lib"] : paths
    end

    # Default gems compiled into the wasm image (json, date, ...) have C
    # code too, yet need no install: a gem depending on one is satisfied by
    # the built-in copy, as it would be by a default gem on disk.
    def builtin?(name)
      require name.tr("-", "/")
      true
    rescue LoadError
      false
    end

    def runtime_deps(name, deps)
      deps - OPTIONAL_NATIVE_DEPS.fetch(name, [])
    end

    # Minimal POSIX tar reader: returns { path => content } for regular files.
    def untar(data)
      result = {}
      pos = 0
      while pos + 512 <= data.bytesize
        header = data.byteslice(pos, 512)
        name = header.byteslice(0, 100).delete("\0").strip
        break if name.empty?
        size = header.byteslice(124, 12).delete("\0").strip.to_i(8)
        prefix = header.byteslice(345, 155).delete("\0").strip
        name = "#{prefix}/#{name}" unless prefix.empty?
        typeflag = header.byteslice(156, 1)
        result[name] = data.byteslice(pos + 512, size) if typeflag == "0" || typeflag == "\0"
        pos += 512 + ((size + 511) / 512) * 512
      end
      result
    end

    # If a required feature belongs to a cached-but-uninstalled gem,
    # install it transparently (used for stdlib that became bundled gems -
    # csv, benchmark - which real Ruby installs ship out of the box).
    def auto_install_feature(feature)
      name = feature.split("/").first
      return nil if installed.key?(name) || !manifest.key?(SUBSTITUTES.fetch(name, name))
      install(name)
      require feature
      true
    rescue StandardError, LoadError
      nil
    end

    # Loads a shim ("net/http"). Returns true when found, nil otherwise.
    def load_feature(path)
      key = path.sub(/\.rb\z/, "") + ".rb"
      files.each do |gem_name, lib|
        next unless lib.key?(key)
        full = "#{gem_name}:#{key}"
        return true if loaded[full]
        loaded[full] = true
        Kernel.eval(lib[key], TOPLEVEL_BINDING, "#{root}/#{gem_name}/#{key}")
        return true
      end
      nil
    end
  end
end

module Kernel
  alias_method :bg_original_require, :require
  def require(path)
    bg_original_require(path)
  rescue LoadError => e
    feature = path.to_s
    BrowserGems.load_feature(feature) or BrowserGems.auto_install_feature(feature) or raise e
  end
end
