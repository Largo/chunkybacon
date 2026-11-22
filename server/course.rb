# frozen_string_literal: true

require "json"
require "uri"
require_relative "../html/lesson_refs"

# The course as the server sees it: html/lessons.js, the same file the page
# loads (window.LESSONS_JSON = JSON.stringify({ui, lessons})), read again
# whenever it changes on disk. Lesson numbers are filled in as on the page
# (html/lesson_refs.rb): a title has none, a reference names an id.
class Course
  WORKSHOP_ID = "werkstatt"   # html/shell/support.rb

  def self.load(path)
    source = File.read(path, encoding: "UTF-8")
    json = source[/JSON\.stringify\((.*)\);\s*\z/m, 1] or raise "#{path}: no JSON.stringify(...)"
    new(JSON.parse(json))
  end

  # the course of +path+, parsed again only when the file changed
  def self.cached(path)
    mtime = File.mtime(path)
    @cache = [mtime, load(path)] unless @cache && @cache[0] == mtime
    @cache[1]
  end

  def initialize(data)
    @ui = data.fetch("ui")
    data = LessonRefs.resolve(data)
    @lessons = data.fetch("lessons")
    @numbers = LessonRefs.numbers(@lessons)
    @by_id = @lessons.to_h { |lesson| [lesson["id"], lesson] }
    # lang => {slug => id}: what a permalink's word names
    @by_slug = langs.to_h do |lang|
      [lang, (ids + [WORKSHOP_ID]).to_h { |id| [slug(lang, id), id] }]
    end
  end

  def langs = @ui.keys
  def lang?(lang) = @ui.key?(lang)
  def ids = @lessons.map { |lesson| lesson["id"] }
  def lesson?(id) = @by_id.key?(id)
  # a ui string, English when the language lacks it (as the shell does)
  def ui(lang, key) = @ui.dig(lang, key) || @ui.dig("en", key)

  # a lesson in one language; English when a translation is missing
  def l10n(id, lang) = @by_id[id] && (@by_id[id][lang] || @by_id[id]["en"])

  # what a page names: a lesson id or the workshop
  def page?(id) = lesson?(id) || id == WORKSHOP_ID

  # "9. Methoden – Ruby lernen mit Chunky Bacon", as the shell titles the tab
  def title(lang, id = nil)
    site = ui(lang, "title")
    return site unless id
    return "#{ui(lang, 'workshopTitle')} – #{site}" if id == WORKSHOP_ID

    "#{numbered_title(lang, id)} – #{site}"
  end

  # "9. Methoden"
  def numbered_title(lang, id) = LessonRefs.numbered(@numbers.fetch(id), l10n(id, lang)&.dig("title"))

  # The lesson's first paragraph as plain text, shortened for a link
  # preview; the course's subtitle for anything else.
  def description(lang, id = nil, limit = 160)
    html = id && l10n(id, lang)&.dig("cells")&.find { |cell| cell["t"] == "h" }&.dig("html")
    return ui(lang, "subtitle") unless html

    text = html.sub(%r{<h2>.*?</h2>}m, "").gsub(/<[^>]+>/, " ").gsub("&nbsp;", " ")
               .gsub("&lt;", "<").gsub("&gt;", ">").gsub("&quot;", '"').gsub("&amp;", "&").squeeze(" ").strip
    text.length > limit ? "#{text[0, limit - 1].rstrip}…" : text
  end

  # The word in a page's permalink, /en/variables, /ja/ループ: lessons.js's
  # "slug" (tools/lesson_slugs.rb), the workshop's ui "workshopSlug";
  # German, and a page without one, its id - the addresses the course
  # always had, which links and search engines already know.
  def slug(lang, id)
    own = id == WORKSHOP_ID ? @ui.dig(lang, "workshopSlug") : @by_id.dig(id, lang, "slug")
    own || id
  end

  # the page a permalink's word names in +lang+, nil for none
  def find(lang, slug) = @by_slug.dig(lang, slug)

  # "en/variables", "ja/%E3%83%AB..." - a page's path below the base;
  # "en" for a language's own start
  def path(lang, id = nil) = id ? "#{lang}/#{URI.encode_uri_component(slug(lang, id))}" : lang

  # a lesson's cells in one language (English when a translation is missing)
  def cells(lang, id) = l10n(id, lang)&.dig("cells") || []

  # /sitemap.xml: the landing page, each language's course and every
  # lesson in every language, a page naming its translations (hreflang)
  def sitemap(origin)
    entry = lambda do |path, alternates = {}|
      links = alternates.map { |lang, href| %(    <xhtml:link rel="alternate" hreflang="#{lang}" href="#{origin}/#{href}"/>\n) }
      "  <url>\n    <loc>#{origin}/#{path}</loc>\n#{links.join}  </url>\n"
    end
    pages = [nil] + ids
    urls = [entry.("")] + pages.flat_map do |id|
      alternates = langs.to_h { |lang| [lang, path(lang, id)] }
      langs.map { |lang| entry.(alternates[lang], alternates) }
    end
    %(<?xml version="1.0" encoding="UTF-8"?>\n) +
      %(<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">\n) +
      urls.join + "</urlset>\n"
  end

  # every lesson with its titles, for /api/lessons
  def index
    @lessons.map do |lesson|
      { "id" => lesson["id"], "titles" => langs.to_h { |lang| [lang, numbered_title(lang, lesson["id"])] } }
    end
  end
end
