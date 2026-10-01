# frozen_string_literal: true

# The optional server: the course without it is a static site (nginx serves
# html/, lessons live at /#methoden). Run this instead and a lesson has a
# permalink - /de/methoden - with its own title and link preview, and there
# is room for backend code under /api.
#
#   cd server && bundle install && bundle exec puma -p 8012
#
# What it serves:
#   /, /de, /de/methoden, /de/werkstatt   index.html, told about permalinks
#                                         (<base>, <meta name="chunky-permalinks">)
#                                         and titled for the lesson
#   /api/lessons                          the lessons and their titles, JSON
#   /rubygems/..., /proxy/ruby-lang/...   the same bridges as nginx/default.conf
#   everything else under html/           as it is (.gz copies where they exist)
require "roda"
require "net/http"
require "rack/utils"
require_relative "course"

class ChunkyServer < Roda
  HTML = File.expand_path("../html", __dir__)
  INDEX = File.join(HTML, "index.html")
  LESSONS = File.join(HTML, "lessons.js")
  # the code revalidates on every load, as with nginx; a 304 is cheap
  STATIC_HEADERS = { "Cache-Control" => "no-cache" }.freeze
  BRIDGE_HEADERS = %w[content-type last-modified etag].freeze

  plugin :public, root: HTML, gzip: true, headers: STATIC_HEADERS
  plugin :head
  plugin :json
  plugin :not_found do
    "<!DOCTYPE html><meta charset=\"UTF-8\"><title>404 – Chunky Bacon</title>" \
      "<p>Diese Seite gibt es nicht. · This page does not exist. · このページはありません。</p>" \
      "<p><a href=\"#{h(base_path)}\">Chunky Bacon</a></p>"
  end

  def self.course = Course.cached(LESSONS)

  route do |r|
    r.public
    course = self.class.course

    r.root { page }

    r.on "api" do
      r.get("lessons") { course.index }
    end

    # nginx/default.conf's bridges: hardcoded hosts, GET and HEAD only, and
    # on rubygems.org only the two kinds of path the gem installer asks for
    r.on "rubygems" do
      r.get("api", "v1", "gems", String) { |name| bridge("rubygems.org", "/api/v1/gems/#{name}") }
      r.get("gems", String) { |file| bridge("rubygems.org", "/gems/#{file}") }
      response.status = 403
      "403 Forbidden"
    end
    r.get("proxy", "ruby-lang", /(.*)/) { |rest| bridge("www.ruby-lang.org", "/#{rest}") }

    r.on String do |lang|
      next unless course.lang?(lang)

      r.is { page(lang) }
      r.is(String) { |id| page(lang, id) if course.page?(id) }
    end
  end

  private

  def h(text) = Rack::Utils.escape_html(text.to_s)

  # where the course lives - "/" unless it is mounted under a path
  def base_path = "#{request.script_name}/"

  # index.html, told that it has permalinks and, for a lesson, titled and
  # described for it (search engines and link previews read this; the shell
  # renders the page itself, as always)
  def page(lang = nil, id = nil)
    course = self.class.course
    base = base_path
    html = File.read(INDEX, encoding: "UTF-8")
    added = [%(<base href="#{h base}">), %(<meta name="chunky-permalinks" content="#{h base}">)]
    if lang
      html = html.sub(/<html lang="[^"]*">/) { %(<html lang="#{lang}">) }
      title = course.title(lang, id)
      description = course.description(lang, id)
      html = html.sub(%r{<title>.*?</title>}m) { "<title>#{h title}</title>" }
      html = meta(html, "name", "description", description)
      html = meta(html, "property", "og:title", title)
      html = meta(html, "property", "og:description", description)
      if id
        url = ->(language) { "#{request.base_url}#{base}#{language}/#{id}" }
        added << %(<link rel="canonical" href="#{h url.(lang)}">)
        added << %(<meta property="og:url" content="#{h url.(lang)}">)
        course.langs.each { |language| added << %(<link rel="alternate" hreflang="#{language}" href="#{h url.(language)}">) }
      end
    end
    # <base> before the first relative URL in <head>
    html.sub('<meta charset="UTF-8">') { |charset| ([charset] + added).join("\n    ") }
  end

  def meta(html, attribute, name, value)
    html.sub(/(<meta #{attribute}="#{Regexp.escape(name)}" content=")[^"]*(")/) { "#{$1}#{h value}#{$2}" }
  end

  def bridge(host, path)
    query = request.query_string
    path = "#{path}?#{query}" unless query.empty?
    upstream = Net::HTTP.start(host, 443, use_ssl: true, open_timeout: 10, read_timeout: 60) do |http|
      klass = request.head? ? Net::HTTP::Head : Net::HTTP::Get
      http.request(klass.new(path, "User-Agent" => "chunkybacon"))
    end
    response.status = upstream.code.to_i
    BRIDGE_HEADERS.each { |name| response[name] = upstream[name] if upstream[name] }
    upstream.body.to_s
  rescue StandardError => e
    response.status = 502
    response["content-type"] = "text/plain"
    "bridge to #{host} failed: #{e.class}: #{e.message}"
  end
end
