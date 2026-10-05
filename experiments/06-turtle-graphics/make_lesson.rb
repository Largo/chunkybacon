# Writes lesson_turtle.json: the draft lesson "Malen mit Chunky" in the
# shape of one entry of html/lessons.js (de, en, ja).
#   ruby make_lesson.rb
require "json"

# the same check for every language (ja must be byte-identical to en):
# a closed drawing of 48, 192 or 768 equal edges (Koch depth 2, 3 or 4)
# whose corners are all 60 or 120 degrees - a 48-gon does not pass
CHECK = "(t = Turtle.from(images).last) && t.closed? && [48, 192, 768].include?(t.edges.size) && " \
        "t.edges.map { |e| e.length.round(1) }.uniq.size == 1 && " \
        "(t.corners.map(&:round) - [60, -60, 120, -120]).empty?"

SQUARE = <<~RUBY.chomp
  turtle do
    4.times do
      forward 100
      right 90
    end
  end
RUBY

de_polygons = <<~RUBY.chomp
  def vieleck(ecken, seite)
    ecken.times do
      forward seite
      right 360.0 / ecken
    end
  end

  turtle do
    (3..8).each do |ecken|
      color "hsl(\#{ecken * 45}, 70%, 45%)"
      vieleck(ecken, 60)
    end
  end

  # dreht sich Chunky insgesamt zweimal ganz herum, wird es ein Stern
  turtle { 5.times { forward 150; right 144 } }
RUBY

en_polygons = <<~RUBY.chomp
  def polygon(corners, side)
    corners.times do
      forward side
      right 360.0 / corners
    end
  end

  turtle do
    (3..8).each do |corners|
      color "hsl(\#{corners * 45}, 70%, 45%)"
      polygon(corners, 60)
    end
  end

  # COMMENT
  turtle { 5.times { forward 150; right 144 } }
RUBY

de_tree = <<~RUBY.chomp
  def baum(laenge, tiefe)
    return if tiefe == 0   # die Abbruchbedingung

    forward laenge
    left 25
    baum(laenge * 0.7, tiefe - 1)   # der linke kleine Baum
    right 50
    baum(laenge * 0.7, tiefe - 1)   # der rechte kleine Baum
    left 25
    back laenge                     # zurück zum Anfang des Stamms
  end

  turtle do
    color "#3a8d3a"
    baum(80, 7)
  end
RUBY

en_tree = <<~RUBY.chomp
  def tree(length, depth)
    return if depth == 0   # C1

    forward length
    left 25
    tree(length * 0.7, depth - 1)   # C2
    right 50
    tree(length * 0.7, depth - 1)   # C3
    left 25
    back length                     # C4
  end

  turtle do
    color "#3a8d3a"
    tree(80, 7)
  end
RUBY

de_starter = <<~RUBY
  def koch(laenge, tiefe)
    if tiefe == 0
      forward laenge
    else
      # viermal koch(laenge / 3.0, tiefe - 1),
      # dazwischen left 60, right 120, left 60
    end
  end

  turtle do
    color "#2a6fb0"
    3.times do
      koch(270, 3)
      right 120
    end
  end
RUBY

en_starter = <<~RUBY
  def koch(length, depth)
    if depth == 0
      forward length
    else
      # C1
      # C2
    end
  end

  turtle do
    color "#2a6fb0"
    3.times do
      koch(270, 3)
      right 120
    end
  end
RUBY

