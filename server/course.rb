# frozen_string_literal: true

require "json"
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
      alternates = langs.to_h { |lang| [lang, [lang, id].compact.join("/")] }
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
