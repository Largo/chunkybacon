# BrowserGems: runtime installation of pure-Ruby gems for ruby.wasm,
# in the spirit of irb.wasm and Evil Martians' Ruby Next playground.
# A .gem file is a tar archive (metadata.gz + data.tar.gz); we fetch it,
# unpack it in Ruby (Zlib + a minimal tar reader), keep the lib/ files in
# memory and hook Kernel#require so `require "chunky_png"` just works.
# Native (C extension) gems cannot work at runtime - they would have to be
# compiled into the wasm binary itself (the TutorialKit.rb approach).
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

  # well-known native gems: fail fast with a clear error before downloading
  NATIVE_GEMS = %w[
    nokogiri sqlite3 pg mysql2 ffi byebug debug bcrypt puma eventmachine
    nio4r websocket-driver msgpack oj yajl-ruby curb typhoeus redcarpet
    commonmarker sassc grpc google-protobuf rmagick vips json-c openssl
  ].freeze

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
      module Net
        class HTTPError < StandardError; end unless defined?(Net::HTTPError)

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
            @body
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
          end
        end
      end
    RUBY
    "net/https.rb" => "require 'net/http'\n"
  }.freeze

  # Source appended to specific gem files after install - for small
  # browser-compat fixes that keep the taught API untouched. (Currently
  # empty; the builtin-minitest thread fix lives in main.rb instead.)
  POST_INSTALL_PATCHES = {
  }.freeze

  class << self
    attr_accessor :fetch_binary, :fetch_text, :cache_base, :proxy_base

    def installed
      @installed ||= {}
    end

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
    # Returns the installed version string.
    def install(name, seen = {})
      name = name.to_s.strip
      return installed[name] if installed[name]
      raise NativeGemError, name if NATIVE_GEMS.include?(name)
      return if seen[name]
      seen[name] = true

      if (entry = manifest[name])
        (entry["deps"] || []).each { |dep| install(dep, seen) }
        bytes = fetch_binary.call("#{cache_base}/#{entry["file"]}")
        raise NotFoundError, name unless bytes
        install_from_bytes(name, entry["version"], bytes)
      else
        info_text = fetch_text.call("#{proxy_base}/api/v1/gems/#{name}.json")
        raise NotFoundError, name unless info_text
        info = JSON.parse(info_text)
        version = info["version"]
        deps = (info.dig("dependencies", "runtime") || []).map { |d| d["name"] }
        deps.each { |dep| install(dep, seen) }
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
        raise NativeGemError, name
      end

      lib = {}
      inner.each do |path, content|
        lib[path[4..]] = content if path.start_with?("lib/") && path.end_with?(".rb")
      end
      (POST_INSTALL_PATCHES[name] || {}).each do |file, patch|
        lib[file] = lib[file].to_s + patch
      end
      files[name] = lib
      installed[name] = version
      version
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

    def feature?(path)
      key = path.to_s.sub(/\.rb\z/, "") + ".rb"
      files.any? { |_, lib| lib.key?(key) }
    end

    def autoload_map
      @autoload_map ||= {}
    end

    # Loads a feature ("chunky_png" or "gammo/css_selector") from an
    # installed gem. Returns true when found, nil otherwise.
    def load_feature(path)
      key = path.sub(/\.rb\z/, "") + ".rb"
      files.each do |gem_name, lib|
        next unless lib.key?(key)
        full = "#{gem_name}:#{key}"
        return true if loaded[full]
        loaded[full] = true
        Kernel.eval(lib[key], TOPLEVEL_BINDING, "/browser_gems/#{gem_name}/#{key}")
        return true
      end
      nil
    end

    # Maps an absolute in-gem path (as used in eval filenames) plus a
    # require_relative argument back to a gem-space feature key.
    def relative_key(caller_path, relative)
      File.expand_path(relative, File.dirname(caller_path))
          .sub(%r{\A/browser_gems/[^/]+/}, "")
    end
  end
end

module Kernel
  alias_method :bg_original_require, :require
  def require(path)
    bg_original_require(path)
  rescue LoadError => e
    BrowserGems.load_feature(path.to_s) or raise e
  end
end

# Ruby's autoload is C-level and bypasses the require hook above, and it
# needs real files (which the wasm VFS cannot provide). For gem-space paths
# we register the constant ourselves and resolve it lazily in const_missing
# - same semantics, no filesystem.
class Module
  alias_method :bg_original_autoload, :autoload
  def autoload(const, path)
    if BrowserGems.feature?(path)
      BrowserGems.autoload_map[[self, const.to_sym]] = path.to_s
    else
      bg_original_autoload(const, path)
    end
  end

  alias_method :bg_original_const_missing, :const_missing
  def const_missing(name)
    if (path = BrowserGems.autoload_map.delete([self, name.to_sym]))
      BrowserGems.load_feature(path)
      return const_get(name) if const_defined?(name)
    end
    bg_original_const_missing(name)
  end
end

# Outside the browser (test harness) main.rb's require_relative bridge is
# absent - provide the gem-space branch here. The absolute-path trick keeps
# the builtin resolution correct despite the wrapper frame.
unless Kernel.private_method_defined?(:original_require_relative)
  module Kernel
    alias_method :bg_original_require_relative, :require_relative
    def require_relative(path)
      location = caller_locations(1, 1).first
      caller_path = ((location && (location.absolute_path || location.path)) || "").to_s
      if caller_path.start_with?("/browser_gems/")
        BrowserGems.load_feature(BrowserGems.relative_key(caller_path, path)) or
          raise LoadError, "cannot load such file -- #{path}"
      else
        bg_original_require_relative(File.absolute_path(path, File.dirname(caller_path)))
      end
    end
  end
end
