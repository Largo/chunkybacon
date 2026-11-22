# frozen_string_literal: true

# Gives every lesson a slug in each language where it has none: the word in
# its permalink, /en/variables, /fr/variables, /ja/変数 (server/app.rb,
# html/shell/router.rb). German keeps the lesson's id, the address the
# course has always had. A slug comes from the lesson's title, its part
# before " – " when that is unique in the language; a slug once
# given is never changed, since search engines and links know it.
#
#   ruby tools/lesson_slugs.rb          writes html/lessons.js
#   ruby tools/lesson_slugs.rb --check  lists what is missing, changes nothing
#
# It edits lessons.js line by line (a "slug" line after each "title" line),
# so the file keeps its layout.
require "json"

module LessonSlugs
  FILE = File.expand_path("../html/lessons.js", __dir__)
  FOLD = { "ß" => "ss", "œ" => "oe", "æ" => "ae", "ø" => "o", "ł" => "l", "’" => "-", "'" => "-" }.freeze

  module_function

  # "Les chaînes – travailler avec du texte" => "les-chaines-travailler-avec-du-texte";
  # Japanese keeps its script: "条件分岐（if）" => "条件分岐-if"
  def slugify(text)
    text = text.to_s.downcase.gsub(/['’]s\b/, "s")   # "Conway's" => "conways"
    FOLD.each { |from, to| text = text.gsub(from, to) }
    # accents off Latin letters only: Japanese keeps its marks (ループ, not ルーフ)
    text = text.gsub(/\p{Latin}/) { |char| char.unicode_normalize(:nfd).gsub(/\p{Mn}/, "") }
    text.gsub(/[^a-z0-9\p{Han}\p{Hiragana}\p{Katakana}ー]+/, "-").gsub(/\A-+|-+\z/, "")
  end

  def short(title) = title.to_s.split(/ – | — /).first

  # {lang => {id => slug}} for every lesson and language lacking one
  def missing(data)
    langs = data["ui"].keys - ["de"]
    lessons = data["lessons"]
    langs.to_h do |lang|
      taken = lessons.filter_map { |lesson| lesson.dig(lang, "slug") }
      wanted = lessons.reject { |lesson| lesson[lang].nil? || lesson.dig(lang, "slug") }
      shorts = wanted.to_h { |lesson| [lesson["id"], slugify(short(lesson[lang]["title"]))] }
      slugs = wanted.to_h do |lesson|
        id = lesson["id"]
        slug = shorts[id]
        clash = slug.empty? || taken.include?(slug) || shorts.count { |_, other| other == slug } > 1
        slug = slugify(lesson[lang]["title"]) if clash
        slug = id if slug.empty? || taken.include?(slug)
        taken << slug
        [id, slug]
      end
      [lang, slugs]
    end
  end

  def write(source, slugs)
    id = lang = nil
    source.lines.map do |line|
      id = Regexp.last_match(1) if line =~ /\A {4,6}"id": "([^"]+)"/
      lang = Regexp.last_match(1) if line =~ /\A      "([a-z]{2})": \{/
      slug = id && lang && slugs.dig(lang, id)
      if slug && line =~ /\A(        )"title": /
        line + %(#{Regexp.last_match(1)}"slug": #{JSON.generate(slug)},\n)
      else
        line
      end
    end.join
  end
end

if $PROGRAM_NAME == __FILE__
  source = File.read(LessonSlugs::FILE, encoding: "UTF-8")
  data = JSON.parse(source[/JSON\.stringify\((.*)\);\s*\z/m, 1])
  slugs = LessonSlugs.missing(data).reject { |_, by_id| by_id.empty? }
  if slugs.empty?
    puts "every lesson has its slugs"
  elsif ARGV.include?("--check")
    slugs.each { |lang, by_id| by_id.each { |id, slug| puts "#{lang}\t#{id}\t#{slug}" } }
    exit 1
  else
    File.write(LessonSlugs::FILE, LessonSlugs.write(source, slugs))
    puts "slugs for #{slugs.sum { |_, by_id| by_id.size }} lessons written"
  end
end
