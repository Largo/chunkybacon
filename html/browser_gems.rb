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

  class << self
    attr_accessor :fetch_binary, :fetch_text, :cache_base, :proxy_base

    def installed
      @installed ||= {}
    end

    def files
      @files ||= {}
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
