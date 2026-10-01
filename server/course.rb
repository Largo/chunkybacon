# frozen_string_literal: true

require "json"

# The course as the server sees it: html/lessons.js, the same file the page
# loads (window.LESSONS_JSON = JSON.stringify({ui, lessons})), read again
# whenever it changes on disk.
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
    @lessons = data.fetch("lessons")
    @by_id = @lessons.to_h { |lesson| [lesson["id"], lesson] }
  end

  def langs = @ui.keys
  def lang?(lang) = @ui.key?(lang)
  def ids = @lessons.map { |lesson| lesson["id"] }
  def lesson?(id) = @by_id.key?(id)
  def ui(lang, key) = @ui.dig(lang, key)

  # what a page names: a lesson id or the workshop
  def page?(id) = lesson?(id) || id == WORKSHOP_ID

  # "9. Methoden – Ruby lernen mit Chunky Bacon", as the shell titles the tab
  def title(lang, id = nil)
    site = ui(lang, "title")
    return site unless id
    return "#{ui(lang, 'workshopTitle')} – #{site}" if id == WORKSHOP_ID

    "#{@by_id.dig(id, lang, 'title')} – #{site}"
  end

  # The lesson's first paragraph as plain text, shortened for a link
  # preview; the course's subtitle for anything else.
  def description(lang, id = nil, limit = 160)
    html = id && @by_id.dig(id, lang, "cells")&.find { |cell| cell["t"] == "h" }&.dig("html")
    return ui(lang, "subtitle") unless html

    text = html.sub(%r{<h2>.*?</h2>}m, "").gsub(/<[^>]+>/, " ").gsub("&nbsp;", " ")
               .gsub("&lt;", "<").gsub("&gt;", ">").gsub("&quot;", '"').gsub("&amp;", "&").squeeze(" ").strip
    text.length > limit ? "#{text[0, limit - 1].rstrip}…" : text
  end

  # every lesson with its titles, for /api/lessons
  def index
    @lessons.map do |lesson|
      { "id" => lesson["id"], "titles" => langs.to_h { |lang| [lang, lesson.dig(lang, "title")] } }
    end
  end
end
