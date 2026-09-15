// Lesson data for "Ruby lernen mit Chunky Bacon".
// Notebook format: each lesson (per language) is a list of cells:
//   { t: "h", html: ... }                        text block
//   { t: "c", code: ... }                        runnable demo cell
//   { t: "x", code, check, hint }                exercise cell (checked)
// All code cells of a lesson share one binding (like a notebook kernel).
// Check snippets are Ruby, eval'd in that binding with extra locals:
// output (captured stdout), result (last expression value), code (source),
// images (data urls from show_image during the run).
window.LESSONS_JSON = JSON.stringify({
  "ui": {
    "de": {
      "title": "Ruby lernen mit Chunky Bacon",
      "subtitle": "Ein Ruby-Notizbuch im Browser – kein Setup, einfach lostippen.",
      "runCell": "▶ Ausführen",
      "reset": "Lektion zurücksetzen",
      "taskLabel": "Aufgabe",
      "loading": "Ruby wird geladen … (einmalig ca. 35 MB)",
      "welcome": "Hallo! Ich bin <strong>Chunky Bacon</strong>, dein Fuchs-Begleiter. 🦊🥓 Diese Seite ist ein <strong>Notizbuch</strong>: Führe jede Code-Zelle mit <em>▶ Ausführen</em> oder <kbd>Shift</kbd>+<kbd>Enter</kbd> aus – den Wert der letzten Zeile zeigt Ruby automatisch als <code>=&gt;</code>. Die Zelle mit dem orangen Rand ist deine Aufgabe. Los geht's!",
      "resetConfirm": "Alle Zellen dieser Lektion zurücksetzen?",
      "praise": [
        "CHUNKY BACON! 🥓 Genau so!",
        "Sauber! Die Füchse jubeln: CHUNKY BACON!",
        "Perfekt! Du bist auf dem Weg zur Ruby-Erleuchtung.",
        "Ausgezeichnet! Matz wäre stolz auf dich.",
        "Wunderbar! Weiter so!"
      ],
      "failIntro": "Hmm, das ist noch nicht ganz richtig.",
      "errorIntro": "Autsch, Ruby meldet einen Fehler – schau unter die Zelle.",
      "nextLesson": "→ Weiter zur nächsten Lektion",
      "progress": "Lektion %d von %d",
      "allDone": "🎉 Du hast alle Lektionen geschafft! CHUNKY BACON! Als nächsten Schritt empfehle ich dir die <a href='https://koans.idogawa.com'>Ruby Koans im Browser</a>.",
      "gemsTitle": "💎 Gems",
      "gemsInstallBtn": "Installieren",
      "gemsCachedTip": "lokal zwischengespeichert – installiert sofort",
      "gemsNote": "Pure-Ruby-Gems von rubygems.org, direkt im Browser installiert. ⚡ = lokal zwischengespeichert. Gems mit C-Code (z.&nbsp;B. nokogiri) funktionieren hier nicht.",
      "gemInstalled": "💎 %s installiert! Jetzt einfach mit <code>require</code> laden.",
      "nativeGem": "%s enthält C-Code (eine „native extension“) und kann nicht zur Laufzeit im Browser installiert werden. Solche Gems müssen beim Bauen der ruby.wasm-Datei fest einkompiliert werden – so macht es z. B. Evil Martians' TutorialKit.rb.",
      "gemNotFound": "Gem „%s“ wurde nicht gefunden (oder der Download schlug fehl).",
      "browserGo": "Los",
      "irbExitNote": "(Auf deinem Computer wäre IRB jetzt beendet – hier darfst du einfach weitertippen. 🦊)",
      "filesTitle": "Dateien (simuliert)",
      "footerCredit": "Ein Angebot von <a href='https://idogawa.com'>Andi Idogawa</a>. Läuft komplett in deinem Browser dank <a href='https://github.com/ruby/ruby.wasm'>ruby.wasm</a>. Schon fertig? Weiter geht's mit den <a href='https://koans.idogawa.com'>Ruby Koans</a>.",
      "footerLicense": "„Chunky Bacon“ stammt aus why's (poignant) guide to Ruby von why the lucky stiff – in liebevoller Erinnerung. Kursinhalte: CC BY-NC-SA 4.0."
    },
    "en": {
      "title": "Learn Ruby with Chunky Bacon",
      "subtitle": "A Ruby notebook in your browser – no setup, just start typing.",
      "runCell": "▶ Run",
      "reset": "Reset lesson",
      "taskLabel": "Task",
      "loading": "Loading Ruby … (one-time, about 35 MB)",
      "welcome": "Hi! I'm <strong>Chunky Bacon</strong>, your fox companion. 🦊🥓 This page is a <strong>notebook</strong>: run every code cell with <em>▶ Run</em> or <kbd>Shift</kbd>+<kbd>Enter</kbd> – Ruby automatically shows the value of the last line as <code>=&gt;</code>. The cell with the orange border is your task. Let's go!",
      "resetConfirm": "Reset all cells of this lesson?",
      "praise": [
        "CHUNKY BACON! 🥓 That's it!",
        "Nice! The foxes cheer: CHUNKY BACON!",
        "Perfect! You are on the path to Ruby enlightenment.",
        "Excellent! Matz would be proud.",
        "Wonderful! Keep going!"
      ],
      "failIntro": "Hmm, that's not quite right yet.",
      "errorIntro": "Ouch, Ruby reports an error – check below the cell.",
      "nextLesson": "→ On to the next lesson",
      "progress": "Lesson %d of %d",
      "allDone": "🎉 You finished all lessons! CHUNKY BACON! As a next step, try the <a href='https://koans.idogawa.com'>Ruby Koans in the browser</a>.",
      "gemsTitle": "💎 Gems",
      "gemsInstallBtn": "Install",
      "gemsCachedTip": "cached locally – installs instantly",
      "gemsNote": "Pure-Ruby gems from rubygems.org, installed right in your browser. ⚡ = cached locally. Gems with C code (e.g. nokogiri) do not work here.",
      "gemInstalled": "💎 %s installed! Now just load it with <code>require</code>.",
      "nativeGem": "%s contains C code (a “native extension”) and cannot be installed at runtime in the browser. Such gems must be compiled into the ruby.wasm binary itself – that is how Evil Martians' TutorialKit.rb does it.",
      "gemNotFound": "Gem “%s” was not found (or the download failed).",
      "browserGo": "Go",
      "irbExitNote": "(On your computer IRB would have quit now – here you can just keep typing. 🦊)",
      "filesTitle": "files (simulated)",
      "footerCredit": "A service by <a href='https://idogawa.com'>Andi Idogawa</a>. Runs entirely in your browser thanks to <a href='https://github.com/ruby/ruby.wasm'>ruby.wasm</a>. Done here? Continue with the <a href='https://koans.idogawa.com'>Ruby Koans</a>.",
      "footerLicense": "“Chunky Bacon” comes from why's (poignant) guide to Ruby by why the lucky stiff – fondly remembered. Course content: CC BY-NC-SA 4.0."
    }
  },
  "lessons": [
    {
      "id": "hallo",
      "section": {
        "de": "Grundkurs",
        "en": "Basics"
      },
      "de": {
        "title": "1. Hallo, Welt!",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Hallo, Welt!</h2><p>Ruby ist eine Programmiersprache, die für <strong>Menschen</strong> gemacht ist. Ihr Erfinder Yukihiro „Matz“ Matsumoto wollte, dass Programmieren Freude macht.</p><p>Diese Seite funktioniert wie ein <strong>Notizbuch</strong>: Sie besteht aus Text und Code-Zellen. Jede Zelle kannst du verändern und mit <em>▶ Ausführen</em> oder <kbd>Shift</kbd>+<kbd>Enter</kbd> laufen lassen. Probier es gleich aus:</p>"
          },
          {
            "t": "c",
            "code": "1 + 1"
          },
          {
            "t": "h",
            "html": "<p>Unter der Zelle erscheint <code>=&gt; 2</code>. Das <code>=&gt;</code> zeigt den <strong>Wert der letzten Zeile</strong> – Ruby macht das automatisch, ganz ohne Extra-Befehl.</p><p>Wenn du Text ausdrücklich <em>ausgeben</em> willst, nimm <code>puts</code> („put string“):</p>"
          },
          {
            "t": "c",
            "code": "puts \"Chunky Bacon!\""
          },
          {
            "t": "h",
            "html": "<p>Der Text zwischen den Anführungszeichen heisst <strong>String</strong> (Zeichenkette). <code>puts</code> schreibt ihn in die Ausgabe. Übrigens: <code>puts</code> selbst hat den Wert <code>nil</code> – „nichts“ – darum siehst du hier keine <code>=&gt;</code>-Zeile.</p><div class='task'><strong>Aufgabe:</strong> Bring die Zelle unten dazu, <code>Hallo, Welt!</code> zu zeigen – mit <code>puts</code> oder einfach als Wert der letzten Zeile.</div>"
          },
          {
            "t": "x",
            "code": "# Dein Code:\n",
            "check": "output.include?(\"Hallo, Welt!\") || result == \"Hallo, Welt!\"",
            "hint": "Schreibe <code>puts \"Hallo, Welt!\"</code> – oder einfach <code>\"Hallo, Welt!\"</code> als letzte Zeile."
          }
        ]
      },
      "en": {
        "title": "1. Hello, World!",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Hello, World!</h2><p>Ruby is a programming language made for <strong>humans</strong>. Its creator Yukihiro “Matz” Matsumoto wanted programming to be joyful.</p><p>This page works like a <strong>notebook</strong>: it consists of text and code cells. You can edit every cell and run it with <em>▶ Run</em> or <kbd>Shift</kbd>+<kbd>Enter</kbd>. Try it right away:</p>"
          },
          {
            "t": "c",
            "code": "1 + 1"
          },
          {
            "t": "h",
            "html": "<p>Below the cell you see <code>=&gt; 2</code>. The <code>=&gt;</code> shows the <strong>value of the last line</strong> – Ruby does that automatically, no extra command needed.</p><p>If you want to explicitly <em>print</em> text, use <code>puts</code> (“put string”):</p>"
          },
          {
            "t": "c",
            "code": "puts \"Chunky Bacon!\""
          },
          {
            "t": "h",
            "html": "<p>The text between the quotes is called a <strong>string</strong>. <code>puts</code> writes it to the output. By the way: <code>puts</code> itself has the value <code>nil</code> – “nothing” – which is why there is no <code>=&gt;</code> line here.</p><div class='task'><strong>Task:</strong> Make the cell below show <code>Hello, World!</code> – with <code>puts</code> or simply as the value of the last line.</div>"
          },
          {
            "t": "x",
            "code": "# Your code:\n",
            "check": "output.include?(\"Hello, World!\") || result == \"Hello, World!\"",
            "hint": "Write <code>puts \"Hello, World!\"</code> – or simply <code>\"Hello, World!\"</code> as the last line."
          }
        ]
      }
    },
    {
      "id": "rechnen",
      "de": {
        "title": "2. Rechnen",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Ruby als Taschenrechner</h2><p>Ruby rechnet mit <code>+</code>, <code>-</code>, <code>*</code> (mal) und <code>/</code> (geteilt). Führ die Zelle aus – und ändere die Zahlen ruhig:</p>"
          },
          {
            "t": "c",
            "code": "3 + 4"
          },
          {
            "t": "h",
            "html": "<p>Alles hinter <code>#</code> ist ein <strong>Kommentar</strong> – Ruby ignoriert ihn. Kommentare sind Notizen für Menschen (und Füchse):</p>"
          },
          {
            "t": "c",
            "code": "5 * 5   # fünf mal fünf"
          },
          {
            "t": "h",
            "html": "<div class='task'><strong>Aufgabe:</strong> Wie viel ist 6 mal 7? Lass Ruby rechnen: Die Zelle soll das Ergebnis von <code>6 * 7</code> zeigen. (Nicht selbst rechnen – das ist ja der Witz!)</div>"
          },
          {
            "t": "x",
            "code": "",
            "check": "(output.include?(\"42\") || result == 42) && code.include?(\"*\")",
            "hint": "Schreibe einfach <code>6 * 7</code> in die Zelle. Der Stern <code>*</code> bedeutet „mal“."
          }
        ]
      },
      "en": {
        "title": "2. Arithmetic",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Ruby as a calculator</h2><p>Ruby calculates with <code>+</code>, <code>-</code>, <code>*</code> (times) and <code>/</code> (divided by). Run the cell – and feel free to change the numbers:</p>"
          },
          {
            "t": "c",
            "code": "3 + 4"
          },
          {
            "t": "h",
            "html": "<p>Everything after <code>#</code> is a <strong>comment</strong> – Ruby ignores it. Comments are notes for humans (and foxes):</p>"
          },
          {
            "t": "c",
            "code": "5 * 5   # five times five"
          },
          {
            "t": "h",
            "html": "<div class='task'><strong>Task:</strong> What is 6 times 7? Let Ruby do the math: the cell should show the result of <code>6 * 7</code>. (Don't compute it yourself – that's the whole point!)</div>"
          },
          {
            "t": "x",
            "code": "",
            "check": "(output.include?(\"42\") || result == 42) && code.include?(\"*\")",
            "hint": "Simply write <code>6 * 7</code> into the cell. The star <code>*</code> means “times”."
          }
        ]
      }
    },
    {
      "id": "variablen",
      "de": {
        "title": "3. Variablen",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Variablen – Dinge beim Namen nennen</h2><p>Eine <strong>Variable</strong> ist ein Name für einen Wert. Mit <code>=</code> weist du ihn zu. Variablennamen schreibt man klein, mit Unterstrichen: <code>lieblings_essen</code>, <code>anzahl_streifen</code>.</p>"
          },
          {
            "t": "c",
            "code": "essen = \"Speck\"\nmenge = 3\nessen"
          },
          {
            "t": "h",
            "html": "<p>Die Zellen einer Lektion teilen sich ihren Speicher – wie in einem echten Notizbuch. Die Variable <code>menge</code> von oben kannst du hier weiterverwenden. (Kommt ein Fehler? Dann führe zuerst die Zelle darüber aus.)</p>"
          },
          {
            "t": "c",
            "code": "menge * 2"
          },
          {
            "t": "h",
            "html": "<div class='task'><strong>Aufgabe:</strong> Lege zwei Variablen an: <code>name</code> mit deinem Namen (ein String) und <code>alter</code> mit einer Zahl.</div>"
          },
          {
            "t": "x",
            "code": "# name = ...\n# alter = ...\n",
            "check": "name.is_a?(String) && !name.empty? && alter.is_a?(Integer)",
            "hint": "Zum Beispiel: <code>name = \"Kaz\"</code> und <code>alter = 7</code>."
          }
        ]
      },
      "en": {
        "title": "3. Variables",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Variables – naming things</h2><p>A <strong>variable</strong> is a name for a value. You assign it with <code>=</code>. Variable names are lowercase, with underscores: <code>favorite_food</code>, <code>bacon_strips</code>.</p>"
          },
          {
            "t": "c",
            "code": "food = \"bacon\"\namount = 3\nfood"
          },
          {
            "t": "h",
            "html": "<p>The cells of a lesson share their memory – like in a real notebook. You can reuse the variable <code>amount</code> from above here. (Getting an error? Run the cell above first.)</p>"
          },
          {
            "t": "c",
            "code": "amount * 2"
          },
          {
            "t": "h",
            "html": "<div class='task'><strong>Task:</strong> Create two variables: <code>name</code> with your name (a string) and <code>age</code> with a number.</div>"
          },
          {
            "t": "x",
            "code": "# name = ...\n# age = ...\n",
            "check": "name.is_a?(String) && !name.empty? && age.is_a?(Integer)",
            "hint": "For example: <code>name = \"Kaz\"</code> and <code>age = 7</code>."
          }
        ]
      }
    },
    {
      "id": "strings",
      "de": {
        "title": "4. Strings verketten",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Strings und Interpolation</h2><p>Du kannst Variablen direkt in einen String einbauen – das heisst <strong>Interpolation</strong> und funktioniert mit <code>#{}</code> in doppelten Anführungszeichen:</p>"
          },
          {
            "t": "c",
            "code": "tier = \"Fuchs\"\n\"Der #{tier} ruft!\""
          },
          {
            "t": "h",
            "html": "<p>Ruby wertet aus, was zwischen <code>#{</code> und <code>}</code> steht, und setzt das Ergebnis ein. Es darf auch gerechnet werden:</p>"
          },
          {
            "t": "c",
            "code": "\"#{3 * 7} Streifen Speck\""
          },
          {
            "t": "h",
            "html": "<div class='task'><strong>Aufgabe:</strong> Unten ist die Variable <code>lieblingsessen</code> vorbereitet. Baue mit Interpolation den Satz <code>Ich mag Chunky Bacon!</code> – die Variable gehört mit <code>#{}</code> in den String.</div>"
          },
          {
            "t": "x",
            "code": "lieblingsessen = \"Chunky Bacon\"\n# \"Ich mag ...!\"\n",
            "check": "(output.include?(\"Ich mag Chunky Bacon!\") || result == \"Ich mag Chunky Bacon!\") && code.include?('#{')",
            "hint": "Schreibe <code>\"Ich mag #{lieblingsessen}!\"</code> als letzte Zeile – mit doppelten Anführungszeichen."
          }
        ]
      },
      "en": {
        "title": "4. String interpolation",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Strings and interpolation</h2><p>You can embed variables right inside a string – that's called <strong>interpolation</strong> and works with <code>#{}</code> inside double quotes:</p>"
          },
          {
            "t": "c",
            "code": "animal = \"fox\"\n\"The #{animal} shouts!\""
          },
          {
            "t": "h",
            "html": "<p>Ruby evaluates whatever is between <code>#{</code> and <code>}</code> and inserts the result. Math works too:</p>"
          },
          {
            "t": "c",
            "code": "\"#{3 * 7} strips of bacon\""
          },
          {
            "t": "h",
            "html": "<div class='task'><strong>Task:</strong> The variable <code>favorite_food</code> is prepared below. Use interpolation to build the sentence <code>I love Chunky Bacon!</code> – the variable goes into the string with <code>#{}</code>.</div>"
          },
          {
            "t": "x",
            "code": "favorite_food = \"Chunky Bacon\"\n# \"I love ...!\"\n",
            "check": "(output.include?(\"I love Chunky Bacon!\") || result == \"I love Chunky Bacon!\") && code.include?('#{')",
            "hint": "Write <code>\"I love #{favorite_food}!\"</code> as the last line – with double quotes."
          }
        ]
      }
    },
    {
      "id": "wenn",
      "de": {
        "title": "5. Entscheidungen (if)",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Wenn … dann … sonst</h2><p>Mit <code>if</code> trifft dein Programm Entscheidungen. Vergleiche: <code>&gt;</code> grösser, <code>&lt;</code> kleiner, <code>==</code> gleich (zwei Gleichheitszeichen!), <code>!=</code> ungleich. Jeder <code>if</code>-Block endet mit <code>end</code>.</p>"
          },
          {
            "t": "c",
            "code": "hunger = 9\nif hunger > 7\n  \"Zeit für Speck!\"\nelse\n  \"Alles gut.\"\nend"
          },
          {
            "t": "h",
            "html": "<p>Sogar <code>if</code> hat in Ruby einen Wert: den Zweig, der gewonnen hat. Ändere <code>hunger</code> auf <code>3</code> und führ die Zelle nochmal aus!</p><div class='task'><strong>Aufgabe:</strong> Unten steht <code>zahl = 7</code>. Die Zelle soll <code>gross</code> ergeben, wenn die Zahl grösser als 5 ist, sonst <code>klein</code> – als Wert oder mit <code>puts</code>.</div>"
          },
          {
            "t": "x",
            "code": "zahl = 7\n# if ...\n",
            "check": "((output + result.to_s).include?(\"gross\") && !(output + result.to_s).include?(\"klein\")) && code.include?(\"if\")",
            "hint": "So geht's: <code>if zahl > 5</code>, dann <code>\"gross\"</code>, dann <code>else</code>, <code>\"klein\"</code> und zum Schluss <code>end</code>."
          }
        ]
      },
      "en": {
        "title": "5. Decisions (if)",
        "cells": [
          {
            "t": "h",
            "html": "<h2>If … then … else</h2><p>With <code>if</code> your program makes decisions. Comparisons: <code>&gt;</code> greater, <code>&lt;</code> less, <code>==</code> equal (two equals signs!), <code>!=</code> not equal. Every <code>if</code> block ends with <code>end</code>.</p>"
          },
          {
            "t": "c",
            "code": "hunger = 9\nif hunger > 7\n  \"Time for bacon!\"\nelse\n  \"All good.\"\nend"
          },
          {
            "t": "h",
            "html": "<p>Even <code>if</code> has a value in Ruby: the branch that won. Change <code>hunger</code> to <code>3</code> and run the cell again!</p><div class='task'><strong>Task:</strong> Below you have <code>number = 7</code>. The cell should yield <code>big</code> if the number is greater than 5, otherwise <code>small</code> – as a value or with <code>puts</code>.</div>"
          },
          {
            "t": "x",
            "code": "number = 7\n# if ...\n",
            "check": "((output + result.to_s).include?(\"big\") && !(output + result.to_s).include?(\"small\")) && code.include?(\"if\")",
            "hint": "Like this: <code>if number > 5</code>, then <code>\"big\"</code>, then <code>else</code>, <code>\"small\"</code> and finally <code>end</code>."
          }
        ]
      }
    },
    {
      "id": "schleifen",
      "de": {
        "title": "6. Schleifen",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Schleifen – Dinge wiederholen</h2><p>In why's legendärem Ruby-Buch rufen zwei Comic-Füchse immer wieder: <em>„Chunky Bacon!“</em> – Wiederholung ist in Ruby wunderbar einfach:</p>"
          },
          {
            "t": "c",
            "code": "3.times do\n  puts \"Chunky Bacon!\"\nend"
          },
          {
            "t": "h",
            "html": "<p>Der Code zwischen <code>do</code> und <code>end</code> heisst <strong>Block</strong> und wird hier dreimal ausgeführt. (Das <code>=&gt; 3</code> darunter ist der Wert von <code>3.times</code> selbst.) Mit Zähler geht es auch:</p>"
          },
          {
            "t": "c",
            "code": "3.times do |i|\n  puts \"Streifen Nummer #{i + 1}\"\nend"
          },
          {
            "t": "h",
            "html": "<div class='task'><strong>Aufgabe:</strong> Gib <code>Chunky Bacon!</code> genau fünfmal aus – mit einer Schleife, nicht mit fünf <code>puts</code>-Zeilen.</div>"
          },
          {
            "t": "x",
            "code": "# 5 mal Chunky Bacon, bitte!\n",
            "check": "((output + result.inspect).scan(\"Chunky Bacon!\").length >= 5) && (code.include?(\"times\") || code.include?(\"each\") || code.include?(\"while\") || code.include?(\"upto\") || code.include?(\"for \"))",
            "hint": "Schreibe <code>5.times do</code> … <code>puts \"Chunky Bacon!\"</code> … <code>end</code>."
          }
        ]
      },
      "en": {
        "title": "6. Loops",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Loops – repeating things</h2><p>In why's legendary Ruby book two cartoon foxes keep shouting: <em>“Chunky Bacon!”</em> – repetition is delightfully easy in Ruby:</p>"
          },
          {
            "t": "c",
            "code": "3.times do\n  puts \"Chunky Bacon!\"\nend"
          },
          {
            "t": "h",
            "html": "<p>The code between <code>do</code> and <code>end</code> is called a <strong>block</strong> and runs three times here. (The <code>=&gt; 3</code> below is the value of <code>3.times</code> itself.) With a counter it looks like this:</p>"
          },
          {
            "t": "c",
            "code": "3.times do |i|\n  puts \"Strip number #{i + 1}\"\nend"
          },
          {
            "t": "h",
            "html": "<div class='task'><strong>Task:</strong> Print <code>Chunky Bacon!</code> exactly five times – with a loop, not with five <code>puts</code> lines.</div>"
          },
          {
            "t": "x",
            "code": "# 5 times Chunky Bacon, please!\n",
            "check": "((output + result.inspect).scan(\"Chunky Bacon!\").length >= 5) && (code.include?(\"times\") || code.include?(\"each\") || code.include?(\"while\") || code.include?(\"upto\") || code.include?(\"for \"))",
            "hint": "Write <code>5.times do</code> … <code>puts \"Chunky Bacon!\"</code> … <code>end</code>."
          }
        ]
      }
    },
    {
      "id": "arrays",
      "de": {
        "title": "7. Arrays",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Arrays – Listen von Dingen</h2><p>Ein <strong>Array</strong> ist eine Liste. Es wird mit eckigen Klammern geschrieben:</p>"
          },
          {
            "t": "c",
            "code": "fruehstueck = [\"Ei\", \"Brot\"]\nfruehstueck.length"
          },
          {
            "t": "h",
            "html": "<p>Mit eckigen Klammern greifst du auf ein Element zu – die Zählung beginnt bei 0!</p>"
          },
          {
            "t": "c",
            "code": "fruehstueck[0]"
          },
          {
            "t": "h",
            "html": "<p>Mit <code>&lt;&lt;</code> („Schaufel“) hängst du etwas hinten an, mit <code>each</code> gehst du alles durch:</p>"
          },
          {
            "t": "c",
            "code": "fruehstueck << \"Kaffee\"\nfruehstueck.each do |sache|\n  puts sache\nend"
          },
          {
            "t": "h",
            "html": "<div class='task'><strong>Aufgabe:</strong> Häng an das Array unten <code>\"Speck\"</code> an. Bonus: gib alle Elemente mit <code>each</code> aus.</div>"
          },
          {
            "t": "x",
            "code": "fruehstueck = [\"Ei\", \"Brot\"]\n# ...\n",
            "check": "fruehstueck.is_a?(Array) && fruehstueck.include?(\"Speck\") && fruehstueck.include?(\"Ei\")",
            "hint": "Schreibe <code>fruehstueck << \"Speck\"</code> unter die erste Zeile."
          }
        ]
      },
      "en": {
        "title": "7. Arrays",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Arrays – lists of things</h2><p>An <strong>array</strong> is a list. You write it with square brackets:</p>"
          },
          {
            "t": "c",
            "code": "breakfast = [\"egg\", \"toast\"]\nbreakfast.length"
          },
          {
            "t": "h",
            "html": "<p>With square brackets you access an element – counting starts at 0!</p>"
          },
          {
            "t": "c",
            "code": "breakfast[0]"
          },
          {
            "t": "h",
            "html": "<p>With <code>&lt;&lt;</code> (the “shovel”) you append to the end, with <code>each</code> you walk through it:</p>"
          },
          {
            "t": "c",
            "code": "breakfast << \"coffee\"\nbreakfast.each do |item|\n  puts item\nend"
          },
          {
            "t": "h",
            "html": "<div class='task'><strong>Task:</strong> Append <code>\"bacon\"</code> to the array below. Bonus: print every element with <code>each</code>.</div>"
          },
          {
            "t": "x",
            "code": "breakfast = [\"egg\", \"toast\"]\n# ...\n",
            "check": "breakfast.is_a?(Array) && breakfast.include?(\"bacon\") && breakfast.include?(\"egg\")",
            "hint": "Write <code>breakfast << \"bacon\"</code> below the first line."
          }
        ]
      }
    },
    {
      "id": "hashes",
      "de": {
        "title": "8. Hashes",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Hashes – Nachschlagewerke</h2><p>Ein <strong>Hash</strong> ordnet Schlüsseln Werte zu, wie ein kleines Wörterbuch. Die Schlüssel wie <code>:name</code> heissen <strong>Symbole</strong> – leichtgewichtige Namen mit Doppelpunkt.</p>"
          },
          {
            "t": "c",
            "code": "tier = { name: \"Chunky\", essen: \"Speck\" }\ntier[:name]"
          },
          {
            "t": "h",
            "html": "<p>Probiere auch <code>tier[:essen]</code> – oder einen Schlüssel, den es nicht gibt: dann bekommst du <code>nil</code>.</p><div class='task'><strong>Aufgabe:</strong> Baue einen Hash <code>fuchs</code> mit den Schlüsseln <code>:name</code> und <code>:essen</code> (Werte darfst du wählen).</div>"
          },
          {
            "t": "x",
            "code": "# fuchs = { ... }\n",
            "check": "fuchs.is_a?(Hash) && fuchs[:name].to_s.length > 0 && fuchs[:essen].to_s.length > 0",
            "hint": "Zum Beispiel: <code>fuchs = { name: \"Chunky\", essen: \"Speck\" }</code>."
          }
        ]
      },
      "en": {
        "title": "8. Hashes",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Hashes – lookup tables</h2><p>A <strong>hash</strong> maps keys to values, like a little dictionary. Keys like <code>:name</code> are <strong>symbols</strong> – lightweight names with a colon.</p>"
          },
          {
            "t": "c",
            "code": "animal = { name: \"Chunky\", food: \"bacon\" }\nanimal[:name]"
          },
          {
            "t": "h",
            "html": "<p>Also try <code>animal[:food]</code> – or a key that doesn't exist: then you get <code>nil</code>.</p><div class='task'><strong>Task:</strong> Build a hash <code>fox</code> with the keys <code>:name</code> and <code>:food</code> (pick any values).</div>"
          },
          {
            "t": "x",
            "code": "# fox = { ... }\n",
            "check": "fox.is_a?(Hash) && fox[:name].to_s.length > 0 && fox[:food].to_s.length > 0",
            "hint": "For example: <code>fox = { name: \"Chunky\", food: \"bacon\" }</code>."
          }
        ]
      }
    },
    {
      "id": "methoden",
      "de": {
        "title": "9. Methoden",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Eigene Methoden schreiben</h2><p>Mit <code>def</code> definierst du eine <strong>Methode</strong> – ein Stück Code mit Namen, das du beliebig oft aufrufen kannst:</p>"
          },
          {
            "t": "c",
            "code": "def begruessung(name)\n  \"Hallo, #{name}!\"\nend\n\nbegruessung(\"Kaz\")"
          },
          {
            "t": "h",
            "html": "<p>Kleine Überraschung: Du rufst schon seit Lektion 1 Methoden auf – denn <code>puts</code> ist eine! Ruby macht die <strong>Klammern optional</strong>: <code>puts \"Hallo\"</code> ist in Wahrheit <code>puts(\"Hallo\")</code>. Das gilt auch für deine eigenen Methoden:</p>"
          },
          {
            "t": "c",
            "code": "mit_klammern  = begruessung(\"Kaz\")\nohne_klammern = begruessung \"Kaz\"\n\n[mit_klammern, ohne_klammern]"
          },
          {
            "t": "h",
            "html": "<p>Genau deshalb lesen sich viele Ruby-Zeilen wie normale Sprache. Die Faustregel der Rubyisten: Klammern <em>weglassen</em>, wenn der Aufruf wie eine Anweisung wirkt (<code>puts \"…\"</code>, <code>require \"csv\"</code>) – Klammern <em>setzen</em>, wenn du mit dem Ergebnis weiterrechnest (<code>begruessung(\"Kaz\").upcase</code>). Bei Aufrufen ganz ohne Argumente lässt man sie fast immer weg: <code>name.upcase</code> statt <code>name.upcase()</code>.</p>"
          },
          {
            "t": "h",
            "html": "<p>Der Wert der <em>letzten Zeile</em> einer Methode ist automatisch ihr Rückgabewert – ein <code>return</code> ist meist unnötig. Das ist sehr rubyisch.</p><div class='task'><strong>Aufgabe:</strong> Schreibe eine Methode <code>quadrat(zahl)</code>, die die Zahl mit sich selbst multipliziert zurückgibt. Teste sie: <code>quadrat(9)</code> als letzte Zeile.</div>"
          },
          {
            "t": "x",
            "code": "# def quadrat(zahl)\n#   ...\n# end\n\n# quadrat(9)\n",
            "check": "quadrat(9) == 81 && quadrat(5) == 25 && code.include?(\"def\")",
            "hint": "So geht's: <code>def quadrat(zahl)</code>, darunter <code>zahl * zahl</code>, dann <code>end</code>."
          }
        ]
      },
      "en": {
        "title": "9. Methods",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Writing your own methods</h2><p>With <code>def</code> you define a <strong>method</strong> – a named piece of code you can call as often as you like:</p>"
          },
          {
            "t": "c",
            "code": "def greeting(name)\n  \"Hello, #{name}!\"\nend\n\ngreeting(\"Kaz\")"
          },
          {
            "t": "h",
            "html": "<p>Small surprise: you've been calling methods since lesson 1 – because <code>puts</code> is one! Ruby makes the <strong>parentheses optional</strong>: <code>puts \"Hello\"</code> is really <code>puts(\"Hello\")</code>. That works for your own methods too:</p>"
          },
          {
            "t": "c",
            "code": "with_parens    = greeting(\"Kaz\")\nwithout_parens = greeting \"Kaz\"\n\n[with_parens, without_parens]"
          },
          {
            "t": "h",
            "html": "<p>That's exactly why so many Ruby lines read like plain language. The Rubyists' rule of thumb: <em>omit</em> the parentheses when the call reads like a statement (<code>puts \"…\"</code>, <code>require \"csv\"</code>) – <em>use</em> them when you keep computing with the result (<code>greeting(\"Kaz\").upcase</code>). For calls with no arguments at all they're almost always omitted: <code>name.upcase</code> instead of <code>name.upcase()</code>.</p>"
          },
          {
            "t": "h",
            "html": "<p>The value of a method's <em>last line</em> is automatically its return value – an explicit <code>return</code> is usually unnecessary. Very Ruby.</p><div class='task'><strong>Task:</strong> Write a method <code>square(number)</code> that returns the number multiplied by itself. Test it: <code>square(9)</code> as the last line.</div>"
          },
          {
            "t": "x",
            "code": "# def square(number)\n#   ...\n# end\n\n# square(9)\n",
            "check": "square(9) == 81 && square(5) == 25 && code.include?(\"def\")",
            "hint": "Like this: <code>def square(number)</code>, below it <code>number * number</code>, then <code>end</code>."
          }
        ]
      }
    },
    {
      "id": "klassen",
      "de": {
        "title": "10. Klassen",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Klassen – eigene Dinge erschaffen</h2><p>In Ruby ist <em>alles</em> ein Objekt. Mit einer <strong>Klasse</strong> baust du deine eigenen Objekte:</p>"
          },
          {
            "t": "c",
            "code": "class Katze\n  attr_reader :name\n\n  def initialize(name)\n    @name = name\n  end\n\n  def ruf\n    \"Miau!\"\n  end\nend\n\nk = Katze.new(\"Mimi\")\nk.ruf"
          },
          {
            "t": "h",
            "html": "<p><code>initialize</code> läuft bei <code>Katze.new</code>. Variablen mit <code>@</code> gehören zum Objekt, und <code>attr_reader :name</code> macht <code>@name</code> von aussen lesbar – probiere <code>k.name</code>! Und noch ein Aha: <code>attr_reader :name</code> ist kein Spezialbefehl, sondern ein ganz normaler Methodenaufruf ohne Klammern – wie in Lektion 9 gelernt: <code>attr_reader(:name)</code>.</p><div class='task'><strong>Aufgabe:</strong> Schreibe nach diesem Vorbild die Klasse <code>Fuchs</code>: mit <code>initialize(name)</code>, <code>attr_reader :name</code> und einer Methode <code>ruf</code>, die <code>\"Chunky Bacon!\"</code> zurückgibt.</div>"
          },
          {
            "t": "x",
            "code": "# class Fuchs\n#   ...\n# end\n",
            "check": "f = Fuchs.new(\"Kaz\"); f.name == \"Kaz\" && f.ruf == \"Chunky Bacon!\" && code.include?(\"class Fuchs\")",
            "hint": "Übernimm das Katzen-Beispiel und pass es an: Klasse <code>Fuchs</code>, und <code>ruf</code> gibt genau <code>\"Chunky Bacon!\"</code> zurück."
          }
        ]
      },
      "en": {
        "title": "10. Classes",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Classes – creating your own things</h2><p>In Ruby, <em>everything</em> is an object. With a <strong>class</strong> you build objects of your own:</p>"
          },
          {
            "t": "c",
            "code": "class Cat\n  attr_reader :name\n\n  def initialize(name)\n    @name = name\n  end\n\n  def shout\n    \"Meow!\"\n  end\nend\n\nk = Cat.new(\"Mimi\")\nk.shout"
          },
          {
            "t": "h",
            "html": "<p><code>initialize</code> runs on <code>Cat.new</code>. Variables with <code>@</code> belong to the object, and <code>attr_reader :name</code> makes <code>@name</code> readable from outside – try <code>k.name</code>! And another aha: <code>attr_reader :name</code> is no special keyword but a perfectly normal method call without parentheses – as learned in lesson 9: <code>attr_reader(:name)</code>.</p><div class='task'><strong>Task:</strong> Following this example, write the class <code>Fox</code>: with <code>initialize(name)</code>, <code>attr_reader :name</code> and a method <code>shout</code> that returns <code>\"Chunky Bacon!\"</code>.</div>"
          },
          {
            "t": "x",
            "code": "# class Fox\n#   ...\n# end\n",
            "check": "f = Fox.new(\"Kaz\"); f.name == \"Kaz\" && f.shout == \"Chunky Bacon!\" && code.include?(\"class Fox\")",
            "hint": "Copy the cat example and adapt it: class <code>Fox</code>, and <code>shout</code> returns exactly <code>\"Chunky Bacon!\"</code>."
          }
        ]
      }
    },
    {
      "id": "module",
      "de": {
        "title": "11. Module",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Module – Werkzeugkisten für Code</h2><p>Ein <strong>Modul</strong> ist eine benannte Kiste für Methoden und Konstanten. Anders als eine Klasse kann man von einem Modul keine Objekte erzeugen (<code>new</code> gibt es nicht) – Module haben zwei andere Jobs: <strong>Ordnung schaffen</strong> und <strong>Fähigkeiten teilen</strong>.</p><p>Du kennst schon einige: <code>Math</code> aus Rubys Standardbibliothek sammelt Mathe-Werkzeuge. An Konstanten kommst du mit <code>::</code>, Methoden rufst du mit Punkt auf:</p>"
          },
          {
            "t": "c",
            "code": "Math::PI"
          },
          {
            "t": "c",
            "code": "Math.sqrt(49)"
          },
          {
            "t": "h",
            "html": "<p><strong>Job 1 – Namensraum:</strong> Ein Modul gruppiert zusammengehörige Klassen unter einem Dach, damit sich Namen nicht in die Quere kommen. Genau darum heissen die Klassen aus früheren Lektionen <code>ChunkyPNG::Image</code> und <code>Sinatra::Base</code> – Klasse <code>Image</code> im Modul <code>ChunkyPNG</code>, Klasse <code>Base</code> im Modul <code>Sinatra</code>:</p>"
          },
          {
            "t": "c",
            "code": "module Wald\n  class Fuchs\n    def ruf\n      \"Chunky Bacon!\"\n    end\n  end\nend\n\nWald::Fuchs.new.ruf"
          },
          {
            "t": "h",
            "html": "<p><strong>Job 2 – Mixin:</strong> Mit <code>include</code> mischst du die Methoden eines Moduls in eine Klasse hinein – so teilen sich viele Klassen eine Fähigkeit, ohne voneinander zu erben: (Auch <code>include</code> ist übrigens nur ein Methodenaufruf ohne Klammern.)</p>"
          },
          {
            "t": "c",
            "code": "module Begruessung\n  def hallo\n    \"Hallo, ich bin #{name}!\"\n  end\nend\n\nclass Igel\n  include Begruessung\n\n  attr_reader :name\n\n  def initialize(name)\n    @name = name\n  end\nend\n\nIgel.new(\"Isi\").hallo"
          },
          {
            "t": "h",
            "html": "<p>So funktionieren auch Rubys berühmteste Mixins: <code>Comparable</code> schenkt einer Klasse <code>&lt;</code>, <code>&gt;</code> und <code>between?</code>, sobald sie <code>&lt;=&gt;</code> kann, und <code>Enumerable</code> schenkt ihr <code>map</code>, <code>select</code> &amp; Co., sobald sie <code>each</code> kann.</p><div class='task'><strong>Aufgabe:</strong> Schreibe ein Modul <code>Laut</code> mit einer Methode <code>ruf</code>, die <code>CHUNKY BACON!</code> zurückgibt. Mische es mit <code>include</code> in eine neue Klasse <code>Dachs</code> und probiere <code>Dachs.new.ruf</code> als letzte Zeile.</div>"
          },
          {
            "t": "x",
            "code": "# module Laut\n#   ...\n# end\n\n# class Dachs\n#   ...\n# end\n",
            "check": "Laut.is_a?(Module) && !Laut.is_a?(Class) && Dachs.include?(Laut) && Dachs.new.ruf == \"CHUNKY BACON!\" && code.include?(\"include\")",
            "hint": "<code>module Laut</code> mit <code>def ruf</code> … <code>\"CHUNKY BACON!\"</code> … dann <code>class Dachs</code> mit <code>include Laut</code> darin."
          }
        ]
      },
      "en": {
        "title": "11. Modules",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Modules – toolboxes for code</h2><p>A <strong>module</strong> is a named box for methods and constants. Unlike a class, a module cannot create objects (there is no <code>new</code>) – modules have two other jobs: <strong>keeping things organized</strong> and <strong>sharing abilities</strong>.</p><p>You already know some: <code>Math</code> from Ruby's standard library collects math tools. You reach constants with <code>::</code> and call methods with a dot:</p>"
          },
          {
            "t": "c",
            "code": "Math::PI"
          },
          {
            "t": "c",
            "code": "Math.sqrt(49)"
          },
          {
            "t": "h",
            "html": "<p><strong>Job 1 – namespace:</strong> A module groups related classes under one roof so names don't clash. That's exactly why the classes from earlier lessons are called <code>ChunkyPNG::Image</code> and <code>Sinatra::Base</code> – class <code>Image</code> inside module <code>ChunkyPNG</code>, class <code>Base</code> inside module <code>Sinatra</code>:</p>"
          },
          {
            "t": "c",
            "code": "module Forest\n  class Fox\n    def shout\n      \"Chunky Bacon!\"\n    end\n  end\nend\n\nForest::Fox.new.shout"
          },
          {
            "t": "h",
            "html": "<p><strong>Job 2 – mixin:</strong> With <code>include</code> you mix a module's methods into a class – that way many classes can share an ability without inheriting from each other: (By the way, <code>include</code> too is just a method call without parentheses.)</p>"
          },
          {
            "t": "c",
            "code": "module Greeting\n  def hello\n    \"Hello, I am #{name}!\"\n  end\nend\n\nclass Hedgehog\n  include Greeting\n\n  attr_reader :name\n\n  def initialize(name)\n    @name = name\n  end\nend\n\nHedgehog.new(\"Izzy\").hello"
          },
          {
            "t": "h",
            "html": "<p>Ruby's most famous mixins work the same way: <code>Comparable</code> gives a class <code>&lt;</code>, <code>&gt;</code> and <code>between?</code> as soon as it can <code>&lt;=&gt;</code>, and <code>Enumerable</code> gives it <code>map</code>, <code>select</code> &amp; co. as soon as it can <code>each</code>.</p><div class='task'><strong>Task:</strong> Write a module <code>Loud</code> with a method <code>shout</code> that returns <code>CHUNKY BACON!</code>. Mix it into a new class <code>Badger</code> with <code>include</code> and try <code>Badger.new.shout</code> as the last line.</div>"
          },
          {
            "t": "x",
            "code": "# module Loud\n#   ...\n# end\n\n# class Badger\n#   ...\n# end\n",
            "check": "Loud.is_a?(Module) && !Loud.is_a?(Class) && Badger.include?(Loud) && Badger.new.shout == \"CHUNKY BACON!\" && code.include?(\"include\")",
            "hint": "<code>module Loud</code> with <code>def shout</code> … <code>\"CHUNKY BACON!\"</code> … then <code>class Badger</code> with <code>include Loud</code> inside."
          }
        ]
      }
    },
    {
      "id": "irb",
      "de": {
        "title": "12. IRB – Rubys Spielwiese",
        "cells": [
          {
            "t": "h",
            "html": "<h2>IRB – Rubys Spielwiese</h2><p>Auf jedem Computer mit Ruby ist <strong>IRB</strong> schon dabei („Interactive RuBy“). Du startest es, indem du im Terminal <code>irb</code> tippst – dann fütterst du Ruby Zeile für Zeile, und wie in diesem Notizbuch zeigt IRB nach jeder Zeile den Wert mit <code>=&gt;</code>:</p><pre><code>$ irb\nirb(main):001:0&gt; 1 + 1\n=&gt; 2\nirb(main):002:0&gt; \"Chunky \" + \"Bacon!\"\n=&gt; \"Chunky Bacon!\"</code></pre><p>Rubyisten haben IRB ständig offen: zum Ausprobieren, Rechnen und Nachschauen, was eine Methode wohl zurückgibt. Hier ist eine <strong>echte IRB-Sitzung</strong> für dich – tippe unten ins Terminal und drücke <kbd>Enter</kbd>:</p>"
          },
          {
            "t": "c",
            "code": "show_irb"
          },
          {
            "t": "h",
            "html": "<p>Drei Tricks, die jeder IRB-Profi kennt – probier sie oben aus:</p><ul><li><code>_</code> (Unterstrich) ist immer die <strong>letzte Antwort</strong>: erst <code>6 * 7</code>, dann <code>_ + 1</code>.</li><li>IRB versteht <strong>mehrzeilige Eingaben</strong>: Tippe <code>def verdoppeln(x)</code> – der Prompt bekommt ein <code>*</code> und wartet, bis du <code>x * 2</code> und <code>end</code> nachgeliefert hast.</li><li><code>exit</code> beendet IRB (auf deinem Rechner … hier bleibt der Fuchs stur).</li></ul><div class='task'><strong>Aufgabe:</strong> Benutze die Zelle unten wie eine IRB-Zeile: Verdreifache jede Zahl im Array <code>[4, 8, 15]</code> mit <code>map</code> – der Wert soll <code>[12, 24, 45]</code> sein. (Erst oben im Terminal ausprobieren!)</div>"
          },
          {
            "t": "x",
            "code": "# [4, 8, 15].map { |x| ... }\n",
            "check": "result == [12, 24, 45] && code.include?(\"map\")",
            "hint": "Schreibe <code>[4, 8, 15].map { |x| x * 3 }</code> als letzte Zeile – <code>map</code> baut aus jedem Element ein neues Array."
          }
        ]
      },
      "en": {
        "title": "12. IRB – Ruby's playground",
        "cells": [
          {
            "t": "h",
            "html": "<h2>IRB – Ruby's playground</h2><p>Every computer with Ruby already ships with <strong>IRB</strong> (“Interactive RuBy”). You start it by typing <code>irb</code> into a terminal – then you feed Ruby one line at a time, and just like this notebook IRB shows each line's value with <code>=&gt;</code>:</p><pre><code>$ irb\nirb(main):001:0&gt; 1 + 1\n=&gt; 2\nirb(main):002:0&gt; \"Chunky \" + \"Bacon!\"\n=&gt; \"Chunky Bacon!\"</code></pre><p>Rubyists keep IRB open all the time: for experiments, quick math, and checking what a method returns. Here is a <strong>real IRB session</strong> for you – type into the terminal below and press <kbd>Enter</kbd>:</p>"
          },
          {
            "t": "c",
            "code": "show_irb"
          },
          {
            "t": "h",
            "html": "<p>Three tricks every IRB pro knows – try them above:</p><ul><li><code>_</code> (underscore) is always the <strong>last answer</strong>: first <code>6 * 7</code>, then <code>_ + 1</code>.</li><li>IRB understands <strong>multi-line input</strong>: type <code>def double(x)</code> – the prompt gets a <code>*</code> and waits until you deliver <code>x * 2</code> and <code>end</code>.</li><li><code>exit</code> quits IRB (on your machine … here the fox refuses to leave).</li></ul><div class='task'><strong>Task:</strong> Use the cell below like an IRB line: triple every number in the array <code>[4, 8, 15]</code> using <code>map</code> – the value should be <code>[12, 24, 45]</code>. (Experiment in the terminal above first!)</div>"
          },
          {
            "t": "x",
            "code": "# [4, 8, 15].map { |x| ... }\n",
            "check": "result == [12, 24, 45] && code.include?(\"map\")",
            "hint": "Write <code>[4, 8, 15].map { |x| x * 3 }</code> as the last line – <code>map</code> builds a new array from every element."
          }
        ]
      }
    },
    {
      "id": "gems",
      "de": {
        "title": "13. Gems installieren",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Gems – Rubys Bausteine</h2><p>Eine <strong>Gem</strong> ist ein fertiges Ruby-Paket, das du in dein Programm laden kannst. Die zentrale Sammelstelle ist <a href='https://rubygems.org' target='_blank'>rubygems.org</a> – über 180&nbsp;000 Gems für alles Mögliche.</p><p>Auf deinem eigenen Computer installierst du eine Gem im Terminal mit <code>gem install</code> und lädst sie danach in IRB oder deinem Programm mit <code>require</code>:</p><pre><code>$ gem install chunky_png\nSuccessfully installed chunky_png-1.4.0\n$ irb\nirb(main):001:0&gt; require \"chunky_png\"\n=&gt; true</code></pre><p>In richtigen Projekten listet man alle Gems in einer Datei namens <code>Gemfile</code> (eine Zeile pro Gem: <code>gem \"chunky_png\"</code>) und holt sie mit <code>bundle install</code> auf einen Schlag – das erledigt <a href='https://bundler.io' target='_blank'>Bundler</a>.</p><p>Auf dieser Seite übernimmt <code>install_gem</code> diesen Job für <em>pure-Ruby</em>-Gems, direkt im Browser (oder du nutzt das 💎-Panel links). Häufig gebrauchte Gems sind lokal zwischengespeichert (⚡) und installieren blitzschnell:</p>"
          },
          {
            "t": "c",
            "code": "install_gem \"chunky_png\""
          },
          {
            "t": "h",
            "html": "<p><code>chunky_png</code> – der Name ist natürlich kein Zufall, liebe Füchse! 🥓 – erstellt PNG-Bilder in purem Ruby. Nach der Installation lädst du es ganz normal mit <code>require</code>. Und mit <code>show_image</code> zeigst du ein Bild direkt unter der Zelle an:</p>"
          },
          {
            "t": "c",
            "code": "require \"chunky_png\"\n\nbild = ChunkyPNG::Image.new(8, 8, ChunkyPNG::Color::WHITE)\n8.times { |i| bild[i, i] = ChunkyPNG::Color.rgb(232, 114, 42) }\nshow_image bild"
          },
          {
            "t": "h",
            "html": "<p>Jeder Pixel ist ansprechbar: <code>bild[x, y] = farbe</code>. Farben baust du mit <code>ChunkyPNG::Color.rgb(rot, gruen, blau)</code>.</p><div class='task'><strong>Aufgabe:</strong> Male die Speck-Fahne! Erzeuge ein Bild <code>bild</code> (mindestens 8×8) und färbe die geraden Zeilen speckrot – <code>ChunkyPNG::Color.rgb(193, 74, 46)</code> –, die ungeraden lässt du weiss. Zeig dein Werk mit <code>show_image bild</code>.</div>"
          },
          {
            "t": "x",
            "code": "install_gem \"chunky_png\"\nrequire \"chunky_png\"\n\n# bild = ChunkyPNG::Image.new(8, 8, ChunkyPNG::Color::WHITE)\n# ...\n# show_image bild\n",
            "check": "defined?(ChunkyPNG) && bild.is_a?(ChunkyPNG::Image) && bild.width >= 8 && bild.pixels.include?(ChunkyPNG::Color.rgb(193, 74, 46)) && images.length >= 1",
            "hint": "Zum Beispiel: <code>8.times do |y|</code> … wenn <code>y.even?</code>, dann <code>8.times { |x| bild[x, y] = ChunkyPNG::Color.rgb(193, 74, 46) }</code> … <code>end</code> – und am Ende <code>show_image bild</code>."
          }
        ]
      },
      "en": {
        "title": "13. Installing gems",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Gems – Ruby's building blocks</h2><p>A <strong>gem</strong> is a ready-made Ruby package you can load into your program. The central collection is <a href='https://rubygems.org' target='_blank'>rubygems.org</a> – over 180,000 gems for everything imaginable.</p><p>On your own computer you install a gem in the terminal with <code>gem install</code>, then load it in IRB or your program with <code>require</code>:</p><pre><code>$ gem install chunky_png\nSuccessfully installed chunky_png-1.4.0\n$ irb\nirb(main):001:0&gt; require \"chunky_png\"\n=&gt; true</code></pre><p>In real projects you list all gems in a file called <code>Gemfile</code> (one line per gem: <code>gem \"chunky_png\"</code>) and fetch them in one go with <code>bundle install</code> – that's <a href='https://bundler.io' target='_blank'>Bundler</a>'s job.</p><p>On this site, <code>install_gem</code> does that job for <em>pure-Ruby</em> gems, right in your browser (or use the 💎 panel on the left). Frequently used gems are cached locally (⚡) and install instantly:</p>"
          },
          {
            "t": "c",
            "code": "install_gem \"chunky_png\""
          },
          {
            "t": "h",
            "html": "<p><code>chunky_png</code> – the name is no coincidence, dear foxes! 🥓 – creates PNG images in pure Ruby. After installing you load it with a normal <code>require</code>. And <code>show_image</code> displays a picture right below the cell:</p>"
          },
          {
            "t": "c",
            "code": "require \"chunky_png\"\n\nimage = ChunkyPNG::Image.new(8, 8, ChunkyPNG::Color::WHITE)\n8.times { |i| image[i, i] = ChunkyPNG::Color.rgb(232, 114, 42) }\nshow_image image"
          },
          {
            "t": "h",
            "html": "<p>Every pixel is addressable: <code>image[x, y] = color</code>. You build colors with <code>ChunkyPNG::Color.rgb(red, green, blue)</code>.</p><div class='task'><strong>Task:</strong> Paint the bacon flag! Create an image <code>image</code> (at least 8×8) and color the even rows bacon-red – <code>ChunkyPNG::Color.rgb(193, 74, 46)</code> – leaving the odd rows white. Show your work with <code>show_image image</code>.</div>"
          },
          {
            "t": "x",
            "code": "install_gem \"chunky_png\"\nrequire \"chunky_png\"\n\n# image = ChunkyPNG::Image.new(8, 8, ChunkyPNG::Color::WHITE)\n# ...\n# show_image image\n",
            "check": "defined?(ChunkyPNG) && image.is_a?(ChunkyPNG::Image) && image.width >= 8 && image.pixels.include?(ChunkyPNG::Color.rgb(193, 74, 46)) && images.length >= 1",
            "hint": "For example: <code>8.times do |y|</code> … if <code>y.even?</code>, then <code>8.times { |x| image[x, y] = ChunkyPNG::Color.rgb(193, 74, 46) }</code> … <code>end</code> – and finally <code>show_image image</code>."
          }
        ]
      }
    },
    {
      "id": "html",
      "de": {
        "title": "14. HTML parsen",
        "cells": [
          {
            "t": "h",
            "html": "<h2>HTML parsen – wie die Profis</h2><p>Ruby wird oft benutzt, um Webseiten auszulesen (<em>Scraping</em>). Das berühmteste Werkzeug dafür heisst <strong>Nokogiri</strong>:</p><pre><code>require \"nokogiri\"\ndoc = Nokogiri::HTML(html)\ndoc.css(\"a\").each { |link| puts link.text }</code></pre><p>Nokogiri ist aber zu grossen Teilen in <strong>C</strong> geschrieben. Hier im Browser läuft Ruby als WebAssembly, und dort lassen sich zur Laufzeit nur pure-Ruby-Gems installieren – C-Gems müssten fest in die wasm-Datei einkompiliert werden. Probier ruhig aus, was passiert:</p>"
          },
          {
            "t": "c",
            "code": "install_gem \"nokogiri\""
          },
          {
            "t": "h",
            "html": "<p>Zum Glück gibt es <code>gammo</code>, einen HTML5-Parser in purem Ruby. Die Ideen sind genau dieselben wie bei Nokogiri: erst <em>parsen</em> (aus Text wird ein Baum), dann mit <strong>CSS-Selektoren</strong> suchen:</p>"
          },
          {
            "t": "c",
            "code": "install_gem \"gammo\"\nrequire \"gammo\"\nrequire \"gammo/css_selector\"\n\nhtml = \"<html><body>\n  <h1>Speisekarte</h1>\n  <ul>\n    <li><a href='/speck'>Speck</a></li>\n    <li><a href='/ei'>Ei</a></li>\n    <li><a href='/kaffee'>Kaffee</a></li>\n  </ul>\n</body></html>\"\n\ndoc = Gammo.new(html).parse\ndoc.css(\"li\").length"
          },
          {
            "t": "h",
            "html": "<p><code>doc.css(\"li\")</code> findet alle <code>&lt;li&gt;</code>-Elemente – wie in einem Stylesheet. Jeder Treffer ist ein Knoten mit <code>inner_text</code> und <code>attributes</code>:</p>"
          },
          {
            "t": "c",
            "code": "doc.css(\"a\").map { |link| link.inner_text }"
          },
          {
            "t": "h",
            "html": "<div class='task'><strong>Aufgabe:</strong> Sammle alle <strong>Link-Adressen</strong> aus dem Dokument: Baue mit <code>map</code> ein Array <code>links</code> aller <code>href</code>-Werte. An ein Attribut kommst du mit <code>link.attributes.to_h[\"href\"]</code>. Ergebnis: <code>[\"/speck\", \"/ei\", \"/kaffee\"]</code>. (Führe zuerst die Zellen oben aus, damit <code>doc</code> existiert.)</div>"
          },
          {
            "t": "x",
            "code": "# links = doc.css(\"a\").map { |link| ... }\n",
            "check": "links == [\"/speck\", \"/ei\", \"/kaffee\"]",
            "hint": "<code>links = doc.css(\"a\").map { |link| link.attributes.to_h[\"href\"] }</code> – und vorher die Demo-Zellen ausführen, damit <code>doc</code> existiert."
          }
        ]
      },
      "en": {
        "title": "14. Parsing HTML",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Parsing HTML – like the pros</h2><p>Ruby is often used to read websites (<em>scraping</em>). The most famous tool for that is <strong>Nokogiri</strong>:</p><pre><code>require \"nokogiri\"\ndoc = Nokogiri::HTML(html)\ndoc.css(\"a\").each { |link| puts link.text }</code></pre><p>But Nokogiri is largely written in <strong>C</strong>. In this browser Ruby runs as WebAssembly, where only pure-Ruby gems can be installed at runtime – C gems would have to be compiled into the wasm binary itself. Go ahead and see what happens:</p>"
          },
          {
            "t": "c",
            "code": "install_gem \"nokogiri\""
          },
          {
            "t": "h",
            "html": "<p>Luckily there is <code>gammo</code>, an HTML5 parser in pure Ruby. The ideas are exactly the same as Nokogiri's: first <em>parse</em> (text becomes a tree), then search with <strong>CSS selectors</strong>:</p>"
          },
          {
            "t": "c",
            "code": "install_gem \"gammo\"\nrequire \"gammo\"\nrequire \"gammo/css_selector\"\n\nhtml = \"<html><body>\n  <h1>Menu</h1>\n  <ul>\n    <li><a href='/bacon'>Bacon</a></li>\n    <li><a href='/egg'>Egg</a></li>\n    <li><a href='/coffee'>Coffee</a></li>\n  </ul>\n</body></html>\"\n\ndoc = Gammo.new(html).parse\ndoc.css(\"li\").length"
          },
          {
            "t": "h",
            "html": "<p><code>doc.css(\"li\")</code> finds all <code>&lt;li&gt;</code> elements – just like in a stylesheet. Every match is a node with <code>inner_text</code> and <code>attributes</code>:</p>"
          },
          {
            "t": "c",
            "code": "doc.css(\"a\").map { |link| link.inner_text }"
          },
          {
            "t": "h",
            "html": "<div class='task'><strong>Task:</strong> Collect all <strong>link addresses</strong> from the document: use <code>map</code> to build an array <code>links</code> of all <code>href</code> values. You reach an attribute via <code>link.attributes.to_h[\"href\"]</code>. Expected result: <code>[\"/bacon\", \"/egg\", \"/coffee\"]</code>. (Run the cells above first so <code>doc</code> exists.)</div>"
          },
          {
            "t": "x",
            "code": "# links = doc.css(\"a\").map { |link| ... }\n",
            "check": "links == [\"/bacon\", \"/egg\", \"/coffee\"]",
            "hint": "<code>links = doc.css(\"a\").map { |link| link.attributes.to_h[\"href\"] }</code> – and run the demo cells first so <code>doc</code> exists."
          }
        ]
      }
    },
    {
      "id": "sinatra",
      "de": {
        "title": "15. Sinatra – Webserver",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Webseiten bauen – Request und Response</h2><p>Bisher lief dein Code einfach von oben nach unten. Ein <strong>Webserver</strong> arbeitet anders: Er wartet auf <em>Anfragen</em> (Requests) wie <code>GET /speisekarte</code> und schickt <em>Antworten</em> (Responses) zurück – meistens HTML. Welcher Code auf welchen Pfad reagiert, bestimmen <strong>Routen</strong>.</p><p><strong>Sinatra</strong> ist seit 2007 der Klassiker unter Rubys Web-Frameworks: Eine Route ist einfach ein Methodenaufruf mit Block. Führ die Zelle aus – darunter erscheint ein kleiner Browser:</p>"
          },
          {
            "t": "c",
            "code": "install_gem \"sinatra\"\nrequire \"sinatra/base\"\n\nclass Imbiss < Sinatra::Base\n  get \"/\" do\n    \"<h1>Chunkys Imbiss</h1>\n     <p>Willkommen! Heute im Angebot: Speck.</p>\n     <a href='/speisekarte'>Zur Speisekarte</a>\"\n  end\n\n  get \"/speisekarte\" do\n    \"<h2>Speisekarte</h2>\n     <ul><li>Speck</li><li>Ei</li><li>Kaffee</li></ul>\n     <a href='/'>Zurück</a>\"\n  end\n\n  get \"/hallo/:name\" do\n    \"Hallo, #{params[:name]}! Schön, dass du da bist.\"\n  end\nend\n\nshow_browser Imbiss, \"/\""
          },
          {
            "t": "h",
            "html": "<p>Der Mini-Browser spricht direkt mit deiner App: Klick auf die Links, oder tipp einen Pfad in die Adressleiste – probier <code>/hallo/Kaz</code> oder auch <code>/pizza</code> (ergibt 404!).</p><p>So funktioniert es: <code>get \"/pfad\" do … end</code> registriert eine Route, der <strong>Rückgabewert des Blocks</strong> wird die Antwort. Teile mit Doppelpunkt wie <code>:name</code> sind Platzhalter und landen in <code>params</code>. Auf einem richtigen Server startest du so eine App mit <code>ruby app.rb</code> und besuchst <code>localhost:4567</code> – hier ruft der Mini-Browser die App direkt auf (beide sprechen <em>Rack</em>, Rubys Web-Standard).</p><div class='task'><strong>Aufgabe:</strong> Ergänze die Route <code>get \"/speck\"</code>, die <code>CHUNKY BACON!</code> zurückgibt. Der Mini-Browser unten zeigt <code>/speck</code> – im Moment noch ein 404.</div>"
          },
          {
            "t": "x",
            "code": "install_gem \"sinatra\"\nrequire \"sinatra/base\"\n\nclass MeineSeite < Sinatra::Base\n  get \"/\" do\n    \"<h1>Meine Seite</h1>\"\n  end\n\n  # get \"/speck\" do\n  #   ...\n  # end\nend\n\nshow_browser MeineSeite, \"/speck\"",
            "check": "s1, _ = mock_get(MeineSeite, \"/\"); s2, b2 = mock_get(MeineSeite, \"/speck\"); s1 == 200 && s2 == 200 && b2.include?(\"CHUNKY BACON!\")",
            "hint": "Genau wie die anderen Routen: <code>get \"/speck\" do</code>, darunter <code>\"CHUNKY BACON!\"</code>, dann <code>end</code>. Danach die Zelle neu ausführen."
          }
        ]
      },
      "en": {
        "title": "15. Sinatra – web server",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Building websites – request and response</h2><p>So far your code simply ran top to bottom. A <strong>web server</strong> works differently: it waits for <em>requests</em> like <code>GET /menu</code> and sends back <em>responses</em> – usually HTML. Which code answers which path is decided by <strong>routes</strong>.</p><p><strong>Sinatra</strong> has been the classic among Ruby's web frameworks since 2007: a route is just a method call with a block. Run the cell – a little browser appears below it:</p>"
          },
          {
            "t": "c",
            "code": "install_gem \"sinatra\"\nrequire \"sinatra/base\"\n\nclass Diner < Sinatra::Base\n  get \"/\" do\n    \"<h1>Chunky's Diner</h1>\n     <p>Welcome! Today's special: bacon.</p>\n     <a href='/menu'>See the menu</a>\"\n  end\n\n  get \"/menu\" do\n    \"<h2>Menu</h2>\n     <ul><li>Bacon</li><li>Egg</li><li>Coffee</li></ul>\n     <a href='/'>Back</a>\"\n  end\n\n  get \"/hello/:name\" do\n    \"Hello, #{params[:name]}! Nice to see you.\"\n  end\nend\n\nshow_browser Diner, \"/\""
          },
          {
            "t": "h",
            "html": "<p>The mini browser talks directly to your app: click the links, or type a path into the address bar – try <code>/hello/Kaz</code> or even <code>/pizza</code> (a 404!).</p><p>How it works: <code>get \"/path\" do … end</code> registers a route, and the <strong>block's return value</strong> becomes the response. Parts with a colon like <code>:name</code> are placeholders and end up in <code>params</code>. On a real server you'd start such an app with <code>ruby app.rb</code> and visit <code>localhost:4567</code> – here the mini browser calls the app directly (both speak <em>Rack</em>, Ruby's web standard).</p><div class='task'><strong>Task:</strong> Add the route <code>get \"/bacon\"</code> returning <code>CHUNKY BACON!</code>. The mini browser below shows <code>/bacon</code> – a 404 for now.</div>"
          },
          {
            "t": "x",
            "code": "install_gem \"sinatra\"\nrequire \"sinatra/base\"\n\nclass MySite < Sinatra::Base\n  get \"/\" do\n    \"<h1>My Site</h1>\"\n  end\n\n  # get \"/bacon\" do\n  #   ...\n  # end\nend\n\nshow_browser MySite, \"/bacon\"",
            "check": "s1, _ = mock_get(MySite, \"/\"); s2, b2 = mock_get(MySite, \"/bacon\"); s1 == 200 && s2 == 200 && b2.include?(\"CHUNKY BACON!\")",
            "hint": "Just like the other routes: <code>get \"/bacon\" do</code>, below it <code>\"CHUNKY BACON!\"</code>, then <code>end</code>. Then run the cell again."
          }
        ]
      }
    },
    {
      "id": "roda",
      "de": {
        "title": "16. Roda – der Routing-Baum",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Roda – der Routing-Baum</h2><p><strong>Roda</strong> (von Jeremy Evans, dem Autor von Sequel) ist ein modernes, sehr schnelles Web-Framework. Statt einer flachen Routenliste wie bei Sinatra kletterst du einen <strong>Baum</strong> hinauf: Der <code>route</code>-Block bekommt den Request <code>r</code>, und du entscheidest Stück für Stück, was mit dem Pfad passiert:</p>"
          },
          {
            "t": "c",
            "code": "install_gem \"roda\"\nrequire \"roda\"\n\nclass Laden < Roda\n  route do |r|\n    r.root do\n      \"<h1>Chunkys Laden</h1>\n       <a href='/speck'>Speck</a>\n       <a href='/gruss/Chunky'>Begrüssung</a>\"\n    end\n\n    r.get \"speck\" do\n      \"<p>Speck: 3 Streifen für 2 Franken.</p><a href='/'>Zurück</a>\"\n    end\n\n    r.get \"gruss\", String do |name|\n      \"Hallo, #{name}! <a href='/'>Zurück</a>\"\n    end\n  end\nend\n\nshow_browser Laden, \"/\""
          },
          {
            "t": "h",
            "html": "<p>Lies den Baum von oben: <code>r.root</code> fängt <code>/</code>, <code>r.get \"speck\"</code> fängt <code>GET /speck</code>. Spannend wird's bei <code>r.get \"gruss\", String</code>: Das matcht <code>/gruss/&lt;irgendwas&gt;</code>, und das Pfadstück landet als Block-Parameter in <code>name</code> – probier <code>/gruss/Ada</code> im Mini-Browser! Passt gar nichts, antwortet Roda automatisch mit <strong>404</strong>.</p><div class='task'><strong>Aufgabe:</strong> Ergänze im Kiosk die Route <code>r.get \"bestellung\", Integer do |anzahl| … end</code>, die z.&nbsp;B. für <code>/bestellung/5</code> den Text <code>5 Streifen Speck, kommt sofort!</code> zurückgibt (nutze Interpolation). Der Mini-Browser unten zeigt aktuell noch 404.</div>"
          },
          {
            "t": "x",
            "code": "install_gem \"roda\"\nrequire \"roda\"\n\nclass Kiosk < Roda\n  route do |r|\n    r.root do\n      \"<h1>Kiosk</h1><a href='/bestellung/5'>5 Streifen bestellen</a>\"\n    end\n\n    # r.get \"bestellung\", Integer do |anzahl|\n    #   ...\n    # end\n  end\nend\n\nshow_browser Kiosk, \"/bestellung/5\"",
            "check": "s1, b1 = mock_get(Kiosk, \"/\"); s2, b2 = mock_get(Kiosk, \"/bestellung/5\"); s3, _ = mock_get(Kiosk, \"/pizza\"); s1 == 200 && b1.include?(\"Kiosk\") && s2 == 200 && b2.include?(\"5\") && b2.include?(\"Speck\") && s3 == 404",
            "hint": "<code>r.get \"bestellung\", Integer do |anzahl|</code> … <code>\"#{anzahl} Streifen Speck, kommt sofort!\"</code> … <code>end</code> – innerhalb des route-Blocks."
          }
        ]
      },
      "en": {
        "title": "16. Roda – the routing tree",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Roda – the routing tree</h2><p><strong>Roda</strong> (by Jeremy Evans, the author of Sequel) is a modern, very fast web framework. Instead of a flat list of routes like Sinatra, you climb a <strong>tree</strong>: the <code>route</code> block receives the request <code>r</code>, and you decide piece by piece what happens with the path:</p>"
          },
          {
            "t": "c",
            "code": "install_gem \"roda\"\nrequire \"roda\"\n\nclass Shop < Roda\n  route do |r|\n    r.root do\n      \"<h1>Chunky's Shop</h1>\n       <a href='/bacon'>Bacon</a>\n       <a href='/greet/Chunky'>Greeting</a>\"\n    end\n\n    r.get \"bacon\" do\n      \"<p>Bacon: 3 strips for 2 francs.</p><a href='/'>Back</a>\"\n    end\n\n    r.get \"greet\", String do |name|\n      \"Hello, #{name}! <a href='/'>Back</a>\"\n    end\n  end\nend\n\nshow_browser Shop, \"/\""
          },
          {
            "t": "h",
            "html": "<p>Read the tree top to bottom: <code>r.root</code> catches <code>/</code>, <code>r.get \"bacon\"</code> catches <code>GET /bacon</code>. It gets interesting with <code>r.get \"greet\", String</code>: that matches <code>/greet/&lt;anything&gt;</code>, and the path segment arrives as the block parameter <code>name</code> – try <code>/greet/Ada</code> in the mini browser! If nothing matches, Roda automatically answers with <strong>404</strong>.</p><div class='task'><strong>Task:</strong> Add the route <code>r.get \"order\", Integer do |amount| … end</code> to the kiosk so that e.g. <code>/order/5</code> returns <code>5 strips of bacon, coming right up!</code> (use interpolation). The mini browser below still shows a 404.</div>"
          },
          {
            "t": "x",
            "code": "install_gem \"roda\"\nrequire \"roda\"\n\nclass Kiosk < Roda\n  route do |r|\n    r.root do\n      \"<h1>Kiosk</h1><a href='/order/5'>Order 5 strips</a>\"\n    end\n\n    # r.get \"order\", Integer do |amount|\n    #   ...\n    # end\n  end\nend\n\nshow_browser Kiosk, \"/order/5\"",
            "check": "s1, b1 = mock_get(Kiosk, \"/\"); s2, b2 = mock_get(Kiosk, \"/order/5\"); s3, _ = mock_get(Kiosk, \"/pizza\"); s1 == 200 && b1.include?(\"Kiosk\") && s2 == 200 && b2.include?(\"5\") && b2.include?(\"bacon\") && s3 == 404",
            "hint": "<code>r.get \"order\", Integer do |amount|</code> … <code>\"#{amount} strips of bacon, coming right up!\"</code> … <code>end</code> – inside the route block."
          }
        ]
      }
    },
    {
      "id": "http",
      "de": {
        "title": "17. HTTP – Daten aus dem Netz",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Daten aus dem Netz holen</h2><p>Bisher haben wir Webseiten <em>gebaut</em> – jetzt drehen wir den Spiess um und <em>rufen welche ab</em>. Rubys Standardbibliothek bringt dafür <code>net/http</code> mit: Du baust aus einer Adresse ein <code>URI</code>-Objekt und schickst eine Anfrage los. Holen wir uns die offizielle Ruby-Website:</p>"
          },
          {
            "t": "c",
            "code": "require \"net/http\"\n\nantwort = Net::HTTP.get_response(URI(\"https://www.ruby-lang.org/de/\"))\nantwort.code"
          },
          {
            "t": "h",
            "html": "<p><code>get_response</code> liefert ein Antwort-Objekt: <code>code</code> ist der Statuscode (als String – eine berühmte kleine Eigenheit von <code>net/http</code>!), und in <code>body</code> steckt die ganze Seite als HTML-Text:</p>"
          },
          {
            "t": "c",
            "code": "antwort.body[0, 160]"
          },
          {
            "t": "h",
            "html": "<p>Moderne Dienste liefern Daten meist als <strong>JSON</strong> – perfekt zum Weiterverarbeiten. Die rubygems.org-API kennst du ja schon von der Gems-Lektion; fragen wir sie, wie oft <code>rack</code> heruntergeladen wurde:</p>"
          },
          {
            "t": "c",
            "code": "require \"json\"\n\ndaten = JSON.parse(Net::HTTP.get(URI(\"https://rubygems.org/api/v1/gems/rack.json\")))\ndaten[\"downloads\"]"
          },
          {
            "t": "h",
            "html": "<p>Auch die GitHub-API antwortet mit JSON – zum Beispiel mit den Sternen von Ruby selbst:</p>"
          },
          {
            "t": "c",
            "code": "repo = JSON.parse(Net::HTTP.get(URI(\"https://api.github.com/repos/ruby/ruby\")))\nrepo[\"stargazers_count\"]"
          },
          {
            "t": "h",
            "html": "<p><strong>Ehrliche Fussnote:</strong> Im Browser sitzt Ruby in einer Sandbox und darf nicht beliebige Server ansprechen. Diese Seite stellt deshalb eine kleine Brücke bereit – erreichbar sind <code>www.ruby-lang.org</code>, <code>rubygems.org</code> und <code>api.github.com</code>; andere Adressen ergeben einen <code>SocketError</code>. Auf deinem eigenen Computer funktioniert <code>net/http</code> mit jeder URL.</p><div class='task'><strong>Aufgabe:</strong> Frag die rubygems-API nach der Gem <code>sinatra</code>: Parse <code>https://rubygems.org/api/v1/gems/sinatra.json</code> in eine Variable <code>info</code> und lass die Zelle die Zahl der Downloads (<code>info[\"downloads\"]</code>) ergeben.</div>"
          },
          {
            "t": "x",
            "code": "require \"net/http\"\nrequire \"json\"\n\n# info = JSON.parse(Net::HTTP.get(URI(\"...\")))\n# info[\"downloads\"]\n",
            "check": "info.is_a?(Hash) && info[\"name\"] == \"sinatra\" && info[\"downloads\"].is_a?(Integer) && info[\"downloads\"] > 0 && result == info[\"downloads\"]",
            "hint": "<code>info = JSON.parse(Net::HTTP.get(URI(\"https://rubygems.org/api/v1/gems/sinatra.json\")))</code> – und als letzte Zeile <code>info[\"downloads\"]</code>."
          }
        ]
      },
      "en": {
        "title": "17. HTTP – fetching data from the web",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Fetching data from the web</h2><p>So far we've <em>built</em> websites – now let's turn the tables and <em>fetch</em> some. Ruby's standard library ships <code>net/http</code> for that: you build a <code>URI</code> object from an address and send a request. Let's fetch the official Ruby website:</p>"
          },
          {
            "t": "c",
            "code": "require \"net/http\"\n\nresponse = Net::HTTP.get_response(URI(\"https://www.ruby-lang.org/en/\"))\nresponse.code"
          },
          {
            "t": "h",
            "html": "<p><code>get_response</code> returns a response object: <code>code</code> is the status code (as a String – a famous little quirk of <code>net/http</code>!), and <code>body</code> holds the whole page as HTML text:</p>"
          },
          {
            "t": "c",
            "code": "response.body[0, 160]"
          },
          {
            "t": "h",
            "html": "<p>Modern services usually deliver data as <strong>JSON</strong> – perfect for processing. You already know the rubygems.org API from the gems lesson; let's ask it how often <code>rack</code> has been downloaded:</p>"
          },
          {
            "t": "c",
            "code": "require \"json\"\n\ndata = JSON.parse(Net::HTTP.get(URI(\"https://rubygems.org/api/v1/gems/rack.json\")))\ndata[\"downloads\"]"
          },
          {
            "t": "h",
            "html": "<p>The GitHub API answers with JSON too – for example with the stars of Ruby itself:</p>"
          },
          {
            "t": "c",
            "code": "repo = JSON.parse(Net::HTTP.get(URI(\"https://api.github.com/repos/ruby/ruby\")))\nrepo[\"stargazers_count\"]"
          },
          {
            "t": "h",
            "html": "<p><strong>Honest footnote:</strong> in the browser Ruby sits in a sandbox and may not talk to arbitrary servers. This site therefore provides a little bridge – reachable are <code>www.ruby-lang.org</code>, <code>rubygems.org</code> and <code>api.github.com</code>; other addresses raise a <code>SocketError</code>. On your own computer <code>net/http</code> works with any URL.</p><div class='task'><strong>Task:</strong> Ask the rubygems API about the gem <code>sinatra</code>: parse <code>https://rubygems.org/api/v1/gems/sinatra.json</code> into a variable <code>info</code> and make the cell yield the number of downloads (<code>info[\"downloads\"]</code>).</div>"
          },
          {
            "t": "x",
            "code": "require \"net/http\"\nrequire \"json\"\n\n# info = JSON.parse(Net::HTTP.get(URI(\"...\")))\n# info[\"downloads\"]\n",
            "check": "info.is_a?(Hash) && info[\"name\"] == \"sinatra\" && info[\"downloads\"].is_a?(Integer) && info[\"downloads\"] > 0 && result == info[\"downloads\"]",
            "hint": "<code>info = JSON.parse(Net::HTTP.get(URI(\"https://rubygems.org/api/v1/gems/sinatra.json\")))</code> – and as the last line <code>info[\"downloads\"]</code>."
          }
        ]
      }
    },
    {
      "id": "tl-collections",
      "section": {
        "de": "Aufbaukurs: timelog",
        "en": "Advanced: timelog"
      },
      "de": {
        "title": "18. Projekt timelog: Collections",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Projekt timelog – los geht's!</h2><p>Ab hier bauen wir gemeinsam ein richtiges Programm: <strong>timelog</strong>, eine Zeiterfassung. In jeder Lektion wächst sie ein Stück – bis sie am Ende Einträge parst, Berichte rechnet, getestet ist und sogar eine Weboberfläche hat.</p><p>Wir starten mit der Datenform. Ein Zeiteintrag hat ein Projekt und Stunden – als Hash. Viele Einträge – als Array von Hashes:</p>"
          },
          {
            "t": "c",
            "code": "eintraege = [\n  { projekt: \"ProjectX\", stunden: 3.5 },\n  { projekt: \"Intern\",   stunden: 2.0 },\n  { projekt: \"ProjectX\", stunden: 3.0 }\n]\neintraege.length"
          },
          {
            "t": "h",
            "html": "<p>Jetzt zeigen die Collection-Methoden ihre Kraft. <code>map</code> zieht Werte heraus, <code>select</code> filtert, <code>sum</code> summiert – und alles lässt sich verketten:</p>"
          },
          {
            "t": "c",
            "code": "eintraege.select { |e| e[:projekt] == \"ProjectX\" }\n         .sum { |e| e[:stunden] }"
          },
          {
            "t": "h",
            "html": "<p>Der Star für Berichte ist <code>group_by</code>: Es sortiert Elemente in einen Hash von Gruppen. Zusammen mit <code>transform_values</code> wird daraus in zwei Zeilen ein kompletter Bericht:</p>"
          },
          {
            "t": "c",
            "code": "eintraege.group_by { |e| e[:projekt] }"
          },
          {
            "t": "h",
            "html": "<p>Auch nützlich: <code>tally</code> zählt Vorkommen, <code>sort_by</code> sortiert, <code>each_with_object</code> baut beliebige Strukturen auf.</p><div class='task'><strong>Aufgabe:</strong> Baue aus <code>eintraege</code> einen Hash <code>stunden</code>, der jedem Projekt die <strong>Gesamtstunden</strong> zuordnet: <code>{\"ProjectX\"=>6.5, \"Intern\"=>2.0}</code>. Tipp: <code>group_by</code> + <code>transform_values</code>.</div>"
          },
          {
            "t": "x",
            "code": "eintraege = [\n  { projekt: \"ProjectX\", stunden: 3.5 },\n  { projekt: \"Intern\",   stunden: 2.0 },\n  { projekt: \"ProjectX\", stunden: 3.0 }\n]\n\n# stunden = ...\n",
            "check": "stunden == { \"ProjectX\" => 6.5, \"Intern\" => 2.0 }",
            "hint": "<code>stunden = eintraege.group_by { |e| e[:projekt] }.transform_values { |liste| liste.sum { |e| e[:stunden] } }</code>"
          }
        ]
      },
      "en": {
        "title": "18. Project timelog: collections",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Project timelog – here we go!</h2><p>From here on we build a real program together: <strong>timelog</strong>, a time tracker. It grows a little in every lesson – until it parses entries, computes reports, is fully tested and even has a web interface.</p><p>We start with the data shape. A time entry has a project and hours – as a hash. Many entries – as an array of hashes:</p>"
          },
          {
            "t": "c",
            "code": "entries = [\n  { project: \"ProjectX\", hours: 3.5 },\n  { project: \"Intern\",   hours: 2.0 },\n  { project: \"ProjectX\", hours: 3.0 }\n]\nentries.length"
          },
          {
            "t": "h",
            "html": "<p>Now the collection methods show their power. <code>map</code> extracts values, <code>select</code> filters, <code>sum</code> adds up – and everything chains:</p>"
          },
          {
            "t": "c",
            "code": "entries.select { |e| e[:project] == \"ProjectX\" }\n       .sum { |e| e[:hours] }"
          },
          {
            "t": "h",
            "html": "<p>The star for reports is <code>group_by</code>: it sorts elements into a hash of groups. Together with <code>transform_values</code> that becomes a complete report in two lines:</p>"
          },
          {
            "t": "c",
            "code": "entries.group_by { |e| e[:project] }"
          },
          {
            "t": "h",
            "html": "<p>Also useful: <code>tally</code> counts occurrences, <code>sort_by</code> sorts, <code>each_with_object</code> builds arbitrary structures.</p><div class='task'><strong>Task:</strong> Build a hash <code>hours</code> from <code>entries</code> that maps each project to its <strong>total hours</strong>: <code>{\"ProjectX\"=>6.5, \"Intern\"=>2.0}</code>. Hint: <code>group_by</code> + <code>transform_values</code>.</div>"
          },
          {
            "t": "x",
            "code": "entries = [\n  { project: \"ProjectX\", hours: 3.5 },\n  { project: \"Intern\",   hours: 2.0 },\n  { project: \"ProjectX\", hours: 3.0 }\n]\n\n# hours = ...\n",
            "check": "hours == { \"ProjectX\" => 6.5, \"Intern\" => 2.0 }",
            "hint": "<code>hours = entries.group_by { |e| e[:project] }.transform_values { |list| list.sum { |e| e[:hours] } }</code>"
          }
        ]
      }
    },
    {
      "id": "tl-parsing",
      "de": {
        "title": "19. Text parsen: Regex",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Einträge parsen – reguläre Ausdrücke</h2><p>timelog soll Zeilen wie diese verstehen:</p><pre><code>2026-09-15 08:30-12:00 ProjectX Planungsmeeting</code></pre><p>Dafür gibt es <strong>reguläre Ausdrücke</strong> (Regex): Muster, die Text beschreiben. <code>\\d</code> ist eine Ziffer, <code>{2}</code> heisst „genau zwei davon“, und mit <code>(?&lt;name&gt;…)</code> gibst du einer Fundstelle einen Namen:</p>"
          },
          {
            "t": "c",
            "code": "zeile = \"2026-09-15 08:30-12:00 ProjectX Planungsmeeting\"\n\nmuster = /(?<datum>\\d{4}-\\d{2}-\\d{2}) (?<von>\\d{2}:\\d{2})-(?<bis>\\d{2}:\\d{2}) (?<projekt>\\S+)/\ntreffer = zeile.match(muster)\ntreffer[:projekt]"
          },
          {
            "t": "h",
            "html": "<p><code>match</code> liefert ein <code>MatchData</code>-Objekt – benannte Gruppen holst du mit <code>treffer[:von]</code> heraus. Passt nichts, kommt <code>nil</code> zurück (perfekt für <code>if</code>). Schnelltest ohne Daten: <code>zeile.match?(muster)</code>.</p><p>Für Fallunterscheidungen hat Ruby das elegante <code>case/when</code> – es versteht Ranges, Klassen und sogar Regexe:</p>"
          },
          {
            "t": "c",
            "code": "def einordnen(stunden)\n  case stunden\n  when 0...4 then \"Halbtag\"\n  when 4...9 then \"Ganztag\"\n  else            \"Ueberstunden!\"\n  end\nend\n\neinordnen(7.5)"
          },
          {
            "t": "h",
            "html": "<div class='task'><strong>Aufgabe:</strong> Schreibe <code>parse_zeile(zeile)</code>: Sie zerlegt eine timelog-Zeile mit benannten Gruppen und gibt <code>{ projekt:, von:, bis: }</code> zurück – bei unpassenden Zeilen <code>nil</code>. Teste mit der Beispielzeile als letzter Zeile: <code>parse_zeile(\"2026-09-15 08:30-12:00 ProjectX Meeting\")</code>.</div>"
          },
          {
            "t": "x",
            "code": "# def parse_zeile(zeile)\n#   muster = /.../  # benannte Gruppen: datum, von, bis, projekt\n#   ...\n# end\n",
            "check": "parse_zeile(\"2026-09-15 08:30-12:00 ProjectX Meeting\") == { projekt: \"ProjectX\", von: \"08:30\", bis: \"12:00\" } && parse_zeile(\"Kaffeepause\").nil? && code.include?(\"(?<\")",
            "hint": "Muster wie in der Demo. Danach: <code>treffer = zeile.match(muster)</code>, <code>return nil unless treffer</code>, dann <code>{ projekt: treffer[:projekt], von: treffer[:von], bis: treffer[:bis] }</code>."
          }
        ]
      },
      "en": {
        "title": "19. Parsing text: regex",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Parsing entries – regular expressions</h2><p>timelog should understand lines like this:</p><pre><code>2026-09-15 08:30-12:00 ProjectX planning-meeting</code></pre><p>That's what <strong>regular expressions</strong> (regex) are for: patterns that describe text. <code>\\d</code> is a digit, <code>{2}</code> means “exactly two of them”, and <code>(?&lt;name&gt;…)</code> gives a match a name:</p>"
          },
          {
            "t": "c",
            "code": "line = \"2026-09-15 08:30-12:00 ProjectX planning-meeting\"\n\npattern = /(?<date>\\d{4}-\\d{2}-\\d{2}) (?<from>\\d{2}:\\d{2})-(?<to>\\d{2}:\\d{2}) (?<project>\\S+)/\nhit = line.match(pattern)\nhit[:project]"
          },
          {
            "t": "h",
            "html": "<p><code>match</code> returns a <code>MatchData</code> object – you fetch named groups with <code>hit[:from]</code>. If nothing matches you get <code>nil</code> (perfect for <code>if</code>). Quick test without data: <code>line.match?(pattern)</code>.</p><p>For branching, Ruby has the elegant <code>case/when</code> – it understands ranges, classes and even regexes:</p>"
          },
          {
            "t": "c",
            "code": "def classify(hours)\n  case hours\n  when 0...4 then \"half day\"\n  when 4...9 then \"full day\"\n  else            \"overtime!\"\n  end\nend\n\nclassify(7.5)"
          },
          {
            "t": "h",
            "html": "<div class='task'><strong>Task:</strong> Write <code>parse_line(line)</code>: it splits a timelog line using named groups and returns <code>{ project:, from:, to: }</code> – or <code>nil</code> for lines that don't match. Test it as the last line: <code>parse_line(\"2026-09-15 08:30-12:00 ProjectX meeting\")</code>.</div>"
          },
          {
            "t": "x",
            "code": "# def parse_line(line)\n#   pattern = /.../  # named groups: date, from, to, project\n#   ...\n# end\n",
            "check": "parse_line(\"2026-09-15 08:30-12:00 ProjectX meeting\") == { project: \"ProjectX\", from: \"08:30\", to: \"12:00\" } && parse_line(\"coffee break\").nil? && code.include?(\"(?<\")",
            "hint": "Pattern like in the demo. Then: <code>hit = line.match(pattern)</code>, <code>return nil unless hit</code>, then <code>{ project: hit[:project], from: hit[:from], to: hit[:to] }</code>."
          }
        ]
      }
    },
    {
      "id": "tl-methods",
      "de": {
        "title": "20. Methoden richtig bauen",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Methoden mit Stil</h2><p>Du kennst <code>def</code> – jetzt kommen die Feinheiten, die Ruby-Code lesbar machen. <strong>Keyword-Argumente</strong> machen Aufrufe selbsterklärend, Defaults machen Argumente optional:</p>"
          },
          {
            "t": "c",
            "code": "def gruss(name:, laut: false)\n  text = \"Hallo, #{name}\"\n  laut ? text.upcase + \"!\" : text\nend\n\ngruss(name: \"Kaz\", laut: true)"
          },
          {
            "t": "h",
            "html": "<p>Vergleiche <code>gruss(name: \"Kaz\")</code> mit einem anonymen <code>gruss(\"Kaz\", true)</code> – bei mehreren Argumenten gewinnt die Keyword-Variante klar an Lesbarkeit. Weitere Konventionen: <code>*rest</code> sammelt beliebig viele Argumente ein, Methoden mit <code>?</code> geben wahr/falsch zurück, Methoden mit <code>!</code> sind die „gefährliche“ Variante. Und: Der Wert der letzten Zeile ist automatisch der Rückgabewert.</p><p>Zur Erinnerung aus Lektion 9: Klammern sind optional. Zusammen mit Keyword-Argumenten entsteht so der deklarative Ruby-Stil, den du aus <code>attr_reader :name</code> kennst – <code>add_entry projekt: \"X\", von: \"08:30\", bis: \"10:00\"</code> liest sich fast wie Konfiguration. In verschachtelten Ausdrücken gehören die Klammern aber wieder hin.</p><p>Für timelog brauchen wir Zeitrechnung – <code>\"08:30\"</code> in Stunden seit Mitternacht:</p>"
          },
          {
            "t": "c",
            "code": "def als_stunden(uhrzeit)\n  h, m = uhrzeit.split(\":\").map(&:to_i)\n  h + m / 60.0\nend\n\nals_stunden(\"08:30\")"
          },
          {
            "t": "h",
            "html": "<div class='task'><strong>Aufgabe:</strong> Schreibe <code>add_entry(projekt:, von:, bis:, notiz: nil)</code>. Sie gibt einen Hash zurück: <code>{ projekt:, von:, bis:, notiz:, stunden: }</code>, wobei <code>stunden</code> die Differenz aus <code>als_stunden(bis)</code> und <code>als_stunden(von)</code> ist. <code>add_entry(projekt: \"X\", von: \"08:30\", bis: \"10:00\")</code> soll also <code>stunden: 1.5</code> enthalten.</div>"
          },
          {
            "t": "x",
            "code": "def als_stunden(uhrzeit)\n  h, m = uhrzeit.split(\":\").map(&:to_i)\n  h + m / 60.0\nend\n\n# def add_entry(projekt:, von:, bis:, notiz: nil)\n#   ...\n# end\n",
            "check": "e = add_entry(projekt: \"X\", von: \"08:30\", bis: \"10:00\"); e[:stunden] == 1.5 && e[:projekt] == \"X\" && e[:notiz].nil? && add_entry(projekt: \"Y\", von: \"09:00\", bis: \"17:00\", notiz: \"Doku\")[:notiz] == \"Doku\" && code.include?(\"projekt:\")",
            "hint": "<code>{ projekt: projekt, von: von, bis: bis, notiz: notiz, stunden: als_stunden(bis) - als_stunden(von) }</code> – als letzte Zeile der Methode."
          }
        ]
      },
      "en": {
        "title": "20. Building methods properly",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Methods with style</h2><p>You know <code>def</code> – now come the finer points that make Ruby code readable. <strong>Keyword arguments</strong> make calls self-explaining, defaults make arguments optional:</p>"
          },
          {
            "t": "c",
            "code": "def greet(name:, loud: false)\n  text = \"Hello, #{name}\"\n  loud ? text.upcase + \"!\" : text\nend\n\ngreet(name: \"Kaz\", loud: true)"
          },
          {
            "t": "h",
            "html": "<p>Compare <code>greet(name: \"Kaz\")</code> with an anonymous <code>greet(\"Kaz\", true)</code> – with several arguments the keyword variant clearly wins on readability. More conventions: <code>*rest</code> collects any number of arguments, methods ending in <code>?</code> return true/false, methods ending in <code>!</code> are the “dangerous” variant. And: the value of the last line is automatically the return value.</p><p>Remember lesson 9: parentheses are optional. Combined with keyword arguments this creates the declarative Ruby style you know from <code>attr_reader :name</code> – <code>add_entry project: \"X\", from: \"08:30\", to: \"10:00\"</code> reads almost like configuration. In nested expressions, though, the parentheses go back in.</p><p>timelog needs time math – <code>\"08:30\"</code> as hours since midnight:</p>"
          },
          {
            "t": "c",
            "code": "def as_hours(time)\n  h, m = time.split(\":\").map(&:to_i)\n  h + m / 60.0\nend\n\nas_hours(\"08:30\")"
          },
          {
            "t": "h",
            "html": "<div class='task'><strong>Task:</strong> Write <code>add_entry(project:, from:, to:, note: nil)</code>. It returns a hash: <code>{ project:, from:, to:, note:, hours: }</code>, where <code>hours</code> is the difference of <code>as_hours(to)</code> and <code>as_hours(from)</code>. So <code>add_entry(project: \"X\", from: \"08:30\", to: \"10:00\")</code> should contain <code>hours: 1.5</code>.</div>"
          },
          {
            "t": "x",
            "code": "def as_hours(time)\n  h, m = time.split(\":\").map(&:to_i)\n  h + m / 60.0\nend\n\n# def add_entry(project:, from:, to:, note: nil)\n#   ...\n# end\n",
            "check": "e = add_entry(project: \"X\", from: \"08:30\", to: \"10:00\"); e[:hours] == 1.5 && e[:project] == \"X\" && e[:note].nil? && add_entry(project: \"Y\", from: \"09:00\", to: \"17:00\", note: \"docs\")[:note] == \"docs\" && code.include?(\"project:\")",
            "hint": "<code>{ project: project, from: from, to: to, note: note, hours: as_hours(to) - as_hours(from) }</code> – as the method's last line."
          }
        ]
      }
    },
    {
      "id": "tl-classes",
      "de": {
        "title": "21. Entry & Timesheet",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Vom Hash zur Klasse</h2><p>Hashes sind super zum Anfangen – aber sobald Daten <em>Verhalten</em> brauchen (Stunden ausrechnen, sich schön ausgeben), ist eine Klasse der richtige Ort. Wir bauen timelog um zwei Klassen: <code>Entry</code> (ein Eintrag) und <code>Timesheet</code> (die Sammlung).</p>"
          },
          {
            "t": "c",
            "code": "class Entry\n  attr_reader :projekt, :von, :bis, :notiz\n\n  def initialize(projekt:, von:, bis:, notiz: nil)\n    @projekt = projekt\n    @von = von\n    @bis = bis\n    @notiz = notiz\n  end\n\n  def stunden\n    als_stunden(@bis) - als_stunden(@von)\n  end\n\n  def to_s\n    \"#{@projekt}: #{@von}-#{@bis} (#{stunden}h)\"\n  end\n\n  private\n\n  def als_stunden(uhrzeit)\n    h, m = uhrzeit.split(\":\").map(&:to_i)\n    h + m / 60.0\n  end\nend\n\nEntry.new(projekt: \"ProjectX\", von: \"08:30\", bis: \"12:00\").to_s"
          },
          {
            "t": "h",
            "html": "<p>Beachte: <code>als_stunden</code> ist <code>private</code> – ein internes Detail, das von aussen niemand braucht. <code>to_s</code> bestimmt, wie sich das Objekt als Text ausgibt. Instanzvariablen (<code>@projekt</code>) gehören zum Objekt; Konstanten (<code>GROSS</code>) zur Klasse. Von Klassenvariablen (<code>@@…</code>) und globalen Variablen (<code>$…</code>) lässt man besser die Finger – sie sind geteilter Zustand, der schwer zu verfolgen ist.</p>"
          },
          {
            "t": "c",
            "code": "class Timesheet\n  def initialize\n    @eintraege = []\n  end\n\n  def add(entry)\n    @eintraege << entry\n    self\n  end\n\n  def anzahl\n    @eintraege.length\n  end\nend\n\nblatt = Timesheet.new\nblatt.add(Entry.new(projekt: \"ProjectX\", von: \"08:30\", bis: \"12:00\"))\nblatt.anzahl"
          },
          {
            "t": "h",
            "html": "<p>Das <code>self</code> am Ende von <code>add</code> erlaubt Verkettung: <code>blatt.add(a).add(b)</code>.</p><div class='task'><strong>Aufgabe:</strong> Ergänze <code>Timesheet</code> um <code>total_for(projekt)</code>: die Gesamtstunden aller Einträge dieses Projekts. Nutze <code>select</code> und <code>sum</code> auf <code>@eintraege</code>.</div>"
          },
          {
            "t": "x",
            "code": "# Entry aus der Demo-Zelle oben wird hier weiterverwendet -\n# fuehre sie zuerst aus!\n\nclass Timesheet\n  def initialize\n    @eintraege = []\n  end\n\n  def add(entry)\n    @eintraege << entry\n    self\n  end\n\n  # def total_for(projekt)\n  #   ...\n  # end\nend\n",
            "check": "ts = Timesheet.new.add(Entry.new(projekt: \"A\", von: \"08:00\", bis: \"10:30\")).add(Entry.new(projekt: \"B\", von: \"10:30\", bis: \"11:30\")).add(Entry.new(projekt: \"A\", von: \"13:00\", bis: \"14:00\")); ts.total_for(\"A\") == 3.5 && ts.total_for(\"B\") == 1.0 && ts.total_for(\"C\") == 0",
            "hint": "<code>def total_for(projekt); @eintraege.select { |e| e.projekt == projekt }.sum(&:stunden); end</code> – und vorher die Entry-Zelle oben ausführen."
          }
        ]
      },
      "en": {
        "title": "21. Entry & Timesheet",
        "cells": [
          {
            "t": "h",
            "html": "<h2>From hash to class</h2><p>Hashes are great to start with – but as soon as data needs <em>behavior</em> (computing hours, printing itself nicely), a class is the right home. We build timelog around two classes: <code>Entry</code> (one entry) and <code>Timesheet</code> (the collection).</p>"
          },
          {
            "t": "c",
            "code": "class Entry\n  attr_reader :project, :from, :to, :note\n\n  def initialize(project:, from:, to:, note: nil)\n    @project = project\n    @from = from\n    @to = to\n    @note = note\n  end\n\n  def hours\n    as_hours(@to) - as_hours(@from)\n  end\n\n  def to_s\n    \"#{@project}: #{@from}-#{@to} (#{hours}h)\"\n  end\n\n  private\n\n  def as_hours(time)\n    h, m = time.split(\":\").map(&:to_i)\n    h + m / 60.0\n  end\nend\n\nEntry.new(project: \"ProjectX\", from: \"08:30\", to: \"12:00\").to_s"
          },
          {
            "t": "h",
            "html": "<p>Note: <code>as_hours</code> is <code>private</code> – an internal detail nobody outside needs. <code>to_s</code> decides how the object prints as text. Instance variables (<code>@project</code>) belong to the object; constants (<code>BIG</code>) to the class. Class variables (<code>@@…</code>) and globals (<code>$…</code>) are best avoided – shared state that's hard to trace.</p>"
          },
          {
            "t": "c",
            "code": "class Timesheet\n  def initialize\n    @entries = []\n  end\n\n  def add(entry)\n    @entries << entry\n    self\n  end\n\n  def count\n    @entries.length\n  end\nend\n\nsheet = Timesheet.new\nsheet.add(Entry.new(project: \"ProjectX\", from: \"08:30\", to: \"12:00\"))\nsheet.count"
          },
          {
            "t": "h",
            "html": "<p>The <code>self</code> at the end of <code>add</code> enables chaining: <code>sheet.add(a).add(b)</code>.</p><div class='task'><strong>Task:</strong> Extend <code>Timesheet</code> with <code>total_for(project)</code>: the total hours of all entries for that project. Use <code>select</code> and <code>sum</code> on <code>@entries</code>.</div>"
          },
          {
            "t": "x",
            "code": "# Entry from the demo cell above is reused here -\n# run it first!\n\nclass Timesheet\n  def initialize\n    @entries = []\n  end\n\n  def add(entry)\n    @entries << entry\n    self\n  end\n\n  # def total_for(project)\n  #   ...\n  # end\nend\n",
            "check": "ts = Timesheet.new.add(Entry.new(project: \"A\", from: \"08:00\", to: \"10:30\")).add(Entry.new(project: \"B\", from: \"10:30\", to: \"11:30\")).add(Entry.new(project: \"A\", from: \"13:00\", to: \"14:00\")); ts.total_for(\"A\") == 3.5 && ts.total_for(\"B\") == 1.0 && ts.total_for(\"C\") == 0",
            "hint": "<code>def total_for(project); @entries.select { |e| e.project == project }.sum(&:hours); end</code> – and run the Entry cell above first."
          }
        ]
      }
    },
    {
      "id": "tl-minitest",
      "de": {
        "title": "22. Testen mit Minitest",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Tests – dein Sicherheitsnetz</h2><p>Ruby prüft Typen erst zur Laufzeit – ein Tippfehler fällt sonst erst auf, wenn der Code läuft. Deshalb gehören <strong>Tests</strong> in Ruby-Projekten fest dazu. Das Werkzeug ist schon an Bord: <strong>Minitest</strong> kommt mit Ruby mit.</p><p>Ein Test ist eine Klasse, die von <code>Minitest::Test</code> erbt; jede Methode, die mit <code>test_</code> beginnt, ist ein Testfall. <code>assert_equal erwartet, tatsaechlich</code> prüft Gleichheit. Hier im Notizbuch startet <code>run_tests</code> den Testlauf:</p>"
          },
          {
            "t": "c",
            "code": "class Dauer\n  attr_reader :minuten\n\n  def initialize(minuten)\n    @minuten = minuten\n  end\n\n  def in_stunden\n    minuten / 60.0\n  end\nend\n\nclass TestDauer < Minitest::Test\n  def test_in_stunden\n    assert_equal 1.5, Dauer.new(90).in_stunden\n  end\n\n  def test_null_minuten\n    assert_equal 0.0, Dauer.new(0).in_stunden\n  end\nend\n\nrun_tests"
          },
          {
            "t": "h",
            "html": "<p>Der Bericht liest sich so: <code>2 runs</code> (zwei Testmethoden), <code>2 assertions</code> (zwei Prüfungen), <code>0 failures, 0 errors</code> – alles grün. Und wenn etwas schiefgeht? Minitest zeigt dir genau, <em>was</em> erwartet wurde und <em>was</em> kam:</p>"
          },
          {
            "t": "c",
            "code": "class TestKaputt < Minitest::Test\n  def test_absichtlich_falsch\n    assert_equal 100, Dauer.new(90).minuten\n  end\nend\n\nrun_tests"
          },
          {
            "t": "h",
            "html": "<div class='offweb' data-title='Auf deinem Computer'><p>Dort schreibst du Tests in eigene Dateien und startest sie direkt – <code>minitest/autorun</code> sorgt dafür, dass sie am Programmende automatisch laufen:</p><pre><code># test/test_dauer.rb\nrequire \"minitest/autorun\"\nrequire_relative \"../lib/dauer\"\n\nclass TestDauer < Minitest::Test\n  def test_in_stunden\n    assert_equal 1.5, Dauer.new(90).in_stunden\n  end\nend</code></pre><pre><code>$ ruby test/test_dauer.rb\n2 runs, 2 assertions, 0 failures, 0 errors, 0 skips</code></pre><p>Weitere Helfer: <code>assert</code>, <code>refute</code>, <code>assert_nil</code>, <code>assert_raises</code>, und <code>setup</code> für gemeinsame Vorbereitung. RSpec ist die bekannteste Alternative mit eigener Sprache (<code>expect(x).to eq(y)</code>).</p></div><div class='task'><strong>Aufgabe:</strong> Unten steht die Klasse <code>Eintrag</code>. Schreibe <code>TestEintrag</code> mit <strong>mindestens zwei</strong> Tests: einer für einen gültigen Eintrag, einer für ungültige Fälle (negative Stunden oder leeres Projekt). Starte mit <code>run_tests</code> – alles muss grün sein. Ab jetzt gilt: <em>Keine Aufgabe ohne Tests!</em></div>"
          },
          {
            "t": "x",
            "code": "class Eintrag\n  attr_reader :projekt, :stunden\n\n  def initialize(projekt, stunden)\n    @projekt = projekt\n    @stunden = stunden\n  end\n\n  def gueltig?\n    stunden > 0 && !projekt.to_s.empty?\n  end\nend\n\n# class TestEintrag < Minitest::Test\n#   def test_...\n#   end\n# end\n\n# run_tests\n",
            "check": "defined?(TestEintrag) && TestEintrag.instance_methods.grep(/\\Atest_/).length >= 2 && output.include?(\"0 failures\") && output.include?(\"0 errors\") && output.include?(\"runs,\")",
            "hint": "Zum Beispiel: <code>def test_gueltig; assert Eintrag.new(\"X\", 2.0).gueltig?; end</code> und <code>def test_negative_stunden; refute Eintrag.new(\"X\", -1).gueltig?; end</code> – dann <code>run_tests</code>."
          }
        ]
      },
      "en": {
        "title": "22. Testing with Minitest",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Tests – your safety net</h2><p>Ruby checks types only at runtime – a typo won't surface until the code actually runs. That's why <strong>tests</strong> are a fixture of Ruby projects. The tool is already on board: <strong>Minitest</strong> ships with Ruby.</p><p>A test is a class inheriting from <code>Minitest::Test</code>; every method starting with <code>test_</code> is a test case. <code>assert_equal expected, actual</code> checks equality. Here in the notebook, <code>run_tests</code> starts the test run:</p>"
          },
          {
            "t": "c",
            "code": "class Duration\n  attr_reader :minutes\n\n  def initialize(minutes)\n    @minutes = minutes\n  end\n\n  def in_hours\n    minutes / 60.0\n  end\nend\n\nclass TestDuration < Minitest::Test\n  def test_in_hours\n    assert_equal 1.5, Duration.new(90).in_hours\n  end\n\n  def test_zero_minutes\n    assert_equal 0.0, Duration.new(0).in_hours\n  end\nend\n\nrun_tests"
          },
          {
            "t": "h",
            "html": "<p>Reading the report: <code>2 runs</code> (two test methods), <code>2 assertions</code> (two checks), <code>0 failures, 0 errors</code> – all green. And when something breaks? Minitest shows you exactly <em>what</em> was expected and <em>what</em> arrived:</p>"
          },
          {
            "t": "c",
            "code": "class TestBroken < Minitest::Test\n  def test_deliberately_wrong\n    assert_equal 100, Duration.new(90).minutes\n  end\nend\n\nrun_tests"
          },
          {
            "t": "h",
            "html": "<div class='offweb' data-title='On your machine'><p>There you put tests into their own files and run them directly – <code>minitest/autorun</code> makes them run automatically when the program ends:</p><pre><code># test/test_duration.rb\nrequire \"minitest/autorun\"\nrequire_relative \"../lib/duration\"\n\nclass TestDuration < Minitest::Test\n  def test_in_hours\n    assert_equal 1.5, Duration.new(90).in_hours\n  end\nend</code></pre><pre><code>$ ruby test/test_duration.rb\n2 runs, 2 assertions, 0 failures, 0 errors, 0 skips</code></pre><p>More helpers: <code>assert</code>, <code>refute</code>, <code>assert_nil</code>, <code>assert_raises</code>, and <code>setup</code> for shared preparation. RSpec is the best-known alternative with its own language (<code>expect(x).to eq(y)</code>).</p></div><div class='task'><strong>Task:</strong> Below is the class <code>Entry</code>. Write <code>TestEntry</code> with <strong>at least two</strong> tests: one for a valid entry, one for invalid cases (negative hours or empty project). Finish with <code>run_tests</code> – everything must be green. From now on: <em>no exercise without tests!</em></div>"
          },
          {
            "t": "x",
            "code": "class Entry\n  attr_reader :project, :hours\n\n  def initialize(project, hours)\n    @project = project\n    @hours = hours\n  end\n\n  def valid?\n    hours > 0 && !project.to_s.empty?\n  end\nend\n\n# class TestEntry < Minitest::Test\n#   def test_...\n#   end\n# end\n\n# run_tests\n",
            "check": "defined?(TestEntry) && TestEntry.instance_methods.grep(/\\Atest_/).length >= 2 && output.include?(\"0 failures\") && output.include?(\"0 errors\") && output.include?(\"runs,\")",
            "hint": "For example: <code>def test_valid; assert Entry.new(\"X\", 2.0).valid?; end</code> and <code>def test_negative_hours; refute Entry.new(\"X\", -1).valid?; end</code> – then <code>run_tests</code>."
          }
        ]
      }
    },
    {
      "id": "tl-mixins",
      "de": {
        "title": "23. Enumerable & Data",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Zwei Superkräfte zum Einmischen</h2><p>In der Modul-Lektion hast du Mixins kennengelernt – jetzt kommen die zwei berühmtesten im Einsatz für timelog. <strong>Comparable</strong>: Sobald deine Klasse <code>&lt;=&gt;</code> kann (den „Raumschiff-Operator“: -1, 0 oder 1), schenkt dir das Mixin <code>&lt;</code>, <code>&gt;</code>, <code>==</code>, <code>between?</code> und mehr.</p><p>Gleichzeitig lernst du <code>Data</code> kennen – Rubys Klasse für unveränderliche Wertobjekte:</p>"
          },
          {
            "t": "c",
            "code": "Dauer = Data.define(:minuten) do\n  include Comparable\n\n  def <=>(andere)\n    minuten <=> andere.minuten\n  end\n\n  def to_s\n    \"#{minuten / 60}h #{minuten % 60}min\"\n  end\nend\n\npausen = [Dauer.new(minuten: 90), Dauer.new(minuten: 45), Dauer.new(minuten: 120)]\npausen.max.to_s"
          },
          {
            "t": "h",
            "html": "<p><code>Data.define</code> erzeugt eine Klasse mit fixen Feldern, Gleichheit und <code>inspect</code> geschenkt – und die Objekte sind eingefroren (kein versehentliches Ändern). Für veränderliche Fälle gibt es das ältere <code>Struct</code>.</p><p>Die zweite Superkraft: <strong>Enumerable</strong>. Deine Klasse liefert nur <code>each</code> – und bekommt dafür die GESAMTE Collection-Werkzeugkiste: <code>map</code>, <code>select</code>, <code>sum</code>, <code>sort_by</code>, <code>group_by</code> … genau die Methoden aus Lektion 18, jetzt auf deiner eigenen Klasse.</p><div class='task'><strong>Aufgabe:</strong> Mach <code>Timesheet</code> enumerable: <code>include Enumerable</code> plus eine Methode <code>each</code>, die den Block an <code>@eintraege.each</code> weiterreicht. Danach funktioniert die letzte Zeile.</div>"
          },
          {
            "t": "x",
            "code": "class Timesheet\n  # include ...\n\n  def initialize(eintraege)\n    @eintraege = eintraege\n  end\n\n  # def each(&block)\n  #   ...\n  # end\nend\n\nts = Timesheet.new([\n  { projekt: \"A\", stunden: 2.0 },\n  { projekt: \"B\", stunden: 1.0 }\n])\n\n# ts.sum { |e| e[:stunden] }\n",
            "check": "Timesheet.include?(Enumerable) && ts.map { |e| e[:projekt] } == [\"A\", \"B\"] && ts.sum { |e| e[:stunden] } == 3.0 && code.include?(\"include Enumerable\") && code.include?(\"def each\")",
            "hint": "<code>include Enumerable</code> in die Klasse, dazu <code>def each(&block); @eintraege.each(&block); end</code>."
          }
        ]
      },
      "en": {
        "title": "23. Enumerable & Data",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Two superpowers to mix in</h2><p>You met mixins in the modules lesson – now come the two most famous ones, deployed for timelog. <strong>Comparable</strong>: as soon as your class can <code>&lt;=&gt;</code> (the “spaceship operator”: -1, 0 or 1), the mixin gives you <code>&lt;</code>, <code>&gt;</code>, <code>==</code>, <code>between?</code> and more.</p><p>At the same time, meet <code>Data</code> – Ruby's class for immutable value objects:</p>"
          },
          {
            "t": "c",
            "code": "Duration = Data.define(:minutes) do\n  include Comparable\n\n  def <=>(other)\n    minutes <=> other.minutes\n  end\n\n  def to_s\n    \"#{minutes / 60}h #{minutes % 60}min\"\n  end\nend\n\nbreaks = [Duration.new(minutes: 90), Duration.new(minutes: 45), Duration.new(minutes: 120)]\nbreaks.max.to_s"
          },
          {
            "t": "h",
            "html": "<p><code>Data.define</code> creates a class with fixed fields, equality and <code>inspect</code> for free – and the objects are frozen (no accidental mutation). For mutable cases there's the older <code>Struct</code>.</p><p>The second superpower: <strong>Enumerable</strong>. Your class provides just <code>each</code> – and receives the ENTIRE collection toolbox in return: <code>map</code>, <code>select</code>, <code>sum</code>, <code>sort_by</code>, <code>group_by</code> … exactly the methods from lesson 18, now on your own class.</p><div class='task'><strong>Task:</strong> Make <code>Timesheet</code> enumerable: <code>include Enumerable</code> plus an <code>each</code> method that forwards the block to <code>@entries.each</code>. Then the last line works.</div>"
          },
          {
            "t": "x",
            "code": "class Timesheet\n  # include ...\n\n  def initialize(entries)\n    @entries = entries\n  end\n\n  # def each(&block)\n  #   ...\n  # end\nend\n\nts = Timesheet.new([\n  { project: \"A\", hours: 2.0 },\n  { project: \"B\", hours: 1.0 }\n])\n\n# ts.sum { |e| e[:hours] }\n",
            "check": "Timesheet.include?(Enumerable) && ts.map { |e| e[:project] } == [\"A\", \"B\"] && ts.sum { |e| e[:hours] } == 3.0 && code.include?(\"include Enumerable\") && code.include?(\"def each\")",
            "hint": "<code>include Enumerable</code> into the class, plus <code>def each(&block); @entries.each(&block); end</code>."
          }
        ]
      }
    },
    {
      "id": "tl-blocks",
      "de": {
        "title": "24. Blocks, Procs & Lambdas",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Blocks – Code als Geschenk</h2><p>Du benutzt Blocks seit Lektion 6 – jetzt schauen wir hinter den Vorhang. Eine Methode nimmt einen Block entgegen und führt ihn mit <code>yield</code> aus; <code>block_given?</code> verrät, ob einer da ist. Damit baust du „Rahmen“-Methoden wie diese Stoppuhr:</p>"
          },
          {
            "t": "c",
            "code": "def mit_zeitmessung(name)\n  start = Process.clock_gettime(Process::CLOCK_MONOTONIC)\n  ergebnis = yield\n  ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000\n  puts \"#{name}: #{ms.round(1)} ms\"\n  ergebnis\nend\n\nmit_zeitmessung(\"Summe\") { (1..100_000).sum }"
          },
          {
            "t": "h",
            "html": "<p>Ein Block ist kein Objekt – aber du kannst ihn zu einem machen. <code>proc</code> und <code>lambda</code> verpacken Code in Variablen. Die Unterschiede: Ein Lambda prüft die Argumentzahl streng und <code>return</code> verlässt nur das Lambda; ein Proc ist bei beidem locker. Und <code>&amp;:to_s</code> ist die Kurzform „mach aus dem Symbol einen Block“:</p>"
          },
          {
            "t": "c",
            "code": "verdopple = ->(x) { x * 2 }\n\n[verdopple.call(21), verdopple.(5), [1, 2, 3].map(&:to_s)]"
          },
          {
            "t": "h",
            "html": "<p>Lambdas sind <strong>Closures</strong>: Sie nehmen ihre Umgebung mit. Perfekt für timelog-Berichtsformate – jedes Format ist ein kleines verpacktes Programm:</p>"
          },
          {
            "t": "c",
            "code": "formate = {\n  text: ->(e) { \"#{e[:projekt].ljust(10)} #{e[:stunden]}h\" },\n  csv:  ->(e) { \"#{e[:projekt]};#{e[:stunden]}\" }\n}\n\neintrag = { projekt: \"ProjectX\", stunden: 3.5 }\nformate[:csv].call(eintrag)"
          },
          {
            "t": "h",
            "html": "<div class='task'><strong>Aufgabe:</strong> Schreibe <code>each_projekt(eintraege)</code>: Die Methode gruppiert die Einträge nach Projekt und übergibt <strong>per <code>yield</code></strong> jedes Paar <code>(projekt, liste)</code> an den Block – wie <code>each</code>, nur eine Etage höher.</div>"
          },
          {
            "t": "x",
            "code": "# def each_projekt(eintraege)\n#   ... group_by ... yield ...\n# end\n\n# Test:\n# each_projekt([{ projekt: \"A\", stunden: 1.0 }]) do |projekt, liste|\n#   puts \"#{projekt}: #{liste.length} Eintraege\"\n# end\n",
            "check": "gesammelt = []; each_projekt([{ projekt: \"A\", stunden: 1.0 }, { projekt: \"B\", stunden: 2.0 }, { projekt: \"A\", stunden: 0.5 }]) { |p, liste| gesammelt << [p, liste.length] }; gesammelt == [[\"A\", 2], [\"B\", 1]] && code.include?(\"yield\")",
            "hint": "<code>def each_projekt(eintraege); eintraege.group_by { |e| e[:projekt] }.each { |projekt, liste| yield(projekt, liste) }; end</code>"
          }
        ]
      },
      "en": {
        "title": "24. Blocks, procs & lambdas",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Blocks – code as a gift</h2><p>You've been using blocks since lesson 6 – now let's look behind the curtain. A method receives a block and runs it with <code>yield</code>; <code>block_given?</code> tells you whether one arrived. That's how you build “wrapper” methods like this stopwatch:</p>"
          },
          {
            "t": "c",
            "code": "def with_timing(name)\n  start = Process.clock_gettime(Process::CLOCK_MONOTONIC)\n  result = yield\n  ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000\n  puts \"#{name}: #{ms.round(1)} ms\"\n  result\nend\n\nwith_timing(\"sum\") { (1..100_000).sum }"
          },
          {
            "t": "h",
            "html": "<p>A block is not an object – but you can make it one. <code>proc</code> and <code>lambda</code> wrap code into variables. The differences: a lambda checks its argument count strictly and <code>return</code> leaves only the lambda; a proc is relaxed about both. And <code>&amp;:to_s</code> is the shorthand for “turn this symbol into a block”:</p>"
          },
          {
            "t": "c",
            "code": "double = ->(x) { x * 2 }\n\n[double.call(21), double.(5), [1, 2, 3].map(&:to_s)]"
          },
          {
            "t": "h",
            "html": "<p>Lambdas are <strong>closures</strong>: they carry their environment with them. Perfect for timelog report formats – each format is a small packaged program:</p>"
          },
          {
            "t": "c",
            "code": "formats = {\n  text: ->(e) { \"#{e[:project].ljust(10)} #{e[:hours]}h\" },\n  csv:  ->(e) { \"#{e[:project]};#{e[:hours]}\" }\n}\n\nentry = { project: \"ProjectX\", hours: 3.5 }\nformats[:csv].call(entry)"
          },
          {
            "t": "h",
            "html": "<div class='task'><strong>Task:</strong> Write <code>each_project(entries)</code>: the method groups the entries by project and hands <strong>via <code>yield</code></strong> each pair <code>(project, list)</code> to the block – like <code>each</code>, one floor up.</div>"
          },
          {
            "t": "x",
            "code": "# def each_project(entries)\n#   ... group_by ... yield ...\n# end\n\n# Test:\n# each_project([{ project: \"A\", hours: 1.0 }]) do |project, list|\n#   puts \"#{project}: #{list.length} entries\"\n# end\n",
            "check": "collected = []; each_project([{ project: \"A\", hours: 1.0 }, { project: \"B\", hours: 2.0 }, { project: \"A\", hours: 0.5 }]) { |p, list| collected << [p, list.length] }; collected == [[\"A\", 2], [\"B\", 1]] && code.include?(\"yield\")",
            "hint": "<code>def each_project(entries); entries.group_by { |e| e[:project] }.each { |project, list| yield(project, list) }; end</code>"
          }
        ]
      }
    },
    {
      "id": "tl-errors",
      "de": {
        "title": "25. Fehler behandeln",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Wenn etwas schiefgeht</h2><p>Mit <code>raise</code> wirft Ruby eine Exception, mit <code>rescue</code> fängst du sie, <code>ensure</code> läuft <em>immer</em> (aufräumen!). Gute Programme definieren eine eigene <strong>Fehler-Familie</strong> – dann können Aufrufer gezielt „alle timelog-Fehler“ fangen, ohne fremde Fehler zu verschlucken:</p>"
          },
          {
            "t": "c",
            "code": "module Timelog\n  class Error        < StandardError; end\n  class ParseError   < Error; end\n  class OverlapError < Error; end\nend\n\nbegin\n  raise Timelog::ParseError, \"Zeile 7 ist kein Zeiteintrag\"\nrescue Timelog::Error => e\n  \"gefangen: #{e.class}: #{e.message}\"\nend"
          },
          {
            "t": "h",
            "html": "<p>Wann Exception, wann Rückgabewert? Faustregel: <code>nil</code> für „kann normal vorkommen“ (Zeile passt nicht ins Muster), Exception für „hier stimmt etwas grundsätzlich nicht“ (Eintrag endet vor seinem Beginn). Erbe immer von <code>StandardError</code>, nie von <code>Exception</code> direkt – sonst fängst du auch Strg-C. Und pack die Familie in dein Modul (<code>Timelog::ParseError</code>), damit sie niemandem in die Quere kommt.</p><p>Bei <em>vorübergehenden</em> Fehlern (Netzwerk!) hilft <code>retry</code>: Es springt zurück an den Anfang des <code>begin</code>-Blocks:</p>"
          },
          {
            "t": "c",
            "code": "class TimelogError < StandardError; end\n\nversuche = 0\nwackliger_dienst = lambda do\n  versuche += 1\n  raise TimelogError, \"Netzwerkfehler\" if versuche < 3\n  \"Daten empfangen (Versuch #{versuche})\"\nend\n\nbegin\n  wackliger_dienst.call\nrescue TimelogError\n  retry if versuche < 5\nend"
          },
          {
            "t": "h",
            "html": "<div class='offweb' data-title='Auf deinem Computer'><p>Echter Retry-Code wartet zwischen den Versuchen immer länger (<em>Backoff</em>) – <code>sleep</code> gibt es im Browser nicht:</p><pre><code>rescue TimelogError\n  wartezeit = 2 ** versuch   # 1s, 2s, 4s, 8s ...\n  sleep(wartezeit)\n  retry if versuch < 5</code></pre></div><div class='task'><strong>Aufgabe:</strong> Schreibe <code>sync_mit_retry(dienst, max:)</code>: Sie ruft <code>dienst.call</code> auf. Wirft der Dienst einen <code>TimelogError</code>, wird bis zu <code>max</code>-mal insgesamt versucht – danach fliegt der Fehler weiter (einfach nicht mehr <code>retry</code> aufrufen). Bei Erfolg gibt sie das Ergebnis zurück.</div>"
          },
          {
            "t": "x",
            "code": "class TimelogError < StandardError; end\n\n# def sync_mit_retry(dienst, max:)\n#   versuche = 0\n#   begin\n#     ...\n#   rescue TimelogError\n#     ...\n#   end\n# end\n",
            "check": "z1 = 0; ok_dienst = lambda { z1 += 1; raise TimelogError, \"kaputt\" if z1 < 3; \"ok\" }; erg = sync_mit_retry(ok_dienst, max: 5); kaputt = begin; z2 = 0; immer_kaputt = lambda { z2 += 1; raise TimelogError, \"kaputt\" }; sync_mit_retry(immer_kaputt, max: 2); false; rescue TimelogError; z2 == 2; end; erg == \"ok\" && z1 == 3 && kaputt && code.include?(\"retry\")",
            "hint": "<code>versuche += 1</code> im begin-Block vor <code>dienst.call</code>; im rescue: <code>retry if versuche < max</code>, sonst <code>raise</code>."
          }
        ]
      },
      "en": {
        "title": "25. Handling errors",
        "cells": [
          {
            "t": "h",
            "html": "<h2>When things go wrong</h2><p><code>raise</code> throws an exception, <code>rescue</code> catches it, <code>ensure</code> runs <em>always</em> (cleanup!). Good programs define their own <strong>error family</strong> – then callers can catch “all timelog errors” without swallowing unrelated ones:</p>"
          },
          {
            "t": "c",
            "code": "module Timelog\n  class Error        < StandardError; end\n  class ParseError   < Error; end\n  class OverlapError < Error; end\nend\n\nbegin\n  raise Timelog::ParseError, \"line 7 is not a time entry\"\nrescue Timelog::Error => e\n  \"caught: #{e.class}: #{e.message}\"\nend"
          },
          {
            "t": "h",
            "html": "<p>Exception or return value? Rule of thumb: <code>nil</code> for “can happen normally” (a line doesn't match the pattern), exception for “something is fundamentally wrong here” (an entry ends before it starts). Always inherit from <code>StandardError</code>, never from <code>Exception</code> directly – or you'll catch Ctrl-C too. And put the family into your module (<code>Timelog::ParseError</code>) so it never clashes with anyone else's.</p><p>For <em>transient</em> errors (networks!) there's <code>retry</code>: it jumps back to the start of the <code>begin</code> block:</p>"
          },
          {
            "t": "c",
            "code": "class TimelogError < StandardError; end\n\nattempts = 0\nflaky_service = lambda do\n  attempts += 1\n  raise TimelogError, \"network error\" if attempts < 3\n  \"data received (attempt #{attempts})\"\nend\n\nbegin\n  flaky_service.call\nrescue TimelogError\n  retry if attempts < 5\nend"
          },
          {
            "t": "h",
            "html": "<div class='offweb' data-title='On your machine'><p>Real retry code waits longer between attempts (<em>backoff</em>) – there is no <code>sleep</code> in the browser:</p><pre><code>rescue TimelogError\n  wait = 2 ** attempt   # 1s, 2s, 4s, 8s ...\n  sleep(wait)\n  retry if attempt < 5</code></pre></div><div class='task'><strong>Task:</strong> Write <code>sync_with_retry(service, max:)</code>: it calls <code>service.call</code>. If the service raises a <code>TimelogError</code>, it tries up to <code>max</code> times in total – after that the error propagates (simply don't <code>retry</code> anymore). On success it returns the result.</div>"
          },
          {
            "t": "x",
            "code": "class TimelogError < StandardError; end\n\n# def sync_with_retry(service, max:)\n#   attempts = 0\n#   begin\n#     ...\n#   rescue TimelogError\n#     ...\n#   end\n# end\n",
            "check": "c1 = 0; ok_service = lambda { c1 += 1; raise TimelogError, \"broken\" if c1 < 3; \"ok\" }; res = sync_with_retry(ok_service, max: 5); broke = begin; c2 = 0; always_broken = lambda { c2 += 1; raise TimelogError, \"broken\" }; sync_with_retry(always_broken, max: 2); false; rescue TimelogError; c2 == 2; end; res == \"ok\" && c1 == 3 && broke && code.include?(\"retry\")",
            "hint": "<code>attempts += 1</code> in the begin block before <code>service.call</code>; in the rescue: <code>retry if attempts < max</code>, otherwise <code>raise</code>."
          }
        ]
      }
    },
    {
      "id": "tl-formats",
      "de": {
        "title": "26. Daten speichern: Formate",
        "cells": [
          {
            "t": "h",
            "html": "<h2>timelog wird dauerhaft</h2><p>Bisher leben unsere Einträge nur im Speicher. Zeit für <strong>Serialisierung</strong>: Daten in Text verwandeln und zurück. Ruby bringt die drei wichtigsten Formate mit. <strong>JSON</strong> ist die Sprache der Web-APIs:</p>"
          },
          {
            "t": "c",
            "code": "require \"json\"\n\neintraege = [\n  { projekt: \"ProjectX\", stunden: 3.5 },\n  { projekt: \"Intern\",   stunden: 2.0 }\n]\n\ntext = JSON.pretty_generate(eintraege)\nputs text\nJSON.parse(text, symbolize_names: true) == eintraege"
          },
          {
            "t": "h",
            "html": "<p>Beachte <code>symbolize_names: true</code> – JSON kennt keine Symbole, beim Einlesen wären die Schlüssel sonst Strings. <strong>CSV</strong> ist das Format für Tabellen (Excel!):</p>"
          },
          {
            "t": "c",
            "code": "require \"csv\"\n\ncsv_text = CSV.generate do |csv|\n  csv << [\"projekt\", \"stunden\"]\n  eintraege.each { |e| csv << [e[:projekt], e[:stunden]] }\nend\nputs csv_text\n\nCSV.parse(csv_text, headers: true).map { |zeile| zeile[\"projekt\"] }"
          },
          {
            "t": "h",
            "html": "<p>Und <strong>YAML</strong> ist das Lieblingsformat für Konfigurationsdateien – Menschen können es gut lesen und schreiben:</p>"
          },
          {
            "t": "c",
            "code": "require \"yaml\"\n\nkonfig = YAML.safe_load(\"stundensatz: 120\\nrunden_auf: 15\\n\")\nkonfig[\"stundensatz\"]"
          },
          {
            "t": "h",
            "html": "<p>Und jetzt: <strong>Dateien</strong>! Auf deinem Rechner speichert Ruby mit <code>File.write</code> und liest mit <code>File.read</code>. Hier im Browser simulieren wir dafür ein kleines Dateisystem – mit eigenem Datei-Fenster (<code>show_files</code>):</p>"
          },
          {
            "t": "c",
            "code": "File.write(\"notizen.txt\", \"Speck kaufen!\\nTimelog testen.\")\nFile.write(\"projekte/plan.txt\", \"Q4: timelog fertigstellen\")\n\nshow_files"
          },
          {
            "t": "h",
            "html": "<p>Klick eine Datei an, um hineinzuschauen – wie im Explorer oder Finder. Und alles Übrige geht wie gewohnt: lesen, suchen, prüfen:</p>"
          },
          {
            "t": "c",
            "code": "[File.read(\"notizen.txt\"),\n Dir.glob(\"**/*.txt\"),\n File.exist?(\"beispiel.csv\")]"
          },
          {
            "t": "h",
            "html": "<div class='offweb' data-title='Auf deinem Computer'><p>Unser Dateifenster ist eine Simulation – bei dir sind es echte Dateien auf der Platte, mit denselben Befehlen. Dort gibt es noch mehr Komfort:</p><pre><code># Block-Form schliesst die Datei automatisch:\nFile.open(\"log.txt\", \"a\") { |f| f.puts \"neuer Eintrag\" }\n\nPathname.new(\"a/b.json\")    # Pfade als Objekte\nTempfile.create(\"test\")     # Wegwerf-Dateien fuer Tests\nStringIO.new(\"...\")         # \"Datei\" im Speicher</code></pre></div><div class='task'><strong>Aufgabe:</strong> Schreibe <code>nach_csv(eintraege)</code> (CSV-Text mit Kopfzeile <code>projekt,stunden</code>) und <code>aus_csv(text)</code> (zurück zu Hashes mit Symbol-Schlüsseln und <code>Float</code>-Stunden). Speichere dann <code>daten</code> mit <code>File.write</code> in <code>eintraege.csv</code> und lies sie mit <code>aus_csv(File.read(…))</code> zurück – verlustfrei. Wirf danach einen Blick ins Datei-Fenster oben (⟳)!</div>"
          },
          {
            "t": "x",
            "code": "require \"csv\"\n\ndaten = [\n  { projekt: \"A\", stunden: 1.5 },\n  { projekt: \"B\", stunden: 2.0 }\n]\n\n# def nach_csv(eintraege)\n#   ...\n# end\n\n# def aus_csv(text)\n#   ...  # Tipp: zeile[\"stunden\"].to_f\n# end\n\n# File.write(\"eintraege.csv\", nach_csv(daten))\n# aus_csv(File.read(\"eintraege.csv\"))\n",
            "check": "File.exist?(\"eintraege.csv\") && aus_csv(File.read(\"eintraege.csv\")) == daten && nach_csv(daten).lines.first.strip == \"projekt,stunden\"",
            "hint": "<code>nach_csv</code>/<code>aus_csv</code> wie in den Demos, dann <code>File.write(\"eintraege.csv\", nach_csv(daten))</code> und als letzte Zeile <code>aus_csv(File.read(\"eintraege.csv\"))</code>."
          }
        ]
      },
      "en": {
        "title": "26. Saving data: formats",
        "cells": [
          {
            "t": "h",
            "html": "<h2>timelog becomes persistent</h2><p>So far our entries live only in memory. Time for <strong>serialization</strong>: turning data into text and back. Ruby ships the three most important formats. <strong>JSON</strong> is the language of web APIs:</p>"
          },
          {
            "t": "c",
            "code": "require \"json\"\n\nentries = [\n  { project: \"ProjectX\", hours: 3.5 },\n  { project: \"Intern\",   hours: 2.0 }\n]\n\ntext = JSON.pretty_generate(entries)\nputs text\nJSON.parse(text, symbolize_names: true) == entries"
          },
          {
            "t": "h",
            "html": "<p>Note <code>symbolize_names: true</code> – JSON has no symbols, so keys would come back as strings otherwise. <strong>CSV</strong> is the format for tables (Excel!):</p>"
          },
          {
            "t": "c",
            "code": "require \"csv\"\n\ncsv_text = CSV.generate do |csv|\n  csv << [\"project\", \"hours\"]\n  entries.each { |e| csv << [e[:project], e[:hours]] }\nend\nputs csv_text\n\nCSV.parse(csv_text, headers: true).map { |row| row[\"project\"] }"
          },
          {
            "t": "h",
            "html": "<p>And <strong>YAML</strong> is the favorite for configuration files – pleasant for humans to read and write:</p>"
          },
          {
            "t": "c",
            "code": "require \"yaml\"\n\nconfig = YAML.safe_load(\"rate: 120\\nround_to: 15\\n\")\nconfig[\"rate\"]"
          },
          {
            "t": "h",
            "html": "<p>And now: <strong>files</strong>! On your machine Ruby saves with <code>File.write</code> and reads with <code>File.read</code>. Here in the browser we simulate a little filesystem for that – with its own file window (<code>show_files</code>):</p>"
          },
          {
            "t": "c",
            "code": "File.write(\"notizen.txt\", \"buy bacon!\\ntest timelog.\")\nFile.write(\"projekte/plan.txt\", \"Q4: finish timelog\")\n\nshow_files"
          },
          {
            "t": "h",
            "html": "<p>Click a file to peek inside – just like Explorer or Finder. And everything else works as usual: reading, searching, checking:</p>"
          },
          {
            "t": "c",
            "code": "[File.read(\"notizen.txt\"),\n Dir.glob(\"**/*.txt\"),\n File.exist?(\"beispiel.csv\")]"
          },
          {
            "t": "h",
            "html": "<div class='offweb' data-title='On your machine'><p>Our file window is a simulation – on your machine these are real files on disk, with the same commands. There you also get extra comfort:</p><pre><code># Block form closes the file automatically:\nFile.open(\"log.txt\", \"a\") { |f| f.puts \"new entry\" }\n\nPathname.new(\"a/b.json\")    # paths as objects\nTempfile.create(\"test\")     # throwaway files for tests\nStringIO.new(\"...\")         # in-memory \"file\"</code></pre></div><div class='task'><strong>Task:</strong> Write <code>to_csv(entries)</code> (CSV text with header <code>project,hours</code>) and <code>from_csv(text)</code> (back to hashes with symbol keys and <code>Float</code> hours). Then save <code>data</code> with <code>File.write</code> into <code>entries.csv</code> and read it back with <code>from_csv(File.read(…))</code> – losslessly. Afterwards take a look at the file window above (⟳)!</div>"
          },
          {
            "t": "x",
            "code": "require \"csv\"\n\ndata = [\n  { project: \"A\", hours: 1.5 },\n  { project: \"B\", hours: 2.0 }\n]\n\n# def to_csv(entries)\n#   ...\n# end\n\n# def from_csv(text)\n#   ...  # hint: row[\"hours\"].to_f\n# end\n\n# File.write(\"entries.csv\", to_csv(data))\n# from_csv(File.read(\"entries.csv\"))\n",
            "check": "File.exist?(\"entries.csv\") && from_csv(File.read(\"entries.csv\")) == data && to_csv(data).lines.first.strip == \"project,hours\"",
            "hint": "<code>to_csv</code>/<code>from_csv</code> like the demos, then <code>File.write(\"entries.csv\", to_csv(data))</code> and as the last line <code>from_csv(File.read(\"entries.csv\"))</code>."
          }
        ]
      }
    },
    {
      "id": "tl-cli",
      "de": {
        "title": "27. Kommandozeile & Gems",
        "cells": [
          {
            "t": "h",
            "html": "<h2>timelog als richtiges Werkzeug</h2><p>Auf deinem Rechner startet man Programme im Terminal: <code>timelog add \"ProjectX\" --from 08:30</code>. Alles hinter dem Programmnamen landet als String-Array in <code>ARGV</code>. Für das saubere Zerlegen gibt es <strong>OptionParser</strong> aus der Standardbibliothek – hier üben wir mit selbstgebauten Arrays:</p>"
          },
          {
            "t": "c",
            "code": "require \"optparse\"\n\nargv = [\"report\", \"--week\", \"--format\", \"csv\"]\n\noptionen = { format: \"text\", woche: false }\nparser = OptionParser.new do |p|\n  p.on(\"--week\", \"nur diese Woche\")        { optionen[:woche] = true }\n  p.on(\"--format FORMAT\", \"text oder csv\") { |f| optionen[:format] = f }\nend\n\nrest = parser.parse(argv)\n[optionen, rest]"
          },
          {
            "t": "h",
            "html": "<p><code>parse</code> pflückt die Optionen heraus und gibt zurück, was übrig bleibt – hier das Kommando <code>\"report\"</code>. Gratis dazu: <code>--help</code> mit den Beschreibungstexten.</p></div>"
          },
          {
            "t": "h",
            "html": "<div class='offweb' data-title='Auf deinem Computer: vom Skript zur Gem'><p>Ein installierbares Werkzeug hat eine feste Struktur und eine <code>.gemspec</code>-Datei:</p><pre><code>timelog/\n├── lib/timelog.rb        # der Code\n├── bin/timelog           # das Kommando (#!/usr/bin/env ruby)\n├── test/test_timelog.rb\n├── timelog.gemspec       # Name, Version, Autor, Dateien\n├── Gemfile               # Abhaengigkeiten (Bundler)\n└── Rakefile              # Aufgaben: rake test</code></pre><pre><code>$ bundle install          # holt Abhaengigkeiten, schreibt Gemfile.lock\n$ rake test               # laesst die Tests laufen\n$ gem build timelog.gemspec\n$ gem install timelog-0.1.0.gem\n$ timelog report --week   # dein Werkzeug, ueberall!</code></pre><p>Exit-Codes nicht vergessen: <code>exit 1</code> bei Fehlern, damit Skripte deine Fehlschläge bemerken.</p></div><div class='task'><strong>Aufgabe:</strong> Schreibe <code>parse_argv(argv)</code> mit OptionParser: Unterstützt werden <code>--week</code> und <code>--format FORMAT</code> (Default <code>\"text\"</code>). Zurück kommt ein Hash <code>{ befehl:, woche:, format: }</code>, wobei <code>befehl</code> das erste übrige Argument ist.</div>"
          },
          {
            "t": "x",
            "code": "require \"optparse\"\n\n# def parse_argv(argv)\n#   optionen = { woche: false, format: \"text\" }\n#   ...\n# end\n",
            "check": "a = parse_argv([\"report\", \"--week\"]); b = parse_argv([\"export\", \"--format\", \"csv\"]); c2 = parse_argv([\"add\"]); a == { befehl: \"report\", woche: true, format: \"text\" } && b == { befehl: \"export\", woche: false, format: \"csv\" } && c2 == { befehl: \"add\", woche: false, format: \"text\" }",
            "hint": "Wie in der Demo – am Ende: <code>rest = parser.parse(argv); { befehl: rest.first, woche: optionen[:woche], format: optionen[:format] }</code>"
          }
        ]
      },
      "en": {
        "title": "27. Command line & gems",
        "cells": [
          {
            "t": "h",
            "html": "<h2>timelog as a real tool</h2><p>On your machine, programs start in the terminal: <code>timelog add \"ProjectX\" --from 08:30</code>. Everything after the program name arrives as a string array in <code>ARGV</code>. For clean parsing there's <strong>OptionParser</strong> from the standard library – here we practice with hand-built arrays:</p>"
          },
          {
            "t": "c",
            "code": "require \"optparse\"\n\nargv = [\"report\", \"--week\", \"--format\", \"csv\"]\n\noptions = { format: \"text\", week: false }\nparser = OptionParser.new do |p|\n  p.on(\"--week\", \"this week only\")        { options[:week] = true }\n  p.on(\"--format FORMAT\", \"text or csv\")  { |f| options[:format] = f }\nend\n\nrest = parser.parse(argv)\n[options, rest]"
          },
          {
            "t": "h",
            "html": "<p><code>parse</code> plucks out the options and returns what remains – here the command <code>\"report\"</code>. For free on top: <code>--help</code> with the description texts.</p>"
          },
          {
            "t": "h",
            "html": "<div class='offweb' data-title='On your machine: from script to gem'><p>An installable tool has a fixed structure and a <code>.gemspec</code> file:</p><pre><code>timelog/\n├── lib/timelog.rb        # the code\n├── bin/timelog           # the command (#!/usr/bin/env ruby)\n├── test/test_timelog.rb\n├── timelog.gemspec       # name, version, author, files\n├── Gemfile               # dependencies (Bundler)\n└── Rakefile              # tasks: rake test</code></pre><pre><code>$ bundle install          # fetches deps, writes Gemfile.lock\n$ rake test               # runs the tests\n$ gem build timelog.gemspec\n$ gem install timelog-0.1.0.gem\n$ timelog report --week   # your tool, everywhere!</code></pre><p>Don't forget exit codes: <code>exit 1</code> on failure, so scripts notice your errors.</p></div><div class='task'><strong>Task:</strong> Write <code>parse_argv(argv)</code> with OptionParser: it supports <code>--week</code> and <code>--format FORMAT</code> (default <code>\"text\"</code>). It returns a hash <code>{ command:, week:, format: }</code>, where <code>command</code> is the first remaining argument.</div>"
          },
          {
            "t": "x",
            "code": "require \"optparse\"\n\n# def parse_argv(argv)\n#   options = { week: false, format: \"text\" }\n#   ...\n# end\n",
            "check": "a = parse_argv([\"report\", \"--week\"]); b = parse_argv([\"export\", \"--format\", \"csv\"]); c2 = parse_argv([\"add\"]); a == { command: \"report\", week: true, format: \"text\" } && b == { command: \"export\", week: false, format: \"csv\" } && c2 == { command: \"add\", week: false, format: \"text\" }",
            "hint": "Like the demo – at the end: <code>rest = parser.parse(argv); { command: rest.first, week: options[:week], format: options[:format] }</code>"
          }
        ]
      }
    },
    {
      "id": "tl-pattern",
      "de": {
        "title": "28. Pattern Matching",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Modernes Ruby: case/in</h2><p>Seit Ruby 3 gibt es neben <code>case/when</code> das mächtigere <strong>Pattern Matching</strong> mit <code>case/in</code>: Es prüft die <em>Form</em> von Daten und zerlegt sie im selben Schritt. Perfekt für unser Kommando-Array aus der CLI-Lektion:</p>"
          },
          {
            "t": "c",
            "code": "befehl = [\"add\", \"ProjectX\", 3.5]\n\ncase befehl\nin [\"add\", projekt, stunden]\n  \"Neuer Eintrag: #{projekt} (#{stunden}h)\"\nin [\"report\"]\n  \"Bericht wird erstellt\"\nend"
          },
          {
            "t": "h",
            "html": "<p>Das Muster <code>[\"add\", projekt, stunden]</code> passt nur auf dreielementige Arrays mit <code>\"add\"</code> vorn – und bindet die restlichen Werte gleich an Variablen. Auch Hashes lassen sich zerlegen, mit Typ-Prüfung und Wächter-Bedingung (<code>if</code>) obendrauf:</p>"
          },
          {
            "t": "c",
            "code": "eintrag = { projekt: \"ProjectX\", stunden: 3.5 }\n\ncase eintrag\nin { projekt: String => p, stunden: Float => s } if s > 0\n  \"#{p}: #{s}h - sieht gut aus\"\nin { stunden: }\n  \"Ungueltige Stunden: #{stunden.inspect}\"\nend"
          },
          {
            "t": "h",
            "html": "<p>Dazu passt der Rest des modernen Rubys: <em>endless methods</em> für Einzeiler (<code>def quadrat(x) = x * x</code>), die Hash-Kurzform <code>{ projekt:, stunden: }</code> wenn Variable und Schlüssel gleich heissen, und <code>daten => { projekt: }</code> als Zerlege-Zuweisung ausserhalb von <code>case</code>.</p><div class='task'><strong>Aufgabe:</strong> Schreibe <code>dispatch(befehl)</code> mit <code>case/in</code>: <code>[\"add\", projekt, stunden]</code> → <code>\"Eintrag: &lt;projekt&gt; (&lt;stunden&gt;h)\"</code>, <code>[\"report\"]</code> → <code>\"Bericht\"</code>, <code>[\"export\", format]</code> → <code>\"Export als &lt;format&gt;\"</code>, alles andere (<code>else</code>) → <code>\"Unbekanntes Kommando\"</code>.</div>"
          },
          {
            "t": "x",
            "code": "# def dispatch(befehl)\n#   case befehl\n#   in ...\n#   end\n# end\n",
            "check": "dispatch([\"add\", \"X\", 2.5]) == \"Eintrag: X (2.5h)\" && dispatch([\"report\"]) == \"Bericht\" && dispatch([\"export\", \"csv\"]) == \"Export als csv\" && dispatch([\"tanzen\"]) == \"Unbekanntes Kommando\" && code.include?(\"in [\")",
            "hint": "Vier Zweige: <code>in [\"add\", projekt, stunden]</code>, <code>in [\"report\"]</code>, <code>in [\"export\", format]</code>, <code>else</code>."
          }
        ]
      },
      "en": {
        "title": "28. Pattern matching",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Modern Ruby: case/in</h2><p>Since Ruby 3 there is, next to <code>case/when</code>, the more powerful <strong>pattern matching</strong> with <code>case/in</code>: it checks the <em>shape</em> of data and takes it apart in the same step. Perfect for our command array from the CLI lesson:</p>"
          },
          {
            "t": "c",
            "code": "command = [\"add\", \"ProjectX\", 3.5]\n\ncase command\nin [\"add\", project, hours]\n  \"New entry: #{project} (#{hours}h)\"\nin [\"report\"]\n  \"Generating report\"\nend"
          },
          {
            "t": "h",
            "html": "<p>The pattern <code>[\"add\", project, hours]</code> only matches three-element arrays starting with <code>\"add\"</code> – and binds the remaining values to variables right away. Hashes deconstruct too, with type checks and a guard condition (<code>if</code>) on top:</p>"
          },
          {
            "t": "c",
            "code": "entry = { project: \"ProjectX\", hours: 3.5 }\n\ncase entry\nin { project: String => p, hours: Float => h } if h > 0\n  \"#{p}: #{h}h - looks good\"\nin { hours: }\n  \"Invalid hours: #{hours.inspect}\"\nend"
          },
          {
            "t": "h",
            "html": "<p>The rest of modern Ruby fits right in: <em>endless methods</em> for one-liners (<code>def square(x) = x * x</code>), the hash shorthand <code>{ project:, hours: }</code> when variable and key share a name, and <code>data => { project: }</code> as a deconstructing assignment outside of <code>case</code>.</p><div class='task'><strong>Task:</strong> Write <code>dispatch(command)</code> with <code>case/in</code>: <code>[\"add\", project, hours]</code> → <code>\"Entry: &lt;project&gt; (&lt;hours&gt;h)\"</code>, <code>[\"report\"]</code> → <code>\"Report\"</code>, <code>[\"export\", format]</code> → <code>\"Export as &lt;format&gt;\"</code>, anything else (<code>else</code>) → <code>\"Unknown command\"</code>.</div>"
          },
          {
            "t": "x",
            "code": "# def dispatch(command)\n#   case command\n#   in ...\n#   end\n# end\n",
            "check": "dispatch([\"add\", \"X\", 2.5]) == \"Entry: X (2.5h)\" && dispatch([\"report\"]) == \"Report\" && dispatch([\"export\", \"csv\"]) == \"Export as csv\" && dispatch([\"dance\"]) == \"Unknown command\" && code.include?(\"in [\")",
            "hint": "Four branches: <code>in [\"add\", project, hours]</code>, <code>in [\"report\"]</code>, <code>in [\"export\", format]</code>, <code>else</code>."
          }
        ]
      }
    },
    {
      "id": "tl-meta",
      "de": {
        "title": "29. Objektmodell & Metaprogrammierung",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Wie Ruby Methoden findet</h2><p>Wenn du <code>objekt.methode</code> aufrufst, klettert Ruby eine Kette hinauf: erst die Singleton-Klasse des Objekts (dort landen Methoden, die nur <em>dieses</em> Objekt hat), dann seine Klasse, dann die Mixins, dann die Oberklassen. Die Kette kannst du dir anzeigen lassen:</p>"
          },
          {
            "t": "c",
            "code": "sonderling = \"normaler String\"\n\ndef sonderling.schrei\n  upcase + \"!!!\"\nend\n\n[sonderling.schrei, String.ancestors.first(4)]"
          },
          {
            "t": "h",
            "html": "<p>Weil Klassen selbst Objekte sind, kann Code <em>Code erzeugen</em> – das ist Metaprogrammierung. <code>define_method</code> definiert Methoden zur Laufzeit, <code>send</code> ruft eine Methode auf, deren Name in einer Variablen steckt:</p>"
          },
          {
            "t": "c",
            "code": "class Konfig\n  def initialize(werte)\n    @werte = werte\n  end\n\n  %w[host port sprache].each do |feld|\n    define_method(feld) { @werte[feld] }\n  end\nend\n\nk = Konfig.new({ \"host\" => \"idogawa.com\", \"port\" => 8011 })\n[k.host, k.send(\"port\")]"
          },
          {
            "t": "h",
            "html": "<p>Genau so bauen Rails &amp; Co. ihre Makros wie <code>has_many</code> oder <code>validates</code>. Wichtige Warnung eines weisen Fuchses: <em>Der cleverste Code ist oft das Erste, was man später löscht.</em> Auch <code>method_missing</code> existiert (fängt alle unbekannten Aufrufe – immer zusammen mit <code>respond_to_missing?</code>), aber ein explizites <code>define_method</code> ist fast immer klarer.</p><div class='task'><strong>Aufgabe:</strong> Baue dein eigenes Rails-Makro: <code>Modell.validates_presence_of(*felder)</code> soll per <code>define_method</code> eine Methode <code>valid?</code> erzeugen, die prüft, dass keines der Felder <code>nil</code> oder <code>\"\"</code> ist. Die Klasse <code>Buchung</code> unten benutzt es dann wie in Rails.</div>"
          },
          {
            "t": "x",
            "code": "class Modell\n  # def self.validates_presence_of(*felder)\n  #   define_method(:valid?) do\n  #     ...\n  #   end\n  # end\nend\n\nclass Buchung < Modell\n  attr_accessor :projekt, :stunden\n  # validates_presence_of :projekt\nend\n",
            "check": "b = Buchung.new; b.projekt = \"X\"; b2 = Buchung.new; b2.projekt = \"\"; b3 = Buchung.new; b.valid? && !b2.valid? && !b3.valid? && code.include?(\"define_method\")",
            "hint": "<code>felder.all? { |f| wert = send(f); !wert.nil? && wert != \"\" }</code> – im define_method-Block. Danach in <code>Buchung</code> die Zeile <code>validates_presence_of :projekt</code> aktivieren."
          }
        ]
      },
      "en": {
        "title": "29. Object model & metaprogramming",
        "cells": [
          {
            "t": "h",
            "html": "<h2>How Ruby finds methods</h2><p>When you call <code>object.method</code>, Ruby climbs a chain: first the object's singleton class (home of methods only <em>this</em> object has), then its class, then the mixins, then the superclasses. You can display the chain:</p>"
          },
          {
            "t": "c",
            "code": "oddball = \"a normal string\"\n\ndef oddball.shout\n  upcase + \"!!!\"\nend\n\n[oddball.shout, String.ancestors.first(4)]"
          },
          {
            "t": "h",
            "html": "<p>Because classes are objects themselves, code can <em>create code</em> – that's metaprogramming. <code>define_method</code> defines methods at runtime, <code>send</code> calls a method whose name sits in a variable:</p>"
          },
          {
            "t": "c",
            "code": "class Config\n  def initialize(values)\n    @values = values\n  end\n\n  %w[host port language].each do |field|\n    define_method(field) { @values[field] }\n  end\nend\n\nc = Config.new({ \"host\" => \"idogawa.com\", \"port\" => 8011 })\n[c.host, c.send(\"port\")]"
          },
          {
            "t": "h",
            "html": "<p>That's exactly how Rails &amp; co. build their macros like <code>has_many</code> or <code>validates</code>. An important warning from a wise fox: <em>the cleverest code is often the first thing you delete later.</em> <code>method_missing</code> exists too (catches all unknown calls – always pair it with <code>respond_to_missing?</code>), but an explicit <code>define_method</code> is almost always clearer.</p><div class='task'><strong>Task:</strong> Build your own Rails macro: <code>BaseModel.validates_presence_of(*fields)</code> should use <code>define_method</code> to create a <code>valid?</code> method checking that none of the fields is <code>nil</code> or <code>\"\"</code>. The class <code>Booking</code> below then uses it Rails-style.</div>"
          },
          {
            "t": "x",
            "code": "class BaseModel\n  # def self.validates_presence_of(*fields)\n  #   define_method(:valid?) do\n  #     ...\n  #   end\n  # end\nend\n\nclass Booking < BaseModel\n  attr_accessor :project, :hours\n  # validates_presence_of :project\nend\n",
            "check": "b = Booking.new; b.project = \"X\"; b2 = Booking.new; b2.project = \"\"; b3 = Booking.new; b.valid? && !b2.valid? && !b3.valid? && code.include?(\"define_method\")",
            "hint": "<code>fields.all? { |f| value = send(f); !value.nil? && value != \"\" }</code> – inside the define_method block. Then activate the line <code>validates_presence_of :project</code> in <code>Booking</code>."
          }
        ]
      }
    },
    {
      "id": "tl-dsl",
      "de": {
        "title": "30. Eine eigene DSL",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Konfiguration wie die Grossen</h2><p>Viele Ruby-Werkzeuge konfiguriert man mit eleganten Blöcken – das nennt man eine <strong>DSL</strong> (domain-specific language). Der Trick dahinter ist eine einzige Methode: <code>instance_eval</code> führt einen Block so aus, als stünde er <em>im Objekt drin</em> – <code>self</code> wechselt:</p>"
          },
          {
            "t": "c",
            "code": "class Speisekarte\n  attr_reader :gerichte\n\n  def initialize\n    @gerichte = {}\n  end\n\n  def gericht(name, preis:)\n    @gerichte[name] = preis\n  end\nend\n\ndef speisekarte(&block)\n  karte = Speisekarte.new\n  karte.instance_eval(&block)\n  karte\nend\n\nkarte = speisekarte do\n  gericht \"Speck\", preis: 8\n  gericht \"Ei\",    preis: 3\nend\n\nkarte.gerichte"
          },
          {
            "t": "h",
            "html": "<p>Im Block ruft <code>gericht \"Speck\", preis: 8</code> in Wahrheit eine Methode der <code>Speisekarte</code> auf – ganz ohne Empfänger davor. Das liest sich wie eine Mini-Sprache. (<code>instance_exec</code> ist die Schwester, die zusätzlich Argumente in den Block reicht.)</p><p><strong>Ehrliche Warnung:</strong> Eine DSL lohnt sich nur, wenn viele Menschen sie oft lesen – sonst tut es ein schlichter Hash genauso gut und ist leichter zu debuggen. Verwandte Bausteine aus der Werkzeugkiste: unsere Formatter-Lambdas aus Lektion 24 waren das <em>Strategy</em>-Muster, und ein <em>Null-Objekt</em> (z. B. ein GastNutzer statt <code>nil</code>) erspart tausend <code>if</code>-Abfragen.</p><div class='task'><strong>Aufgabe:</strong> Baue die timelog-Konfiguration: <code>Timelog.configure { … }</code> führt den Block per <code>instance_eval</code> auf einer neuen <code>Konfiguration</code> aus, <code>Timelog.config</code> gibt sie zurück. Im Block sollen <code>projekt \"Name\", satz: 120</code> und <code>runde_auf 15</code> funktionieren.</div>"
          },
          {
            "t": "x",
            "code": "module Timelog\n  class Konfiguration\n    attr_reader :projekte, :raster\n\n    def initialize\n      @projekte = {}\n      @raster = 60\n    end\n\n    # def projekt(name, satz:)\n    #   ...\n    # end\n\n    # def runde_auf(minuten)\n    #   ...\n    # end\n  end\n\n  # def self.configure(&block)\n  #   ...\n  # end\n\n  # def self.config\n  #   ...\n  # end\nend\n\n# Timelog.configure do\n#   projekt \"ProjectX\", satz: 120\n#   runde_auf 15\n# end\n",
            "check": "Timelog.configure { projekt \"A\", satz: 100\n runde_auf 30 }; Timelog.config.projekte[\"A\"] == 100 && Timelog.config.raster == 30 && code.include?(\"instance_eval\")",
            "hint": "<code>def self.configure(&block); @config = Konfiguration.new; @config.instance_eval(&block); @config; end</code> und <code>def self.config; @config; end</code>. Die DSL-Methoden schreiben einfach in <code>@projekte</code> bzw. <code>@raster</code>."
          }
        ]
      },
      "en": {
        "title": "30. Your own DSL",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Configuration like the big ones</h2><p>Many Ruby tools are configured with elegant blocks – that's called a <strong>DSL</strong> (domain-specific language). The trick behind it is a single method: <code>instance_eval</code> runs a block as if it were written <em>inside the object</em> – <code>self</code> switches:</p>"
          },
          {
            "t": "c",
            "code": "class Menu\n  attr_reader :dishes\n\n  def initialize\n    @dishes = {}\n  end\n\n  def dish(name, price:)\n    @dishes[name] = price\n  end\nend\n\ndef menu(&block)\n  m = Menu.new\n  m.instance_eval(&block)\n  m\nend\n\ncard = menu do\n  dish \"Bacon\", price: 8\n  dish \"Egg\",   price: 3\nend\n\ncard.dishes"
          },
          {
            "t": "h",
            "html": "<p>Inside the block, <code>dish \"Bacon\", price: 8</code> really calls a method of the <code>Menu</code> – with no receiver in front. It reads like a mini language. (<code>instance_exec</code> is the sibling that additionally passes arguments into the block.)</p><p><strong>Honest warning:</strong> a DSL only pays off when many people read it often – otherwise a plain hash does the job and is easier to debug. Related building blocks: our formatter lambdas from lesson 24 were the <em>Strategy</em> pattern, and a <em>null object</em> (e.g. a GuestUser instead of <code>nil</code>) saves a thousand <code>if</code> checks.</p><div class='task'><strong>Task:</strong> Build the timelog configuration: <code>Timelog.configure { … }</code> runs the block via <code>instance_eval</code> on a fresh <code>Configuration</code>, <code>Timelog.config</code> returns it. Inside the block, <code>project \"Name\", rate: 120</code> and <code>round_to 15</code> must work.</div>"
          },
          {
            "t": "x",
            "code": "module Timelog\n  class Configuration\n    attr_reader :projects, :grid\n\n    def initialize\n      @projects = {}\n      @grid = 60\n    end\n\n    # def project(name, rate:)\n    #   ...\n    # end\n\n    # def round_to(minutes)\n    #   ...\n    # end\n  end\n\n  # def self.configure(&block)\n  #   ...\n  # end\n\n  # def self.config\n  #   ...\n  # end\nend\n\n# Timelog.configure do\n#   project \"ProjectX\", rate: 120\n#   round_to 15\n# end\n",
            "check": "Timelog.configure { project \"A\", rate: 100\n round_to 30 }; Timelog.config.projects[\"A\"] == 100 && Timelog.config.grid == 30 && code.include?(\"instance_eval\")",
            "hint": "<code>def self.configure(&block); @config = Configuration.new; @config.instance_eval(&block); @config; end</code> and <code>def self.config; @config; end</code>. The DSL methods simply write into <code>@projects</code> / <code>@grid</code>."
          }
        ]
      }
    },
    {
      "id": "tl-quality",
      "de": {
        "title": "31. Codequalität & Debugging",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Werkzeuge für sauberen Code</h2><p>In Teams sorgt ein <strong>Linter</strong> für einheitlichen Stil: <em>RuboCop</em> ist der grosse Konfigurierbare mit hunderten Regeln, <em>Standard</em> die Null-Diskussionen-Variante („eine Konfiguration für alle“). Wichtiger als jede einzelne Regel: Das Team streitet nicht mehr über Kommas. Dazu kommen <em>YARD</em> für Doku-Kommentare und – wer mag – Typsignaturen mit <em>RBS</em> oder <em>Sorbet</em>.</p><div class='offweb' data-title='Auf deinem Computer'><pre><code>$ gem install standard\n$ standardrb            # prueft den Stil\n$ standardrb --fix      # repariert vieles gleich selbst\n\n# Und zum Debuggen mit Haltepunkt mitten im Code:\nrequire \"debug\"\nbinding.break           # oder binding.irb - oeffnet eine Konsole GENAU HIER</code></pre></div><p>Debuggen geht aber überall – auch hier. Das Universalwerkzeug heisst <code>p</code>: Es druckt sein Argument <em>und gibt es zurück</em>, du kannst es also mitten in jede Kette einschleusen:</p>"
          },
          {
            "t": "c",
            "code": "werte = [3, 1, 4, 1, 5, 9]\n\nwerte.select { |x| p(x).odd? }.sum"
          },
          {
            "t": "h",
            "html": "<p>Verwandte Helfer: <code>pp</code> für hübsche Hashes, <code>obj.inspect</code> für die ehrliche Darstellung, <code>caller</code> zeigt, wer die aktuelle Methode aufgerufen hat.</p><div class='task'><strong>Aufgabe:</strong> In der Zelle unten steckt ein klassischer Bug: <code>runde</code> soll Minuten auf das <strong>nächste</strong> Raster runden (<code>runde(38, 15)</code> → <code>45</code>), schneidet aber immer ab. Finde den Fehler (probier <code>p</code>!) und repariere die Methode.</div>"
          },
          {
            "t": "x",
            "code": "# Diese Methode soll auf das NAECHSTE Raster runden -\n# aber sie liefert runde(38, 15) => 30 statt 45. Warum?\n\ndef runde(minuten, raster)\n  (minuten / raster) * raster\nend\n\nrunde(38, 15)\n",
            "check": "runde(38, 15) == 45 && runde(8, 15) == 15 && runde(7, 15) == 0 && runde(22, 15) == 15 && runde(60, 60) == 60",
            "hint": "<code>38 / 15</code> ist Ganzzahl-Division (ergibt 2, Rest weg!). Erst zu Float machen, dann runden: <code>(minuten.to_f / raster).round * raster</code>."
          }
        ]
      },
      "en": {
        "title": "31. Code quality & debugging",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Tools for clean code</h2><p>In teams, a <strong>linter</strong> keeps the style uniform: <em>RuboCop</em> is the big configurable one with hundreds of rules, <em>Standard</em> the zero-discussion variant (“one config for everyone”). More important than any single rule: the team stops arguing about commas. Add <em>YARD</em> for doc comments and – if you like – type signatures with <em>RBS</em> or <em>Sorbet</em>.</p><div class='offweb' data-title='On your machine'><pre><code>$ gem install standard\n$ standardrb            # checks the style\n$ standardrb --fix      # repairs a lot by itself\n\n# And for breakpoint debugging right in your code:\nrequire \"debug\"\nbinding.break           # or binding.irb - opens a console RIGHT HERE</code></pre></div><p>But debugging works everywhere – including here. The universal tool is <code>p</code>: it prints its argument <em>and returns it</em>, so you can sneak it into the middle of any chain:</p>"
          },
          {
            "t": "c",
            "code": "values = [3, 1, 4, 1, 5, 9]\n\nvalues.select { |x| p(x).odd? }.sum"
          },
          {
            "t": "h",
            "html": "<p>Related helpers: <code>pp</code> for pretty hashes, <code>obj.inspect</code> for the honest representation, <code>caller</code> shows who called the current method.</p><div class='task'><strong>Task:</strong> The cell below hides a classic bug: <code>round_to</code> should round minutes to the <strong>nearest</strong> grid (<code>round_to(38, 15)</code> → <code>45</code>), but it always truncates. Find the bug (try <code>p</code>!) and repair the method.</div>"
          },
          {
            "t": "x",
            "code": "# This method should round to the NEAREST grid -\n# but it returns round_to(38, 15) => 30 instead of 45. Why?\n\ndef round_to(minutes, grid)\n  (minutes / grid) * grid\nend\n\nround_to(38, 15)\n",
            "check": "round_to(38, 15) == 45 && round_to(8, 15) == 15 && round_to(7, 15) == 0 && round_to(22, 15) == 15 && round_to(60, 60) == 60",
            "hint": "<code>38 / 15</code> is integer division (gives 2, remainder gone!). Convert to Float first, then round: <code>(minutes.to_f / grid).round * grid</code>."
          }
        ]
      }
    },
    {
      "id": "tl-performance",
      "de": {
        "title": "32. Performance & Nebenläufigkeit",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Erst messen, dann optimieren</h2><p>Die goldene Regel: <strong>niemals raten</strong>. Rubys <code>Benchmark</code> misst, was wirklich langsam ist – oft ist es nicht das, was man denkt. Klassiker: <code>+=</code> auf Strings erzeugt jedes Mal einen <em>neuen</em> String, die Schaufel <code>&lt;&lt;</code> erweitert denselben:</p>"
          },
          {
            "t": "c",
            "code": "require \"benchmark\"\n\nn = 5_000\nplus = Benchmark.realtime do\n  s = \"\"\n  n.times { s += \"x\" }\nend\nschaufel = Benchmark.realtime do\n  s = \"\"\n  n.times { s << \"x\" }\nend\n\n{ plus: plus.round(4), schaufel: schaufel.round(4) }"
          },
          {
            "t": "h",
            "html": "<p>Dahinter steckt das grosse Thema <strong>Allokationen</strong>: Jedes unnötige Zwischenobjekt kostet Zeit und Speicher. Und die schnellste Optimierung überhaupt: Code, der gar nicht erst läuft.</p><div class='offweb' data-title='Auf deinem Computer: Profiler'><pre><code>$ gem install benchmark-ips stackprof\n# benchmark-ips: wie oft pro Sekunde? (aussagekraeftiger als einmal messen)\n# stackprof:     WO verbringt das Programm seine Zeit?</code></pre></div><p><strong>Nebenläufigkeit:</strong> Mit <code>Thread</code> erledigt Ruby mehrere Dinge „gleichzeitig“. In MRI teilen sich alle Threads einen Interpreter (die <em>GVL</em>) – echter Gewinn entsteht darum vor allem beim <em>Warten</em> (Netzwerk, Dateien); für CPU-Parallelität gibt es <em>Ractors</em>. Im Browser existieren keine echten Threads, deshalb sind <code>Thread</code> und <code>sleep</code> hier <strong>simuliert</strong> (kooperativ, mit virtueller Zeit) – aber die API ist die echte:</p>"
          },
          {
            "t": "c",
            "code": "abrufe = [\"kunden\", \"projekte\", \"zeiten\"].map do |name|\n  Thread.new do\n    sleep 1   # simulierter Netzwerk-Download\n    \"#{name}: geladen\"\n  end\nend\n\nabrufe.map(&:value)"
          },
          {
            "t": "h",
            "html": "<p>Drei „Downloads“, gestartet mit <code>Thread.new</code>, eingesammelt mit <code>value</code> – auf deinem Rechner dauert das die Zeit von <em>einem</em> Download statt dreien. Und weil unsere simulierten Threads sich bei jedem <code>sleep</code> abwechseln, kannst du das Verschachteln sogar in der Ausgabe beobachten:</p>"
          },
          {
            "t": "c",
            "code": "faeden = 2.times.map do |i|\n  Thread.new do\n    3.times do |n|\n      puts \"Faden #{i}: Schritt #{n}\"\n      sleep 0.1\n    end\n  end\nend\nfaeden.each(&:join)\n\"fertig\""
          },
          {
            "t": "h",
            "html": "<p>Unter der Haube unserer Simulation stecken übrigens <strong>Fibers</strong>: kooperative Mini-Programme, die sich die Kontrolle explizit zuwerfen – das Fundament vieler async-Bibliotheken. Die kannst du auch direkt benutzen:</p>"
          },
          {
            "t": "c",
            "code": "erzaehler = Fiber.new do\n  Fiber.yield \"Kapitel 1: Speck\"\n  Fiber.yield \"Kapitel 2: Mehr Speck\"\n  \"Ende\"\nend\n\n[erzaehler.resume, erzaehler.resume, erzaehler.resume]"
          },
          {
            "t": "h",
            "html": "<div class='task'><strong>Aufgabe:</strong> <code>langsamer_bericht</code> unten durchsucht die Einträge <strong>einmal pro Projekt</strong> – bei vielen Projekten wird das quadratisch langsam. Schreibe <code>schneller_bericht</code>, der mit <strong>einem einzigen</strong> <code>group_by</code>-Durchlauf dasselbe Ergebnis liefert. Miss den Unterschied mit Benchmark!</div>"
          },
          {
            "t": "x",
            "code": "eintraege = 500.times.map { |i| { projekt: \"P#{i % 5}\", stunden: 1.0 } }\n\ndef langsamer_bericht(eintraege)\n  eintraege.map { |e| e[:projekt] }.uniq.to_h do |p|\n    [p, eintraege.select { |e| e[:projekt] == p }.sum { |e| e[:stunden] }]\n  end\nend\n\n# def schneller_bericht(eintraege)\n#   ...\n# end\n\n# require \"benchmark\"\n# { langsam: Benchmark.realtime { 50.times { langsamer_bericht(eintraege) } }.round(3),\n#   schnell: Benchmark.realtime { 50.times { schneller_bericht(eintraege) } }.round(3) }\n",
            "check": "schneller_bericht(eintraege) == langsamer_bericht(eintraege) && code.include?(\"group_by\")",
            "hint": "<code>eintraege.group_by { |e| e[:projekt] }.transform_values { |l| l.sum { |e| e[:stunden] } }</code> – ein Durchlauf statt einer pro Projekt."
          }
        ]
      },
      "en": {
        "title": "32. Performance & concurrency",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Measure first, then optimize</h2><p>The golden rule: <strong>never guess</strong>. Ruby's <code>Benchmark</code> measures what is actually slow – often it's not what you think. A classic: <code>+=</code> on strings creates a <em>new</em> string every time, the shovel <code>&lt;&lt;</code> extends the same one:</p>"
          },
          {
            "t": "c",
            "code": "require \"benchmark\"\n\nn = 5_000\nplus = Benchmark.realtime do\n  s = \"\"\n  n.times { s += \"x\" }\nend\nshovel = Benchmark.realtime do\n  s = \"\"\n  n.times { s << \"x\" }\nend\n\n{ plus: plus.round(4), shovel: shovel.round(4) }"
          },
          {
            "t": "h",
            "html": "<p>Behind this sits the big topic of <strong>allocations</strong>: every unnecessary intermediate object costs time and memory. And the fastest optimization of all: code that never runs in the first place.</p><div class='offweb' data-title='On your machine: profilers'><pre><code>$ gem install benchmark-ips stackprof\n# benchmark-ips: how many times per second? (more telling than one run)\n# stackprof:     WHERE does the program spend its time?</code></pre></div><p><strong>Concurrency:</strong> with <code>Thread</code>, Ruby does several things “at once”. In MRI all threads share one interpreter (the <em>GVL</em>) – real gains therefore appear mostly while <em>waiting</em> (network, files); for CPU parallelism there are <em>Ractors</em>. The browser has no real threads, so <code>Thread</code> and <code>sleep</code> are <strong>simulated</strong> here (cooperatively, with virtual time) – but the API is the real one:</p>"
          },
          {
            "t": "c",
            "code": "fetches = [\"clients\", \"projects\", \"times\"].map do |name|\n  Thread.new do\n    sleep 1   # simulated network download\n    \"#{name}: loaded\"\n  end\nend\n\nfetches.map(&:value)"
          },
          {
            "t": "h",
            "html": "<p>Three “downloads”, started with <code>Thread.new</code>, collected with <code>value</code> – on your machine this takes the time of <em>one</em> download instead of three. And because our simulated threads take turns at every <code>sleep</code>, you can even watch the interleaving in the output:</p>"
          },
          {
            "t": "c",
            "code": "threads = 2.times.map do |i|\n  Thread.new do\n    3.times do |n|\n      puts \"thread #{i}: step #{n}\"\n      sleep 0.1\n    end\n  end\nend\nthreads.each(&:join)\n\"done\""
          },
          {
            "t": "h",
            "html": "<p>By the way, under the hood of our simulation sit <strong>Fibers</strong>: cooperative mini-programs that pass control explicitly – the foundation of many async libraries. You can use them directly too:</p>"
          },
          {
            "t": "c",
            "code": "narrator = Fiber.new do\n  Fiber.yield \"Chapter 1: Bacon\"\n  Fiber.yield \"Chapter 2: More bacon\"\n  \"The end\"\nend\n\n[narrator.resume, narrator.resume, narrator.resume]"
          },
          {
            "t": "h",
            "html": "<div class='task'><strong>Task:</strong> <code>slow_report</code> below scans the entries <strong>once per project</strong> – with many projects that turns quadratic. Write <code>fast_report</code> producing the same result with a <strong>single</strong> <code>group_by</code> pass. Measure the difference with Benchmark!</div>"
          },
          {
            "t": "x",
            "code": "entries = 500.times.map { |i| { project: \"P#{i % 5}\", hours: 1.0 } }\n\ndef slow_report(entries)\n  entries.map { |e| e[:project] }.uniq.to_h do |p|\n    [p, entries.select { |e| e[:project] == p }.sum { |e| e[:hours] }]\n  end\nend\n\n# def fast_report(entries)\n#   ...\n# end\n\n# require \"benchmark\"\n# { slow: Benchmark.realtime { 50.times { slow_report(entries) } }.round(3),\n#   fast: Benchmark.realtime { 50.times { fast_report(entries) } }.round(3) }\n",
            "check": "fast_report(entries) == slow_report(entries) && code.include?(\"group_by\")",
            "hint": "<code>entries.group_by { |e| e[:project] }.transform_values { |l| l.sum { |e| e[:hours] } }</code> – one pass instead of one per project."
          }
        ]
      }
    },
    {
      "id": "tl-capstone",
      "de": {
        "title": "33. Finale: timelog im Web",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Alles zusammen: die Weboberfläche</h2><p>Zum Abschluss verbinden wir <em>alles</em>: Collections für den Bericht, Roda fürs Routing, <strong>ERB</strong> als Vorlagensprache und den Mini-Browser als Bühne. ERB ist HTML mit eingebettetem Ruby: <code>&lt;%= … %&gt;</code> fügt einen Wert ein, <code>&lt;% … %&gt;</code> führt Code aus (Schleifen!):</p>"
          },
          {
            "t": "c",
            "code": "install_gem \"roda\"\nrequire \"roda\"\nrequire \"erb\"\n\nEINTRAEGE = [\n  { projekt: \"ProjectX\", stunden: 3.5 },\n  { projekt: \"Intern\",   stunden: 2.0 },\n  { projekt: \"ProjectX\", stunden: 3.0 }\n]\n\nVORLAGE = ERB.new(<<~HTML)\n  <h1>timelog</h1>\n  <table border='1' cellpadding='6'>\n    <tr><th>Projekt</th><th>Stunden</th></tr>\n    <% bericht.each do |projekt, stunden| %>\n      <tr>\n        <td><a href='/projekt/<%= projekt %>'><%= projekt %></a></td>\n        <td><%= stunden %></td>\n      </tr>\n    <% end %>\n  </table>\nHTML\n\nclass TimelogWeb < Roda\n  route do |r|\n    r.root do\n      bericht = EINTRAEGE.group_by { |e| e[:projekt] }\n                         .transform_values { |l| l.sum { |e| e[:stunden] } }\n      VORLAGE.result(binding)\n    end\n  end\nend\n\nshow_browser TimelogWeb, \"/\""
          },
          {
            "t": "h",
            "html": "<p><code>VORLAGE.result(binding)</code> gibt der Vorlage Zugriff auf die lokalen Variablen der Route – so kommt <code>bericht</code> ins HTML. Genau so funktionieren die Views in Rails, Sinatra und Roda (dort mit Komfort-Helfern drumherum).</p><div class='task'><strong>Aufgabe:</strong> Die Projektnamen sind schon Links! Ergänze die Route <code>r.get \"projekt\", String do |name| … end</code>: Sie zeigt eine Detailseite mit dem Projektnamen als Überschrift und allen Stunden-Werten des Projekts (z.&nbsp;B. per <code>map</code>/<code>join</code>). Unbekannte Pfade sollen 404 bleiben. Damit ist timelog komplett – klick dich durch!</div>"
          },
          {
            "t": "x",
            "code": "install_gem \"roda\"\nrequire \"roda\"\nrequire \"erb\"\n\nEINTRAEGE = [\n  { projekt: \"ProjectX\", stunden: 3.5 },\n  { projekt: \"Intern\",   stunden: 2.0 },\n  { projekt: \"ProjectX\", stunden: 3.0 }\n]\n\nclass TimelogWeb < Roda\n  route do |r|\n    r.root do\n      \"<h1>timelog</h1><a href='/projekt/ProjectX'>ProjectX</a> <a href='/projekt/Intern'>Intern</a>\"\n    end\n\n    # r.get \"projekt\", String do |name|\n    #   passende = EINTRAEGE.select { ... }\n    #   \"<h2>...</h2>...\"\n    # end\n  end\nend\n\nshow_browser TimelogWeb, \"/\"\n",
            "check": "s1, b1 = mock_get(TimelogWeb, \"/\"); s2, b2 = mock_get(TimelogWeb, \"/projekt/ProjectX\"); s3, _ = mock_get(TimelogWeb, \"/quatsch\"); s1 == 200 && b1.include?(\"ProjectX\") && s2 == 200 && b2.include?(\"ProjectX\") && b2.include?(\"3.5\") && s3 == 404",
            "hint": "<code>r.get \"projekt\", String do |name|; passende = EINTRAEGE.select { |e| e[:projekt] == name }; \"&lt;h2&gt;#{name}&lt;/h2&gt;\" + passende.map { |e| \"#{e[:stunden]}h\" }.join(\", \"); end</code>"
          },
          {
            "t": "h",
            "html": "<h2>🎓 Geschafft!</h2><p>Du hast timelog von der ersten Collection bis zur Weboberfläche gebaut – mit Tests, Fehlerbehandlung, eigener DSL und Metaprogrammierung. Das ist kein Spielzeug-Wissen: Genau diese Bausteine stecken in jedem echten Ruby-Projekt.</p><p><strong>Wie weiter?</strong> Übe mit den <a href='https://koans.idogawa.com'>Ruby Koans</a>, bau timelog auf deinem eigenen Rechner als richtige Gem nach (Lektion 27 zeigt die Struktur) – und wenn du tiefer graben willst: Die Bücher <em>Programming Ruby</em> („Pickaxe“) und <em>Polished Ruby Programming</em> begleiten dich vom Handwerk zur Meisterschaft. CHUNKY BACON! 🦊🥓</p>"
          }
        ]
      },
      "en": {
        "title": "33. Finale: timelog on the web",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Everything together: the web interface</h2><p>To finish, we connect <em>everything</em>: collections for the report, Roda for routing, <strong>ERB</strong> as the template language and the mini browser as the stage. ERB is HTML with embedded Ruby: <code>&lt;%= … %&gt;</code> inserts a value, <code>&lt;% … %&gt;</code> runs code (loops!):</p>"
          },
          {
            "t": "c",
            "code": "install_gem \"roda\"\nrequire \"roda\"\nrequire \"erb\"\n\nENTRIES = [\n  { project: \"ProjectX\", hours: 3.5 },\n  { project: \"Intern\",   hours: 2.0 },\n  { project: \"ProjectX\", hours: 3.0 }\n]\n\nTEMPLATE = ERB.new(<<~HTML)\n  <h1>timelog</h1>\n  <table border='1' cellpadding='6'>\n    <tr><th>Project</th><th>Hours</th></tr>\n    <% report.each do |project, hours| %>\n      <tr>\n        <td><a href='/project/<%= project %>'><%= project %></a></td>\n        <td><%= hours %></td>\n      </tr>\n    <% end %>\n  </table>\nHTML\n\nclass TimelogWeb < Roda\n  route do |r|\n    r.root do\n      report = ENTRIES.group_by { |e| e[:project] }\n                      .transform_values { |l| l.sum { |e| e[:hours] } }\n      TEMPLATE.result(binding)\n    end\n  end\nend\n\nshow_browser TimelogWeb, \"/\""
          },
          {
            "t": "h",
            "html": "<p><code>TEMPLATE.result(binding)</code> gives the template access to the route's local variables – that's how <code>report</code> reaches the HTML. Views in Rails, Sinatra and Roda work exactly like this (with comfort helpers wrapped around).</p><div class='task'><strong>Task:</strong> The project names are already links! Add the route <code>r.get \"project\", String do |name| … end</code>: it shows a detail page with the project name as heading and all the project's hour values (e.g. via <code>map</code>/<code>join</code>). Unknown paths stay 404. With that, timelog is complete – click around!</div>"
          },
          {
            "t": "x",
            "code": "install_gem \"roda\"\nrequire \"roda\"\nrequire \"erb\"\n\nENTRIES = [\n  { project: \"ProjectX\", hours: 3.5 },\n  { project: \"Intern\",   hours: 2.0 },\n  { project: \"ProjectX\", hours: 3.0 }\n]\n\nclass TimelogWeb < Roda\n  route do |r|\n    r.root do\n      \"<h1>timelog</h1><a href='/project/ProjectX'>ProjectX</a> <a href='/project/Intern'>Intern</a>\"\n    end\n\n    # r.get \"project\", String do |name|\n    #   matching = ENTRIES.select { ... }\n    #   \"<h2>...</h2>...\"\n    # end\n  end\nend\n\nshow_browser TimelogWeb, \"/\"\n",
            "check": "s1, b1 = mock_get(TimelogWeb, \"/\"); s2, b2 = mock_get(TimelogWeb, \"/project/ProjectX\"); s3, _ = mock_get(TimelogWeb, \"/nonsense\"); s1 == 200 && b1.include?(\"ProjectX\") && s2 == 200 && b2.include?(\"ProjectX\") && b2.include?(\"3.5\") && s3 == 404",
            "hint": "<code>r.get \"project\", String do |name|; matching = ENTRIES.select { |e| e[:project] == name }; \"&lt;h2&gt;#{name}&lt;/h2&gt;\" + matching.map { |e| \"#{e[:hours]}h\" }.join(\", \"); end</code>"
          },
          {
            "t": "h",
            "html": "<h2>🎓 You made it!</h2><p>You built timelog from the first collection to a web interface – with tests, error handling, your own DSL and metaprogramming. That's not toy knowledge: exactly these building blocks sit inside every real Ruby project.</p><p><strong>Where next?</strong> Practice with the <a href='https://koans.idogawa.com'>Ruby Koans</a>, rebuild timelog on your own machine as a proper gem (lesson 27 shows the structure) – and if you want to dig deeper: the books <em>Programming Ruby</em> (“the Pickaxe”) and <em>Polished Ruby Programming</em> take you from craft to mastery. CHUNKY BACON! 🦊🥓</p>"
          }
        ]
      }
    }
  ]
});