en_comments = {
  polygons: { "COMMENT" => "turn twice all the way round and it becomes a star" },
  tree: { "C1" => "the base case", "C2" => "the small tree on the left", "C3" => "the small tree on the right",
          "C4" => "back to the foot of the trunk" },
  starter: { "C1" => "four times koch(length / 3.0, depth - 1),", "C2" => "with left 60, right 120, left 60 in between" }
}
ja_comments = {
  polygons: { "COMMENT" => "ぐるっと2回まわると、星になります" },
  tree: { "C1" => "終了条件", "C2" => "左の小さな木", "C3" => "右の小さな木", "C4" => "幹の根もとへもどる" },
  starter: { "C1" => "koch(length / 3.0, depth - 1) を4回、", "C2" => "あいだに left 60、right 120、left 60" }
}
fill = ->(code, words) { words.reduce(code) { |c, (k, v)| c.gsub(/\b#{k}\b/, v) } }

def lesson(title, cells) = { "title" => title, "cells" => cells }
def h(html) = { "t" => "h", "html" => html }
def c(code) = { "t" => "c", "code" => code }
def x(code, hint) = { "t" => "x", "code" => code, "check" => CHECK, "hint" => hint }

de = lesson("10. Malen mit Chunky", [
  h("<h2>Malen mit Chunky</h2><p>In den 1960ern erfanden Seymour Papert und seine Kollegen die Sprache Logo: " \
    "Kinder steuerten darin eine <em>Schildkröte</em> (englisch <em>turtle</em>), die beim Laufen eine Spur zog. " \
    "Hier ist Chunky die Schildkröte. Was du in <code>turtle do</code> … <code>end</code> schreibst, sind Befehle an Chunky:</p>" \
    "<ul><li><code>forward 100</code> – 100 Schritte geradeaus, und dabei zeichnen</li>" \
    "<li><code>right 90</code>, <code>left 90</code> – sich um 90 Grad drehen</li>" \
    "<li><code>pen_up</code>, <code>pen_down</code>, <code>color \"red\"</code>, <code>pen_width 5</code></li></ul>" \
    "<p>Chunky startet in der Mitte und schaut nach oben. Ein Quadrat ist viermal „vor und rechts drehen“ – eine Schleife wie in Lektion 6:</p>"),
  c(SQUARE),
  h("<p>Das <code>=&gt; #&lt;Turtle 4 lines …&gt;</code> darunter ist Chunkys Protokoll: jeder Strich wird mitgeschrieben. " \
    "Bei einem Vieleck dreht sich Chunky einmal ganz herum, also um 360 Grad – an jeder Ecke um <code>360.0 / ecken</code>. " \
    "Das ist eine Methode mit zwei Parametern (Lektion 9), und Methoden, die du selbst schreibst, kennt Chunky im <code>turtle</code>-Block auch:</p>"),
  c(de_polygons),
  h("<p>Jetzt wird es magisch: eine Methode, die sich <strong>selbst aufruft</strong>. Ein Baum ist ein Stamm mit zwei kleineren Bäumen darauf – " \
    "und jeder davon ist wieder ein Stamm mit zwei noch kleineren Bäumen … Damit das aufhört, braucht die Methode eine <strong>Abbruchbedingung</strong>: " \
    "bei Tiefe 0 zeichnet sie nichts mehr. Das heisst <strong>Rekursion</strong>. Am Schluss geht Chunky mit <code>back</code> zurück, " \
    "damit der Aufrufer dort weitermacht, wo er aufgehört hat.</p>"),
  c(de_tree),
  h("<div class='task'><strong>Aufgabe:</strong> Zeichne die <strong>Koch-Schneeflocke</strong>. Eine Koch-Kurve der Tiefe 0 ist ein gerader Strich. " \
    "Eine Kurve der Tiefe <code>n</code> besteht aus vier Kurven der Tiefe <code>n - 1</code>, jede ein Drittel so lang, " \
    "mit <code>left 60</code>, <code>right 120</code> und <code>left 60</code> dazwischen. Ergänze den <code>else</code>-Zweig – " \
    "drei Kurven der Tiefe 3 ergeben die Flocke.</div>"),
  x(de_starter, "Vier Aufrufe, drei Drehungen: <code>koch(laenge / 3.0, tiefe - 1)</code>, <code>left 60</code>, " \
                "<code>koch(…)</code>, <code>right 120</code>, <code>koch(…)</code>, <code>left 60</code>, <code>koch(…)</code>.")
])

en = lesson("10. Drawing with Chunky", [
  h("<h2>Drawing with Chunky</h2><p>In the 1960s Seymour Papert and his colleagues invented the Logo language: " \
    "children steered a <em>turtle</em> that left a trail wherever it walked. " \
    "Here Chunky is the turtle. What you write in <code>turtle do</code> … <code>end</code> are commands for Chunky:</p>" \
    "<ul><li><code>forward 100</code> – walk 100 steps straight ahead, drawing as you go</li>" \
    "<li><code>right 90</code>, <code>left 90</code> – turn by 90 degrees</li>" \
    "<li><code>pen_up</code>, <code>pen_down</code>, <code>color \"red\"</code>, <code>pen_width 5</code></li></ul>" \
    "<p>Chunky starts in the middle, looking up. A square is “forward and turn right” four times – a loop, as in lesson 6:</p>"),
  c(SQUARE),
  h("<p>The <code>=&gt; #&lt;Turtle 4 lines …&gt;</code> below is Chunky's log: every line is recorded. " \
    "Walking round a polygon, Chunky turns all the way round once, 360 degrees – <code>360.0 / corners</code> at each corner. " \
    "That is a method with two parameters (lesson 9), and the methods you write yourself work inside the <code>turtle</code> block too:</p>"),
  c(fill.(en_polygons, en_comments[:polygons])),
  h("<p>Now for some magic: a method that <strong>calls itself</strong>. A tree is a trunk with two smaller trees on top – " \
    "and each of those is a trunk with two even smaller trees … To stop somewhere, the method needs a <strong>base case</strong>: " \
    "at depth 0 it draws nothing. This is called <strong>recursion</strong>. At the end Chunky walks <code>back</code>, " \
    "so the caller carries on where it left off.</p>"),
  c(fill.(en_tree, en_comments[:tree])),
  h("<div class='task'><strong>Task:</strong> Draw the <strong>Koch snowflake</strong>. A Koch curve of depth 0 is a straight line. " \
    "A curve of depth <code>n</code> is four curves of depth <code>n - 1</code>, each a third as long, " \
    "with <code>left 60</code>, <code>right 120</code> and <code>left 60</code> in between. Fill in the <code>else</code> branch – " \
    "three curves of depth 3 make the flake.</div>"),
  x(fill.(en_starter, en_comments[:starter]),
    "Four calls, three turns: <code>koch(length / 3.0, depth - 1)</code>, <code>left 60</code>, " \
    "<code>koch(…)</code>, <code>right 120</code>, <code>koch(…)</code>, <code>left 60</code>, <code>koch(…)</code>.")
])

ja = lesson("10. Chunkyとお絵かき", [
  h("<h2>Chunkyとお絵かき</h2><p>1960年代、シーモア・パパートたちはLogoという言語を作りました。" \
    "子どもたちは、歩いたあとに線をのこす<em>カメ</em>（タートル）を動かして絵をかきました。" \
    "ここではChunkyがそのカメです。<code>turtle do</code> … <code>end</code>の中に書くのは、Chunkyへの命令です：</p>" \
    "<ul><li><code>forward 100</code> – まっすぐ100歩進んで、線をかく</li>" \
    "<li><code>right 90</code>、<code>left 90</code> – 90度向きを変える</li>" \
    "<li><code>pen_up</code>、<code>pen_down</code>、<code>color \"red\"</code>、<code>pen_width 5</code></li></ul>" \
    "<p>Chunkyはまんなかから、上を向いてスタートします。正方形は「進んで右を向く」の4回くり返し。レッスン6のループです：</p>"),
  c(SQUARE),
  h("<p>下に出る<code>=&gt; #&lt;Turtle 4 lines …&gt;</code>はChunkyの記録です。かいた線は、ぜんぶ記録されています。" \
    "多角形をひとまわりすると、Chunkyはちょうど1回転、つまり360度まわります。角ごとに<code>360.0 / corners</code>度です。" \
    "これは引数が2つあるメソッドになります（レッスン9）。自分で書いたメソッドも、<code>turtle</code>ブロックの中で使えます：</p>"),
  c(fill.(en_polygons, ja_comments[:polygons])),
  h("<p>ここからが魔法です。<strong>自分自身を呼び出す</strong>メソッドです。木は、幹の上に小さな木が2本のったもの。" \
    "その小さな木も、また幹の上にもっと小さな木が2本……。どこかで止めるために、メソッドには<strong>終了条件</strong>が必要です。" \
    "深さが0なら何もかきません。これを<strong>再帰</strong>といいます。最後にChunkyは<code>back</code>でもどるので、" \
    "呼び出した側は続きからかけます。</p>"),
  c(fill.(en_tree, ja_comments[:tree])),
  h("<div class='task'><strong>課題：</strong><strong>コッホ雪片</strong>をかきましょう。深さ0のコッホ曲線は、まっすぐな線です。" \
    "深さ<code>n</code>の曲線は、長さ3分の1の深さ<code>n - 1</code>の曲線4本でできていて、あいだに" \
    "<code>left 60</code>、<code>right 120</code>、<code>left 60</code>が入ります。<code>else</code>の中を書いてください。" \
    "深さ3の曲線3本で、雪の結晶になります。</div>"),
  x(fill.(en_starter, ja_comments[:starter]),
    "呼び出し4回に、回転3回だよ：<code>koch(length / 3.0, depth - 1)</code>、<code>left 60</code>、" \
    "<code>koch(…)</code>、<code>right 120</code>、<code>koch(…)</code>、<code>left 60</code>、<code>koch(…)</code>！")
])

File.write(File.join(__dir__, "lesson_turtle.json"), JSON.pretty_generate({ "id" => "turtle", "de" => de, "en" => en, "ja" => ja }) + "\n")
puts "lesson_turtle.json: #{[de, en, ja].map { |l| l['cells'].size }.inspect} cells"
