# Sketch of a matplotlib lesson (de/en/ja), in lessons.js's format.
#
#   ruby experiments/01-matplotlib-charts/lesson_matplotlib.rb
#
# writes lesson_matplotlib.json next to this file; serve.rb inserts it after
# the NumPy lesson of html/lessons.js on the fly (nothing in html/ changes).
# Japanese runs the English code, comments translated (HANDOVER §3).
require "json"

def h(html) = { "t" => "h", "html" => html }
def c(code) = { "t" => "c", "code" => code }
def x(code, check, hint) = { "t" => "x", "code" => code, "check" => check, "hint" => hint }

# the exercise passes when a chart with the title is under the cell: the
# figure is an SVG whose text stays text (svg.fonttype "none")
def check(title)
  <<~RUBY.chomp
    code.include?(".bar") && images.any? { |url| url.start_with?("data:image/svg+xml") && url.split(",", 2).last.unpack1("m0").include?(#{title.inspect}) }
  RUBY
end

EN_CODE = {
  line: <<~RUBY.chomp,
    require "pycall"
    plt = PyCall.import_module("matplotlib.pyplot")

    days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    temps = [12.5, 15.0, 9.5, 21.0, 18.5, 23.0, 19.5]
    plt.plot(days, temps, marker: "o")
    plt.title("A week of weather")
    plt.show()
  RUBY
  bar: <<~RUBY.chomp,
    ice_creams = [40, 55, 20, 90, 70, 120, 85]
    plt.bar(days, ice_creams, color: "orange")
    plt.ylabel("ice creams sold")
    plt.show()
  RUBY
  numpy: <<~RUBY.chomp,
    np = PyCall.import_module("numpy")
    x = np.linspace(0, 2 * np.pi, 100)
    plt.plot(x, np.sin(x), label: "sin")
    plt.plot(x, np.cos(x), label: "cos")
    plt.legend()
    plt.show()
  RUBY
  figure: <<~RUBY.chomp,
    fig = plt.figure(figsize: [9, 3])
    left = fig.add_subplot(1, 2, 1)
    left.plot(days, temps, color: "tomato")
    left.set_title("Temperature")
    right = fig.add_subplot(1, 2, 2)
    right.scatter(temps, ice_creams)
    right.set_title("Ice creams by temperature")
    plt.savefig("weather.png")
    plt.show()
  RUBY
  task: <<~RUBY
    require "pycall"
    plt = PyCall.import_module("matplotlib.pyplot")

    days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    mice = [3, 5, 2, 6, 4, 7, 1]
    # a bar chart titled "Fox hunt", then plt.show()
  RUBY
}.freeze

# the English code with Japanese comments (only the task has one)
JA_TASK = EN_CODE[:task].sub("# a bar chart titled \"Fox hunt\", then plt.show()",
                             "# タイトル「Fox hunt」の棒グラフをかいて、plt.show()")

lesson = {
  "id" => "matplotlib",
  "de" => {
    "title" => "26. matplotlib: Diagramme",
    "cells" => [
      h("<h2>Zahlen als Bild</h2><p>Eine Tabelle voller Zahlen sagt wenig – ein Diagramm sagt es auf einen Blick. " \
        "<a href='https://matplotlib.org' target='_blank'>matplotlib</a> ist die Bibliothek, mit der Python seit über zwanzig Jahren zeichnet. " \
        "Wir erreichen sie wie pandas und NumPy über pycall. Eine Woche Temperaturen, als Linie:</p>"),
      c(<<~RUBY.chomp),
        require "pycall"
        plt = PyCall.import_module("matplotlib.pyplot")

        tage = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
        temperaturen = [12.5, 15.0, 9.5, 21.0, 18.5, 23.0, 19.5]
        plt.plot(tage, temperaturen, marker: "o")
        plt.title("Eine Woche Wetter")
        plt.show()
      RUBY
      h("<p><code>plt</code> ist matplotlibs Zeichenbrett, <code>pyplot</code>. <code>plot</code> zieht eine Linie durch die Punkte – " \
        "Ruby-Arrays gehen direkt hinein, und <code>marker: \"o\"</code> ist ein Python-Schlüsselwortargument, das einen Punkt auf jeden Wert setzt. " \
        "<code>plt.show()</code> zeigt das Bild: hier unter der Zelle, auf deinem Computer in einem eigenen Fenster.</p>" \
        "<p>Nach <code>show</code> ist das Brett wieder leer. Ein Balkendiagramm, mit Farbe und einer Beschriftung der y-Achse:</p>"),
      c(<<~RUBY.chomp),
        glaces = [40, 55, 20, 90, 70, 120, 85]
        plt.bar(tage, glaces, color: "orange")
        plt.ylabel("verkaufte Glaces")
        plt.show()
      RUBY
      h("<p>Am Samstag, dem wärmsten Tag, die meisten Glaces – das sieht man sofort.</p>" \
        "<p>Mit NumPy aus Lektion 25 werden es Kurven: <code>linspace</code> macht 100 Punkte zwischen 0 und 2π, und zwei <code>plot</code> vor einem <code>show</code> landen im selben Bild. " \
        "<code>label:</code> gibt jeder Linie einen Namen für die Legende:</p>"),
      c(<<~RUBY.chomp),
        np = PyCall.import_module("numpy")
        x = np.linspace(0, 2 * np.pi, 100)
        plt.plot(x, np.sin(x), label: "sin")
        plt.plot(x, np.cos(x), label: "cos")
        plt.legend()
        plt.show()
      RUBY
      h("<p>Mehrere Diagramme nebeneinander: <code>plt.figure</code> ist das ganze Bild (<code>figsize</code> in Zoll), " \
        "<code>add_subplot(1, 2, 1)</code> das erste von zwei Feldern in einer Zeile. Jedes Feld hat seine eigenen Methoden – <code>set_title</code> statt <code>title</code>. " \
        "Und <code>plt.savefig</code> schreibt das Bild in eine Datei, die du unter der Zelle herunterladen kannst:</p>"),
      c(<<~RUBY.chomp),
        fig = plt.figure(figsize: [9, 3])
        links = fig.add_subplot(1, 2, 1)
        links.plot(tage, temperaturen, color: "tomato")
        links.set_title("Temperatur")
        rechts = fig.add_subplot(1, 2, 2)
        rechts.scatter(temperaturen, glaces)
        rechts.set_title("Glaces je Temperatur")
        plt.savefig("wetter.png")
        plt.show()
      RUBY
      h("<p>Rechts ein Streudiagramm: je wärmer, desto mehr Glaces – genau das, was scikit-learn in der nächsten Lektion als Gerade lernt.</p>" \
        "<div class='offweb' data-title='Auf deinem Computer'><p><code>pip install matplotlib</code> und <code>gem install pycall</code>, und der Code läuft unverändert – " \
        "<code>plt.show()</code> öffnet ein Fenster, <code>savefig</code> schreibt die Datei neben dein Programm. matplotlib steht unter einer BSD-artigen Lizenz (PSF-basiert).</p></div>" \
        "<div class='task'><strong>Aufgabe:</strong> Der Fuchs hat diese Woche Mäuse gefangen. Zeichne daraus ein Balkendiagramm mit dem Titel <code>Fuchs-Jagd</code> und zeig es mit <code>plt.show()</code>.</div>"),
      x(<<~RUBY, check("Fuchs-Jagd"), "<code>plt.bar(tage, maeuse)</code> zeichnet die Balken, <code>plt.title(\"Fuchs-Jagd\")</code> setzt den Titel – und erst <code>plt.show()</code> bringt das Bild unter die Zelle.")
        require "pycall"
        plt = PyCall.import_module("matplotlib.pyplot")

        tage = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
        maeuse = [3, 5, 2, 6, 4, 7, 1]
        # ein Balkendiagramm mit dem Titel "Fuchs-Jagd", dann plt.show()
      RUBY
    ]
  },
  "en" => {
    "title" => "26. matplotlib: charts",
    "cells" => [
      h("<h2>Numbers as a picture</h2><p>A table full of numbers says little – a chart says it at a glance. " \
        "<a href='https://matplotlib.org' target='_blank'>matplotlib</a> is the library Python has drawn with for over twenty years. " \
        "We reach it through pycall, like pandas and NumPy. A week of temperatures, as a line:</p>"),
      c(EN_CODE[:line]),
      h("<p><code>plt</code> is matplotlib's drawing board, <code>pyplot</code>. <code>plot</code> draws a line through the points – " \
        "Ruby arrays go straight in, and <code>marker: \"o\"</code> is a Python keyword argument that puts a dot on every value. " \
        "<code>plt.show()</code> shows the picture: here below the cell, on your computer in a window of its own.</p>" \
        "<p>After <code>show</code> the board is empty again. A bar chart, with a colour and a label on the y axis:</p>"),
      c(EN_CODE[:bar]),
      h("<p>Saturday, the warmest day, sold the most ice creams – you see it at once.</p>" \
        "<p>With NumPy from lesson 25 we get curves: <code>linspace</code> makes 100 points between 0 and 2π, and two <code>plot</code>s before one <code>show</code> end up in the same picture. " \
        "<code>label:</code> names each line for the legend:</p>"),
      c(EN_CODE[:numpy]),
      h("<p>Several charts side by side: <code>plt.figure</code> is the whole picture (<code>figsize</code> in inches), " \
        "<code>add_subplot(1, 2, 1)</code> the first of two panels in one row. Each panel has methods of its own – <code>set_title</code> instead of <code>title</code>. " \
        "And <code>plt.savefig</code> writes the picture to a file you can download below the cell:</p>"),
      c(EN_CODE[:figure]),
      h("<p>On the right, a scatter plot: the warmer, the more ice creams – exactly what scikit-learn learns as a straight line in the next lesson.</p>" \
        "<div class='offweb' data-title='On your computer'><p><code>pip install matplotlib</code> and <code>gem install pycall</code>, and the code runs unchanged – " \
        "<code>plt.show()</code> opens a window, <code>savefig</code> writes the file next to your program. matplotlib is under a BSD-style licence (PSF-based).</p></div>" \
        "<div class='task'><strong>Task:</strong> The fox caught some mice this week. Draw them as a bar chart titled <code>Fox hunt</code> and show it with <code>plt.show()</code>.</div>"),
      x(EN_CODE[:task], check("Fox hunt"), "<code>plt.bar(days, mice)</code> draws the bars, <code>plt.title(\"Fox hunt\")</code> sets the title – and only <code>plt.show()</code> puts the picture below the cell.")
    ]
  },
  "ja" => {
    "title" => "26. matplotlib：グラフ",
    "cells" => [
      h("<h2>数を絵にする</h2><p>数がならんだ表はなかなか読めませんが、グラフならひと目でわかります。" \
        "<a href='https://matplotlib.org' target='_blank'>matplotlib</a>は、Pythonが20年以上つかってきた描画ライブラリです。" \
        "pandasやNumPyと同じく、pycallから使います。1週間の気温を線で描いてみましょう。</p>"),
      c(EN_CODE[:line]),
      h("<p><code>plt</code>はmatplotlibの画板、<code>pyplot</code>です。<code>plot</code>は点を線でつなぎます。" \
        "Rubyの配列はそのまま渡せます。<code>marker: \"o\"</code>はPythonのキーワード引数で、各値に点を打ちます。" \
        "<code>plt.show()</code>で絵が出ます。ここではセルの下に、あなたのコンピューターでは別のウィンドウに表示されます。</p>" \
        "<p><code>show</code>のあと、画板はまた空になります。色とy軸のラベルをつけた棒グラフです。</p>"),
      c(EN_CODE[:bar]),
      h("<p>いちばん暑い土曜日に、アイスがいちばん売れました。ひと目でわかりますね。</p>" \
        "<p>レッスン25のNumPyを使うと曲線も描けます。<code>linspace</code>は0から2πまでに100個の点をつくり、" \
        "<code>show</code>の前に<code>plot</code>を2回呼ぶと、同じ絵に入ります。<code>label:</code>は凡例に出る線の名前です。</p>"),
      c(EN_CODE[:numpy]),
      h("<p>グラフを横にならべるには、<code>plt.figure</code>で絵全体をつくり（<code>figsize</code>はインチ）、" \
        "<code>add_subplot(1, 2, 1)</code>で1行2列の1つ目の枠を取ります。枠には専用のメソッドがあり、<code>title</code>のかわりに<code>set_title</code>を使います。" \
        "<code>plt.savefig</code>は絵をファイルに書き出し、セルの下からダウンロードできます。</p>"),
      c(EN_CODE[:figure]),
      h("<p>右は散布図です。暑いほどアイスが売れる――次のレッスンでscikit-learnが直線として学ぶのは、まさにこれです。</p>" \
        "<div class='offweb' data-title='あなたのコンピューターで'><p><code>pip install matplotlib</code>と<code>gem install pycall</code>で、このコードはそのまま動きます。" \
        "<code>plt.show()</code>はウィンドウを開き、<code>savefig</code>はプログラムの横にファイルを書きます。matplotlibはBSD系（PSFベース）のライセンスです。</p></div>" \
        "<div class='task'><strong>課題：</strong>キツネが今週つかまえたネズミの数です。タイトル<code>Fox hunt</code>の棒グラフにして、<code>plt.show()</code>で表示してください。</div>"),
      x(JA_TASK, check("Fox hunt"), "<code>plt.bar(days, mice)</code>で棒、<code>plt.title(\"Fox hunt\")</code>でタイトル。<code>plt.show()</code>をよばないと、絵はセルの下に出てこないよ。")
    ]
  }
}

File.write(File.join(__dir__, "lesson_matplotlib.json"), JSON.pretty_generate(lesson))
puts "wrote lesson_matplotlib.json (#{lesson['de']['cells'].size} cells per language)"
