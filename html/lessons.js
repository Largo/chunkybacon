// Lesson data for "Ruby lernen mit Chunky Bacon".
// Notebook format: each lesson (per language) is a list of cells:
//   { t: "h", html: ... }                        text block
//   { t: "c", code: ... }                        runnable demo cell
//   { t: "x", code, check, hint }                exercise cell (checked)
// All code cells of a lesson share one binding (like a notebook kernel).
// Check snippets are Ruby, eval'd in that binding with extra locals:
// output (captured stdout), result (last expression value), code (source).
window.LESSONS_JSON = JSON.stringify({
  ui: {
    de: {
      title: "Ruby lernen mit Chunky Bacon",
      subtitle: "Ein Ruby-Notizbuch im Browser – kein Setup, einfach lostippen.",
      runCell: "▶ Ausführen",
      reset: "Lektion zurücksetzen",
      taskLabel: "Aufgabe",
      loading: "Ruby wird geladen … (einmalig ca. 35 MB)",
      welcome: "Hallo! Ich bin <strong>Chunky Bacon</strong>, dein Fuchs-Begleiter. 🦊🥓 Diese Seite ist ein <strong>Notizbuch</strong>: Führe jede Code-Zelle mit <em>▶ Ausführen</em> oder <kbd>Shift</kbd>+<kbd>Enter</kbd> aus – den Wert der letzten Zeile zeigt Ruby automatisch als <code>=&gt;</code>. Die Zelle mit dem orangen Rand ist deine Aufgabe. Los geht's!",
      resetConfirm: "Alle Zellen dieser Lektion zurücksetzen?",
      praise: [
        "CHUNKY BACON! 🥓 Genau so!",
        "Sauber! Die Füchse jubeln: CHUNKY BACON!",
        "Perfekt! Du bist auf dem Weg zur Ruby-Erleuchtung.",
        "Ausgezeichnet! Matz wäre stolz auf dich.",
        "Wunderbar! Weiter so!"
      ],
      failIntro: "Hmm, das ist noch nicht ganz richtig.",
      errorIntro: "Autsch, Ruby meldet einen Fehler – schau unter die Zelle.",
      nextLesson: "→ Weiter zur nächsten Lektion",
      progress: "Lektion %d von %d",
      allDone: "🎉 Du hast alle Lektionen geschafft! CHUNKY BACON! Als nächsten Schritt empfehle ich dir die <a href='https://koans.idogawa.com'>Ruby Koans im Browser</a>.",
      gemsTitle: "💎 Gems",
      gemsInstallBtn: "Installieren",
      gemsCachedTip: "lokal zwischengespeichert – installiert sofort",
      gemsNote: "Pure-Ruby-Gems von rubygems.org, direkt im Browser installiert. ⚡ = lokal zwischengespeichert. Gems mit C-Code (z.&nbsp;B. nokogiri) funktionieren hier nicht.",
      gemInstalled: "💎 %s installiert! Jetzt einfach mit <code>require</code> laden.",
      nativeGem: "%s enthält C-Code (eine „native extension“) und kann nicht zur Laufzeit im Browser installiert werden. Solche Gems müssen beim Bauen der ruby.wasm-Datei fest einkompiliert werden – so macht es z. B. Evil Martians' TutorialKit.rb.",
      gemNotFound: "Gem „%s“ wurde nicht gefunden (oder der Download schlug fehl).",
      browserGo: "Los",
      irbExitNote: "(Auf deinem Computer wäre IRB jetzt beendet – hier darfst du einfach weitertippen. 🦊)",
      footerCredit: "Ein Angebot von <a href='https://idogawa.com'>Andi Idogawa</a>. Läuft komplett in deinem Browser dank <a href='https://github.com/ruby/ruby.wasm'>ruby.wasm</a>. Schon fertig? Weiter geht's mit den <a href='https://koans.idogawa.com'>Ruby Koans</a>.",
      footerLicense: "„Chunky Bacon“ stammt aus why's (poignant) guide to Ruby von why the lucky stiff – in liebevoller Erinnerung. Kursinhalte: CC BY-NC-SA 4.0."
    },
    en: {
      title: "Learn Ruby with Chunky Bacon",
      subtitle: "A Ruby notebook in your browser – no setup, just start typing.",
      runCell: "▶ Run",
      reset: "Reset lesson",
      taskLabel: "Task",
      loading: "Loading Ruby … (one-time, about 35 MB)",
      welcome: "Hi! I'm <strong>Chunky Bacon</strong>, your fox companion. 🦊🥓 This page is a <strong>notebook</strong>: run every code cell with <em>▶ Run</em> or <kbd>Shift</kbd>+<kbd>Enter</kbd> – Ruby automatically shows the value of the last line as <code>=&gt;</code>. The cell with the orange border is your task. Let's go!",
      resetConfirm: "Reset all cells of this lesson?",
      praise: [
        "CHUNKY BACON! 🥓 That's it!",
        "Nice! The foxes cheer: CHUNKY BACON!",
        "Perfect! You are on the path to Ruby enlightenment.",
        "Excellent! Matz would be proud.",
        "Wonderful! Keep going!"
      ],
      failIntro: "Hmm, that's not quite right yet.",
      errorIntro: "Ouch, Ruby reports an error – check below the cell.",
      nextLesson: "→ On to the next lesson",
      progress: "Lesson %d of %d",
      allDone: "🎉 You finished all lessons! CHUNKY BACON! As a next step, try the <a href='https://koans.idogawa.com'>Ruby Koans in the browser</a>.",
      gemsTitle: "💎 Gems",
      gemsInstallBtn: "Install",
      gemsCachedTip: "cached locally – installs instantly",
      gemsNote: "Pure-Ruby gems from rubygems.org, installed right in your browser. ⚡ = cached locally. Gems with C code (e.g. nokogiri) do not work here.",
      gemInstalled: "💎 %s installed! Now just load it with <code>require</code>.",
      nativeGem: "%s contains C code (a “native extension”) and cannot be installed at runtime in the browser. Such gems must be compiled into the ruby.wasm binary itself – that is how Evil Martians' TutorialKit.rb does it.",
      gemNotFound: "Gem “%s” was not found (or the download failed).",
      browserGo: "Go",
      irbExitNote: "(On your computer IRB would have quit now – here you can just keep typing. 🦊)",
      footerCredit: "A service by <a href='https://idogawa.com'>Andi Idogawa</a>. Runs entirely in your browser thanks to <a href='https://github.com/ruby/ruby.wasm'>ruby.wasm</a>. Done here? Continue with the <a href='https://koans.idogawa.com'>Ruby Koans</a>.",
      footerLicense: "“Chunky Bacon” comes from why's (poignant) guide to Ruby by why the lucky stiff – fondly remembered. Course content: CC BY-NC-SA 4.0."
    }
  },
  lessons: [
    {
      id: "hallo",
      de: {
        title: "1. Hallo, Welt!",
        cells: [
          { t: "h", html: "<h2>Hallo, Welt!</h2><p>Ruby ist eine Programmiersprache, die für <strong>Menschen</strong> gemacht ist. Ihr Erfinder Yukihiro „Matz“ Matsumoto wollte, dass Programmieren Freude macht.</p><p>Diese Seite funktioniert wie ein <strong>Notizbuch</strong>: Sie besteht aus Text und Code-Zellen. Jede Zelle kannst du verändern und mit <em>▶ Ausführen</em> oder <kbd>Shift</kbd>+<kbd>Enter</kbd> laufen lassen. Probier es gleich aus:</p>" },
          { t: "c", code: "1 + 1" },
          { t: "h", html: "<p>Unter der Zelle erscheint <code>=&gt; 2</code>. Das <code>=&gt;</code> zeigt den <strong>Wert der letzten Zeile</strong> – Ruby macht das automatisch, ganz ohne Extra-Befehl.</p><p>Wenn du Text ausdrücklich <em>ausgeben</em> willst, nimm <code>puts</code> („put string“):</p>" },
          { t: "c", code: "puts \"Chunky Bacon!\"" },
          { t: "h", html: "<p>Der Text zwischen den Anführungszeichen heisst <strong>String</strong> (Zeichenkette). <code>puts</code> schreibt ihn in die Ausgabe. Übrigens: <code>puts</code> selbst hat den Wert <code>nil</code> – „nichts“ – darum siehst du hier keine <code>=&gt;</code>-Zeile.</p><div class='task'><strong>Aufgabe:</strong> Bring die Zelle unten dazu, <code>Hallo, Welt!</code> zu zeigen – mit <code>puts</code> oder einfach als Wert der letzten Zeile.</div>" },
          { t: "x", code: "# Dein Code:\n",
            check: "output.include?(\"Hallo, Welt!\") || result == \"Hallo, Welt!\"",
            hint: "Schreibe <code>puts \"Hallo, Welt!\"</code> – oder einfach <code>\"Hallo, Welt!\"</code> als letzte Zeile." }
        ]
      },
      en: {
        title: "1. Hello, World!",
        cells: [
          { t: "h", html: "<h2>Hello, World!</h2><p>Ruby is a programming language made for <strong>humans</strong>. Its creator Yukihiro “Matz” Matsumoto wanted programming to be joyful.</p><p>This page works like a <strong>notebook</strong>: it consists of text and code cells. You can edit every cell and run it with <em>▶ Run</em> or <kbd>Shift</kbd>+<kbd>Enter</kbd>. Try it right away:</p>" },
          { t: "c", code: "1 + 1" },
          { t: "h", html: "<p>Below the cell you see <code>=&gt; 2</code>. The <code>=&gt;</code> shows the <strong>value of the last line</strong> – Ruby does that automatically, no extra command needed.</p><p>If you want to explicitly <em>print</em> text, use <code>puts</code> (“put string”):</p>" },
          { t: "c", code: "puts \"Chunky Bacon!\"" },
          { t: "h", html: "<p>The text between the quotes is called a <strong>string</strong>. <code>puts</code> writes it to the output. By the way: <code>puts</code> itself has the value <code>nil</code> – “nothing” – which is why there is no <code>=&gt;</code> line here.</p><div class='task'><strong>Task:</strong> Make the cell below show <code>Hello, World!</code> – with <code>puts</code> or simply as the value of the last line.</div>" },
          { t: "x", code: "# Your code:\n",
            check: "output.include?(\"Hello, World!\") || result == \"Hello, World!\"",
            hint: "Write <code>puts \"Hello, World!\"</code> – or simply <code>\"Hello, World!\"</code> as the last line." }
        ]
      }
    },
    {
      id: "rechnen",
      de: {
        title: "2. Rechnen",
        cells: [
          { t: "h", html: "<h2>Ruby als Taschenrechner</h2><p>Ruby rechnet mit <code>+</code>, <code>-</code>, <code>*</code> (mal) und <code>/</code> (geteilt). Führ die Zelle aus – und ändere die Zahlen ruhig:</p>" },
          { t: "c", code: "3 + 4" },
          { t: "h", html: "<p>Alles hinter <code>#</code> ist ein <strong>Kommentar</strong> – Ruby ignoriert ihn. Kommentare sind Notizen für Menschen (und Füchse):</p>" },
          { t: "c", code: "5 * 5   # fünf mal fünf" },
          { t: "h", html: "<div class='task'><strong>Aufgabe:</strong> Wie viel ist 6 mal 7? Lass Ruby rechnen: Die Zelle soll das Ergebnis von <code>6 * 7</code> zeigen. (Nicht selbst rechnen – das ist ja der Witz!)</div>" },
          { t: "x", code: "",
            check: "(output.include?(\"42\") || result == 42) && code.include?(\"*\")",
            hint: "Schreibe einfach <code>6 * 7</code> in die Zelle. Der Stern <code>*</code> bedeutet „mal“." }
        ]
      },
      en: {
        title: "2. Arithmetic",
        cells: [
          { t: "h", html: "<h2>Ruby as a calculator</h2><p>Ruby calculates with <code>+</code>, <code>-</code>, <code>*</code> (times) and <code>/</code> (divided by). Run the cell – and feel free to change the numbers:</p>" },
          { t: "c", code: "3 + 4" },
          { t: "h", html: "<p>Everything after <code>#</code> is a <strong>comment</strong> – Ruby ignores it. Comments are notes for humans (and foxes):</p>" },
          { t: "c", code: "5 * 5   # five times five" },
          { t: "h", html: "<div class='task'><strong>Task:</strong> What is 6 times 7? Let Ruby do the math: the cell should show the result of <code>6 * 7</code>. (Don't compute it yourself – that's the whole point!)</div>" },
          { t: "x", code: "",
            check: "(output.include?(\"42\") || result == 42) && code.include?(\"*\")",
            hint: "Simply write <code>6 * 7</code> into the cell. The star <code>*</code> means “times”." }
        ]
      }
    },
    {
      id: "variablen",
      de: {
        title: "3. Variablen",
        cells: [
          { t: "h", html: "<h2>Variablen – Dinge beim Namen nennen</h2><p>Eine <strong>Variable</strong> ist ein Name für einen Wert. Mit <code>=</code> weist du ihn zu. Variablennamen schreibt man klein, mit Unterstrichen: <code>lieblings_essen</code>, <code>anzahl_streifen</code>.</p>" },
          { t: "c", code: "essen = \"Speck\"\nmenge = 3\nessen" },
          { t: "h", html: "<p>Die Zellen einer Lektion teilen sich ihren Speicher – wie in einem echten Notizbuch. Die Variable <code>menge</code> von oben kannst du hier weiterverwenden. (Kommt ein Fehler? Dann führe zuerst die Zelle darüber aus.)</p>" },
          { t: "c", code: "menge * 2" },
          { t: "h", html: "<div class='task'><strong>Aufgabe:</strong> Lege zwei Variablen an: <code>name</code> mit deinem Namen (ein String) und <code>alter</code> mit einer Zahl.</div>" },
          { t: "x", code: "# name = ...\n# alter = ...\n",
            check: "name.is_a?(String) && !name.empty? && alter.is_a?(Integer)",
            hint: "Zum Beispiel: <code>name = \"Kaz\"</code> und <code>alter = 7</code>." }
        ]
      },
      en: {
        title: "3. Variables",
        cells: [
          { t: "h", html: "<h2>Variables – naming things</h2><p>A <strong>variable</strong> is a name for a value. You assign it with <code>=</code>. Variable names are lowercase, with underscores: <code>favorite_food</code>, <code>bacon_strips</code>.</p>" },
          { t: "c", code: "food = \"bacon\"\namount = 3\nfood" },
          { t: "h", html: "<p>The cells of a lesson share their memory – like in a real notebook. You can reuse the variable <code>amount</code> from above here. (Getting an error? Run the cell above first.)</p>" },
          { t: "c", code: "amount * 2" },
          { t: "h", html: "<div class='task'><strong>Task:</strong> Create two variables: <code>name</code> with your name (a string) and <code>age</code> with a number.</div>" },
          { t: "x", code: "# name = ...\n# age = ...\n",
            check: "name.is_a?(String) && !name.empty? && age.is_a?(Integer)",
            hint: "For example: <code>name = \"Kaz\"</code> and <code>age = 7</code>." }
        ]
      }
    },
    {
      id: "strings",
      de: {
        title: "4. Strings verketten",
        cells: [
          { t: "h", html: "<h2>Strings und Interpolation</h2><p>Du kannst Variablen direkt in einen String einbauen – das heisst <strong>Interpolation</strong> und funktioniert mit <code>#{}</code> in doppelten Anführungszeichen:</p>" },
          { t: "c", code: "tier = \"Fuchs\"\n\"Der #{tier} ruft!\"" },
          { t: "h", html: "<p>Ruby wertet aus, was zwischen <code>#{</code> und <code>}</code> steht, und setzt das Ergebnis ein. Es darf auch gerechnet werden:</p>" },
          { t: "c", code: "\"#{3 * 7} Streifen Speck\"" },
          { t: "h", html: "<div class='task'><strong>Aufgabe:</strong> Unten ist die Variable <code>lieblingsessen</code> vorbereitet. Baue mit Interpolation den Satz <code>Ich mag Chunky Bacon!</code> – die Variable gehört mit <code>#{}</code> in den String.</div>" },
          { t: "x", code: "lieblingsessen = \"Chunky Bacon\"\n# \"Ich mag ...!\"\n",
            check: "(output.include?(\"Ich mag Chunky Bacon!\") || result == \"Ich mag Chunky Bacon!\") && code.include?('#{')",
            hint: "Schreibe <code>\"Ich mag #{lieblingsessen}!\"</code> als letzte Zeile – mit doppelten Anführungszeichen." }
        ]
      },
      en: {
        title: "4. String interpolation",
        cells: [
          { t: "h", html: "<h2>Strings and interpolation</h2><p>You can embed variables right inside a string – that's called <strong>interpolation</strong> and works with <code>#{}</code> inside double quotes:</p>" },
          { t: "c", code: "animal = \"fox\"\n\"The #{animal} shouts!\"" },
          { t: "h", html: "<p>Ruby evaluates whatever is between <code>#{</code> and <code>}</code> and inserts the result. Math works too:</p>" },
          { t: "c", code: "\"#{3 * 7} strips of bacon\"" },
          { t: "h", html: "<div class='task'><strong>Task:</strong> The variable <code>favorite_food</code> is prepared below. Use interpolation to build the sentence <code>I love Chunky Bacon!</code> – the variable goes into the string with <code>#{}</code>.</div>" },
          { t: "x", code: "favorite_food = \"Chunky Bacon\"\n# \"I love ...!\"\n",
            check: "(output.include?(\"I love Chunky Bacon!\") || result == \"I love Chunky Bacon!\") && code.include?('#{')",
            hint: "Write <code>\"I love #{favorite_food}!\"</code> as the last line – with double quotes." }
        ]
      }
    },
    {
      id: "wenn",
      de: {
        title: "5. Entscheidungen (if)",
        cells: [
          { t: "h", html: "<h2>Wenn … dann … sonst</h2><p>Mit <code>if</code> trifft dein Programm Entscheidungen. Vergleiche: <code>&gt;</code> grösser, <code>&lt;</code> kleiner, <code>==</code> gleich (zwei Gleichheitszeichen!), <code>!=</code> ungleich. Jeder <code>if</code>-Block endet mit <code>end</code>.</p>" },
          { t: "c", code: "hunger = 9\nif hunger > 7\n  \"Zeit für Speck!\"\nelse\n  \"Alles gut.\"\nend" },
          { t: "h", html: "<p>Sogar <code>if</code> hat in Ruby einen Wert: den Zweig, der gewonnen hat. Ändere <code>hunger</code> auf <code>3</code> und führ die Zelle nochmal aus!</p><div class='task'><strong>Aufgabe:</strong> Unten steht <code>zahl = 7</code>. Die Zelle soll <code>gross</code> ergeben, wenn die Zahl grösser als 5 ist, sonst <code>klein</code> – als Wert oder mit <code>puts</code>.</div>" },
          { t: "x", code: "zahl = 7\n# if ...\n",
            check: "((output + result.to_s).include?(\"gross\") && !(output + result.to_s).include?(\"klein\")) && code.include?(\"if\")",
            hint: "So geht's: <code>if zahl > 5</code>, dann <code>\"gross\"</code>, dann <code>else</code>, <code>\"klein\"</code> und zum Schluss <code>end</code>." }
        ]
      },
      en: {
        title: "5. Decisions (if)",
        cells: [
          { t: "h", html: "<h2>If … then … else</h2><p>With <code>if</code> your program makes decisions. Comparisons: <code>&gt;</code> greater, <code>&lt;</code> less, <code>==</code> equal (two equals signs!), <code>!=</code> not equal. Every <code>if</code> block ends with <code>end</code>.</p>" },
          { t: "c", code: "hunger = 9\nif hunger > 7\n  \"Time for bacon!\"\nelse\n  \"All good.\"\nend" },
          { t: "h", html: "<p>Even <code>if</code> has a value in Ruby: the branch that won. Change <code>hunger</code> to <code>3</code> and run the cell again!</p><div class='task'><strong>Task:</strong> Below you have <code>number = 7</code>. The cell should yield <code>big</code> if the number is greater than 5, otherwise <code>small</code> – as a value or with <code>puts</code>.</div>" },
          { t: "x", code: "number = 7\n# if ...\n",
            check: "((output + result.to_s).include?(\"big\") && !(output + result.to_s).include?(\"small\")) && code.include?(\"if\")",
            hint: "Like this: <code>if number > 5</code>, then <code>\"big\"</code>, then <code>else</code>, <code>\"small\"</code> and finally <code>end</code>." }
        ]
      }
    },
    {
      id: "schleifen",
      de: {
        title: "6. Schleifen",
        cells: [
          { t: "h", html: "<h2>Schleifen – Dinge wiederholen</h2><p>In why's legendärem Ruby-Buch rufen zwei Comic-Füchse immer wieder: <em>„Chunky Bacon!“</em> – Wiederholung ist in Ruby wunderbar einfach:</p>" },
          { t: "c", code: "3.times do\n  puts \"Chunky Bacon!\"\nend" },
          { t: "h", html: "<p>Der Code zwischen <code>do</code> und <code>end</code> heisst <strong>Block</strong> und wird hier dreimal ausgeführt. (Das <code>=&gt; 3</code> darunter ist der Wert von <code>3.times</code> selbst.) Mit Zähler geht es auch:</p>" },
          { t: "c", code: "3.times do |i|\n  puts \"Streifen Nummer #{i + 1}\"\nend" },
          { t: "h", html: "<div class='task'><strong>Aufgabe:</strong> Gib <code>Chunky Bacon!</code> genau fünfmal aus – mit einer Schleife, nicht mit fünf <code>puts</code>-Zeilen.</div>" },
          { t: "x", code: "# 5 mal Chunky Bacon, bitte!\n",
            check: "((output + result.inspect).scan(\"Chunky Bacon!\").length >= 5) && (code.include?(\"times\") || code.include?(\"each\") || code.include?(\"while\") || code.include?(\"upto\") || code.include?(\"for \"))",
            hint: "Schreibe <code>5.times do</code> … <code>puts \"Chunky Bacon!\"</code> … <code>end</code>." }
        ]
      },
      en: {
        title: "6. Loops",
        cells: [
          { t: "h", html: "<h2>Loops – repeating things</h2><p>In why's legendary Ruby book two cartoon foxes keep shouting: <em>“Chunky Bacon!”</em> – repetition is delightfully easy in Ruby:</p>" },
          { t: "c", code: "3.times do\n  puts \"Chunky Bacon!\"\nend" },
          { t: "h", html: "<p>The code between <code>do</code> and <code>end</code> is called a <strong>block</strong> and runs three times here. (The <code>=&gt; 3</code> below is the value of <code>3.times</code> itself.) With a counter it looks like this:</p>" },
          { t: "c", code: "3.times do |i|\n  puts \"Strip number #{i + 1}\"\nend" },
          { t: "h", html: "<div class='task'><strong>Task:</strong> Print <code>Chunky Bacon!</code> exactly five times – with a loop, not with five <code>puts</code> lines.</div>" },
          { t: "x", code: "# 5 times Chunky Bacon, please!\n",
            check: "((output + result.inspect).scan(\"Chunky Bacon!\").length >= 5) && (code.include?(\"times\") || code.include?(\"each\") || code.include?(\"while\") || code.include?(\"upto\") || code.include?(\"for \"))",
            hint: "Write <code>5.times do</code> … <code>puts \"Chunky Bacon!\"</code> … <code>end</code>." }
        ]
      }
    },
    {
      id: "arrays",
      de: {
        title: "7. Arrays",
        cells: [
          { t: "h", html: "<h2>Arrays – Listen von Dingen</h2><p>Ein <strong>Array</strong> ist eine Liste. Es wird mit eckigen Klammern geschrieben:</p>" },
          { t: "c", code: "fruehstueck = [\"Ei\", \"Brot\"]\nfruehstueck.length" },
          { t: "h", html: "<p>Mit eckigen Klammern greifst du auf ein Element zu – die Zählung beginnt bei 0!</p>" },
          { t: "c", code: "fruehstueck[0]" },
          { t: "h", html: "<p>Mit <code>&lt;&lt;</code> („Schaufel“) hängst du etwas hinten an, mit <code>each</code> gehst du alles durch:</p>" },
          { t: "c", code: "fruehstueck << \"Kaffee\"\nfruehstueck.each do |sache|\n  puts sache\nend" },
          { t: "h", html: "<div class='task'><strong>Aufgabe:</strong> Häng an das Array unten <code>\"Speck\"</code> an. Bonus: gib alle Elemente mit <code>each</code> aus.</div>" },
          { t: "x", code: "fruehstueck = [\"Ei\", \"Brot\"]\n# ...\n",
            check: "fruehstueck.is_a?(Array) && fruehstueck.include?(\"Speck\") && fruehstueck.include?(\"Ei\")",
            hint: "Schreibe <code>fruehstueck << \"Speck\"</code> unter die erste Zeile." }
        ]
      },
      en: {
        title: "7. Arrays",
        cells: [
          { t: "h", html: "<h2>Arrays – lists of things</h2><p>An <strong>array</strong> is a list. You write it with square brackets:</p>" },
          { t: "c", code: "breakfast = [\"egg\", \"toast\"]\nbreakfast.length" },
          { t: "h", html: "<p>With square brackets you access an element – counting starts at 0!</p>" },
          { t: "c", code: "breakfast[0]" },
          { t: "h", html: "<p>With <code>&lt;&lt;</code> (the “shovel”) you append to the end, with <code>each</code> you walk through it:</p>" },
          { t: "c", code: "breakfast << \"coffee\"\nbreakfast.each do |item|\n  puts item\nend" },
          { t: "h", html: "<div class='task'><strong>Task:</strong> Append <code>\"bacon\"</code> to the array below. Bonus: print every element with <code>each</code>.</div>" },
          { t: "x", code: "breakfast = [\"egg\", \"toast\"]\n# ...\n",
            check: "breakfast.is_a?(Array) && breakfast.include?(\"bacon\") && breakfast.include?(\"egg\")",
            hint: "Write <code>breakfast << \"bacon\"</code> below the first line." }
        ]
      }
    },
    {
      id: "hashes",
      de: {
        title: "8. Hashes",
        cells: [
          { t: "h", html: "<h2>Hashes – Nachschlagewerke</h2><p>Ein <strong>Hash</strong> ordnet Schlüsseln Werte zu, wie ein kleines Wörterbuch. Die Schlüssel wie <code>:name</code> heissen <strong>Symbole</strong> – leichtgewichtige Namen mit Doppelpunkt.</p>" },
          { t: "c", code: "tier = { name: \"Chunky\", essen: \"Speck\" }\ntier[:name]" },
          { t: "h", html: "<p>Probiere auch <code>tier[:essen]</code> – oder einen Schlüssel, den es nicht gibt: dann bekommst du <code>nil</code>.</p><div class='task'><strong>Aufgabe:</strong> Baue einen Hash <code>fuchs</code> mit den Schlüsseln <code>:name</code> und <code>:essen</code> (Werte darfst du wählen).</div>" },
          { t: "x", code: "# fuchs = { ... }\n",
            check: "fuchs.is_a?(Hash) && fuchs[:name].to_s.length > 0 && fuchs[:essen].to_s.length > 0",
            hint: "Zum Beispiel: <code>fuchs = { name: \"Chunky\", essen: \"Speck\" }</code>." }
        ]
      },
      en: {
        title: "8. Hashes",
        cells: [
          { t: "h", html: "<h2>Hashes – lookup tables</h2><p>A <strong>hash</strong> maps keys to values, like a little dictionary. Keys like <code>:name</code> are <strong>symbols</strong> – lightweight names with a colon.</p>" },
          { t: "c", code: "animal = { name: \"Chunky\", food: \"bacon\" }\nanimal[:name]" },
          { t: "h", html: "<p>Also try <code>animal[:food]</code> – or a key that doesn't exist: then you get <code>nil</code>.</p><div class='task'><strong>Task:</strong> Build a hash <code>fox</code> with the keys <code>:name</code> and <code>:food</code> (pick any values).</div>" },
          { t: "x", code: "# fox = { ... }\n",
            check: "fox.is_a?(Hash) && fox[:name].to_s.length > 0 && fox[:food].to_s.length > 0",
            hint: "For example: <code>fox = { name: \"Chunky\", food: \"bacon\" }</code>." }
        ]
      }
    },
    {
      id: "methoden",
      de: {
        title: "9. Methoden",
        cells: [
          { t: "h", html: "<h2>Eigene Methoden schreiben</h2><p>Mit <code>def</code> definierst du eine <strong>Methode</strong> – ein Stück Code mit Namen, das du beliebig oft aufrufen kannst:</p>" },
          { t: "c", code: "def begruessung(name)\n  \"Hallo, #{name}!\"\nend\n\nbegruessung(\"Kaz\")" },
          { t: "h", html: "<p>Der Wert der <em>letzten Zeile</em> einer Methode ist automatisch ihr Rückgabewert – ein <code>return</code> ist meist unnötig. Das ist sehr rubyisch.</p><div class='task'><strong>Aufgabe:</strong> Schreibe eine Methode <code>quadrat(zahl)</code>, die die Zahl mit sich selbst multipliziert zurückgibt. Teste sie: <code>quadrat(9)</code> als letzte Zeile.</div>" },
          { t: "x", code: "# def quadrat(zahl)\n#   ...\n# end\n\n# quadrat(9)\n",
            check: "quadrat(9) == 81 && quadrat(5) == 25 && code.include?(\"def\")",
            hint: "So geht's: <code>def quadrat(zahl)</code>, darunter <code>zahl * zahl</code>, dann <code>end</code>." }
        ]
      },
      en: {
        title: "9. Methods",
        cells: [
          { t: "h", html: "<h2>Writing your own methods</h2><p>With <code>def</code> you define a <strong>method</strong> – a named piece of code you can call as often as you like:</p>" },
          { t: "c", code: "def greeting(name)\n  \"Hello, #{name}!\"\nend\n\ngreeting(\"Kaz\")" },
          { t: "h", html: "<p>The value of a method's <em>last line</em> is automatically its return value – an explicit <code>return</code> is usually unnecessary. Very Ruby.</p><div class='task'><strong>Task:</strong> Write a method <code>square(number)</code> that returns the number multiplied by itself. Test it: <code>square(9)</code> as the last line.</div>" },
          { t: "x", code: "# def square(number)\n#   ...\n# end\n\n# square(9)\n",
            check: "square(9) == 81 && square(5) == 25 && code.include?(\"def\")",
            hint: "Like this: <code>def square(number)</code>, below it <code>number * number</code>, then <code>end</code>." }
        ]
      }
    },
    {
      id: "klassen",
      de: {
        title: "10. Klassen",
        cells: [
          { t: "h", html: "<h2>Klassen – eigene Dinge erschaffen</h2><p>In Ruby ist <em>alles</em> ein Objekt. Mit einer <strong>Klasse</strong> baust du deine eigenen Objekte:</p>" },
          { t: "c", code: "class Katze\n  attr_reader :name\n\n  def initialize(name)\n    @name = name\n  end\n\n  def ruf\n    \"Miau!\"\n  end\nend\n\nk = Katze.new(\"Mimi\")\nk.ruf" },
          { t: "h", html: "<p><code>initialize</code> läuft bei <code>Katze.new</code>. Variablen mit <code>@</code> gehören zum Objekt, und <code>attr_reader :name</code> macht <code>@name</code> von aussen lesbar – probiere <code>k.name</code>!</p><div class='task'><strong>Aufgabe:</strong> Schreibe nach diesem Vorbild die Klasse <code>Fuchs</code>: mit <code>initialize(name)</code>, <code>attr_reader :name</code> und einer Methode <code>ruf</code>, die <code>\"Chunky Bacon!\"</code> zurückgibt.</div>" },
          { t: "x", code: "# class Fuchs\n#   ...\n# end\n",
            check: "f = Fuchs.new(\"Kaz\"); f.name == \"Kaz\" && f.ruf == \"Chunky Bacon!\" && code.include?(\"class Fuchs\")",
            hint: "Übernimm das Katzen-Beispiel und pass es an: Klasse <code>Fuchs</code>, und <code>ruf</code> gibt genau <code>\"Chunky Bacon!\"</code> zurück." }
        ]
      },
      en: {
        title: "10. Classes",
        cells: [
          { t: "h", html: "<h2>Classes – creating your own things</h2><p>In Ruby, <em>everything</em> is an object. With a <strong>class</strong> you build objects of your own:</p>" },
          { t: "c", code: "class Cat\n  attr_reader :name\n\n  def initialize(name)\n    @name = name\n  end\n\n  def shout\n    \"Meow!\"\n  end\nend\n\nk = Cat.new(\"Mimi\")\nk.shout" },
          { t: "h", html: "<p><code>initialize</code> runs on <code>Cat.new</code>. Variables with <code>@</code> belong to the object, and <code>attr_reader :name</code> makes <code>@name</code> readable from outside – try <code>k.name</code>!</p><div class='task'><strong>Task:</strong> Following this example, write the class <code>Fox</code>: with <code>initialize(name)</code>, <code>attr_reader :name</code> and a method <code>shout</code> that returns <code>\"Chunky Bacon!\"</code>.</div>" },
          { t: "x", code: "# class Fox\n#   ...\n# end\n",
            check: "f = Fox.new(\"Kaz\"); f.name == \"Kaz\" && f.shout == \"Chunky Bacon!\" && code.include?(\"class Fox\")",
            hint: "Copy the cat example and adapt it: class <code>Fox</code>, and <code>shout</code> returns exactly <code>\"Chunky Bacon!\"</code>." }
        ]
      }
    },
    {
      id: "module",
      de: {
        title: "11. Module",
        cells: [
          { t: "h", html: "<h2>Module – Werkzeugkisten für Code</h2><p>Ein <strong>Modul</strong> ist eine benannte Kiste für Methoden und Konstanten. Anders als eine Klasse kann man von einem Modul keine Objekte erzeugen (<code>new</code> gibt es nicht) – Module haben zwei andere Jobs: <strong>Ordnung schaffen</strong> und <strong>Fähigkeiten teilen</strong>.</p><p>Du kennst schon einige: <code>Math</code> aus Rubys Standardbibliothek sammelt Mathe-Werkzeuge. An Konstanten kommst du mit <code>::</code>, Methoden rufst du mit Punkt auf:</p>" },
          { t: "c", code: "Math::PI" },
          { t: "c", code: "Math.sqrt(49)" },
          { t: "h", html: "<p><strong>Job 1 – Namensraum:</strong> Ein Modul gruppiert zusammengehörige Klassen unter einem Dach, damit sich Namen nicht in die Quere kommen. Genau darum heissen die Klassen aus früheren Lektionen <code>ChunkyPNG::Image</code> und <code>Sinatra::Base</code> – Klasse <code>Image</code> im Modul <code>ChunkyPNG</code>, Klasse <code>Base</code> im Modul <code>Sinatra</code>:</p>" },
          { t: "c", code: "module Wald\n  class Fuchs\n    def ruf\n      \"Chunky Bacon!\"\n    end\n  end\nend\n\nWald::Fuchs.new.ruf" },
          { t: "h", html: "<p><strong>Job 2 – Mixin:</strong> Mit <code>include</code> mischst du die Methoden eines Moduls in eine Klasse hinein – so teilen sich viele Klassen eine Fähigkeit, ohne voneinander zu erben:</p>" },
          { t: "c", code: "module Begruessung\n  def hallo\n    \"Hallo, ich bin #{name}!\"\n  end\nend\n\nclass Igel\n  include Begruessung\n\n  attr_reader :name\n\n  def initialize(name)\n    @name = name\n  end\nend\n\nIgel.new(\"Isi\").hallo" },
          { t: "h", html: "<p>So funktionieren auch Rubys berühmteste Mixins: <code>Comparable</code> schenkt einer Klasse <code>&lt;</code>, <code>&gt;</code> und <code>between?</code>, sobald sie <code>&lt;=&gt;</code> kann, und <code>Enumerable</code> schenkt ihr <code>map</code>, <code>select</code> &amp; Co., sobald sie <code>each</code> kann.</p><div class='task'><strong>Aufgabe:</strong> Schreibe ein Modul <code>Laut</code> mit einer Methode <code>ruf</code>, die <code>CHUNKY BACON!</code> zurückgibt. Mische es mit <code>include</code> in eine neue Klasse <code>Dachs</code> und probiere <code>Dachs.new.ruf</code> als letzte Zeile.</div>" },
          { t: "x", code: "# module Laut\n#   ...\n# end\n\n# class Dachs\n#   ...\n# end\n",
            check: "Laut.is_a?(Module) && !Laut.is_a?(Class) && Dachs.include?(Laut) && Dachs.new.ruf == \"CHUNKY BACON!\" && code.include?(\"include\")",
            hint: "<code>module Laut</code> mit <code>def ruf</code> … <code>\"CHUNKY BACON!\"</code> … dann <code>class Dachs</code> mit <code>include Laut</code> darin." }
        ]
      },
      en: {
        title: "11. Modules",
        cells: [
          { t: "h", html: "<h2>Modules – toolboxes for code</h2><p>A <strong>module</strong> is a named box for methods and constants. Unlike a class, a module cannot create objects (there is no <code>new</code>) – modules have two other jobs: <strong>keeping things organized</strong> and <strong>sharing abilities</strong>.</p><p>You already know some: <code>Math</code> from Ruby's standard library collects math tools. You reach constants with <code>::</code> and call methods with a dot:</p>" },
          { t: "c", code: "Math::PI" },
          { t: "c", code: "Math.sqrt(49)" },
          { t: "h", html: "<p><strong>Job 1 – namespace:</strong> A module groups related classes under one roof so names don't clash. That's exactly why the classes from earlier lessons are called <code>ChunkyPNG::Image</code> and <code>Sinatra::Base</code> – class <code>Image</code> inside module <code>ChunkyPNG</code>, class <code>Base</code> inside module <code>Sinatra</code>:</p>" },
          { t: "c", code: "module Forest\n  class Fox\n    def shout\n      \"Chunky Bacon!\"\n    end\n  end\nend\n\nForest::Fox.new.shout" },
          { t: "h", html: "<p><strong>Job 2 – mixin:</strong> With <code>include</code> you mix a module's methods into a class – that way many classes can share an ability without inheriting from each other:</p>" },
          { t: "c", code: "module Greeting\n  def hello\n    \"Hello, I am #{name}!\"\n  end\nend\n\nclass Hedgehog\n  include Greeting\n\n  attr_reader :name\n\n  def initialize(name)\n    @name = name\n  end\nend\n\nHedgehog.new(\"Izzy\").hello" },
          { t: "h", html: "<p>Ruby's most famous mixins work the same way: <code>Comparable</code> gives a class <code>&lt;</code>, <code>&gt;</code> and <code>between?</code> as soon as it can <code>&lt;=&gt;</code>, and <code>Enumerable</code> gives it <code>map</code>, <code>select</code> &amp; co. as soon as it can <code>each</code>.</p><div class='task'><strong>Task:</strong> Write a module <code>Loud</code> with a method <code>shout</code> that returns <code>CHUNKY BACON!</code>. Mix it into a new class <code>Badger</code> with <code>include</code> and try <code>Badger.new.shout</code> as the last line.</div>" },
          { t: "x", code: "# module Loud\n#   ...\n# end\n\n# class Badger\n#   ...\n# end\n",
            check: "Loud.is_a?(Module) && !Loud.is_a?(Class) && Badger.include?(Loud) && Badger.new.shout == \"CHUNKY BACON!\" && code.include?(\"include\")",
            hint: "<code>module Loud</code> with <code>def shout</code> … <code>\"CHUNKY BACON!\"</code> … then <code>class Badger</code> with <code>include Loud</code> inside." }
        ]
      }
    },
    {
      id: "irb",
      de: {
        title: "12. IRB – Rubys Spielwiese",
        cells: [
          { t: "h", html: "<h2>IRB – Rubys Spielwiese</h2><p>Auf jedem Computer mit Ruby ist <strong>IRB</strong> schon dabei („Interactive RuBy“). Du startest es, indem du im Terminal <code>irb</code> tippst – dann fütterst du Ruby Zeile für Zeile, und wie in diesem Notizbuch zeigt IRB nach jeder Zeile den Wert mit <code>=&gt;</code>:</p><pre><code>$ irb\nirb(main):001:0&gt; 1 + 1\n=&gt; 2\nirb(main):002:0&gt; \"Chunky \" + \"Bacon!\"\n=&gt; \"Chunky Bacon!\"</code></pre><p>Rubyisten haben IRB ständig offen: zum Ausprobieren, Rechnen und Nachschauen, was eine Methode wohl zurückgibt. Hier ist eine <strong>echte IRB-Sitzung</strong> für dich – tippe unten ins Terminal und drücke <kbd>Enter</kbd>:</p>" },
          { t: "c", code: "show_irb" },
          { t: "h", html: "<p>Drei Tricks, die jeder IRB-Profi kennt – probier sie oben aus:</p><ul><li><code>_</code> (Unterstrich) ist immer die <strong>letzte Antwort</strong>: erst <code>6 * 7</code>, dann <code>_ + 1</code>.</li><li>IRB versteht <strong>mehrzeilige Eingaben</strong>: Tippe <code>def verdoppeln(x)</code> – der Prompt bekommt ein <code>*</code> und wartet, bis du <code>x * 2</code> und <code>end</code> nachgeliefert hast.</li><li><code>exit</code> beendet IRB (auf deinem Rechner … hier bleibt der Fuchs stur).</li></ul><div class='task'><strong>Aufgabe:</strong> Benutze die Zelle unten wie eine IRB-Zeile: Verdreifache jede Zahl im Array <code>[4, 8, 15]</code> mit <code>map</code> – der Wert soll <code>[12, 24, 45]</code> sein. (Erst oben im Terminal ausprobieren!)</div>" },
          { t: "x", code: "# [4, 8, 15].map { |x| ... }\n",
            check: "result == [12, 24, 45] && code.include?(\"map\")",
            hint: "Schreibe <code>[4, 8, 15].map { |x| x * 3 }</code> als letzte Zeile – <code>map</code> baut aus jedem Element ein neues Array." }
        ]
      },
      en: {
        title: "12. IRB – Ruby's playground",
        cells: [
          { t: "h", html: "<h2>IRB – Ruby's playground</h2><p>Every computer with Ruby already ships with <strong>IRB</strong> (“Interactive RuBy”). You start it by typing <code>irb</code> into a terminal – then you feed Ruby one line at a time, and just like this notebook IRB shows each line's value with <code>=&gt;</code>:</p><pre><code>$ irb\nirb(main):001:0&gt; 1 + 1\n=&gt; 2\nirb(main):002:0&gt; \"Chunky \" + \"Bacon!\"\n=&gt; \"Chunky Bacon!\"</code></pre><p>Rubyists keep IRB open all the time: for experiments, quick math, and checking what a method returns. Here is a <strong>real IRB session</strong> for you – type into the terminal below and press <kbd>Enter</kbd>:</p>" },
          { t: "c", code: "show_irb" },
          { t: "h", html: "<p>Three tricks every IRB pro knows – try them above:</p><ul><li><code>_</code> (underscore) is always the <strong>last answer</strong>: first <code>6 * 7</code>, then <code>_ + 1</code>.</li><li>IRB understands <strong>multi-line input</strong>: type <code>def double(x)</code> – the prompt gets a <code>*</code> and waits until you deliver <code>x * 2</code> and <code>end</code>.</li><li><code>exit</code> quits IRB (on your machine … here the fox refuses to leave).</li></ul><div class='task'><strong>Task:</strong> Use the cell below like an IRB line: triple every number in the array <code>[4, 8, 15]</code> using <code>map</code> – the value should be <code>[12, 24, 45]</code>. (Experiment in the terminal above first!)</div>" },
          { t: "x", code: "# [4, 8, 15].map { |x| ... }\n",
            check: "result == [12, 24, 45] && code.include?(\"map\")",
            hint: "Write <code>[4, 8, 15].map { |x| x * 3 }</code> as the last line – <code>map</code> builds a new array from every element." }
        ]
      }
    },
    {
      id: "gems",
      de: {
        title: "13. Gems installieren",
        cells: [
          { t: "h", html: "<h2>Gems – Rubys Bausteine</h2><p>Eine <strong>Gem</strong> ist ein fertiges Ruby-Paket, das du in dein Programm laden kannst. Die zentrale Sammelstelle ist <a href='https://rubygems.org' target='_blank'>rubygems.org</a> – über 180&nbsp;000 Gems für alles Mögliche.</p><p>Auf deinem eigenen Computer installierst du eine Gem im Terminal mit <code>gem install</code> und lädst sie danach in IRB oder deinem Programm mit <code>require</code>:</p><pre><code>$ gem install chunky_png\nSuccessfully installed chunky_png-1.4.0\n$ irb\nirb(main):001:0&gt; require \"chunky_png\"\n=&gt; true</code></pre><p>In richtigen Projekten listet man alle Gems in einer Datei namens <code>Gemfile</code> (eine Zeile pro Gem: <code>gem \"chunky_png\"</code>) und holt sie mit <code>bundle install</code> auf einen Schlag – das erledigt <a href='https://bundler.io' target='_blank'>Bundler</a>.</p><p>Auf dieser Seite übernimmt <code>install_gem</code> diesen Job für <em>pure-Ruby</em>-Gems, direkt im Browser (oder du nutzt das 💎-Panel links). Häufig gebrauchte Gems sind lokal zwischengespeichert (⚡) und installieren blitzschnell:</p>" },
          { t: "c", code: "install_gem \"chunky_png\"" },
          { t: "h", html: "<p><code>chunky_png</code> – der Name ist natürlich kein Zufall, liebe Füchse! 🥓 – erstellt PNG-Bilder in purem Ruby. Nach der Installation lädst du es ganz normal mit <code>require</code>. Und mit <code>show_image</code> zeigst du ein Bild direkt unter der Zelle an:</p>" },
          { t: "c", code: "require \"chunky_png\"\n\nbild = ChunkyPNG::Image.new(8, 8, ChunkyPNG::Color::WHITE)\n8.times { |i| bild[i, i] = ChunkyPNG::Color.rgb(232, 114, 42) }\nshow_image bild" },
          { t: "h", html: "<p>Jeder Pixel ist ansprechbar: <code>bild[x, y] = farbe</code>. Farben baust du mit <code>ChunkyPNG::Color.rgb(rot, gruen, blau)</code>.</p><div class='task'><strong>Aufgabe:</strong> Male die Speck-Fahne! Erzeuge ein Bild <code>bild</code> (mindestens 8×8) und färbe die geraden Zeilen speckrot – <code>ChunkyPNG::Color.rgb(193, 74, 46)</code> –, die ungeraden lässt du weiss. Zeig dein Werk mit <code>show_image bild</code>.</div>" },
          { t: "x", code: "install_gem \"chunky_png\"\nrequire \"chunky_png\"\n\n# bild = ChunkyPNG::Image.new(8, 8, ChunkyPNG::Color::WHITE)\n# ...\n# show_image bild\n",
            check: "defined?(ChunkyPNG) && bild.is_a?(ChunkyPNG::Image) && bild.width >= 8 && bild.pixels.include?(ChunkyPNG::Color.rgb(193, 74, 46)) && images.length >= 1",
            hint: "Zum Beispiel: <code>8.times do |y|</code> … wenn <code>y.even?</code>, dann <code>8.times { |x| bild[x, y] = ChunkyPNG::Color.rgb(193, 74, 46) }</code> … <code>end</code> – und am Ende <code>show_image bild</code>." }
        ]
      },
      en: {
        title: "13. Installing gems",
        cells: [
          { t: "h", html: "<h2>Gems – Ruby's building blocks</h2><p>A <strong>gem</strong> is a ready-made Ruby package you can load into your program. The central collection is <a href='https://rubygems.org' target='_blank'>rubygems.org</a> – over 180,000 gems for everything imaginable.</p><p>On your own computer you install a gem in the terminal with <code>gem install</code>, then load it in IRB or your program with <code>require</code>:</p><pre><code>$ gem install chunky_png\nSuccessfully installed chunky_png-1.4.0\n$ irb\nirb(main):001:0&gt; require \"chunky_png\"\n=&gt; true</code></pre><p>In real projects you list all gems in a file called <code>Gemfile</code> (one line per gem: <code>gem \"chunky_png\"</code>) and fetch them in one go with <code>bundle install</code> – that's <a href='https://bundler.io' target='_blank'>Bundler</a>'s job.</p><p>On this site, <code>install_gem</code> does that job for <em>pure-Ruby</em> gems, right in your browser (or use the 💎 panel on the left). Frequently used gems are cached locally (⚡) and install instantly:</p>" },
          { t: "c", code: "install_gem \"chunky_png\"" },
          { t: "h", html: "<p><code>chunky_png</code> – the name is no coincidence, dear foxes! 🥓 – creates PNG images in pure Ruby. After installing you load it with a normal <code>require</code>. And <code>show_image</code> displays a picture right below the cell:</p>" },
          { t: "c", code: "require \"chunky_png\"\n\nimage = ChunkyPNG::Image.new(8, 8, ChunkyPNG::Color::WHITE)\n8.times { |i| image[i, i] = ChunkyPNG::Color.rgb(232, 114, 42) }\nshow_image image" },
          { t: "h", html: "<p>Every pixel is addressable: <code>image[x, y] = color</code>. You build colors with <code>ChunkyPNG::Color.rgb(red, green, blue)</code>.</p><div class='task'><strong>Task:</strong> Paint the bacon flag! Create an image <code>image</code> (at least 8×8) and color the even rows bacon-red – <code>ChunkyPNG::Color.rgb(193, 74, 46)</code> – leaving the odd rows white. Show your work with <code>show_image image</code>.</div>" },
          { t: "x", code: "install_gem \"chunky_png\"\nrequire \"chunky_png\"\n\n# image = ChunkyPNG::Image.new(8, 8, ChunkyPNG::Color::WHITE)\n# ...\n# show_image image\n",
            check: "defined?(ChunkyPNG) && image.is_a?(ChunkyPNG::Image) && image.width >= 8 && image.pixels.include?(ChunkyPNG::Color.rgb(193, 74, 46)) && images.length >= 1",
            hint: "For example: <code>8.times do |y|</code> … if <code>y.even?</code>, then <code>8.times { |x| image[x, y] = ChunkyPNG::Color.rgb(193, 74, 46) }</code> … <code>end</code> – and finally <code>show_image image</code>." }
        ]
      }
    },
    {
      id: "html",
      de: {
        title: "14. HTML parsen",
        cells: [
          { t: "h", html: "<h2>HTML parsen – wie die Profis</h2><p>Ruby wird oft benutzt, um Webseiten auszulesen (<em>Scraping</em>). Das berühmteste Werkzeug dafür heisst <strong>Nokogiri</strong>:</p><pre><code>require \"nokogiri\"\ndoc = Nokogiri::HTML(html)\ndoc.css(\"a\").each { |link| puts link.text }</code></pre><p>Nokogiri ist aber zu grossen Teilen in <strong>C</strong> geschrieben. Hier im Browser läuft Ruby als WebAssembly, und dort lassen sich zur Laufzeit nur pure-Ruby-Gems installieren – C-Gems müssten fest in die wasm-Datei einkompiliert werden. Probier ruhig aus, was passiert:</p>" },
          { t: "c", code: "install_gem \"nokogiri\"" },
          { t: "h", html: "<p>Zum Glück gibt es <code>gammo</code>, einen HTML5-Parser in purem Ruby. Die Ideen sind genau dieselben wie bei Nokogiri: erst <em>parsen</em> (aus Text wird ein Baum), dann mit <strong>CSS-Selektoren</strong> suchen:</p>" },
          { t: "c", code: "install_gem \"gammo\"\nrequire \"gammo\"\nrequire \"gammo/css_selector\"\n\nhtml = \"<html><body>\n  <h1>Speisekarte</h1>\n  <ul>\n    <li><a href='/speck'>Speck</a></li>\n    <li><a href='/ei'>Ei</a></li>\n    <li><a href='/kaffee'>Kaffee</a></li>\n  </ul>\n</body></html>\"\n\ndoc = Gammo.new(html).parse\ndoc.css(\"li\").length" },
          { t: "h", html: "<p><code>doc.css(\"li\")</code> findet alle <code>&lt;li&gt;</code>-Elemente – wie in einem Stylesheet. Jeder Treffer ist ein Knoten mit <code>inner_text</code> und <code>attributes</code>:</p>" },
          { t: "c", code: "doc.css(\"a\").map { |link| link.inner_text }" },
          { t: "h", html: "<div class='task'><strong>Aufgabe:</strong> Sammle alle <strong>Link-Adressen</strong> aus dem Dokument: Baue mit <code>map</code> ein Array <code>links</code> aller <code>href</code>-Werte. An ein Attribut kommst du mit <code>link.attributes.to_h[\"href\"]</code>. Ergebnis: <code>[\"/speck\", \"/ei\", \"/kaffee\"]</code>. (Führe zuerst die Zellen oben aus, damit <code>doc</code> existiert.)</div>" },
          { t: "x", code: "# links = doc.css(\"a\").map { |link| ... }\n",
            check: "links == [\"/speck\", \"/ei\", \"/kaffee\"]",
            hint: "<code>links = doc.css(\"a\").map { |link| link.attributes.to_h[\"href\"] }</code> – und vorher die Demo-Zellen ausführen, damit <code>doc</code> existiert." }
        ]
      },
      en: {
        title: "14. Parsing HTML",
        cells: [
          { t: "h", html: "<h2>Parsing HTML – like the pros</h2><p>Ruby is often used to read websites (<em>scraping</em>). The most famous tool for that is <strong>Nokogiri</strong>:</p><pre><code>require \"nokogiri\"\ndoc = Nokogiri::HTML(html)\ndoc.css(\"a\").each { |link| puts link.text }</code></pre><p>But Nokogiri is largely written in <strong>C</strong>. In this browser Ruby runs as WebAssembly, where only pure-Ruby gems can be installed at runtime – C gems would have to be compiled into the wasm binary itself. Go ahead and see what happens:</p>" },
          { t: "c", code: "install_gem \"nokogiri\"" },
          { t: "h", html: "<p>Luckily there is <code>gammo</code>, an HTML5 parser in pure Ruby. The ideas are exactly the same as Nokogiri's: first <em>parse</em> (text becomes a tree), then search with <strong>CSS selectors</strong>:</p>" },
          { t: "c", code: "install_gem \"gammo\"\nrequire \"gammo\"\nrequire \"gammo/css_selector\"\n\nhtml = \"<html><body>\n  <h1>Menu</h1>\n  <ul>\n    <li><a href='/bacon'>Bacon</a></li>\n    <li><a href='/egg'>Egg</a></li>\n    <li><a href='/coffee'>Coffee</a></li>\n  </ul>\n</body></html>\"\n\ndoc = Gammo.new(html).parse\ndoc.css(\"li\").length" },
          { t: "h", html: "<p><code>doc.css(\"li\")</code> finds all <code>&lt;li&gt;</code> elements – just like in a stylesheet. Every match is a node with <code>inner_text</code> and <code>attributes</code>:</p>" },
          { t: "c", code: "doc.css(\"a\").map { |link| link.inner_text }" },
          { t: "h", html: "<div class='task'><strong>Task:</strong> Collect all <strong>link addresses</strong> from the document: use <code>map</code> to build an array <code>links</code> of all <code>href</code> values. You reach an attribute via <code>link.attributes.to_h[\"href\"]</code>. Expected result: <code>[\"/bacon\", \"/egg\", \"/coffee\"]</code>. (Run the cells above first so <code>doc</code> exists.)</div>" },
          { t: "x", code: "# links = doc.css(\"a\").map { |link| ... }\n",
            check: "links == [\"/bacon\", \"/egg\", \"/coffee\"]",
            hint: "<code>links = doc.css(\"a\").map { |link| link.attributes.to_h[\"href\"] }</code> – and run the demo cells first so <code>doc</code> exists." }
        ]
      }
    },
    {
      id: "sinatra",
      de: {
        title: "15. Sinatra – Webserver",
        cells: [
          { t: "h", html: "<h2>Webseiten bauen – Request und Response</h2><p>Bisher lief dein Code einfach von oben nach unten. Ein <strong>Webserver</strong> arbeitet anders: Er wartet auf <em>Anfragen</em> (Requests) wie <code>GET /speisekarte</code> und schickt <em>Antworten</em> (Responses) zurück – meistens HTML. Welcher Code auf welchen Pfad reagiert, bestimmen <strong>Routen</strong>.</p><p><strong>Sinatra</strong> ist seit 2007 der Klassiker unter Rubys Web-Frameworks: Eine Route ist einfach ein Methodenaufruf mit Block. Führ die Zelle aus – darunter erscheint ein kleiner Browser:</p>" },
          { t: "c", code: "install_gem \"sinatra\"\nrequire \"sinatra/base\"\n\nclass Imbiss < Sinatra::Base\n  get \"/\" do\n    \"<h1>Chunkys Imbiss</h1>\n     <p>Willkommen! Heute im Angebot: Speck.</p>\n     <a href='/speisekarte'>Zur Speisekarte</a>\"\n  end\n\n  get \"/speisekarte\" do\n    \"<h2>Speisekarte</h2>\n     <ul><li>Speck</li><li>Ei</li><li>Kaffee</li></ul>\n     <a href='/'>Zurück</a>\"\n  end\n\n  get \"/hallo/:name\" do\n    \"Hallo, #{params[:name]}! Schön, dass du da bist.\"\n  end\nend\n\nshow_browser Imbiss, \"/\"" },
          { t: "h", html: "<p>Der Mini-Browser spricht direkt mit deiner App: Klick auf die Links, oder tipp einen Pfad in die Adressleiste – probier <code>/hallo/Kaz</code> oder auch <code>/pizza</code> (ergibt 404!).</p><p>So funktioniert es: <code>get \"/pfad\" do … end</code> registriert eine Route, der <strong>Rückgabewert des Blocks</strong> wird die Antwort. Teile mit Doppelpunkt wie <code>:name</code> sind Platzhalter und landen in <code>params</code>. Auf einem richtigen Server startest du so eine App mit <code>ruby app.rb</code> und besuchst <code>localhost:4567</code> – hier ruft der Mini-Browser die App direkt auf (beide sprechen <em>Rack</em>, Rubys Web-Standard).</p><div class='task'><strong>Aufgabe:</strong> Ergänze die Route <code>get \"/speck\"</code>, die <code>CHUNKY BACON!</code> zurückgibt. Der Mini-Browser unten zeigt <code>/speck</code> – im Moment noch ein 404.</div>" },
          { t: "x", code: "install_gem \"sinatra\"\nrequire \"sinatra/base\"\n\nclass MeineSeite < Sinatra::Base\n  get \"/\" do\n    \"<h1>Meine Seite</h1>\"\n  end\n\n  # get \"/speck\" do\n  #   ...\n  # end\nend\n\nshow_browser MeineSeite, \"/speck\"",
            check: "s1, _ = mock_get(MeineSeite, \"/\"); s2, b2 = mock_get(MeineSeite, \"/speck\"); s1 == 200 && s2 == 200 && b2.include?(\"CHUNKY BACON!\")",
            hint: "Genau wie die anderen Routen: <code>get \"/speck\" do</code>, darunter <code>\"CHUNKY BACON!\"</code>, dann <code>end</code>. Danach die Zelle neu ausführen." }
        ]
      },
      en: {
        title: "15. Sinatra – web server",
        cells: [
          { t: "h", html: "<h2>Building websites – request and response</h2><p>So far your code simply ran top to bottom. A <strong>web server</strong> works differently: it waits for <em>requests</em> like <code>GET /menu</code> and sends back <em>responses</em> – usually HTML. Which code answers which path is decided by <strong>routes</strong>.</p><p><strong>Sinatra</strong> has been the classic among Ruby's web frameworks since 2007: a route is just a method call with a block. Run the cell – a little browser appears below it:</p>" },
          { t: "c", code: "install_gem \"sinatra\"\nrequire \"sinatra/base\"\n\nclass Diner < Sinatra::Base\n  get \"/\" do\n    \"<h1>Chunky's Diner</h1>\n     <p>Welcome! Today's special: bacon.</p>\n     <a href='/menu'>See the menu</a>\"\n  end\n\n  get \"/menu\" do\n    \"<h2>Menu</h2>\n     <ul><li>Bacon</li><li>Egg</li><li>Coffee</li></ul>\n     <a href='/'>Back</a>\"\n  end\n\n  get \"/hello/:name\" do\n    \"Hello, #{params[:name]}! Nice to see you.\"\n  end\nend\n\nshow_browser Diner, \"/\"" },
          { t: "h", html: "<p>The mini browser talks directly to your app: click the links, or type a path into the address bar – try <code>/hello/Kaz</code> or even <code>/pizza</code> (a 404!).</p><p>How it works: <code>get \"/path\" do … end</code> registers a route, and the <strong>block's return value</strong> becomes the response. Parts with a colon like <code>:name</code> are placeholders and end up in <code>params</code>. On a real server you'd start such an app with <code>ruby app.rb</code> and visit <code>localhost:4567</code> – here the mini browser calls the app directly (both speak <em>Rack</em>, Ruby's web standard).</p><div class='task'><strong>Task:</strong> Add the route <code>get \"/bacon\"</code> returning <code>CHUNKY BACON!</code>. The mini browser below shows <code>/bacon</code> – a 404 for now.</div>" },
          { t: "x", code: "install_gem \"sinatra\"\nrequire \"sinatra/base\"\n\nclass MySite < Sinatra::Base\n  get \"/\" do\n    \"<h1>My Site</h1>\"\n  end\n\n  # get \"/bacon\" do\n  #   ...\n  # end\nend\n\nshow_browser MySite, \"/bacon\"",
            check: "s1, _ = mock_get(MySite, \"/\"); s2, b2 = mock_get(MySite, \"/bacon\"); s1 == 200 && s2 == 200 && b2.include?(\"CHUNKY BACON!\")",
            hint: "Just like the other routes: <code>get \"/bacon\" do</code>, below it <code>\"CHUNKY BACON!\"</code>, then <code>end</code>. Then run the cell again." }
        ]
      }
    },
    {
      id: "roda",
      de: {
        title: "16. Roda – der Routing-Baum",
        cells: [
          { t: "h", html: "<h2>Roda – der Routing-Baum</h2><p><strong>Roda</strong> (von Jeremy Evans, dem Autor von Sequel) ist ein modernes, sehr schnelles Web-Framework. Statt einer flachen Routenliste wie bei Sinatra kletterst du einen <strong>Baum</strong> hinauf: Der <code>route</code>-Block bekommt den Request <code>r</code>, und du entscheidest Stück für Stück, was mit dem Pfad passiert:</p>" },
          { t: "c", code: "install_gem \"roda\"\nrequire \"roda\"\n\nclass Laden < Roda\n  route do |r|\n    r.root do\n      \"<h1>Chunkys Laden</h1>\n       <a href='/speck'>Speck</a>\n       <a href='/gruss/Chunky'>Begrüssung</a>\"\n    end\n\n    r.get \"speck\" do\n      \"<p>Speck: 3 Streifen für 2 Franken.</p><a href='/'>Zurück</a>\"\n    end\n\n    r.get \"gruss\", String do |name|\n      \"Hallo, #{name}! <a href='/'>Zurück</a>\"\n    end\n  end\nend\n\nshow_browser Laden, \"/\"" },
          { t: "h", html: "<p>Lies den Baum von oben: <code>r.root</code> fängt <code>/</code>, <code>r.get \"speck\"</code> fängt <code>GET /speck</code>. Spannend wird's bei <code>r.get \"gruss\", String</code>: Das matcht <code>/gruss/&lt;irgendwas&gt;</code>, und das Pfadstück landet als Block-Parameter in <code>name</code> – probier <code>/gruss/Ada</code> im Mini-Browser! Passt gar nichts, antwortet Roda automatisch mit <strong>404</strong>.</p><div class='task'><strong>Aufgabe:</strong> Ergänze im Kiosk die Route <code>r.get \"bestellung\", Integer do |anzahl| … end</code>, die z.&nbsp;B. für <code>/bestellung/5</code> den Text <code>5 Streifen Speck, kommt sofort!</code> zurückgibt (nutze Interpolation). Der Mini-Browser unten zeigt aktuell noch 404.</div>" },
          { t: "x", code: "install_gem \"roda\"\nrequire \"roda\"\n\nclass Kiosk < Roda\n  route do |r|\n    r.root do\n      \"<h1>Kiosk</h1><a href='/bestellung/5'>5 Streifen bestellen</a>\"\n    end\n\n    # r.get \"bestellung\", Integer do |anzahl|\n    #   ...\n    # end\n  end\nend\n\nshow_browser Kiosk, \"/bestellung/5\"",
            check: "s1, b1 = mock_get(Kiosk, \"/\"); s2, b2 = mock_get(Kiosk, \"/bestellung/5\"); s3, _ = mock_get(Kiosk, \"/pizza\"); s1 == 200 && b1.include?(\"Kiosk\") && s2 == 200 && b2.include?(\"5\") && b2.include?(\"Speck\") && s3 == 404",
            hint: "<code>r.get \"bestellung\", Integer do |anzahl|</code> … <code>\"#{anzahl} Streifen Speck, kommt sofort!\"</code> … <code>end</code> – innerhalb des route-Blocks." }
        ]
      },
      en: {
        title: "16. Roda – the routing tree",
        cells: [
          { t: "h", html: "<h2>Roda – the routing tree</h2><p><strong>Roda</strong> (by Jeremy Evans, the author of Sequel) is a modern, very fast web framework. Instead of a flat list of routes like Sinatra, you climb a <strong>tree</strong>: the <code>route</code> block receives the request <code>r</code>, and you decide piece by piece what happens with the path:</p>" },
          { t: "c", code: "install_gem \"roda\"\nrequire \"roda\"\n\nclass Shop < Roda\n  route do |r|\n    r.root do\n      \"<h1>Chunky's Shop</h1>\n       <a href='/bacon'>Bacon</a>\n       <a href='/greet/Chunky'>Greeting</a>\"\n    end\n\n    r.get \"bacon\" do\n      \"<p>Bacon: 3 strips for 2 francs.</p><a href='/'>Back</a>\"\n    end\n\n    r.get \"greet\", String do |name|\n      \"Hello, #{name}! <a href='/'>Back</a>\"\n    end\n  end\nend\n\nshow_browser Shop, \"/\"" },
          { t: "h", html: "<p>Read the tree top to bottom: <code>r.root</code> catches <code>/</code>, <code>r.get \"bacon\"</code> catches <code>GET /bacon</code>. It gets interesting with <code>r.get \"greet\", String</code>: that matches <code>/greet/&lt;anything&gt;</code>, and the path segment arrives as the block parameter <code>name</code> – try <code>/greet/Ada</code> in the mini browser! If nothing matches, Roda automatically answers with <strong>404</strong>.</p><div class='task'><strong>Task:</strong> Add the route <code>r.get \"order\", Integer do |amount| … end</code> to the kiosk so that e.g. <code>/order/5</code> returns <code>5 strips of bacon, coming right up!</code> (use interpolation). The mini browser below still shows a 404.</div>" },
          { t: "x", code: "install_gem \"roda\"\nrequire \"roda\"\n\nclass Kiosk < Roda\n  route do |r|\n    r.root do\n      \"<h1>Kiosk</h1><a href='/order/5'>Order 5 strips</a>\"\n    end\n\n    # r.get \"order\", Integer do |amount|\n    #   ...\n    # end\n  end\nend\n\nshow_browser Kiosk, \"/order/5\"",
            check: "s1, b1 = mock_get(Kiosk, \"/\"); s2, b2 = mock_get(Kiosk, \"/order/5\"); s3, _ = mock_get(Kiosk, \"/pizza\"); s1 == 200 && b1.include?(\"Kiosk\") && s2 == 200 && b2.include?(\"5\") && b2.include?(\"bacon\") && s3 == 404",
            hint: "<code>r.get \"order\", Integer do |amount|</code> … <code>\"#{amount} strips of bacon, coming right up!\"</code> … <code>end</code> – inside the route block." }
        ]
      }
    }
  ]
});
