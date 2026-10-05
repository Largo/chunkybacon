// Lesson data for "Ruby lernen mit Chunky Bacon".
// Notebook format: each lesson (per language) is a list of cells:
//   { t: "h", html: ... }                        text block
//   { t: "c", code: ... }                        runnable demo cell
//   { t: "x", code, check, hint }                exercise cell (checked)
// All code cells of a lesson share one binding (like a notebook kernel).
// Check snippets are Ruby, eval'd in that binding with extra locals:
// output (captured stdout), result (last expression value), code (source),
// images (data urls from show_image during the run), downloads (names of
// the files offered below the cell: written by the run or download_file).
window.LESSONS_JSON = JSON.stringify({
  "ui": {
    "de": {
      "title": "Ruby lernen mit Chunky Bacon",
      "subtitle": "Ein Ruby-Notizbuch im Browser – kein Setup, einfach lostippen.",
      "runCell": "▶ Ausführen",
      "running": "läuft …",
      "reset": "Lektion zurücksetzen",
      "taskLabel": "Aufgabe",
      "loading": "Ruby wird geladen … (einmalig ca. 10 MB)",
      "kernelFailed": "Ruby konnte nicht geladen werden – bitte lade die Seite neu.",
      "shellFailed": "Die Seite konnte nicht starten – bitte lade sie neu.",
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
      "liveLabel": "⚡ Live",
      "liveOn": "Live: Der Code läuft von selbst, kurz nachdem du aufhörst zu tippen – als Probe, die keine Dateien speichert. ▶ führt ihn richtig aus.",
      "liveOff": "Live ist aus – klicken, damit der Code beim Tippen von selbst läuft.",
      "liveSlow": "Diese Zelle braucht zu lange für Live – mit ▶ ausführen.",
      "liveStopped": "Nach einer Sekunde angehalten – mit ▶ läuft der Code ganz.",
      "liveNeedsRun": "Gems installieren, Daten aus dem Netz holen und eine Datenbank ändern geht nur mit ▶.",
      "nextLesson": "→ Weiter zur nächsten Lektion",
      "progress": "Lektion %d von %d",
      "allDone": "🎉 Du hast alle Lektionen geschafft! CHUNKY BACON! Als nächsten Schritt empfehle ich dir die <a href='https://koans.idogawa.com'>Ruby Koans im Browser</a> – und auf <a href='https://www.rubyevents.org' target='_blank'>RubyEvents.org</a> die nächste Ruby-Konferenz oder ein Meetup.",
      "gemsTitle": "💎 Gems",
      "gemsInstallBtn": "Installieren",
      "gemsCachedTip": "lokal zwischengespeichert – installiert sofort",
      "gemsNote": "Pure-Ruby-Gems von rubygems.org, direkt im Browser installiert. ⚡ = lokal zwischengespeichert. Gems mit C-Code funktionieren hier nicht – ausser nokogiri und bigdecimal, die es in reinem Ruby nachgebaut gibt.",
      "gemInstalled": "💎 %s installiert! Jetzt einfach mit <code>require</code> laden.",
      "nativeDep": "%s braucht %s, und das enthält C-Code (eine „native extension“) – das kann nicht zur Laufzeit im Browser installiert werden. Solche Gems müssen beim Bauen der ruby.wasm-Datei fest einkompiliert werden.",
      "nativeGem": "%s enthält C-Code (eine „native extension“) und kann nicht zur Laufzeit im Browser installiert werden. Solche Gems müssen beim Bauen der ruby.wasm-Datei fest einkompiliert werden – so macht es z. B. Evil Martians' TutorialKit.rb.",
      "gemNotFound": "Gem „%s“ wurde nicht gefunden (oder der Download schlug fehl).",
      "browserGo": "Los",
      "irbExitNote": "(Auf deinem Computer wäre IRB jetzt beendet – hier darfst du einfach weitertippen. 🦊)",
      "filesTitle": "Dateien (simuliert)",
      "threeLoading": "Die 3D-Engine (three.js) wird noch geladen – führe die Zelle gleich nochmal aus.",
      "pythonLoading": "Python (Pyodide) wird geladen – beim ersten Mal ein paar MB. Führe die Zelle gleich nochmal aus.",
      "pythonOffline": "Python ist nicht in deiner Offline-Kopie. Mit Internet läuft diese Zelle – oder setz unter «Dein Fortschritt» das Häkchen bei «Python mitnehmen».",
      "sqliteLoading": "SQLite wird geladen – beim ersten Mal rund 1 MB. Führe die Zelle gleich nochmal aus.",
      "downloadTip": "Dateien, die deine Zelle geschrieben hat – zum Herunterladen anklicken.",
      "footerCredit": "Ein Angebot von <a href='https://idogawa.com'>Andi Idogawa</a>. Läuft komplett in deinem Browser dank <a href='https://github.com/ruby/ruby.wasm'>ruby.wasm</a>. Schon fertig? Weiter geht's mit den <a href='https://koans.idogawa.com'>Ruby Koans</a>.",
      "footerLicense": "„<a href='https://chunkybacon.dev/glossary/chunky-bacon/'>Chunky Bacon</a>“ stammt aus why's (poignant) guide to Ruby von why the lucky stiff – in liebevoller Erinnerung. Kursinhalte: <a href='https://creativecommons.org/licenses/by-sa/4.0/deed.de'>CC BY-SA 4.0</a>, Code: <a href='https://github.com/Largo/chunkybacon/blob/main/LICENSE'>MIT</a>.",
      "progressButton": "Fortschritt",
      "progressTitle": "Dein Fortschritt",
      "progressIntro": "Erledigte Lektionen, dein Code und deine Werkstatt-Dateien bleiben auf deinem Gerät – diese Seite speichert nichts auf einem Server. Sichere sie, damit nichts verloren geht und alles auf einen anderen Rechner umziehen kann.",
      "folderTitle": "In einem Ordner speichern",
      "folderExplain": "Wähle einen Ordner auf deinem Rechner. Jede Änderung landet sofort dort: dein Fortschritt in chunkybacon-progress.json, deine Werkstatt-Dateien als echte Dateien.",
      "folderChoose": "Ordner wählen",
      "folderResume": "Ordner „%s“ wieder öffnen",
      "folderResumeNote": "Nach einem Neustart fragt dein Browser einmal nach, ob diese Seite den Ordner weiter benutzen darf.",
      "folderConnected": "Verbunden mit dem Ordner „%s“.",
      "folderSavedAt": "Zuletzt gespeichert um %s.",
      "folderDisconnect": "Ordner trennen",
      "folderError": "Speichern im Ordner fehlgeschlagen: %s",
      "folderUnsupported": "In einem Ordner speichern können Chrome und Edge, wenn die Seite über https kommt. Hier geht es mit einer Datei:",
      "fileTitle": "Als Datei",
      "fileExplain": "Lade die Datei herunter und später hier wieder – auch in einem anderen Browser oder auf einem anderen Rechner.",
      "fileDownload": "Datei herunterladen",
      "fileLoad": "Datei laden",
      "fileLoaded": "Fortschritt geladen.",
      "fileUnchanged": "Die Datei enthält nichts, was hier nicht schon ist.",
      "fileInvalid": "Das ist keine Fortschrittsdatei von Chunky Bacon.",
      "offlineTitle": "Offline lernen",
      "offlineExplain": "Speichere den ganzen Kurs auf diesem Gerät – dann funktioniert er auch ohne Internet, im Zug oder im Flugzeug. Einmalig bis zu 55 MB Download, etwa 87 MB Speicherplatz (ohne Python 20 und 44 MB). Wird der Kurs online geändert, holt sich die Kopie die Änderungen von selbst.",
      "offlineEnable": "Auf diesem Gerät speichern",
      "offlineLoading": "Wird gespeichert …",
      "offlineReady": "Auf diesem Gerät gespeichert – funktioniert auch offline. Stand: %s",
      "offlineUpdating": "Eine neuere Version wird gerade gespeichert …",
      "offlineFromCopy": "Du bist gerade offline und siehst die gespeicherte Kopie. Gems, die nicht im Kurs enthalten sind, und Seiten aus dem Internet gehen erst wieder mit Verbindung.",
      "offlineDisable": "Kopie löschen",
      "offlineError": "Der Kurs konnte nicht gespeichert werden: %s",
      "offlineRetry": "Nochmals versuchen",
      "offlinePython": "Python mitnehmen – für die Python-Lektionen (pandas, SymPy, NumPy, scikit-learn), rund 43 MB",
      "offlineUnsupported": "Offline lernen geht in diesem Browser nicht (zum Beispiel in einem privaten Fenster).",
      "gemOffline": "Gem „%s“ ist nicht in der Offline-Kopie – zum Installieren brauchst du eine Internetverbindung.",
      "close": "Schliessen",
      "workshopNav": "🛠 Werkstatt",
      "navTitle": "Lektionen",
      "navSearch": "Lektion suchen",
      "navNone": "Keine Lektion passt.",
      "navToggle": "Lektionen ein- und ausblenden",
      "navDone": "%d von %d fertig",
      "workshopTitle": "Werkstatt",
      "workshopIntro": "Hier baust du deine eigenen Programme – mit so vielen Dateien, wie du willst. Ein Programm kann Dateien lesen und schreiben (<code>File.read</code>, <code>File.write</code>), andere .rb-Dateien mit <code>require_relative</code> laden und mit <code>gets</code> Eingaben lesen.",
      "workshopWelcome": "Willkommen in der <strong>Werkstatt</strong>! 🛠 Hier gibt es keine Aufgaben – nur dich und Ruby. Deine Dateien bleiben in diesem Browser. In Chrome und Edge kannst du oben unter <em>Fortschritt</em> einen Ordner verbinden, dann liegen sie als echte Dateien auf deinem Rechner.",
      "wsFiles": "Dateien",
      "wsInBrowser": "in diesem Browser",
      "wsInFolder": "im Ordner „%s“",
      "wsLocked": "Der Ordner „%s“ wartet auf deine Freigabe.",
      "wsUnlock": "Freigeben",
      "wsNewFile": "+ Neue Datei",
      "wsBadName": "Nimm Buchstaben, Ziffern, - und _, z. B. spiel.rb oder daten/liste.txt.",
      "wsExists": "„%s“ gibt es schon.",
      "wsDelete": "„%s“ löschen",
      "wsRename": "„%s“ umbenennen",
      "wsDeleteConfirm": "„%s“ wirklich löschen?",
      "wsUpload": "Hochladen",
      "wsDownload": "Herunterladen",
      "wsDatabase": "🗄 Eine SQLite-Datenbank (%s). Dein Programm öffnet sie mit Sequel.sqlite und ihrem Namen. Mit „Herunterladen“ bekommst du die Datei für ein SQLite-Werkzeug wie DB Browser for SQLite.",
      "wsStdin": "Eingabe für gets",
      "wsStdinHint": "Jede Zeile ist die Antwort auf ein gets.",
      "wsNotRuby": "Ausführen lassen sich .rb-Dateien.",
      "wsStarter": "# Willkommen in der Werkstatt! Das ist dein eigenes Programm.\n# Ändere es, lege weitere Dateien an und starte es mit ▶ Ausführen.\n\nname = gets&.chomp\nname = \"Fuchs\" if name.nil? || name.empty?\nputs \"Hallo, #{name}! 🦊\"\n\n# Was dein Programm schreibt, erscheint links in der Dateiliste.\nFile.write(\"gruss.txt\", \"Chunky Bacon grüsst #{name}!\\n\")\nputs File.read(\"gruss.txt\")\n",
      "letterFrom": "Absender: ein Fuchs",
      "letterTo": "Chunky Bacon",
      "letterStreet": "Speckweg 1",
      "letterValue": "CHF 1.20",
      "letterPost": "Chunky Post",
      "letterClear": "Radieren",
      "letterSees": "Das bekommt Ruby:",
      "letterHint": "Schreib die Postleitzahl in die roten Kästchen"
    },
    "en": {
      "title": "Learn Ruby with Chunky Bacon",
      "subtitle": "A Ruby notebook in your browser – no setup, just start typing.",
      "runCell": "▶ Run",
      "running": "running …",
      "reset": "Reset lesson",
      "taskLabel": "Task",
      "loading": "Loading Ruby … (one-time, about 10 MB)",
      "kernelFailed": "Ruby could not be loaded – please reload the page.",
      "shellFailed": "The page could not start – please reload it.",
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
      "liveLabel": "⚡ Live",
      "liveOn": "Live: the code runs by itself a moment after you stop typing – as a rehearsal that saves no files. ▶ runs it for real.",
      "liveOff": "Live is off – click to have the code run by itself as you type.",
      "liveSlow": "This cell takes too long for live runs – run it with ▶.",
      "liveStopped": "Stopped after a second – ▶ runs the code all the way.",
      "liveNeedsRun": "Installing gems, fetching from the web and changing a database only happen with ▶.",
      "nextLesson": "→ On to the next lesson",
      "progress": "Lesson %d of %d",
      "allDone": "🎉 You finished all lessons! CHUNKY BACON! As a next step, try the <a href='https://koans.idogawa.com'>Ruby Koans in the browser</a> – and find your next Ruby conference or meetup on <a href='https://www.rubyevents.org' target='_blank'>RubyEvents.org</a>.",
      "gemsTitle": "💎 Gems",
      "gemsInstallBtn": "Install",
      "gemsCachedTip": "cached locally – installs instantly",
      "gemsNote": "Pure-Ruby gems from rubygems.org, installed right in your browser. ⚡ = cached locally. Gems with C code do not work here – except nokogiri and bigdecimal, which exist rebuilt in pure Ruby.",
      "gemInstalled": "💎 %s installed! Now just load it with <code>require</code>.",
      "nativeDep": "%s needs %s, which contains C code (a “native extension”) and cannot be installed at runtime in the browser. Such gems must be compiled into the ruby.wasm binary itself.",
      "nativeGem": "%s contains C code (a “native extension”) and cannot be installed at runtime in the browser. Such gems must be compiled into the ruby.wasm binary itself – that is how Evil Martians' TutorialKit.rb does it.",
      "gemNotFound": "Gem “%s” was not found (or the download failed).",
      "browserGo": "Go",
      "irbExitNote": "(On your computer IRB would have quit now – here you can just keep typing. 🦊)",
      "filesTitle": "files (simulated)",
      "threeLoading": "The 3D engine (three.js) is still loading – run the cell again in a moment.",
      "pythonLoading": "Python (Pyodide) is loading – a few MB, the first time only. Run the cell again in a moment.",
      "pythonOffline": "Python is not in your offline copy. This cell runs with an internet connection – or tick “Include Python” under “Your progress”.",
      "sqliteLoading": "SQLite is loading – about 1 MB, the first time only. Run the cell again in a moment.",
      "downloadTip": "Files your cell wrote – click to download.",
      "footerCredit": "A service by <a href='https://idogawa.com'>Andi Idogawa</a>. Runs entirely in your browser thanks to <a href='https://github.com/ruby/ruby.wasm'>ruby.wasm</a>. Done here? Continue with the <a href='https://koans.idogawa.com'>Ruby Koans</a>.",
      "footerLicense": "“<a href='https://chunkybacon.dev/glossary/chunky-bacon/'>Chunky Bacon</a>” comes from why's (poignant) guide to Ruby by why the lucky stiff – fondly remembered. Course content: <a href='https://creativecommons.org/licenses/by-sa/4.0/'>CC BY-SA 4.0</a>, code: <a href='https://github.com/Largo/chunkybacon/blob/main/LICENSE'>MIT</a>.",
      "progressButton": "Progress",
      "progressTitle": "Your progress",
      "progressIntro": "Finished lessons, your code and your workshop files stay on your device – this site stores nothing on a server. Save them so nothing gets lost and everything can move to another computer.",
      "folderTitle": "Save to a folder",
      "folderExplain": "Pick a folder on your computer. Every change goes there right away: your progress into chunkybacon-progress.json, your workshop files as real files.",
      "folderChoose": "Choose folder",
      "folderResume": "Reopen folder “%s”",
      "folderResumeNote": "After a restart your browser asks once whether this site may keep using the folder.",
      "folderConnected": "Connected to the folder “%s”.",
      "folderSavedAt": "Last saved at %s.",
      "folderDisconnect": "Disconnect folder",
      "folderError": "Saving to the folder failed: %s",
      "folderUnsupported": "Chrome and Edge can save to a folder when the site comes over https. Here it works with a file:",
      "fileTitle": "As a file",
      "fileExplain": "Download the file and load it here again later – in another browser or on another computer, too.",
      "fileDownload": "Download file",
      "fileLoad": "Load file",
      "fileLoaded": "Progress loaded.",
      "fileUnchanged": "The file holds nothing that is not here already.",
      "fileInvalid": "That is not a Chunky Bacon progress file.",
      "offlineTitle": "Learn offline",
      "offlineExplain": "Keep the whole course on this device – then it works without internet too, on a train or a plane. Up to 55 MB to download once, about 87 MB of storage (without Python 20 and 44 MB). When the course changes online, the copy picks up the changes by itself.",
      "offlineEnable": "Keep on this device",
      "offlineLoading": "Saving …",
      "offlineReady": "Saved on this device – works offline too. As of %s",
      "offlineUpdating": "A newer version is being saved …",
      "offlineFromCopy": "You are offline right now and see the saved copy. Gems that are not part of the course and pages from the internet work again once you are connected.",
      "offlineDisable": "Delete the copy",
      "offlineError": "The course could not be saved: %s",
      "offlineRetry": "Try again",
      "offlinePython": "Include Python – for the Python lessons (pandas, SymPy, NumPy, scikit-learn), about 43 MB",
      "offlineUnsupported": "Learning offline does not work in this browser (in a private window, for example).",
      "gemOffline": "Gem “%s” is not in the offline copy – installing it needs an internet connection.",
      "close": "Close",
      "workshopNav": "🛠 Workshop",
      "navTitle": "Lessons",
      "navSearch": "Find a lesson",
      "navNone": "No lesson matches.",
      "navToggle": "Show or hide the lessons",
      "navDone": "%d of %d done",
      "workshopTitle": "Workshop",
      "workshopIntro": "Build your own programs here – with as many files as you like. A program can read and write files (<code>File.read</code>, <code>File.write</code>), load other .rb files with <code>require_relative</code> and read input with <code>gets</code>.",
      "workshopWelcome": "Welcome to the <strong>workshop</strong>! 🛠 No tasks here – just you and Ruby. Your files stay in this browser. In Chrome and Edge you can connect a folder under <em>Progress</em> at the top, and they become real files on your computer.",
      "wsFiles": "Files",
      "wsInBrowser": "in this browser",
      "wsInFolder": "in the folder “%s”",
      "wsLocked": "The folder “%s” is waiting for your permission.",
      "wsUnlock": "Allow",
      "wsNewFile": "+ New file",
      "wsBadName": "Use letters, digits, - and _, e.g. game.rb or data/list.txt.",
      "wsExists": "“%s” exists already.",
      "wsDelete": "Delete “%s”",
      "wsRename": "Rename “%s”",
      "wsDeleteConfirm": "Really delete “%s”?",
      "wsUpload": "Upload",
      "wsDownload": "Download",
      "wsDatabase": "🗄 A SQLite database (%s). Your program opens it with Sequel.sqlite and its name. “Download” gives you the file for a SQLite tool such as DB Browser for SQLite.",
      "wsStdin": "Input for gets",
      "wsStdinHint": "Each line answers one gets.",
      "wsNotRuby": ".rb files can be run.",
      "wsStarter": "# Welcome to the workshop! This is your own program.\n# Change it, add more files and start it with ▶ Run.\n\nname = gets&.chomp\nname = \"Fox\" if name.nil? || name.empty?\nputs \"Hello, #{name}! 🦊\"\n\n# Whatever your program writes shows up in the file list on the left.\nFile.write(\"greeting.txt\", \"Chunky Bacon greets #{name}!\\n\")\nputs File.read(\"greeting.txt\")\n",
      "letterFrom": "From: a fox",
      "letterTo": "Chunky Bacon",
      "letterStreet": "1 Bacon Lane",
      "letterValue": "$1.70",
      "letterPost": "Chunky Post",
      "letterClear": "Clear",
      "letterSees": "What Ruby gets:",
      "letterHint": "Write the postcode into the red boxes"
    },
    "ja": {
      "title": "Chunky Baconと学ぶRuby",
      "subtitle": "ブラウザで動くRubyのノートブック。セットアップ不要、すぐに書き始められます。",
      "runCell": "▶ 実行",
      "running": "実行中 …",
      "reset": "レッスンをリセット",
      "taskLabel": "課題",
      "loading": "Rubyを読み込み中 …（初回のみ、約10 MB）",
      "kernelFailed": "Rubyを読み込めませんでした。ページを再読み込みしてください。",
      "shellFailed": "ページを開始できませんでした。再読み込みしてください。",
      "welcome": "こんにちは！ぼくは<strong>Chunky Bacon</strong>、きみの相棒のキツネだよ。🦊🥓 このページは<strong>ノートブック</strong>になっていて、どのコードセルも<em>▶ 実行</em>か<kbd>Shift</kbd>+<kbd>Enter</kbd>で動かせるよ。最後の行の値は、Rubyが自動で<code>=&gt;</code>のあとに見せてくれる。オレンジの枠のセルがきみの課題だよ。さあ、始めよう！",
      "resetConfirm": "このレッスンのセルをすべて元に戻しますか？",
      "praise": [
        "CHUNKY BACON! 🥓 そのとおり！",
        "いいね！キツネたちも大喜び：CHUNKY BACON!",
        "完璧！Rubyの悟りへの道を着実に進んでるよ。",
        "すばらしい！Matzもきっと喜ぶよ。",
        "お見事！この調子でいこう！"
      ],
      "failIntro": "うーん、まだちょっと違うみたい。",
      "errorIntro": "あいたっ、Rubyがエラーを出したよ。セルの下を見てみて。",
      "liveLabel": "⚡ ライブ",
      "liveOn": "ライブ：入力の手を止めると、少ししてコードがひとりでに動きます。ファイルは保存しない試し実行です。本番の実行は ▶ で。",
      "liveOff": "ライブはオフです。クリックすると、入力中にコードがひとりでに動きます。",
      "liveSlow": "このセルはライブ実行には時間がかかりすぎます。▶ で実行してね。",
      "liveStopped": "1秒で止めました。▶ なら最後まで実行します。",
      "liveNeedsRun": "gemのインストール、ネットからのデータ取得、データベースの変更は ▶ のときだけ行います。",
      "nextLesson": "→ 次のレッスンへ",
      "progress": "レッスン %d / %d",
      "allDone": "🎉 全レッスン制覇！CHUNKY BACON! 次のステップには<a href='https://koans.idogawa.com'>ブラウザで動くRuby Koans</a>がおすすめだよ。次のRubyカンファレンスやミートアップは<a href='https://www.rubyevents.org' target='_blank'>RubyEvents.org</a>で探してみてね。",
      "gemsTitle": "💎 Gems",
      "gemsInstallBtn": "インストール",
      "gemsCachedTip": "ローカルにキャッシュ済み – すぐにインストールできます",
      "gemsNote": "rubygems.orgのピュアRubyのgemを、ブラウザの中で直接インストールします。⚡ = ローカルにキャッシュ済み。Cのコードを含むgemはここでは動きません。ただしnokogiriとbigdecimalは、ピュアRubyで作り直した版があるので使えます。",
      "gemInstalled": "💎 %sをインストールしたよ！あとは<code>require</code>で読み込むだけ。",
      "nativeDep": "%sは%sを必要としますが、そちらにはCのコード（「ネイティブ拡張」）が含まれているため、ブラウザの中で実行時にインストールすることはできません。こうしたgemは、ruby.wasmのバイナリをビルドするときに組み込んでおく必要があります。",
      "nativeGem": "%sにはCのコード（「ネイティブ拡張」）が含まれているため、ブラウザの中で実行時にインストールすることはできません。こうしたgemは、ruby.wasmのバイナリをビルドするときに組み込んでおく必要があります。Evil MartiansのTutorialKit.rbもこの方法をとっています。",
      "gemNotFound": "gem「%s」が見つかりませんでした（またはダウンロードに失敗しました）。",
      "browserGo": "移動",
      "irbExitNote": "（きみのコンピューターなら、IRBはここで終了しているところ。ここではそのまま入力を続けていいよ。🦊）",
      "filesTitle": "ファイル（シミュレーション）",
      "threeLoading": "3Dエンジン（three.js）をまだ読み込んでいます。少し待ってから、もう一度セルを実行してください。",
      "pythonLoading": "Python（Pyodide）を読み込んでいます（初回のみ数MB）。少し待ってから、もう一度セルを実行してください。",
      "pythonOffline": "Pythonはオフラインコピーに入っていません。インターネットにつながればこのセルは動きます。または「あなたの進捗」で「Pythonも保存する」にチェックを入れてください。",
      "sqliteLoading": "SQLiteを読み込んでいます（初回のみ約1 MB）。少し待ってから、もう一度セルを実行してください。",
      "downloadTip": "セルが書き出したファイルです。クリックするとダウンロードできます。",
      "footerCredit": "制作：<a href='https://idogawa.com'>Andi Idogawa</a>。<a href='https://github.com/ruby/ruby.wasm'>ruby.wasm</a>のおかげで、すべてブラウザの中だけで動いています。ひととおり終わったら、次は<a href='https://koans.idogawa.com'>Ruby Koans</a>へどうぞ。",
      "footerLicense": "「<a href='https://chunkybacon.dev/glossary/chunky-bacon/'>Chunky Bacon</a>」は、why the lucky stiffの『why's (poignant) guide to Ruby』に由来します。なつかしい思い出とともに。コースの内容：<a href='https://creativecommons.org/licenses/by-sa/4.0/deed.ja'>CC BY-SA 4.0</a>、コード：<a href='https://github.com/Largo/chunkybacon/blob/main/LICENSE'>MIT</a>。",
      "progressButton": "進捗",
      "progressTitle": "あなたの進捗",
      "progressIntro": "終えたレッスン、あなたのコード、工房のファイルは、すべてあなたの端末に残ります。このサイトはサーバーに何も保存しません。なくさないように、また別のコンピューターへ移せるように、保存しておきましょう。",
      "folderTitle": "フォルダーに保存",
      "folderExplain": "コンピューター上のフォルダーを選んでください。変更はすぐにそこへ保存されます。進捗はchunkybacon-progress.jsonに、工房のファイルは本物のファイルとして保存されます。",
      "folderChoose": "フォルダーを選ぶ",
      "folderResume": "フォルダー「%s」をもう一度開く",
      "folderResumeNote": "ブラウザを再起動したあとは、このサイトがフォルダーを引き続き使ってよいか、ブラウザが一度だけ確認します。",
      "folderConnected": "フォルダー「%s」に接続しています。",
      "folderSavedAt": "最終保存：%s",
      "folderDisconnect": "フォルダーの接続を解除",
      "folderError": "フォルダーへの保存に失敗しました：%s",
      "folderUnsupported": "フォルダーへの保存は、サイトがhttpsで配信されているときにChromeとEdgeで使えます。ここではファイルで保存できます：",
      "fileTitle": "ファイルとして保存",
      "fileExplain": "ファイルをダウンロードしておけば、あとでここに読み込み直せます。別のブラウザや別のコンピューターでも使えます。",
      "fileDownload": "ファイルをダウンロード",
      "fileLoad": "ファイルを読み込む",
      "fileLoaded": "進捗を読み込みました。",
      "fileUnchanged": "このファイルには、ここにまだないものは含まれていません。",
      "fileInvalid": "これはChunky Baconの進捗ファイルではありません。",
      "offlineTitle": "オフラインで学ぶ",
      "offlineExplain": "コース全体をこの端末に保存すると、インターネットがなくても（電車や飛行機の中でも）使えます。最初に最大55 MBをダウンロードし、約87 MBの容量を使います（Pythonなしなら20 MBと44 MB）。オンラインのコースが更新されると、コピーも自動で更新されます。",
      "offlineEnable": "この端末に保存",
      "offlineLoading": "保存しています…",
      "offlineReady": "この端末に保存済みです。オフラインでも使えます。（%s 時点）",
      "offlineUpdating": "新しいバージョンを保存しています…",
      "offlineFromCopy": "現在オフラインのため、保存したコピーを表示しています。コースに含まれていないgemやインターネット上のページは、接続が戻ると使えるようになります。",
      "offlineDisable": "コピーを削除",
      "offlineError": "コースを保存できませんでした：%s",
      "offlineRetry": "もう一度試す",
      "offlinePython": "Pythonも保存する（pandas・SymPy・NumPy・scikit-learnのレッスン用、約43 MB）",
      "offlineUnsupported": "このブラウザ（たとえばプライベートウィンドウ）ではオフライン学習を使えません。",
      "gemOffline": "gem「%s」はオフライン用コピーに含まれていません。インストールするにはインターネット接続が必要です。",
      "close": "閉じる",
      "workshopNav": "🛠 工房",
      "navTitle": "レッスン",
      "navSearch": "レッスンを探す",
      "navNone": "当てはまるレッスンはありません。",
      "navToggle": "レッスン一覧を開く・閉じる",
      "navDone": "%d / %d 完了",
      "workshopTitle": "工房",
      "workshopIntro": "ここでは自分だけのプログラムを作れます。ファイルはいくつでも作れます。プログラムはファイルを読み書きしたり（<code>File.read</code>、<code>File.write</code>）、<code>require_relative</code>でほかの.rbファイルを読み込んだり、<code>gets</code>で入力を読んだりできます。",
      "workshopWelcome": "<strong>工房</strong>へようこそ！🛠 ここには課題はないよ。きみとRubyだけ。ファイルはこのブラウザの中に保存される。ChromeとEdgeなら、上の<em>進捗</em>からフォルダーをつなげば、きみのコンピューター上の本物のファイルになるよ。",
      "wsFiles": "ファイル",
      "wsInBrowser": "このブラウザ内",
      "wsInFolder": "フォルダー「%s」内",
      "wsLocked": "フォルダー「%s」があなたの許可を待っています。",
      "wsUnlock": "許可する",
      "wsNewFile": "+ 新しいファイル",
      "wsBadName": "英字、数字、-、_ を使ってください。例：game.rb、data/list.txt",
      "wsExists": "「%s」はすでにあります。",
      "wsDelete": "「%s」を削除",
      "wsRename": "「%s」の名前を変更",
      "wsDeleteConfirm": "「%s」を本当に削除しますか？",
      "wsUpload": "アップロード",
      "wsDownload": "ダウンロード",
      "wsDatabase": "🗄 SQLiteデータベース（%s）です。プログラムからは、Sequel.sqliteにこのファイル名を渡して開けます。「ダウンロード」で、DB Browser for SQLiteなどのSQLiteツール用にファイルを取り出せます。",
      "wsStdin": "getsへの入力",
      "wsStdinHint": "1行が、getsの1回ぶんの答えになります。",
      "wsNotRuby": "実行できるのは.rbファイルです。",
      "wsStarter": "# 工房へようこそ！これはきみ自身のプログラムだよ。\n# 書き換えたり、ファイルを増やしたりして、▶ 実行で動かしてみよう。\n\nname = gets&.chomp\nname = \"Fox\" if name.nil? || name.empty?\nputs \"Hello, #{name}! 🦊\"\n\n# プログラムが書き出したファイルは、左のファイル一覧に出てくるよ。\nFile.write(\"greeting.txt\", \"Chunky Bacon greets #{name}!\\n\")\nputs File.read(\"greeting.txt\")\n",
      "letterFrom": "差出人：キツネ",
      "letterTo": "チャンキー・ベーコン 様",
      "letterStreet": "ベーコン通り1",
      "letterValue": "110円",
      "letterPost": "Chunky Post",
      "letterClear": "消す",
      "letterSees": "Rubyが受け取るもの：",
      "letterHint": "赤い枠に郵便番号を書いてね"
    }
  },
  "lessons": [
    {
      "id": "hallo",
      "section": {
        "de": "Grundkurs",
        "en": "Basics",
        "ja": "基礎コース"
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
      },
      "ja": {
        "title": "1. Hello, World!",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Hello, World!</h2><p>Rubyは<strong>人間</strong>のために作られたプログラミング言語です。生みの親のまつもとゆきひろ（Matz）は、プログラミングを楽しいものにしたいと考えました。</p><p>このページは<strong>ノートブック</strong>のようになっていて、文章のセルとコードのセルでできています。どのセルも自由に書き換えられ、<em>▶ 実行</em>か<kbd>Shift</kbd>+<kbd>Enter</kbd>で実行できます。さっそく試してみましょう：</p>"
          },
          {
            "t": "c",
            "code": "1 + 1"
          },
          {
            "t": "h",
            "html": "<p>セルの下に<code>=&gt; 2</code>と表示されましたね。この<code>=&gt;</code>は<strong>最後の行の値</strong>を示しています。特別な命令を書かなくても、Rubyが自動で表示してくれるのです。</p><p>テキストを明示的に<em>出力</em>したいときは、<code>puts</code>（「put string」の略）を使います：</p>"
          },
          {
            "t": "c",
            "code": "puts \"Chunky Bacon!\""
          },
          {
            "t": "h",
            "html": "<p>引用符で囲まれたテキストを<strong>文字列</strong>といいます。<code>puts</code>は、それを出力に書き出します。ちなみに<code>puts</code>そのものの値は<code>nil</code>、つまり「何もない」です。だから、ここには<code>=&gt;</code>の行が出ないのです。</p><div class='task'><strong>課題：</strong>下のセルに<code>Hello, World!</code>と表示させましょう。<code>puts</code>を使っても、単に最後の行の値にしてもかまいません。</div>"
          },
          {
            "t": "x",
            "code": "# ここにコードを書こう:\n",
            "check": "output.include?(\"Hello, World!\") || result == \"Hello, World!\"",
            "hint": "<code>puts \"Hello, World!\"</code>って書いてみて。最後の行にただ<code>\"Hello, World!\"</code>と書くだけでもいいよ。"
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
      },
      "ja": {
        "title": "2. 計算",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Rubyを電卓として使う</h2><p>Rubyは<code>+</code>、<code>-</code>、<code>*</code>（かける）、<code>/</code>（わる）で計算します。セルを実行してみましょう。数字も自由に変えてみてください：</p>"
          },
          {
            "t": "c",
            "code": "3 + 4"
          },
          {
            "t": "h",
            "html": "<p><code>#</code>から後ろはすべて<strong>コメント</strong>で、Rubyはこれを無視します。コメントは人間（とキツネ）のためのメモです：</p>"
          },
          {
            "t": "c",
            "code": "5 * 5   # 5かける5"
          },
          {
            "t": "h",
            "html": "<div class='task'><strong>課題：</strong>6かける7はいくつでしょう？計算はRubyにまかせて、セルに<code>6 * 7</code>の結果が表示されるようにしてください。（自分で計算してはいけませんよ。それでは意味がありませんからね！）</div>"
          },
          {
            "t": "x",
            "code": "",
            "check": "(output.include?(\"42\") || result == 42) && code.include?(\"*\")",
            "hint": "セルに<code>6 * 7</code>って書くだけでいいよ。星印の<code>*</code>は「かける」って意味なんだ。"
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
      },
      "ja": {
        "title": "3. 変数",
        "cells": [
          {
            "t": "h",
            "html": "<h2>変数：値に名前をつける</h2><p><strong>変数</strong>は、値につける名前です。<code>=</code>で値を代入します。変数名は小文字で書き、単語のあいだはアンダースコアでつなぎます：<code>favorite_food</code>、<code>bacon_strips</code>。</p>"
          },
          {
            "t": "c",
            "code": "food = \"bacon\"\namount = 3\nfood"
          },
          {
            "t": "h",
            "html": "<p>同じレッスンのセルどうしは、記憶を共有しています。本物のノートと同じですね。上で作った変数<code>amount</code>は、ここでもそのまま使えます。（エラーが出たら、先に上のセルを実行してください。）</p>"
          },
          {
            "t": "c",
            "code": "amount * 2"
          },
          {
            "t": "h",
            "html": "<div class='task'><strong>課題：</strong>変数を2つ作りましょう。<code>name</code>には自分の名前（文字列）を、<code>age</code>には数を入れてください。</div>"
          },
          {
            "t": "x",
            "code": "# name = ...\n# age = ...\n",
            "check": "name.is_a?(String) && !name.empty? && age.is_a?(Integer)",
            "hint": "たとえば<code>name = \"Kaz\"</code>と<code>age = 7</code>みたいにね。"
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
      },
      "ja": {
        "title": "4. 文字列の式展開",
        "cells": [
          {
            "t": "h",
            "html": "<h2>文字列と式展開</h2><p>文字列の中には、変数をそのまま埋め込めます。これを<strong>式展開</strong>といい、ダブルクォートで囲んだ文字列の中で<code>#{}</code>を使います：</p>"
          },
          {
            "t": "c",
            "code": "animal = \"fox\"\n\"The #{animal} shouts!\""
          },
          {
            "t": "h",
            "html": "<p>Rubyは<code>#{</code>と<code>}</code>のあいだにあるものを評価して、その結果を差し込みます。計算もできます：</p>"
          },
          {
            "t": "c",
            "code": "\"#{3 * 7} strips of bacon\""
          },
          {
            "t": "h",
            "html": "<div class='task'><strong>課題：</strong>下に変数<code>favorite_food</code>を用意しました。式展開を使って、<code>I love Chunky Bacon!</code>という文を作りましょう。変数は<code>#{}</code>で文字列の中に入れます。</div>"
          },
          {
            "t": "x",
            "code": "favorite_food = \"Chunky Bacon\"\n# \"I love ...!\"\n",
            "check": "(output.include?(\"I love Chunky Bacon!\") || result == \"I love Chunky Bacon!\") && code.include?('#{')",
            "hint": "最後の行に<code>\"I love #{favorite_food}!\"</code>って書いてみて。ダブルクォートを使うのを忘れずにね。"
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
      },
      "ja": {
        "title": "5. 条件分岐（if）",
        "cells": [
          {
            "t": "h",
            "html": "<h2>もし〜なら、そうでなければ</h2><p><code>if</code>を使うと、プログラムが判断を下せるようになります。比較には次の記号を使います：<code>&gt;</code>（より大きい）、<code>&lt;</code>（より小さい）、<code>==</code>（等しい。イコールを2つ！）、<code>!=</code>（等しくない）。<code>if</code>のブロックは、どれも<code>end</code>で終わります。</p>"
          },
          {
            "t": "c",
            "code": "hunger = 9\nif hunger > 7\n  \"Time for bacon!\"\nelse\n  \"All good.\"\nend"
          },
          {
            "t": "h",
            "html": "<p>Rubyでは<code>if</code>にも値があります。選ばれたほうの分岐の値です。<code>hunger</code>を<code>3</code>に変えて、もう一度セルを実行してみましょう！</p><div class='task'><strong>課題：</strong>下に<code>number = 7</code>があります。数が5より大きければ<code>big</code>、そうでなければ<code>small</code>になるようにしてください。値として返しても、<code>puts</code>で出力してもかまいません。</div>"
          },
          {
            "t": "x",
            "code": "number = 7\n# if ...\n",
            "check": "((output + result.to_s).include?(\"big\") && !(output + result.to_s).include?(\"small\")) && code.include?(\"if\")",
            "hint": "こんなふうに書くよ：<code>if number > 5</code>、次に<code>\"big\"</code>、それから<code>else</code>と<code>\"small\"</code>、最後に<code>end</code>。"
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
            "html": "<h2>Schleifen – Dinge wiederholen</h2><p>In why's legendärem Ruby-Buch rufen zwei Comic-Füchse immer wieder: <a href='https://chunkybacon.dev/glossary/chunky-bacon/' target='_blank'><em>„Chunky Bacon!“</em></a> – Wiederholung ist in Ruby wunderbar einfach:</p>"
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
            "html": "<h2>Loops – repeating things</h2><p>In why's legendary Ruby book two cartoon foxes keep shouting: <a href='https://chunkybacon.dev/glossary/chunky-bacon/' target='_blank'><em>“Chunky Bacon!”</em></a> – repetition is delightfully easy in Ruby:</p>"
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
      },
      "ja": {
        "title": "6. ループ",
        "cells": [
          {
            "t": "h",
            "html": "<h2>ループ：くり返し</h2><p>why the lucky stiffの伝説のRuby本『why's (poignant) guide to Ruby』では、マンガのキツネ2匹が何度も<a href='https://chunkybacon.dev/glossary/chunky-bacon/' target='_blank'><em>「Chunky Bacon!」</em></a>と叫びます。Rubyなら、くり返しも驚くほど簡単です：</p>"
          },
          {
            "t": "c",
            "code": "3.times do\n  puts \"Chunky Bacon!\"\nend"
          },
          {
            "t": "h",
            "html": "<p><code>do</code>と<code>end</code>のあいだのコードを<strong>ブロック</strong>といい、ここでは3回実行されます。（下に出る<code>=&gt; 3</code>は、<code>3.times</code>そのものの値です。）カウンターを使うと、こうなります：</p>"
          },
          {
            "t": "c",
            "code": "3.times do |i|\n  puts \"Strip number #{i + 1}\"\nend"
          },
          {
            "t": "h",
            "html": "<div class='task'><strong>課題：</strong><code>Chunky Bacon!</code>をちょうど5回出力しましょう。<code>puts</code>を5行並べるのではなく、ループを使ってくださいね。</div>"
          },
          {
            "t": "x",
            "code": "# Chunky Baconを5回、お願い！\n",
            "check": "((output + result.inspect).scan(\"Chunky Bacon!\").length >= 5) && (code.include?(\"times\") || code.include?(\"each\") || code.include?(\"while\") || code.include?(\"upto\") || code.include?(\"for \"))",
            "hint": "<code>5.times do</code>、<code>puts \"Chunky Bacon!\"</code>、<code>end</code>の3行を書いてみて。"
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
      },
      "ja": {
        "title": "7. 配列",
        "cells": [
          {
            "t": "h",
            "html": "<h2>配列：ものを並べたリスト</h2><p><strong>配列</strong>はリストです。角かっこで囲んで書きます：</p>"
          },
          {
            "t": "c",
            "code": "breakfast = [\"egg\", \"toast\"]\nbreakfast.length"
          },
          {
            "t": "h",
            "html": "<p>要素を取り出すときも角かっこを使います。数えはじめは0からですよ！</p>"
          },
          {
            "t": "c",
            "code": "breakfast[0]"
          },
          {
            "t": "h",
            "html": "<p><code>&lt;&lt;</code>（「シャベル」と呼ばれます）で末尾に要素を追加し、<code>each</code>で要素を1つずつ順番にたどれます：</p>"
          },
          {
            "t": "c",
            "code": "breakfast << \"coffee\"\nbreakfast.each do |item|\n  puts item\nend"
          },
          {
            "t": "h",
            "html": "<div class='task'><strong>課題：</strong>下の配列に<code>\"bacon\"</code>を追加しましょう。ボーナス：<code>each</code>ですべての要素を出力してみてください。</div>"
          },
          {
            "t": "x",
            "code": "breakfast = [\"egg\", \"toast\"]\n# ...\n",
            "check": "breakfast.is_a?(Array) && breakfast.include?(\"bacon\") && breakfast.include?(\"egg\")",
            "hint": "1行目の下に<code>breakfast << \"bacon\"</code>って書いてみて。"
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
      },
      "ja": {
        "title": "8. ハッシュ",
        "cells": [
          {
            "t": "h",
            "html": "<h2>ハッシュ：対応表</h2><p><strong>ハッシュ</strong>は、キーと値を結びつけます。ちょうど小さな辞書のようなものです。<code>:name</code>のようなキーは<strong>シンボル</strong>といい、コロンのついた軽い名前です。</p>"
          },
          {
            "t": "c",
            "code": "animal = { name: \"Chunky\", food: \"bacon\" }\nanimal[:name]"
          },
          {
            "t": "h",
            "html": "<p><code>animal[:food]</code>も試してみましょう。存在しないキーを指定すると、<code>nil</code>が返ってきます。</p><div class='task'><strong>課題：</strong>キー<code>:name</code>と<code>:food</code>を持つハッシュ<code>fox</code>を作りましょう（値は何でもかまいません）。</div>"
          },
          {
            "t": "x",
            "code": "# fox = { ... }\n",
            "check": "fox.is_a?(Hash) && fox[:name].to_s.length > 0 && fox[:food].to_s.length > 0",
            "hint": "たとえば<code>fox = { name: \"Chunky\", food: \"bacon\" }</code>みたいにね。"
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
      },
      "ja": {
        "title": "9. メソッド",
        "cells": [
          {
            "t": "h",
            "html": "<h2>自分でメソッドを書く</h2><p><code>def</code>で<strong>メソッド</strong>を定義します。メソッドとは名前のついたコードのかたまりで、何度でも呼び出せます：</p>"
          },
          {
            "t": "c",
            "code": "def greeting(name)\n  \"Hello, #{name}!\"\nend\n\ngreeting(\"Kaz\")"
          },
          {
            "t": "h",
            "html": "<p>ちょっと驚くかもしれませんが、じつはレッスン1からずっと、メソッドを呼び出していたのです。<code>puts</code>もメソッドだからです！Rubyでは<strong>かっこを省略できます</strong>。<code>puts \"Hello\"</code>は、本当は<code>puts(\"Hello\")</code>なのです。自分で作ったメソッドでも同じです：</p>"
          },
          {
            "t": "c",
            "code": "with_parens    = greeting(\"Kaz\")\nwithout_parens = greeting \"Kaz\"\n\n[with_parens, without_parens]"
          },
          {
            "t": "h",
            "html": "<p>Rubyのコードの多くがふつうの英文のように読めるのは、まさにこのおかげです。Rubyistの目安はこうです：呼び出しが命令文のように読めるとき（<code>puts \"…\"</code>、<code>require \"csv\"</code>）はかっこを<em>省き</em>、結果を使ってさらに計算を続けるとき（<code>greeting(\"Kaz\").upcase</code>）はかっこを<em>つけます</em>。引数がひとつもない呼び出しでは、ほぼ必ず省略します。<code>name.upcase()</code>ではなく<code>name.upcase</code>と書きます。</p>"
          },
          {
            "t": "h",
            "html": "<p>メソッドの<em>最後の行</em>の値は、自動的にそのメソッドの戻り値になります。わざわざ<code>return</code>と書く必要は、たいていありません。いかにもRubyらしいところです。</p><div class='task'><strong>課題：</strong>数をそれ自身とかけ合わせた値を返すメソッド<code>square(number)</code>を書きましょう。最後の行を<code>square(9)</code>にして試してください。</div>"
          },
          {
            "t": "x",
            "code": "# def square(number)\n#   ...\n# end\n\n# square(9)\n",
            "check": "square(9) == 81 && square(5) == 25 && code.include?(\"def\")",
            "hint": "こんなふうに書くよ：<code>def square(number)</code>、その下に<code>number * number</code>、最後に<code>end</code>。"
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
      },
      "ja": {
        "title": "10. クラス",
        "cells": [
          {
            "t": "h",
            "html": "<h2>クラス：自分だけのものを作る</h2><p>Rubyでは<em>すべて</em>がオブジェクトです。<strong>クラス</strong>を使えば、自分だけのオブジェクトを作れます：</p>"
          },
          {
            "t": "c",
            "code": "class Cat\n  attr_reader :name\n\n  def initialize(name)\n    @name = name\n  end\n\n  def shout\n    \"Meow!\"\n  end\nend\n\nk = Cat.new(\"Mimi\")\nk.shout"
          },
          {
            "t": "h",
            "html": "<p><code>initialize</code>は<code>Cat.new</code>のときに実行されます。<code>@</code>のついた変数はそのオブジェクトのもので、<code>attr_reader :name</code>と書くと<code>@name</code>を外から読めるようになります。<code>k.name</code>を試してみましょう！もうひとつ、なるほどと思える話があります。<code>attr_reader :name</code>は特別なキーワードではなく、かっこを省いたごくふつうのメソッド呼び出しです。レッスン9で学んだとおり、<code>attr_reader(:name)</code>と同じなのです。</p><div class='task'><strong>課題：</strong>この例にならって、クラス<code>Fox</code>を書きましょう。<code>initialize(name)</code>と<code>attr_reader :name</code>、そして<code>\"Chunky Bacon!\"</code>を返すメソッド<code>shout</code>を用意してください。</div>"
          },
          {
            "t": "x",
            "code": "# class Fox\n#   ...\n# end\n",
            "check": "f = Fox.new(\"Kaz\"); f.name == \"Kaz\" && f.shout == \"Chunky Bacon!\" && code.include?(\"class Fox\")",
            "hint": "猫の例をコピーして書き換えてみて。クラス名は<code>Fox</code>、<code>shout</code>はぴったり<code>\"Chunky Bacon!\"</code>を返すようにね。"
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
            "html": "<p><strong>Job 1 – Namensraum:</strong> Ein Modul gruppiert zusammengehörige Klassen unter einem Dach, damit sich Namen nicht in die Quere kommen. Genau darum heissen die Klassen, die dir in späteren Lektionen begegnen, <code>ChunkyPNG::Image</code> und <code>Sinatra::Base</code> – Klasse <code>Image</code> im Modul <code>ChunkyPNG</code>, Klasse <code>Base</code> im Modul <code>Sinatra</code>:</p>"
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
            "html": "<p><strong>Job 1 – namespace:</strong> A module groups related classes under one roof so names don't clash. That's exactly why the classes you'll meet in later lessons are called <code>ChunkyPNG::Image</code> and <code>Sinatra::Base</code> – class <code>Image</code> inside module <code>ChunkyPNG</code>, class <code>Base</code> inside module <code>Sinatra</code>:</p>"
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
      },
      "ja": {
        "title": "11. モジュール",
        "cells": [
          {
            "t": "h",
            "html": "<h2>モジュール：コードの道具箱</h2><p><strong>モジュール</strong>は、メソッドや定数を入れておく名前つきの箱です。クラスとちがって、モジュールからオブジェクトを作ることはできません（<code>new</code>がありません）。そのかわりモジュールには、別の2つの役割があります。<strong>整理整頓</strong>と<strong>能力の共有</strong>です。</p><p>じつは、もういくつか知っています。Rubyの標準ライブラリにある<code>Math</code>は、数学の道具を集めたモジュールです。定数には<code>::</code>でアクセスし、メソッドはドットで呼び出します：</p>"
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
            "html": "<p><strong>役割1は名前空間です。</strong>モジュールは、関係のあるクラスをひとつ屋根の下にまとめて、名前がぶつからないようにします。ほかのレッスンに出てくるクラスが<code>ChunkyPNG::Image</code>や<code>Sinatra::Base</code>という名前なのは、まさにこのためです。モジュール<code>ChunkyPNG</code>の中にクラス<code>Image</code>が、モジュール<code>Sinatra</code>の中にクラス<code>Base</code>がある、というわけです：</p>"
          },
          {
            "t": "c",
            "code": "module Forest\n  class Fox\n    def shout\n      \"Chunky Bacon!\"\n    end\n  end\nend\n\nForest::Fox.new.shout"
          },
          {
            "t": "h",
            "html": "<p><strong>役割2はMix-inです。</strong><code>include</code>を使うと、モジュールのメソッドをクラスに混ぜ込めます。こうすれば、たがいに継承しあわなくても、たくさんのクラスで同じ能力を共有できます（ちなみに<code>include</code>も、かっこを省いたただのメソッド呼び出しです）：</p>"
          },
          {
            "t": "c",
            "code": "module Greeting\n  def hello\n    \"Hello, I am #{name}!\"\n  end\nend\n\nclass Hedgehog\n  include Greeting\n\n  attr_reader :name\n\n  def initialize(name)\n    @name = name\n  end\nend\n\nHedgehog.new(\"Izzy\").hello"
          },
          {
            "t": "h",
            "html": "<p>Rubyでいちばん有名なMix-inも、同じしくみで動いています。<code>Comparable</code>は、<code>&lt;=&gt;</code>が使えるクラスに<code>&lt;</code>、<code>&gt;</code>、<code>between?</code>を与えます。<code>Enumerable</code>は、<code>each</code>が使えるクラスに<code>map</code>や<code>select</code>などを与えます。</p><div class='task'><strong>課題：</strong><code>CHUNKY BACON!</code>を返すメソッド<code>shout</code>を持つモジュール<code>Loud</code>を書きましょう。それを<code>include</code>で新しいクラス<code>Badger</code>に混ぜ込み、最後の行で<code>Badger.new.shout</code>を試してください。</div>"
          },
          {
            "t": "x",
            "code": "# module Loud\n#   ...\n# end\n\n# class Badger\n#   ...\n# end\n",
            "check": "Loud.is_a?(Module) && !Loud.is_a?(Class) && Badger.include?(Loud) && Badger.new.shout == \"CHUNKY BACON!\" && code.include?(\"include\")",
            "hint": "<code>module Loud</code>の中に<code>def shout</code>を書いて、<code>\"CHUNKY BACON!\"</code>を返すようにしよう。それから<code>class Badger</code>を作って、その中に<code>include Loud</code>と書くんだよ。"
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
      },
      "ja": {
        "title": "12. IRB：Rubyの遊び場",
        "cells": [
          {
            "t": "h",
            "html": "<h2>IRB：Rubyの遊び場</h2><p>Rubyが入っているコンピューターには、<strong>IRB</strong>（「Interactive RuBy」）が最初からついてきます。ターミナルで<code>irb</code>と入力すると起動し、あとはRubyに1行ずつ入力していくだけです。このノートブックと同じように、IRBも各行の値を<code>=&gt;</code>のあとに表示します：</p><pre><code>$ irb\nirb(main):001:0&gt; 1 + 1\n=&gt; 2\nirb(main):002:0&gt; \"Chunky \" + \"Bacon!\"\n=&gt; \"Chunky Bacon!\"</code></pre><p>RubyistはいつもIRBを開きっぱなしにしていて、ちょっとした実験や計算、メソッドが何を返すかの確認に使います。ここに<strong>本物のIRBセッション</strong>を用意しました。下のターミナルに入力して、<kbd>Enter</kbd>を押してみましょう：</p>"
          },
          {
            "t": "c",
            "code": "show_irb"
          },
          {
            "t": "h",
            "html": "<p>IRBの達人ならだれでも知っている3つの技です。上で試してみましょう：</p><ul><li><code>_</code>（アンダースコア）には、いつも<strong>直前の答え</strong>が入っています。まず<code>6 * 7</code>、次に<code>_ + 1</code>と入力してみてください。</li><li>IRBは<strong>複数行の入力</strong>も理解します。<code>def double(x)</code>と入力すると、プロンプトに<code>*</code>がついて、<code>x * 2</code>と<code>end</code>が入力されるまで待ってくれます。</li><li><code>exit</code>でIRBを終了します（自分のコンピューターでは、の話です……ここではキツネが帰ろうとしません）。</li></ul><div class='task'><strong>課題：</strong>下のセルをIRBの1行のように使ってみましょう。<code>map</code>を使って、配列<code>[4, 8, 15]</code>のすべての数を3倍にしてください。値が<code>[12, 24, 45]</code>になれば正解です。（まずは上のターミナルで試してみましょう！）</div>"
          },
          {
            "t": "x",
            "code": "# [4, 8, 15].map { |x| ... }\n",
            "check": "result == [12, 24, 45] && code.include?(\"map\")",
            "hint": "最後の行に<code>[4, 8, 15].map { |x| x * 3 }</code>って書いてみて。<code>map</code>は、それぞれの要素から新しい配列を作ってくれるよ。"
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
            "code": "install_gem \"chunky_bacon\"\nrequire \"chunky_bacon\"\n\nChunkyBacon.shout"
          },
          {
            "t": "h",
            "html": "<p>Das war <code>chunky_bacon</code> – die Gem dieses Kurses, zu finden auf <a href='https://rubygems.org/gems/chunky_bacon' target='_blank'>rubygems.org</a>. Auf deinem eigenen Computer bringt <code>gem install chunky_bacon</code> deinen Programmen die Helfer dieser Seite mit – <code>show_image</code>, <code>show_browser</code> und Co. –, und <code>chunkybacon run main.rb</code> startet ein Programm aus der Werkstatt genau wie hier.</p><p>Jetzt eine Gem, die richtig arbeitet: <code>chunky_png</code> – der Name ist natürlich kein Zufall, liebe Füchse! 🥓 – erstellt PNG-Bilder in purem Ruby. Installieren, mit <code>require</code> laden – und mit <code>show_image</code> zeigst du ein Bild direkt unter der Zelle an:</p>"
          },
          {
            "t": "c",
            "code": "install_gem \"chunky_png\"\nrequire \"chunky_png\"\n\nbild = ChunkyPNG::Image.new(8, 8, ChunkyPNG::Color::WHITE)\n8.times { |i| bild[i, i] = ChunkyPNG::Color.rgb(232, 114, 42) }\nshow_image bild"
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
            "code": "install_gem \"chunky_bacon\"\nrequire \"chunky_bacon\"\n\nChunkyBacon.shout"
          },
          {
            "t": "h",
            "html": "<p>That was <code>chunky_bacon</code> – this course's own gem, on <a href='https://rubygems.org/gems/chunky_bacon' target='_blank'>rubygems.org</a>. On your own computer, <code>gem install chunky_bacon</code> gives your programs this page's helpers – <code>show_image</code>, <code>show_browser</code> and friends – and <code>chunkybacon run main.rb</code> runs a program from the workshop just like here.</p><p>Now a gem that does real work: <code>chunky_png</code> – the name is no coincidence, dear foxes! 🥓 – creates PNG images in pure Ruby. Install it, load it with <code>require</code> – and <code>show_image</code> displays a picture right below the cell:</p>"
          },
          {
            "t": "c",
            "code": "install_gem \"chunky_png\"\nrequire \"chunky_png\"\n\nimage = ChunkyPNG::Image.new(8, 8, ChunkyPNG::Color::WHITE)\n8.times { |i| image[i, i] = ChunkyPNG::Color.rgb(232, 114, 42) }\nshow_image image"
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
      },
      "ja": {
        "title": "13. gemのインストール",
        "cells": [
          {
            "t": "h",
            "html": "<h2>gem：Rubyの部品</h2><p><strong>gem</strong>は、プログラムに読み込んで使える、できあいのRubyパッケージです。gemが集まる中心地が<a href='https://rubygems.org' target='_blank'>rubygems.org</a>で、思いつくかぎりのあらゆる用途に180,000を超えるgemがそろっています。</p><p>自分のコンピューターでは、ターミナルで<code>gem install</code>を実行してgemをインストールし、IRBやプログラムの中で<code>require</code>して読み込みます：</p><pre><code>$ gem install chunky_png\nSuccessfully installed chunky_png-1.4.0\n$ irb\nirb(main):001:0&gt; require \"chunky_png\"\n=&gt; true</code></pre><p>本格的なプロジェクトでは、使うgemをすべて<code>Gemfile</code>というファイルに書き（1つのgemにつき1行：<code>gem \"chunky_png\"</code>）、<code>bundle install</code>でまとめて取ってきます。これは<a href='https://bundler.io' target='_blank'>Bundler</a>の仕事です。</p><p>このサイトでは、<em>ピュアRuby</em>のgemに限り、<code>install_gem</code>がその仕事をブラウザの中で直接引き受けます（左の💎パネルを使ってもかまいません）。よく使われるgemはローカルにキャッシュされていて（⚡）、一瞬でインストールできます：</p>"
          },
          {
            "t": "c",
            "code": "install_gem \"chunky_bacon\"\nrequire \"chunky_bacon\"\n\nChunkyBacon.shout"
          },
          {
            "t": "h",
            "html": "<p>いまのが<code>chunky_bacon</code>、このコース自身のgemです（<a href='https://rubygems.org/gems/chunky_bacon' target='_blank'>rubygems.org</a>で公開しています）。自分のコンピューターで<code>gem install chunky_bacon</code>すると、このページのヘルパー（<code>show_image</code>や<code>show_browser</code>など）が自分のプログラムでも使えるようになり、<code>chunkybacon run main.rb</code>で工房のプログラムをここと同じように実行できます。</p><p>次は、本格的に働くgemです。<code>chunky_png</code>は、ピュアRubyでPNG画像を作るgemです（キツネのみなさん、この名前はもちろん偶然ではありませんよ！🥓）。インストールして<code>require</code>で読み込み、<code>show_image</code>を使うと、セルのすぐ下に画像を表示できます：</p>"
          },
          {
            "t": "c",
            "code": "install_gem \"chunky_png\"\nrequire \"chunky_png\"\n\nimage = ChunkyPNG::Image.new(8, 8, ChunkyPNG::Color::WHITE)\n8.times { |i| image[i, i] = ChunkyPNG::Color.rgb(232, 114, 42) }\nshow_image image"
          },
          {
            "t": "h",
            "html": "<p>ピクセルは1つずつ指定できます：<code>image[x, y] = color</code>。色は<code>ChunkyPNG::Color.rgb(red, green, blue)</code>で作ります。</p><div class='task'><strong>課題：</strong>ベーコンの旗を描きましょう！画像<code>image</code>（8×8以上）を作り、偶数行をベーコンの赤（<code>ChunkyPNG::Color.rgb(193, 74, 46)</code>）で塗って、奇数行は白のままにします。できあがったら<code>show_image image</code>で見せてください。</div>"
          },
          {
            "t": "x",
            "code": "install_gem \"chunky_png\"\nrequire \"chunky_png\"\n\n# image = ChunkyPNG::Image.new(8, 8, ChunkyPNG::Color::WHITE)\n# ...\n# show_image image\n",
            "check": "defined?(ChunkyPNG) && image.is_a?(ChunkyPNG::Image) && image.width >= 8 && image.pixels.include?(ChunkyPNG::Color.rgb(193, 74, 46)) && images.length >= 1",
            "hint": "たとえば<code>8.times do |y|</code>で1行ずつくり返して、<code>y.even?</code>のときだけ<code>8.times { |x| image[x, y] = ChunkyPNG::Color.rgb(193, 74, 46) }</code>で塗り、<code>end</code>で閉じる。最後に<code>show_image image</code>で表示しよう。"
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
            "html": "<h2>HTML parsen – wie die Profis</h2><p>Ruby wird oft benutzt, um Webseiten auszulesen (<em>Scraping</em>). Das berühmteste Werkzeug dafür heisst <strong>Nokogiri</strong> – fast jedes Ruby-Programm, das HTML oder XML liest, benutzt es:</p><pre><code>require \"nokogiri\"\ndoc = Nokogiri::HTML5(html)\ndoc.css(\"a\").each { |link| puts link.text }</code></pre><p>Auf deinem Rechner ist Nokogiri zu grossen Teilen <strong>C</strong>: Es bringt die C-Bibliotheken <em>libxml2</em> und <em>gumbo</em> mit. Hier im Browser läuft Ruby als WebAssembly, und dort lassen sich zur Laufzeit nur Gems in purem Ruby installieren. Darum bekommst du hier <strong>nokogiri-pure</strong>: dasselbe Nokogiri, nur sind seine C-Teile nach Ruby übersetzt. Es ist langsamer, liefert aber dieselben Ergebnisse – und Gems, die Nokogiri brauchen (<code>loofah</code>, <code>sanitize</code>, <code>premailer</code>, <code>rubyXL</code> …), laufen damit auch hier.</p>"
          },
          {
            "t": "c",
            "code": "install_gem \"nokogiri\""
          },
          {
            "t": "h",
            "html": "<p>Die Idee: erst <em>parsen</em> (aus Text wird ein Baum), dann mit <strong>CSS-Selektoren</strong> suchen. <code>Nokogiri::HTML5</code> liest HTML so, wie es ein moderner Browser tut:</p>"
          },
          {
            "t": "c",
            "code": "require \"nokogiri\"\n\nhtml = \"<html><body>\n  <h1>Speisekarte</h1>\n  <ul>\n    <li><a href='/speck'>Speck</a></li>\n    <li><a href='/ei'>Ei</a></li>\n    <li><a href='/kaffee'>Kaffee</a></li>\n  </ul>\n</body></html>\"\n\ndoc = Nokogiri::HTML5(html)\ndoc.css(\"li\").length"
          },
          {
            "t": "h",
            "html": "<p><code>doc.css(\"li\")</code> findet alle <code>&lt;li&gt;</code>-Elemente – wie in einem Stylesheet. Jeder Treffer ist ein Knoten: <code>text</code> liefert seinen Text, und ein Attribut liest du wie bei einem Hash, mit <code>link[\"href\"]</code>:</p>"
          },
          {
            "t": "c",
            "code": "doc.css(\"a\").map { |link| link.text }"
          },
          {
            "t": "h",
            "html": "<div class='task'><strong>Aufgabe:</strong> Sammle alle <strong>Link-Adressen</strong> aus dem Dokument: Baue mit <code>map</code> ein Array <code>links</code> aller <code>href</code>-Werte. An ein Attribut kommst du mit <code>link[\"href\"]</code>. Ergebnis: <code>[\"/speck\", \"/ei\", \"/kaffee\"]</code>. (Führe zuerst die Zellen oben aus, damit <code>doc</code> existiert.)</div>"
          },
          {
            "t": "x",
            "code": "# links = doc.css(\"a\").map { |link| ... }\n",
            "check": "links == [\"/speck\", \"/ei\", \"/kaffee\"]",
            "hint": "<code>links = doc.css(\"a\").map { |link| link[\"href\"] }</code> – und vorher die Demo-Zellen ausführen, damit <code>doc</code> existiert."
          }
        ]
      },
      "en": {
        "title": "14. Parsing HTML",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Parsing HTML – like the pros</h2><p>Ruby is often used to read websites (<em>scraping</em>). The most famous tool for that is <strong>Nokogiri</strong> – almost every Ruby program that reads HTML or XML uses it:</p><pre><code>require \"nokogiri\"\ndoc = Nokogiri::HTML5(html)\ndoc.css(\"a\").each { |link| puts link.text }</code></pre><p>On your machine Nokogiri is largely <strong>C</strong>: it ships the C libraries <em>libxml2</em> and <em>gumbo</em>. In this browser Ruby runs as WebAssembly, where only pure-Ruby gems can be installed at runtime. So here you get <strong>nokogiri-pure</strong>: the same Nokogiri with its C parts translated to Ruby. It is slower, but gives the same results – and gems that need Nokogiri (<code>loofah</code>, <code>sanitize</code>, <code>premailer</code>, <code>rubyXL</code> …) run here too.</p>"
          },
          {
            "t": "c",
            "code": "install_gem \"nokogiri\""
          },
          {
            "t": "h",
            "html": "<p>The idea: first <em>parse</em> (text becomes a tree), then search with <strong>CSS selectors</strong>. <code>Nokogiri::HTML5</code> reads HTML the way a modern browser does:</p>"
          },
          {
            "t": "c",
            "code": "require \"nokogiri\"\n\nhtml = \"<html><body>\n  <h1>Menu</h1>\n  <ul>\n    <li><a href='/bacon'>Bacon</a></li>\n    <li><a href='/egg'>Egg</a></li>\n    <li><a href='/coffee'>Coffee</a></li>\n  </ul>\n</body></html>\"\n\ndoc = Nokogiri::HTML5(html)\ndoc.css(\"li\").length"
          },
          {
            "t": "h",
            "html": "<p><code>doc.css(\"li\")</code> finds all <code>&lt;li&gt;</code> elements – just like in a stylesheet. Every match is a node: <code>text</code> gives its text, and you read an attribute like a hash, with <code>link[\"href\"]</code>:</p>"
          },
          {
            "t": "c",
            "code": "doc.css(\"a\").map { |link| link.text }"
          },
          {
            "t": "h",
            "html": "<div class='task'><strong>Task:</strong> Collect all <strong>link addresses</strong> from the document: use <code>map</code> to build an array <code>links</code> of all <code>href</code> values. You reach an attribute via <code>link[\"href\"]</code>. Expected result: <code>[\"/bacon\", \"/egg\", \"/coffee\"]</code>. (Run the cells above first so <code>doc</code> exists.)</div>"
          },
          {
            "t": "x",
            "code": "# links = doc.css(\"a\").map { |link| ... }\n",
            "check": "links == [\"/bacon\", \"/egg\", \"/coffee\"]",
            "hint": "<code>links = doc.css(\"a\").map { |link| link[\"href\"] }</code> – and run the demo cells first so <code>doc</code> exists."
          }
        ]
      },
      "ja": {
        "title": "14. HTMLのパース",
        "cells": [
          {
            "t": "h",
            "html": "<h2>プロと同じ道具でHTMLをパースする</h2><p>Rubyは、Webサイトから情報を読み取る用途（<em>スクレイピング</em>）によく使われます。そのための道具として最も有名なのが<strong>Nokogiri</strong>です。HTMLやXMLを読むRubyプログラムのほとんどが、これを使っています。</p><pre><code>require \"nokogiri\"\ndoc = Nokogiri::HTML5(html)\ndoc.css(\"a\").each { |link| puts link.text }</code></pre><p>自分のコンピューターにインストールするNokogiriは、大部分が<strong>C</strong>で書かれています。Cのライブラリである<em>libxml2</em>と<em>gumbo</em>を同梱しているのです。一方、このブラウザの中のRubyはWebAssemblyとして動いていて、実行中にインストールできるのはピュアRubyのgemだけです。そこでここでは<strong>nokogiri-pure</strong>を使います。Nokogiriそのままで、Cの部分だけをRubyに書き直したものです。速度は落ちますが結果は同じで、Nokogiriを必要とするgem（<code>loofah</code>、<code>sanitize</code>、<code>premailer</code>、<code>rubyXL</code>など）もここで動きます。</p>"
          },
          {
            "t": "c",
            "code": "install_gem \"nokogiri\""
          },
          {
            "t": "h",
            "html": "<p>考え方はシンプルです。まずテキストを<em>パース</em>して木構造にし、それから<strong>CSSセレクター</strong>で検索します。<code>Nokogiri::HTML5</code>は、最新のブラウザと同じやり方でHTMLを読み込みます。</p>"
          },
          {
            "t": "c",
            "code": "require \"nokogiri\"\n\nhtml = \"<html><body>\n  <h1>Menu</h1>\n  <ul>\n    <li><a href='/bacon'>Bacon</a></li>\n    <li><a href='/egg'>Egg</a></li>\n    <li><a href='/coffee'>Coffee</a></li>\n  </ul>\n</body></html>\"\n\ndoc = Nokogiri::HTML5(html)\ndoc.css(\"li\").length"
          },
          {
            "t": "h",
            "html": "<p><code>doc.css(\"li\")</code>は、すべての<code>&lt;li&gt;</code>要素を見つけます。スタイルシートとまったく同じ書き方です。見つかった要素はそれぞれノードで、<code>text</code>でそのテキストを取り出せます。属性はハッシュと同じように、<code>link[\"href\"]</code>で読み取ります。</p>"
          },
          {
            "t": "c",
            "code": "doc.css(\"a\").map { |link| link.text }"
          },
          {
            "t": "h",
            "html": "<div class='task'><strong>課題：</strong>ドキュメントから<strong>リンク先のアドレス</strong>をすべて集めましょう。<code>map</code>を使って、<code>href</code>の値をすべて集めた配列<code>links</code>を作ってください。属性は<code>link[\"href\"]</code>で取り出せます。結果は<code>[\"/bacon\", \"/egg\", \"/coffee\"]</code>になるはずです。（先に上のセルを実行して、<code>doc</code>を作っておいてください。）</div>"
          },
          {
            "t": "x",
            "code": "# links = doc.css(\"a\").map { |link| ... }\n",
            "check": "links == [\"/bacon\", \"/egg\", \"/coffee\"]",
            "hint": "こう書いてみて：<code>links = doc.css(\"a\").map { |link| link[\"href\"] }</code>。それと、<code>doc</code>ができるように、先に上のデモのセルを実行しておいてね。"
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
      },
      "ja": {
        "title": "15. SinatraでWebサーバー",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Webサイトを作る：リクエストとレスポンス</h2><p>これまでのコードは、上から下へ順番に実行されるだけでした。<strong>Webサーバー</strong>の動き方は違います。<code>GET /menu</code>のような<em>リクエスト</em>が来るのを待ち、<em>レスポンス</em>を返します。レスポンスの中身は、たいていHTMLです。どのパスにどのコードが応えるかは、<strong>ルート</strong>で決めます。</p><p><strong>Sinatra</strong>は2007年から使われ続けている、RubyのWebフレームワークの定番です。ルートといっても、ブロック付きのメソッド呼び出しにすぎません。セルを実行してみてください。下に小さなブラウザが現れます。</p>"
          },
          {
            "t": "c",
            "code": "install_gem \"sinatra\"\nrequire \"sinatra/base\"\n\nclass Diner < Sinatra::Base\n  get \"/\" do\n    \"<h1>Chunky's Diner</h1>\n     <p>Welcome! Today's special: bacon.</p>\n     <a href='/menu'>See the menu</a>\"\n  end\n\n  get \"/menu\" do\n    \"<h2>Menu</h2>\n     <ul><li>Bacon</li><li>Egg</li><li>Coffee</li></ul>\n     <a href='/'>Back</a>\"\n  end\n\n  get \"/hello/:name\" do\n    \"Hello, #{params[:name]}! Nice to see you.\"\n  end\nend\n\nshow_browser Diner, \"/\""
          },
          {
            "t": "h",
            "html": "<p>このミニブラウザは、あなたのアプリと直接やりとりします。リンクをクリックしたり、アドレスバーにパスを入力したりしてみましょう。<code>/hello/Kaz</code>や、あえて<code>/pizza</code>（404になります！）も試してみてください。</p><p>しくみはこうです。<code>get \"/path\" do … end</code>でルートを登録すると、<strong>ブロックの戻り値</strong>がレスポンスになります。<code>:name</code>のようにコロンで始まる部分はプレースホルダーで、実際の値は<code>params</code>に入ります。本物のサーバーなら、このアプリは<code>ruby app.rb</code>で起動して、ブラウザで<code>localhost:4567</code>を開きます。ここでは、ミニブラウザがアプリを直接呼び出しています（ミニブラウザもアプリも、RubyのWeb標準である<em>Rack</em>に従っているからです）。</p><div class='task'><strong>課題：</strong><code>CHUNKY BACON!</code>を返すルート<code>get \"/bacon\"</code>を追加しましょう。下のミニブラウザは<code>/bacon</code>を表示していますが、今はまだ404です。</div>"
          },
          {
            "t": "x",
            "code": "install_gem \"sinatra\"\nrequire \"sinatra/base\"\n\nclass MySite < Sinatra::Base\n  get \"/\" do\n    \"<h1>My Site</h1>\"\n  end\n\n  # get \"/bacon\" do\n  #   ...\n  # end\nend\n\nshow_browser MySite, \"/bacon\"",
            "check": "s1, _ = mock_get(MySite, \"/\"); s2, b2 = mock_get(MySite, \"/bacon\"); s1 == 200 && s2 == 200 && b2.include?(\"CHUNKY BACON!\")",
            "hint": "ほかのルートと同じだよ。<code>get \"/bacon\" do</code>と書いて、その下に<code>\"CHUNKY BACON!\"</code>、最後に<code>end</code>。書けたら、もう一度セルを実行してね。"
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
      },
      "ja": {
        "title": "16. Rodaとルーティングツリー",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Rodaとルーティングツリー</h2><p><strong>Roda</strong>（作者はSequelでも知られるJeremy Evans）は、モダンでとても高速なWebフレームワークです。Sinatraのようにルートを平らなリストに並べるのではなく、<strong>ツリー</strong>をたどっていきます。<code>route</code>ブロックがリクエスト<code>r</code>を受け取り、パスをどう扱うかを一段ずつ決めていくのです。</p>"
          },
          {
            "t": "c",
            "code": "install_gem \"roda\"\nrequire \"roda\"\n\nclass Shop < Roda\n  route do |r|\n    r.root do\n      \"<h1>Chunky's Shop</h1>\n       <a href='/bacon'>Bacon</a>\n       <a href='/greet/Chunky'>Greeting</a>\"\n    end\n\n    r.get \"bacon\" do\n      \"<p>Bacon: 3 strips for 2 francs.</p><a href='/'>Back</a>\"\n    end\n\n    r.get \"greet\", String do |name|\n      \"Hello, #{name}! <a href='/'>Back</a>\"\n    end\n  end\nend\n\nshow_browser Shop, \"/\""
          },
          {
            "t": "h",
            "html": "<p>ツリーは上から順に読みます。<code>r.root</code>は<code>/</code>を、<code>r.get \"bacon\"</code>は<code>GET /bacon</code>を受け止めます。おもしろくなるのは<code>r.get \"greet\", String</code>からです。これは<code>/greet/&lt;anything&gt;</code>にマッチし、パスのその部分がブロック引数<code>name</code>として渡されます。ミニブラウザで<code>/greet/Ada</code>を試してみてください！どれにもマッチしなければ、Rodaが自動で<strong>404</strong>を返します。</p><div class='task'><strong>課題：</strong>Kioskアプリにルート<code>r.get \"order\", Integer do |amount| … end</code>を追加して、たとえば<code>/order/5</code>が<code>5 strips of bacon, coming right up!</code>を返すようにしましょう（文字列の式展開を使います）。下のミニブラウザは、まだ404を表示しています。</div>"
          },
          {
            "t": "x",
            "code": "install_gem \"roda\"\nrequire \"roda\"\n\nclass Kiosk < Roda\n  route do |r|\n    r.root do\n      \"<h1>Kiosk</h1><a href='/order/5'>Order 5 strips</a>\"\n    end\n\n    # r.get \"order\", Integer do |amount|\n    #   ...\n    # end\n  end\nend\n\nshow_browser Kiosk, \"/order/5\"",
            "check": "s1, b1 = mock_get(Kiosk, \"/\"); s2, b2 = mock_get(Kiosk, \"/order/5\"); s3, _ = mock_get(Kiosk, \"/pizza\"); s1 == 200 && b1.include?(\"Kiosk\") && s2 == 200 && b2.include?(\"5\") && b2.include?(\"bacon\") && s3 == 404",
            "hint": "routeブロックの中に、こう書いてみて：<code>r.get \"order\", Integer do |amount|</code> … <code>\"#{amount} strips of bacon, coming right up!\"</code> … <code>end</code>"
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
      },
      "ja": {
        "title": "17. HTTPでWebからデータ取得",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Webからデータを取ってくる</h2><p>ここまではWebサイトを<em>作って</em>きました。今度は立場を入れ替えて、Webサイトを<em>取ってくる</em>側に回りましょう。そのために、Rubyの標準ライブラリには<code>net/http</code>が入っています。アドレスから<code>URI</code>オブジェクトを作り、リクエストを送ります。まずはRubyの公式サイトを取ってきましょう。</p>"
          },
          {
            "t": "c",
            "code": "require \"net/http\"\n\nresponse = Net::HTTP.get_response(URI(\"https://www.ruby-lang.org/en/\"))\nresponse.code"
          },
          {
            "t": "h",
            "html": "<p><code>get_response</code>はレスポンスオブジェクトを返します。<code>code</code>はステータスコードで、なぜか文字列で返ってきます（<code>net/http</code>の有名なちょっとしたクセです！）。<code>body</code>には、ページ全体がHTMLのテキストとして入っています。</p>"
          },
          {
            "t": "c",
            "code": "response.body[0, 160]"
          },
          {
            "t": "h",
            "html": "<p>最近のWebサービスは、たいていデータを<strong>JSON</strong>で返します。プログラムで扱うのにぴったりの形式です。rubygems.orgのAPIは、gemのレッスンですでに登場しましたね。<code>rack</code>がこれまでに何回ダウンロードされたか、聞いてみましょう。</p>"
          },
          {
            "t": "c",
            "code": "require \"json\"\n\ndata = JSON.parse(Net::HTTP.get(URI(\"https://rubygems.org/api/v1/gems/rack.json\")))\ndata[\"downloads\"]"
          },
          {
            "t": "h",
            "html": "<p>GitHubのAPIもJSONで答えてくれます。たとえば、Ruby本体のリポジトリについているスターの数を聞いてみましょう。</p>"
          },
          {
            "t": "c",
            "code": "repo = JSON.parse(Net::HTTP.get(URI(\"https://api.github.com/repos/ruby/ruby\")))\nrepo[\"stargazers_count\"]"
          },
          {
            "t": "h",
            "html": "<p><strong>正直なところ：</strong>ブラウザの中のRubyはサンドボックスに入っていて、好きなサーバーと自由に通信できるわけではありません。そこでこのサイトでは、小さな橋渡しの仕組みを用意しています。つながるのは<code>www.ruby-lang.org</code>、<code>rubygems.org</code>、<code>api.github.com</code>だけで、それ以外のアドレスでは<code>SocketError</code>が発生します。自分のコンピューターでは、<code>net/http</code>はどんなURLにも使えます。</p><div class='task'><strong>課題：</strong>rubygemsのAPIに、<code>sinatra</code>というgemについて聞いてみましょう。<code>https://rubygems.org/api/v1/gems/sinatra.json</code>をパースして変数<code>info</code>に入れ、セルの最後の行の値がダウンロード数（<code>info[\"downloads\"]</code>）になるようにしてください。</div>"
          },
          {
            "t": "x",
            "code": "require \"net/http\"\nrequire \"json\"\n\n# info = JSON.parse(Net::HTTP.get(URI(\"...\")))\n# info[\"downloads\"]\n",
            "check": "info.is_a?(Hash) && info[\"name\"] == \"sinatra\" && info[\"downloads\"].is_a?(Integer) && info[\"downloads\"] > 0 && result == info[\"downloads\"]",
            "hint": "<code>info = JSON.parse(Net::HTTP.get(URI(\"https://rubygems.org/api/v1/gems/sinatra.json\")))</code>と書いて、最後の行を<code>info[\"downloads\"]</code>にしてみて。"
          }
        ]
      }
    },
    {
      "id": "bigdecimal",
      "de": {
        "title": "18. Genau rechnen mit BigDecimal",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Wenn 0.1 + 0.2 nicht 0.3 ist</h2><p>Computer speichern Kommazahlen (<em>Floats</em>) binär – und im Binärsystem ist 0.1 ein unendlicher Bruch, so wie 1/3 im Dezimalsystem. Also wird gerundet, und manchmal sieht man das:</p>"
          },
          {
            "t": "c",
            "code": "0.1 + 0.2"
          },
          {
            "t": "h",
            "html": "<p>Bei Geld ist das nicht lustig: Wer Rappen falsch rundet, hat am Monatsende eine Abrechnung, die nicht aufgeht. Rubys Standardbibliothek bringt darum <strong>BigDecimal</strong> mit – Dezimalzahlen, die genau so rechnen, wie du es in der Schule gelernt hast. Du erzeugst sie aus <strong>Strings</strong>, damit die Zahl nie durch einen Float geht:</p>"
          },
          {
            "t": "c",
            "code": "require \"bigdecimal\"\n\nBigDecimal(\"0.1\") + BigDecimal(\"0.2\")"
          },
          {
            "t": "h",
            "html": "<p><code>0.3e0</code> ist die wissenschaftliche Schreibweise: 0.3 mal 10 hoch 0. Lesbarer wird es mit <code>to_s(\"F\")</code>. Und <code>bigdecimal/util</code> bringt <code>to_d</code> mit, das aus Strings und Zahlen BigDecimals macht:</p>"
          },
          {
            "t": "c",
            "code": "require \"bigdecimal/util\"\n\npreis = \"19.90\".to_d\nmenge = 3\n(preis * menge).to_s(\"F\")"
          },
          {
            "t": "h",
            "html": "<p>Runden kann BigDecimal auf beliebig viele Stellen – und nach klaren Regeln. Kaufmännisch heisst <code>:half_up</code> (2.5 wird 3), Banker runden mit <code>:half_even</code> zur geraden Zahl (2.5 wird 2), damit sich Rundungsfehler über viele Buchungen ausgleichen:</p>"
          },
          {
            "t": "c",
            "code": "drittel = BigDecimal(\"1\") / 3\n\n[drittel.round(2).to_s(\"F\"),\n BigDecimal(\"2.5\").round(0, :half_up).to_s(\"F\"),\n BigDecimal(\"2.5\").round(0, :half_even).to_s(\"F\")]"
          },
          {
            "t": "h",
            "html": "<div class='offweb'><strong>Auf deinem Rechner:</strong> BigDecimal ist eine C-Erweiterung, die bei Ruby dabei ist (seit Ruby 3.4 als eigene Gem – mit Bundler gehört <code>gem \"bigdecimal\"</code> ins Gemfile). Hier im Browser gibt es keine C-Erweiterungen; du rechnest gerade mit <a href='https://github.com/Largo/bigdecimal-pure'>bigdecimal-pure</a>, das dieselbe Klasse in reinem Ruby nachbaut – innen aus Brüchen (<code>Rational</code>). Gleiche API, gleiche Ergebnisse.</div><div class='task'><strong>Aufgabe:</strong> Die Frühstücksrechnung: 3 × Speck zu 4.20, 2 × Ei zu 1.15 und 1 × Kaffee zu 3.80. Rechne die Summe mit BigDecimal aus (nicht mit Floats!) und speichere sie in <code>total</code>. Die Zelle soll <code>total</code> ergeben – erwartet: <code>0.187e2</code>, also 18.70.</div>"
          },
          {
            "t": "x",
            "code": "require \"bigdecimal/util\"\n\n# total = \"4.20\".to_d * 3 + ...\n",
            "check": "total.is_a?(BigDecimal) && total == BigDecimal(\"18.7\")",
            "hint": "<code>total = \"4.20\".to_d * 3 + \"1.15\".to_d * 2 + \"3.80\".to_d</code> – Strings mit <code>to_d</code> in BigDecimals verwandeln, dann ganz normal rechnen."
          }
        ]
      },
      "en": {
        "title": "18. Exact arithmetic with BigDecimal",
        "cells": [
          {
            "t": "h",
            "html": "<h2>When 0.1 + 0.2 is not 0.3</h2><p>Computers store decimal numbers (<em>floats</em>) in binary – and in binary 0.1 is a repeating fraction, like 1/3 in decimal. So it gets rounded, and sometimes that shows:</p>"
          },
          {
            "t": "c",
            "code": "0.1 + 0.2"
          },
          {
            "t": "h",
            "html": "<p>With money that is no joke: round cents wrongly and the books will not balance at the end of the month. That is why Ruby's standard library ships <strong>BigDecimal</strong> – decimal numbers that calculate exactly the way you learned at school. You create them from <strong>strings</strong>, so the number never passes through a float:</p>"
          },
          {
            "t": "c",
            "code": "require \"bigdecimal\"\n\nBigDecimal(\"0.1\") + BigDecimal(\"0.2\")"
          },
          {
            "t": "h",
            "html": "<p><code>0.3e0</code> is scientific notation: 0.3 times 10 to the power of 0. <code>to_s(\"F\")</code> makes it readable. And <code>bigdecimal/util</code> adds <code>to_d</code>, which turns strings and numbers into BigDecimals:</p>"
          },
          {
            "t": "c",
            "code": "require \"bigdecimal/util\"\n\nprice = \"19.90\".to_d\nquantity = 3\n(price * quantity).to_s(\"F\")"
          },
          {
            "t": "h",
            "html": "<p>BigDecimal rounds to any number of digits – by clear rules. Commercial rounding is <code>:half_up</code> (2.5 becomes 3); bankers round to the even number with <code>:half_even</code> (2.5 becomes 2), so rounding errors cancel out over many transactions:</p>"
          },
          {
            "t": "c",
            "code": "third = BigDecimal(\"1\") / 3\n\n[third.round(2).to_s(\"F\"),\n BigDecimal(\"2.5\").round(0, :half_up).to_s(\"F\"),\n BigDecimal(\"2.5\").round(0, :half_even).to_s(\"F\")]"
          },
          {
            "t": "h",
            "html": "<div class='offweb'><strong>On your machine:</strong> BigDecimal is a C extension that comes with Ruby (since Ruby 3.4 as a gem of its own – with Bundler, <code>gem \"bigdecimal\"</code> belongs in the Gemfile). The browser has no C extensions; you are calculating with <a href='https://github.com/Largo/bigdecimal-pure'>bigdecimal-pure</a>, which rebuilds the same class in pure Ruby – out of fractions (<code>Rational</code>) inside. Same API, same results.</div><div class='task'><strong>Task:</strong> The breakfast bill: 3 × bacon at 4.20, 2 × egg at 1.15 and 1 × coffee at 3.80. Add it up with BigDecimal (not with floats!) and store the sum in <code>total</code>. The cell should evaluate to <code>total</code> – expected: <code>0.187e2</code>, that is 18.70.</div>"
          },
          {
            "t": "x",
            "code": "require \"bigdecimal/util\"\n\n# total = \"4.20\".to_d * 3 + ...\n",
            "check": "total.is_a?(BigDecimal) && total == BigDecimal(\"18.7\")",
            "hint": "<code>total = \"4.20\".to_d * 3 + \"1.15\".to_d * 2 + \"3.80\".to_d</code> – turn the strings into BigDecimals with <code>to_d</code>, then calculate as usual."
          }
        ]
      },
      "ja": {
        "title": "18. BigDecimalで正確な計算",
        "cells": [
          {
            "t": "h",
            "html": "<h2>0.1 + 0.2が0.3にならないとき</h2><p>コンピューターは小数（<em>浮動小数点数</em>）を2進数で保存します。ところが2進数では、0.1は10進数の1/3と同じように、どこまでも続く循環小数になります。そのため丸めが起こり、それが表に出てしまうことがあります。</p>"
          },
          {
            "t": "c",
            "code": "0.1 + 0.2"
          },
          {
            "t": "h",
            "html": "<p>お金の計算では、これは笑いごとではありません。たとえば消費税や為替の計算で1円未満の端数を間違って丸めると、月末に帳簿の数字が合わなくなってしまいます。そこでRubyの標準ライブラリには<strong>BigDecimal</strong>が用意されています。学校で習ったとおりに正確に計算できる、10進数の小数です。BigDecimalは<strong>文字列</strong>から作ります。こうすれば、数値が一度も浮動小数点数を経由しません。</p>"
          },
          {
            "t": "c",
            "code": "require \"bigdecimal\"\n\nBigDecimal(\"0.1\") + BigDecimal(\"0.2\")"
          },
          {
            "t": "h",
            "html": "<p><code>0.3e0</code>は指数表記で、「0.3×10の0乗」という意味です。<code>to_s(\"F\")</code>を使うと読みやすい形になります。また、<code>bigdecimal/util</code>を読み込むと<code>to_d</code>が使えるようになり、文字列や数値をBigDecimalに変換できます。</p>"
          },
          {
            "t": "c",
            "code": "require \"bigdecimal/util\"\n\nprice = \"19.90\".to_d\nquantity = 3\n(price * quantity).to_s(\"F\")"
          },
          {
            "t": "h",
            "html": "<p>BigDecimalなら、好きな桁数に、はっきりしたルールで丸めることができます。おなじみの四捨五入は<code>:half_up</code>です（2.5は3になります）。一方、銀行などで使われる偶数丸め（銀行丸め）は<code>:half_even</code>で、ちょうど真ん中の値をいちばん近い偶数に丸めます（2.5は2になります）。こうすると、たくさんの取引を重ねても丸め誤差が打ち消し合います。</p>"
          },
          {
            "t": "c",
            "code": "third = BigDecimal(\"1\") / 3\n\n[third.round(2).to_s(\"F\"),\n BigDecimal(\"2.5\").round(0, :half_up).to_s(\"F\"),\n BigDecimal(\"2.5\").round(0, :half_even).to_s(\"F\")]"
          },
          {
            "t": "h",
            "html": "<div class='offweb'><strong>自分のコンピューターでは：</strong>BigDecimalはRubyに付属しているC拡張です（Ruby 3.4からは独立したgemになったので、Bundlerを使う場合は<code>gem \"bigdecimal\"</code>をGemfileに書きます）。ブラウザではC拡張が使えないため、ここでは<a href='https://github.com/Largo/bigdecimal-pure'>bigdecimal-pure</a>で計算しています。同じクラスをピュアRubyで作り直したもので、内部では分数（<code>Rational</code>）を使っています。APIも結果も同じです。</div><div class='task'><strong>課題：</strong>海外のカフェで朝ごはんのお会計です（単位はドル）。ベーコン4.20 × 3、卵1.15 × 2、コーヒー3.80 × 1。浮動小数点数ではなくBigDecimalで合計を計算して（ここが大事！）、<code>total</code>に入れてください。セルの最後の行の値は<code>total</code>にします。期待される値は<code>0.187e2</code>、つまり18.70です。</div>"
          },
          {
            "t": "x",
            "code": "require \"bigdecimal/util\"\n\n# total = \"4.20\".to_d * 3 + ...\n",
            "check": "total.is_a?(BigDecimal) && total == BigDecimal(\"18.7\")",
            "hint": "たとえばこう：<code>total = \"4.20\".to_d * 3 + \"1.15\".to_d * 2 + \"3.80\".to_d</code>。文字列を<code>to_d</code>でBigDecimalに変えたら、あとはいつもどおり計算するだけだよ。"
          }
        ]
      }
    },
    {
      "id": "three",
      "section": {
        "de": "Ausflüge",
        "en": "Side trips",
        "ja": "寄り道"
      },
      "de": {
        "title": "19. 3D mit three-rb",
        "cells": [
          {
            "t": "h",
            "html": "<h2>3D im Browser – mit Ruby</h2><p>Die bekannteste 3D-Bibliothek des Webs heisst <strong>three.js</strong> und ist in JavaScript geschrieben. Die Gem <a href='https://github.com/lef237/three-rb' target='_blank'><code>three-rb</code></a> gibt dir dieselben Bausteine in <strong>Ruby</strong>: Szene, Kamera, Formen und Materialien baust du in purem Ruby – das eigentliche Zeichnen auf der Grafikkarte übernimmt three.js.</p><p>Dafür ist diese Seite wie gemacht: Ruby läuft hier als WebAssembly, three.js liegt gleich daneben, und die beiden reden über die JavaScript-Brücke miteinander.</p><p>Eine kleine Stolperfalle gleich vorweg: die Gem <em>heisst</em> <code>three-rb</code>, geladen wird sie aber als <code>three</code>. Das kommt öfter vor – der Gem-Name und der <code>require</code>-Name sind zwei verschiedene Dinge.</p>"
          },
          {
            "t": "c",
            "code": "install_gem \"three-rb\"\nrequire \"three\"\n\nszene = Three::Scene.new\nkamera = Three::PerspectiveCamera.new(70, aspect: 460.0 / 320, near: 0.1, far: 100)\nkamera.position.z = 3\n\nwuerfel = Three::Mesh.new(\n  Three::BoxGeometry.new(1, 1, 1),\n  Three::MeshBasicMaterial.new(color: 0xe8722a)\n)\nszene.add(wuerfel)\n\nshow_three szene, kamera"
          },
          {
            "t": "h",
            "html": "<p>Drei Dinge braucht jedes 3D-Bild:</p><ul><li><strong>Szene</strong> (<code>Three::Scene</code>) – die Bühne, auf der alles steht.</li><li><strong>Kamera</strong> (<code>Three::PerspectiveCamera</code>) – der Blickwinkel. <code>70</code> ist das Sichtfeld in Grad, <code>aspect</code> das Seitenverhältnis, <code>near</code> und <code>far</code> begrenzen die sichtbare Tiefe.</li><li><strong>Mesh</strong> (<code>Three::Mesh</code>) – ein Ding zum Anschauen, immer aus zwei Teilen: einer <em>Geometrie</em> (die Form) und einem <em>Material</em> (die Oberfläche).</li></ul><p>Bis dahin ist alles ganz normales Ruby: Objekte, die in einem Baum hängen. Gezeichnet wird nichts. Erst <code>show_three szene, kamera</code> baut unten eine Bühne und lässt three.js ein Bild davon machen.</p><p>Jedes Objekt hat <code>position</code>, <code>rotation</code> und <code>scale</code> – jeweils mit <code>x</code>, <code>y</code> und <code>z</code>. Dreh den Würfel ein wenig; die Zellen teilen sich ja ein Gedächtnis, <code>wuerfel</code> gibt es also noch:</p>"
          },
          {
            "t": "c",
            "code": "wuerfel.rotation.x = 0.5\nwuerfel.rotation.y = 0.8\nwuerfel.scale.set(1.4, 1.4, 1.4)\n\nshow_three szene, kamera"
          },
          {
            "t": "h",
            "html": "<p>Jetzt sieht man immerhin Kanten – vorher war der Würfel ein oranges Quadrat. Schuld ist das Material: <code>MeshBasicMaterial</code> ist eine flache Farbe, der das Licht völlig egal ist.</p><p>Räumlich wird es mit <code>MeshStandardMaterial</code>. Das <em>braucht</em> Licht – ohne bleibt es schwarz. Also eine zweite Szene, diesmal beleuchtet: ein <code>AmbientLight</code> (überall gleich hell, damit nichts ganz im Dunkeln liegt) und ein <code>DirectionalLight</code> (wie die Sonne: aus einer Richtung).</p>"
          },
          {
            "t": "c",
            "code": "szene2 = Three::Scene.new\nszene2.add(Three::AmbientLight.new(0xffffff, 0.35))\n\nlicht = Three::DirectionalLight.new(0xffffff, 2.5)\nlicht.position.set(2, 3, 4)\nszene2.add(licht)\n\nkugel = Three::Mesh.new(\n  Three::SphereGeometry.new(1, width_segments: 48, height_segments: 24),\n  Three::MeshStandardMaterial.new(color: 0xc14a2e, roughness: 0.35, metalness: 0.1)\n)\nszene2.add(kugel)\n\nshow_three szene2, kamera"
          },
          {
            "t": "h",
            "html": "<p>Ein Standbild ist schön, Bewegung ist schöner. Gib <code>show_three</code> einen <strong>Block</strong> mit: er läuft vor jedem Einzelbild – rund 60-mal pro Sekunde – und bekommt die Bildnummer. Mit <code>orbit: true</code> darfst du die Szene ausserdem mit der Maus drehen und mit dem Mausrad zoomen.</p>"
          },
          {
            "t": "c",
            "code": "show_three szene2, kamera, orbit: true do |bild|\n  kugel.position.y = Math.sin(bild * 0.05) * 0.5\n  kugel.rotation.y += 0.01\nend"
          },
          {
            "t": "h",
            "html": "<p>Auf deinem eigenen Rechner ist der Aufbau derselbe, nur hängst du den Renderer selbst an ein <code>&lt;canvas&gt;</code>:</p><pre><code>renderer = Three::Renderers::ThreeJSRenderer.new(canvas: \"#scene\")\nrenderer.set_size(640, 480)\nrenderer.render(szene, kamera)</code></pre><p>Genau das nimmt dir <code>show_three</code> hier ab.</p><div class='task'><strong>Aufgabe:</strong> Bau einen Turm! Lege eine Szene <code>turm</code> an, gib ihr Licht, und stapel <strong>mindestens drei</strong> Würfel übereinander – über <code>position.y</code> auf verschiedene Höhen. Zeig ihn mit <code>show_three turm, kamera</code> und lass ihn sich im Block langsam drehen.</div>"
          },
          {
            "t": "x",
            "code": "# turm = Three::Scene.new\n# turm.add(Three::AmbientLight.new(0xffffff, 0.4))\n# ...\n# show_three turm, kamera do\n#   turm.rotation.y += 0.01\n# end\n",
            "check": "defined?(Three) && turm.is_a?(Three::Scene) && turm.children.count { |k| k.is_a?(Three::Mesh) } >= 3 && scenes.any? { |s| s.equal?(turm) }",
            "hint": "Drei Würfel auf einmal: <code>3.times do |i|</code> … ein <code>Three::Mesh</code> bauen, <code>klotz.position.y = i - 1.0</code> setzen und mit <code>turm.add(klotz)</code> in die Szene hängen … <code>end</code>. Und nicht vergessen, zuerst die Zellen oben auszuführen, damit <code>kamera</code> existiert."
          }
        ]
      },
      "en": {
        "title": "19. 3D with three-rb",
        "cells": [
          {
            "t": "h",
            "html": "<h2>3D in the browser – with Ruby</h2><p>The best known 3D library of the web is called <strong>three.js</strong> and is written in JavaScript. The gem <a href='https://github.com/lef237/three-rb' target='_blank'><code>three-rb</code></a> gives you the same building blocks in <strong>Ruby</strong>: you build scene, camera, shapes and materials in pure Ruby – the actual drawing on the graphics card is done by three.js.</p><p>This page is made for exactly that: Ruby runs here as WebAssembly, three.js sits right next to it, and the two talk over the JavaScript bridge.</p><p>One little trap up front: the gem is <em>called</em> <code>three-rb</code>, but you load it as <code>three</code>. That happens quite often – the gem name and the <code>require</code> name are two different things.</p>"
          },
          {
            "t": "c",
            "code": "install_gem \"three-rb\"\nrequire \"three\"\n\nscene = Three::Scene.new\ncamera = Three::PerspectiveCamera.new(70, aspect: 460.0 / 320, near: 0.1, far: 100)\ncamera.position.z = 3\n\ncube = Three::Mesh.new(\n  Three::BoxGeometry.new(1, 1, 1),\n  Three::MeshBasicMaterial.new(color: 0xe8722a)\n)\nscene.add(cube)\n\nshow_three scene, camera"
          },
          {
            "t": "h",
            "html": "<p>Every 3D picture needs three things:</p><ul><li>a <strong>scene</strong> (<code>Three::Scene</code>) – the stage everything stands on;</li><li>a <strong>camera</strong> (<code>Three::PerspectiveCamera</code>) – the point of view. <code>70</code> is the field of view in degrees, <code>aspect</code> the aspect ratio, <code>near</code> and <code>far</code> limit the visible depth;</li><li>a <strong>mesh</strong> (<code>Three::Mesh</code>) – a thing to look at, always made of two parts: a <em>geometry</em> (the shape) and a <em>material</em> (the surface).</li></ul><p>Up to that point it is all ordinary Ruby: objects hanging in a tree. Nothing is drawn. Only <code>show_three scene, camera</code> builds a stage below and lets three.js make a picture of it.</p><p>Every object has <code>position</code>, <code>rotation</code> and <code>scale</code> – each with <code>x</code>, <code>y</code> and <code>z</code>. Turn the cube a little; the cells share one memory, so <code>cube</code> is still around:</p>"
          },
          {
            "t": "c",
            "code": "cube.rotation.x = 0.5\ncube.rotation.y = 0.8\ncube.scale.set(1.4, 1.4, 1.4)\n\nshow_three scene, camera"
          },
          {
            "t": "h",
            "html": "<p>At least you can see edges now – before, the cube was an orange square. The material is to blame: <code>MeshBasicMaterial</code> is a flat color that does not care about light at all.</p><p>It gets three-dimensional with <code>MeshStandardMaterial</code>. That one <em>needs</em> light – without it, it stays black. So here is a second scene, this time lit: an <code>AmbientLight</code> (equally bright everywhere, so nothing is pitch dark) and a <code>DirectionalLight</code> (like the sun: coming from one direction).</p>"
          },
          {
            "t": "c",
            "code": "scene2 = Three::Scene.new\nscene2.add(Three::AmbientLight.new(0xffffff, 0.35))\n\nsun = Three::DirectionalLight.new(0xffffff, 2.5)\nsun.position.set(2, 3, 4)\nscene2.add(sun)\n\nball = Three::Mesh.new(\n  Three::SphereGeometry.new(1, width_segments: 48, height_segments: 24),\n  Three::MeshStandardMaterial.new(color: 0xc14a2e, roughness: 0.35, metalness: 0.1)\n)\nscene2.add(ball)\n\nshow_three scene2, camera"
          },
          {
            "t": "h",
            "html": "<p>A still picture is nice, movement is nicer. Hand <code>show_three</code> a <strong>block</strong>: it runs before every frame – about 60 times per second – and receives the frame number. With <code>orbit: true</code> you can also turn the scene with the mouse and zoom with the wheel.</p>"
          },
          {
            "t": "c",
            "code": "show_three scene2, camera, orbit: true do |frame|\n  ball.position.y = Math.sin(frame * 0.05) * 0.5\n  ball.rotation.y += 0.01\nend"
          },
          {
            "t": "h",
            "html": "<p>On your own machine the setup is the same, except that you attach the renderer to a <code>&lt;canvas&gt;</code> yourself:</p><pre><code>renderer = Three::Renderers::ThreeJSRenderer.new(canvas: \"#scene\")\nrenderer.set_size(640, 480)\nrenderer.render(scene, camera)</code></pre><p>That is exactly what <code>show_three</code> does for you here.</p><div class='task'><strong>Task:</strong> Build a tower! Create a scene <code>tower</code>, give it light, and stack <strong>at least three</strong> cubes on top of each other – at different heights via <code>position.y</code>. Show it with <code>show_three tower, camera</code> and let it turn slowly in the block.</div>"
          },
          {
            "t": "x",
            "code": "# tower = Three::Scene.new\n# tower.add(Three::AmbientLight.new(0xffffff, 0.4))\n# ...\n# show_three tower, camera do\n#   tower.rotation.y += 0.01\n# end\n",
            "check": "defined?(Three) && tower.is_a?(Three::Scene) && tower.children.count { |k| k.is_a?(Three::Mesh) } >= 3 && scenes.any? { |s| s.equal?(tower) }",
            "hint": "Three cubes at once: <code>3.times do |i|</code> … build a <code>Three::Mesh</code>, set <code>block.position.y = i - 1.0</code> and hang it in the scene with <code>tower.add(block)</code> … <code>end</code>. And remember to run the cells above first, so that <code>camera</code> exists."
          }
        ]
      },
      "ja": {
        "title": "19. three-rbで3D",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Rubyで、ブラウザに3Dを</h2><p>Webでいちばん有名な3Dライブラリは<strong>three.js</strong>といって、JavaScriptで書かれています。<a href='https://github.com/lef237/three-rb' target='_blank'><code>three-rb</code></a>というgemを使うと、それと同じ部品を<strong>Ruby</strong>で使えます。シーン、カメラ、形状、マテリアルはすべてRubyだけで組み立て、グラフィックカードへの実際の描画はthree.jsが引き受けます。</p><p>このページは、まさにそれにうってつけです。ここではRubyがWebAssemblyとして動いていて、すぐ隣にはthree.jsがあり、両者はJavaScriptブリッジを通してやりとりします。</p><p>最初に、ちょっとした落とし穴をひとつ。このgemの<em>名前</em>は<code>three-rb</code>ですが、読み込むときは<code>three</code>と書きます。これはよくあることで、gemの名前と<code>require</code>で指定する名前は、別々のものなのです。</p>"
          },
          {
            "t": "c",
            "code": "install_gem \"three-rb\"\nrequire \"three\"\n\nscene = Three::Scene.new\ncamera = Three::PerspectiveCamera.new(70, aspect: 460.0 / 320, near: 0.1, far: 100)\ncamera.position.z = 3\n\ncube = Three::Mesh.new(\n  Three::BoxGeometry.new(1, 1, 1),\n  Three::MeshBasicMaterial.new(color: 0xe8722a)\n)\nscene.add(cube)\n\nshow_three scene, camera"
          },
          {
            "t": "h",
            "html": "<p>3Dの絵を描くには、いつも次の3つが必要です。</p><ul><li><strong>シーン</strong>（<code>Three::Scene</code>）：すべてが載る舞台。</li><li><strong>カメラ</strong>（<code>Three::PerspectiveCamera</code>）：視点。<code>70</code>は視野角（度）、<code>aspect</code>は縦横比で、<code>near</code>と<code>far</code>は見える奥行きの範囲を決めます。</li><li><strong>メッシュ</strong>（<code>Three::Mesh</code>）：目に見える物体。必ず<em>ジオメトリ</em>（形）と<em>マテリアル</em>（表面）の2つからできています。</li></ul><p>ここまでは、ごくふつうのRubyです。オブジェクトが木構造にぶら下がっているだけで、まだ何も描かれていません。<code>show_three scene, camera</code>を呼んで初めて、下に舞台が用意され、three.jsがその様子を絵にします。</p><p>どのオブジェクトにも<code>position</code>、<code>rotation</code>、<code>scale</code>があり、それぞれに<code>x</code>、<code>y</code>、<code>z</code>があります。立方体を少し回してみましょう。セルどうしは同じメモリを共有しているので、<code>cube</code>はまだ残っています。</p>"
          },
          {
            "t": "c",
            "code": "cube.rotation.x = 0.5\ncube.rotation.y = 0.8\ncube.scale.set(1.4, 1.4, 1.4)\n\nshow_three scene, camera"
          },
          {
            "t": "h",
            "html": "<p>これでようやく辺が見えるようになりました。さっきまでの立方体は、ただのオレンジ色の四角形でしたね。原因はマテリアルです。<code>MeshBasicMaterial</code>は光のことをまったく気にしない、のっぺりした単色なのです。</p><p>立体感を出すには<code>MeshStandardMaterial</code>を使います。こちらは光を<em>必要とし</em>、光がないと真っ黒のままです。そこで2つ目のシーンを、今度は照明つきで作ります。<code>AmbientLight</code>（どこでも同じ明るさの光。真っ暗な部分がなくなります）と、<code>DirectionalLight</code>（太陽のように、一方向から差す光）です。</p>"
          },
          {
            "t": "c",
            "code": "scene2 = Three::Scene.new\nscene2.add(Three::AmbientLight.new(0xffffff, 0.35))\n\nsun = Three::DirectionalLight.new(0xffffff, 2.5)\nsun.position.set(2, 3, 4)\nscene2.add(sun)\n\nball = Three::Mesh.new(\n  Three::SphereGeometry.new(1, width_segments: 48, height_segments: 24),\n  Three::MeshStandardMaterial.new(color: 0xc14a2e, roughness: 0.35, metalness: 0.1)\n)\nscene2.add(ball)\n\nshow_three scene2, camera"
          },
          {
            "t": "h",
            "html": "<p>静止画もいいですが、動くともっと楽しくなります。<code>show_three</code>に<strong>ブロック</strong>を渡してみましょう。ブロックは毎フレームの描画の前に（1秒に約60回）実行され、フレーム番号を受け取ります。さらに<code>orbit: true</code>を付けると、マウスでシーンを回したり、ホイールでズームしたりできます。</p>"
          },
          {
            "t": "c",
            "code": "show_three scene2, camera, orbit: true do |frame|\n  ball.position.y = Math.sin(frame * 0.05) * 0.5\n  ball.rotation.y += 0.01\nend"
          },
          {
            "t": "h",
            "html": "<p>自分のコンピューターでも組み立て方は同じです。ただし、レンダラーを<code>&lt;canvas&gt;</code>に取り付ける作業は自分で行います。</p><pre><code>renderer = Three::Renderers::ThreeJSRenderer.new(canvas: \"#scene\")\nrenderer.set_size(640, 480)\nrenderer.render(scene, camera)</code></pre><p>ここでは、この部分を<code>show_three</code>が代わりにやってくれています。</p><div class='task'><strong>課題：</strong>タワーを建てましょう！シーン<code>tower</code>を作って光を当て、立方体を<strong>3つ以上</strong>積み重ねてください。<code>position.y</code>で、それぞれの高さを変えます。<code>show_three tower, camera</code>で表示し、ブロックを渡してゆっくり回転させましょう。</div>"
          },
          {
            "t": "x",
            "code": "# tower = Three::Scene.new\n# tower.add(Three::AmbientLight.new(0xffffff, 0.4))\n# ...\n# show_three tower, camera do\n#   tower.rotation.y += 0.01\n# end\n",
            "check": "defined?(Three) && tower.is_a?(Three::Scene) && tower.children.count { |k| k.is_a?(Three::Mesh) } >= 3 && scenes.any? { |s| s.equal?(tower) }",
            "hint": "3つまとめて作るなら：<code>3.times do |i|</code> … <code>Three::Mesh</code>を作って<code>block.position.y = i - 1.0</code>を設定し、<code>tower.add(block)</code>でシーンに追加 … <code>end</code>。それから、<code>camera</code>ができるように、先に上のセルを実行しておくのを忘れないでね。"
          }
        ]
      }
    },
    {
      "id": "pptx",
      "de": {
        "title": "20. PowerPoint mit ruby_pptx",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Folien aus Ruby</h2><p>Eine PowerPoint-Datei (<code>.pptx</code>) ist in Wahrheit ein ZIP-Archiv voller XML-Dateien – eine pro Folie, dazu Layouts, Designs und Bilder. Von Hand baut das niemand, aber mit einer Gem wird es ganz einfach: <a href='https://github.com/Largo/ruby_pptx' target='_blank'><code>ruby_pptx</code></a> ist eine Ruby-Portierung der bekannten Python-Bibliothek <em>python-pptx</em>.</p><p>Alles läuft hier im Browser: die Gem wird installiert, die Präsentation in Ruby gebaut und gespeichert. <strong>Jede Datei, die deine Zelle speichert, erscheint darunter als Download</strong> – klick drauf, und du kannst sie in PowerPoint, Keynote oder LibreOffice öffnen.</p>"
          },
          {
            "t": "c",
            "code": "install_gem \"ruby_pptx\"\nrequire \"ruby_pptx\"\n\npraesi = Pptx::Presentation.new_default\ntitel = praesi.slides.add(praesi.slide_layouts[\"Title Slide\"])\ntitel.shapes.title.text = \"Chunky Bacon\"\ntitel.placeholders[1].text_frame.text = \"Eine Präsentation, gebaut mit Ruby\"\n\npraesi.save(\"chunky.pptx\")"
          },
          {
            "t": "h",
            "html": "<p>Was ist da passiert?</p><ul><li><code>Presentation.new_default</code> legt eine leere Präsentation mit der Standard-Vorlage an.</li><li>Jede Folie beruht auf einem <strong>Layout</strong>, genau wie in PowerPoint, wenn du auf „Neue Folie“ klickst. <code>slide_layouts[\"Title Slide\"]</code> sucht es beim Namen.</li><li>Ein Layout bringt <strong>Platzhalter</strong> mit: <code>shapes.title</code> ist der Titel, <code>placeholders[1]</code> das Feld darunter. In ihren <code>text_frame</code> schreibst du den Text.</li><li><code>save</code> schreibt die Datei – und schon liegt sie unten zum Herunterladen bereit.</li></ul><p>Welche Layouts gibt es überhaupt? Frag einfach nach – <code>praesi</code> kennt die Zelle von oben noch:</p>"
          },
          {
            "t": "c",
            "code": "praesi.slide_layouts.map(&:name)"
          },
          {
            "t": "h",
            "html": "<p>Für Aufzählungen nimmst du <code>\"Title and Content\"</code>. Jede Zeile (getrennt mit <code>\\n</code>) wird ein <strong>Absatz</strong> mit eigenem Aufzählungspunkt. Ein Absatz hat eine <code>level</code> für die Einrückung, und seine Textstücke (<code>runs</code>) haben eine <code>font</code> – fett, kursiv, Grösse, Farbe.</p>"
          },
          {
            "t": "c",
            "code": "folie = praesi.slides.add(praesi.slide_layouts[\"Title and Content\"])\nfolie.shapes.title.text = \"Frühstück\"\n\ntext = folie.placeholders[1].text_frame\ntext.text = \"Speck\\nknusprig gebraten\\nEier\\nToast\"\ntext.paragraphs[1].level = 1\ntext.paragraphs[0].runs[0].font.bold = true\n\npraesi.save(\"chunky.pptx\")"
          },
          {
            "t": "h",
            "html": "<p>Auf einer leeren Folie (<code>\"Blank\"</code>) platzierst du Formen selbst. Positionen und Grössen sind echte Längen, keine nackten Zahlen, bei denen man raten muss, ob Pixel oder Zentimeter gemeint sind. <code>at:</code> ist die linke obere Ecke, <code>size:</code> Breite und Höhe.</p><p>Lesen soll sich das wie Ruby: <code>2.cm</code>, <code>1.inch</code>, <code>28.pt</code>. Dafür bringt die Gem eine <strong>Refinement</strong> mit – eine Erweiterung einer eingebauten Klasse, hier <code>Numeric</code>, die nur dort gilt, wo du sie mit <code>using</code> einschaltest. Anders als ein Monkeypatch, der Ruby für alle ändert, kann sie keiner anderen Bibliothek in die Quere kommen. Ohne sie schreibst du <code>Pptx.cm(2)</code> – dasselbe, nur länger.</p><p>Farben gibst du als Hex-Code an, wie in CSS: <code>\"E8722A\"</code> ist das Orange von Chunky Bacon.</p>"
          },
          {
            "t": "c",
            "code": "require \"ruby_pptx/refinements\"\nusing Pptx::Lengths\n\nfolie = praesi.slides.add(praesi.slide_layouts[\"Blank\"])\nbox = folie.shapes.add_shape(:rounded_rectangle,\n                             at: [2.cm, 2.cm],\n                             size: [12.cm, 4.cm])\nbox.fill.solid\nbox.fill.fore_color.rgb = \"E8722A\"\nbox.text_frame.text = \"Chunky Bacon!\"\nbox.text_frame.paragraphs[0].runs[0].font.size = 28.pt\n\npraesi.save(\"chunky.pptx\")"
          },
          {
            "t": "h",
            "html": "<p>Und Diagramme? Die Zahlen kommen in ein <code>ChartData</code>: Kategorien für die x-Achse, dazu eine oder mehrere Datenreihen. Die Gem legt sogar die Excel-Tabelle mit ab, die hinter dem Diagramm steckt – in PowerPoint kannst du die Daten später bearbeiten.</p>"
          },
          {
            "t": "c",
            "code": "daten = Pptx::ChartData.new\ndaten.categories = %w[Mo Di Mi Do Fr]\ndaten.add_series(\"Speck\", [3, 5, 2, 6, 4])\n\nfolie = praesi.slides.add(praesi.slide_layouts[\"Title Only\"])\nfolie.shapes.title.text = \"Speck pro Tag\"\nfolie.shapes.add_chart(:column_clustered, daten,\n                       at: [2.cm, 4.cm],\n                       size: [20.cm, 12.cm])\n\npraesi.save(\"chunky.pptx\")"
          },
          {
            "t": "h",
            "html": "<p>Lesen geht auch: <code>Presentation.open</code> öffnet eine vorhandene Datei, und du läufst durch ihre Folien wie durch ein Array. Die leere Folie hat keinen Titel – deshalb <code>&amp;.</code>, das bei <code>nil</code> einfach <code>nil</code> liefert, statt abzustürzen.</p>"
          },
          {
            "t": "c",
            "code": "gelesen = Pptx::Presentation.open(\"chunky.pptx\")\ngelesen.slides.map { |f| f.shapes.title&.text }"
          },
          {
            "t": "h",
            "html": "<div class='offweb'><strong>Auf deinem Rechner:</strong> <code>gem install ruby_pptx</code> – oder <code>gem \"ruby_pptx\"</code> im Gemfile. Dort liest und schreibt die Gem XML mit <em>Nokogiri</em>, einer schnellen C-Erweiterung. Hier im Browser gibt es keine C-Erweiterungen, also nimmt sie automatisch <em>REXML</em>, das in reinem Ruby geschrieben ist: langsamer, aber mit genau derselben Datei als Ergebnis. Speichern kannst du dort überall hin, z. B. <code>praesi.save(\"~/Desktop/chunky.pptx\")</code>.</div><div class='task'><strong>Aufgabe:</strong> Bau eine <strong>Speisekarte</strong>! Lege eine neue Präsentation <code>karte</code> an, mit einer Titelfolie und <strong>mindestens zwei</strong> weiteren Folien – jede mit einem Titel, z. B. „Vorspeisen“ und „Hauptgänge“ mit ein paar Gerichten als Aufzählung. Speichere sie als <code>karte.pptx</code>.</div>"
          },
          {
            "t": "x",
            "code": "# karte = Pptx::Presentation.new_default\n# titel = karte.slides.add(karte.slide_layouts[\"Title Slide\"])\n# ...\n# karte.save(\"karte.pptx\")\n",
            "check": "downloads.include?(\"karte.pptx\") && (k = Pptx::Presentation.open(\"karte.pptx\")).slides.size >= 3 && k.slides.all? { |f| !f.shapes.title.nil? && !f.shapes.title.text.strip.empty? }",
            "hint": "Drei Folien, jede mit einem Layout, das einen Titel hat (\"Title Slide\", \"Title and Content\"), jeweils <code>shapes.title.text</code> setzen – und am Ende <code>karte.save(\"karte.pptx\")</code>. Der Download muss unter <em>dieser</em> Zelle erscheinen."
          }
        ]
      },
      "en": {
        "title": "20. PowerPoint with ruby_pptx",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Slides from Ruby</h2><p>A PowerPoint file (<code>.pptx</code>) is really a ZIP archive full of XML files – one per slide, plus layouts, themes and images. Nobody writes that by hand, but with a gem it becomes easy: <a href='https://github.com/Largo/ruby_pptx' target='_blank'><code>ruby_pptx</code></a> is a Ruby port of the well-known Python library <em>python-pptx</em>.</p><p>Everything here runs in the browser: the gem is installed, the presentation is built and saved in Ruby. <strong>Every file your cell saves shows up below it as a download</strong> – click it and open it in PowerPoint, Keynote or LibreOffice.</p>"
          },
          {
            "t": "c",
            "code": "install_gem \"ruby_pptx\"\nrequire \"ruby_pptx\"\n\ndeck = Pptx::Presentation.new_default\ntitle = deck.slides.add(deck.slide_layouts[\"Title Slide\"])\ntitle.shapes.title.text = \"Chunky Bacon\"\ntitle.placeholders[1].text_frame.text = \"A presentation, built with Ruby\"\n\ndeck.save(\"chunky.pptx\")"
          },
          {
            "t": "h",
            "html": "<p>What just happened?</p><ul><li><code>Presentation.new_default</code> creates an empty presentation from the default template.</li><li>Every slide is based on a <strong>layout</strong>, just like in PowerPoint when you click “New Slide”. <code>slide_layouts[\"Title Slide\"]</code> finds one by name.</li><li>A layout brings <strong>placeholders</strong>: <code>shapes.title</code> is the title, <code>placeholders[1]</code> the box below it. You write text into their <code>text_frame</code>.</li><li><code>save</code> writes the file – and it is ready to download below.</li></ul><p>Which layouts are there? Just ask – the cell still knows <code>deck</code> from above:</p>"
          },
          {
            "t": "c",
            "code": "deck.slide_layouts.map(&:name)"
          },
          {
            "t": "h",
            "html": "<p>For bullet points use <code>\"Title and Content\"</code>. Each line (separated by <code>\\n</code>) becomes a <strong>paragraph</strong> with its own bullet. A paragraph has a <code>level</code> for indentation, and its pieces of text (<code>runs</code>) have a <code>font</code> – bold, italic, size, colour.</p>"
          },
          {
            "t": "c",
            "code": "slide = deck.slides.add(deck.slide_layouts[\"Title and Content\"])\nslide.shapes.title.text = \"Breakfast\"\n\ntext = slide.placeholders[1].text_frame\ntext.text = \"Bacon\\nnice and crispy\\nEggs\\nToast\"\ntext.paragraphs[1].level = 1\ntext.paragraphs[0].runs[0].font.bold = true\n\ndeck.save(\"chunky.pptx\")"
          },
          {
            "t": "h",
            "html": "<p>On an empty slide (<code>\"Blank\"</code>) you place shapes yourself. Positions and sizes are real lengths – no bare numbers where you have to guess whether pixels or centimetres are meant. <code>at:</code> is the top-left corner, <code>size:</code> width and height.</p><p>It should read like Ruby: <code>2.cm</code>, <code>1.inch</code>, <code>28.pt</code>. For that the gem ships a <strong>refinement</strong> – an extension of a built-in class, here <code>Numeric</code>, that only applies where you switch it on with <code>using</code>. Unlike a monkey patch, which changes Ruby for everyone, it cannot get in the way of any other library. Without it you write <code>Pptx.cm(2)</code> – the same thing, just longer.</p><p>Colours are hex codes, as in CSS: <code>\"E8722A\"</code> is Chunky Bacon orange.</p>"
          },
          {
            "t": "c",
            "code": "require \"ruby_pptx/refinements\"\nusing Pptx::Lengths\n\nslide = deck.slides.add(deck.slide_layouts[\"Blank\"])\nbox = slide.shapes.add_shape(:rounded_rectangle,\n                             at: [2.cm, 2.cm],\n                             size: [12.cm, 4.cm])\nbox.fill.solid\nbox.fill.fore_color.rgb = \"E8722A\"\nbox.text_frame.text = \"Chunky Bacon!\"\nbox.text_frame.paragraphs[0].runs[0].font.size = 28.pt\n\ndeck.save(\"chunky.pptx\")"
          },
          {
            "t": "h",
            "html": "<p>And charts? The numbers go into a <code>ChartData</code>: categories for the x axis, plus one or more series. The gem even stores the Excel sheet behind the chart – in PowerPoint you can edit the data later.</p>"
          },
          {
            "t": "c",
            "code": "data = Pptx::ChartData.new\ndata.categories = %w[Mon Tue Wed Thu Fri]\ndata.add_series(\"Bacon\", [3, 5, 2, 6, 4])\n\nslide = deck.slides.add(deck.slide_layouts[\"Title Only\"])\nslide.shapes.title.text = \"Bacon per day\"\nslide.shapes.add_chart(:column_clustered, data,\n                       at: [2.cm, 4.cm],\n                       size: [20.cm, 12.cm])\n\ndeck.save(\"chunky.pptx\")"
          },
          {
            "t": "h",
            "html": "<p>Reading works too: <code>Presentation.open</code> opens an existing file, and you walk through its slides like an array. The blank slide has no title – hence <code>&amp;.</code>, which simply returns <code>nil</code> for <code>nil</code> instead of crashing.</p>"
          },
          {
            "t": "c",
            "code": "opened = Pptx::Presentation.open(\"chunky.pptx\")\nopened.slides.map { |s| s.shapes.title&.text }"
          },
          {
            "t": "h",
            "html": "<div class='offweb'><strong>On your machine:</strong> <code>gem install ruby_pptx</code> – or <code>gem \"ruby_pptx\"</code> in your Gemfile. There the gem reads and writes XML with <em>Nokogiri</em>, a fast C extension. The browser has no C extensions, so here it automatically uses <em>REXML</em>, written in pure Ruby: slower, but producing exactly the same file. On your machine you can save anywhere, e.g. <code>deck.save(\"~/Desktop/chunky.pptx\")</code>.</div><div class='task'><strong>Task:</strong> Build a <strong>menu</strong>! Create a new presentation <code>menu</code> with a title slide and <strong>at least two</strong> more slides – each with a title, e.g. “Starters” and “Mains” with a few dishes as bullet points. Save it as <code>menu.pptx</code>.</div>"
          },
          {
            "t": "x",
            "code": "# menu = Pptx::Presentation.new_default\n# title = menu.slides.add(menu.slide_layouts[\"Title Slide\"])\n# ...\n# menu.save(\"menu.pptx\")\n",
            "check": "downloads.include?(\"menu.pptx\") && (m = Pptx::Presentation.open(\"menu.pptx\")).slides.size >= 3 && m.slides.all? { |s| !s.shapes.title.nil? && !s.shapes.title.text.strip.empty? }",
            "hint": "Three slides, each from a layout that has a title (\"Title Slide\", \"Title and Content\"), each with <code>shapes.title.text</code> set – and finally <code>menu.save(\"menu.pptx\")</code>. The download has to appear below <em>this</em> cell."
          }
        ]
      },
      "ja": {
        "title": "20. ruby_pptxでPowerPoint",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Rubyでスライドを作る</h2><p>PowerPointのファイル（<code>.pptx</code>）の正体は、XMLファイルがぎっしり詰まったZIPアーカイブです。スライド1枚ごとに1つのファイルがあり、さらにレイアウト、テーマ、画像も入っています。これを手で書く人はいませんが、gemを使えば簡単です。<a href='https://github.com/Largo/ruby_pptx' target='_blank'><code>ruby_pptx</code></a>は、有名なPythonライブラリ<em>python-pptx</em>をRubyに移植したものです。</p><p>ここでは、すべてがブラウザの中で動きます。gemをインストールし、プレゼンテーションを組み立てて保存するまで、全部Rubyで行います。<strong>セルが保存したファイルは、どれもそのセルの下にダウンロードとして表示されます</strong>。クリックして、PowerPoint、Keynote、LibreOfficeで開いてみてください。</p>"
          },
          {
            "t": "c",
            "code": "install_gem \"ruby_pptx\"\nrequire \"ruby_pptx\"\n\ndeck = Pptx::Presentation.new_default\ntitle = deck.slides.add(deck.slide_layouts[\"Title Slide\"])\ntitle.shapes.title.text = \"Chunky Bacon\"\ntitle.placeholders[1].text_frame.text = \"A presentation, built with Ruby\"\n\ndeck.save(\"chunky.pptx\")"
          },
          {
            "t": "h",
            "html": "<p>いま何が起きたのでしょうか？</p><ul><li><code>Presentation.new_default</code>は、標準のテンプレートから空のプレゼンテーションを作ります。</li><li>どのスライドも<strong>レイアウト</strong>をもとにしています。PowerPointで「新しいスライド」をクリックしたときと同じです。<code>slide_layouts[\"Title Slide\"]</code>は、名前でレイアウトを探します。</li><li>レイアウトには<strong>プレースホルダー</strong>が付いてきます。<code>shapes.title</code>がタイトル、<code>placeholders[1]</code>がその下の枠です。テキストは、それぞれの<code>text_frame</code>に書き込みます。</li><li><code>save</code>がファイルを書き出します。これで、下からすぐにダウンロードできます。</li></ul><p>どんなレイアウトがあるのでしょう？聞いてみればわかります。このセルは、上で作った<code>deck</code>をまだ覚えています：</p>"
          },
          {
            "t": "c",
            "code": "deck.slide_layouts.map(&:name)"
          },
          {
            "t": "h",
            "html": "<p>箇条書きには<code>\"Title and Content\"</code>を使います。<code>\\n</code>で区切った1行1行が、それぞれ行頭記号の付いた<strong>段落</strong>になります。段落には字下げを決める<code>level</code>があり、段落の中のテキストの断片（<code>runs</code>）には<code>font</code>があります。太字、斜体、サイズ、色などはここで指定します。</p>"
          },
          {
            "t": "c",
            "code": "slide = deck.slides.add(deck.slide_layouts[\"Title and Content\"])\nslide.shapes.title.text = \"Breakfast\"\n\ntext = slide.placeholders[1].text_frame\ntext.text = \"Bacon\\nnice and crispy\\nEggs\\nToast\"\ntext.paragraphs[1].level = 1\ntext.paragraphs[0].runs[0].font.bold = true\n\ndeck.save(\"chunky.pptx\")"
          },
          {
            "t": "h",
            "html": "<p>空のスライド（<code>\"Blank\"</code>）には、図形を自分で配置します。位置や大きさは、単位の付いた本物の長さで指定します。ピクセルなのかセンチメートルなのか迷ってしまうような、単位のない数値は使いません。<code>at:</code>は左上の角、<code>size:</code>は幅と高さです。</p><p><code>2.cm</code>、<code>1.inch</code>、<code>28.pt</code>のように、Rubyらしく読める書き方にしたいところです。そのために、このgemには<strong>refinement</strong>（リファインメント）が付いています。refinementは組み込みクラス（ここでは<code>Numeric</code>）を拡張するしくみで、<code>using</code>で有効にした場所でだけ効きます。Ruby全体を書き換えてしまうモンキーパッチと違って、ほかのライブラリの邪魔をすることはありません。refinementを使わない場合は<code>Pptx.cm(2)</code>と書きます。意味は同じで、少し長くなるだけです。</p><p>色はCSSと同じく16進数のコードで指定します。<code>\"E8722A\"</code>はChunky Baconのオレンジです。</p>"
          },
          {
            "t": "c",
            "code": "require \"ruby_pptx/refinements\"\nusing Pptx::Lengths\n\nslide = deck.slides.add(deck.slide_layouts[\"Blank\"])\nbox = slide.shapes.add_shape(:rounded_rectangle,\n                             at: [2.cm, 2.cm],\n                             size: [12.cm, 4.cm])\nbox.fill.solid\nbox.fill.fore_color.rgb = \"E8722A\"\nbox.text_frame.text = \"Chunky Bacon!\"\nbox.text_frame.paragraphs[0].runs[0].font.size = 28.pt\n\ndeck.save(\"chunky.pptx\")"
          },
          {
            "t": "h",
            "html": "<p>グラフはどうでしょう？数値は<code>ChartData</code>に入れます。x軸に並べるカテゴリと、1つ以上の系列です。このgemは、グラフの裏にあるExcelのシートまで一緒に保存してくれます。そのため、PowerPointであとからデータを編集することもできます。</p>"
          },
          {
            "t": "c",
            "code": "data = Pptx::ChartData.new\ndata.categories = %w[Mon Tue Wed Thu Fri]\ndata.add_series(\"Bacon\", [3, 5, 2, 6, 4])\n\nslide = deck.slides.add(deck.slide_layouts[\"Title Only\"])\nslide.shapes.title.text = \"Bacon per day\"\nslide.shapes.add_chart(:column_clustered, data,\n                       at: [2.cm, 4.cm],\n                       size: [20.cm, 12.cm])\n\ndeck.save(\"chunky.pptx\")"
          },
          {
            "t": "h",
            "html": "<p>読み込みもできます。<code>Presentation.open</code>で既存のファイルを開けば、配列と同じようにスライドを順にたどれます。空のスライドにはタイトルがないので、<code>&amp;.</code>を使っています。これは、相手が<code>nil</code>のときにエラーで止まらず、そのまま<code>nil</code>を返してくれる書き方です。</p>"
          },
          {
            "t": "c",
            "code": "opened = Pptx::Presentation.open(\"chunky.pptx\")\nopened.slides.map { |s| s.shapes.title&.text }"
          },
          {
            "t": "h",
            "html": "<div class='offweb'><strong>自分のコンピューターでは：</strong><code>gem install ruby_pptx</code>でインストールします。Gemfileに<code>gem \"ruby_pptx\"</code>と書いてもかまいません。そこでは、gemは高速なC拡張である<em>Nokogiri</em>を使ってXMLを読み書きします。ブラウザにはC拡張がないので、ここでは自動的に、ピュアRubyで書かれた<em>REXML</em>が使われます。速度は落ちますが、できあがるファイルはまったく同じです。自分のコンピューターなら保存先も自由で、たとえば<code>deck.save(\"~/Desktop/chunky.pptx\")</code>とすればデスクトップに保存されます。</div><div class='task'><strong>課題：</strong><strong>メニュー</strong>を作りましょう！新しいプレゼンテーション<code>menu</code>を作り、タイトルスライドに加えて、<strong>2枚以上</strong>のスライドを追加してください。どのスライドにもタイトルを付けます。たとえば「前菜」と「メイン」のスライドを作り、料理をいくつか箇条書きにします。最後に<code>menu.pptx</code>として保存してください。</div>"
          },
          {
            "t": "x",
            "code": "# menu = Pptx::Presentation.new_default\n# title = menu.slides.add(menu.slide_layouts[\"Title Slide\"])\n# ...\n# menu.save(\"menu.pptx\")\n",
            "check": "downloads.include?(\"menu.pptx\") && (m = Pptx::Presentation.open(\"menu.pptx\")).slides.size >= 3 && m.slides.all? { |s| !s.shapes.title.nil? && !s.shapes.title.text.strip.empty? }",
            "hint": "スライドは3枚だよ。どれもタイトルのあるレイアウト（\"Title Slide\"、\"Title and Content\"）から作って、それぞれ<code>shapes.title.text</code>を設定しよう。最後に<code>menu.save(\"menu.pptx\")</code>。ダウンロードが<em>この</em>セルの下に出てくればOKだよ。"
          }
        ]
      }
    },
    {
      "id": "pdf",
      "de": {
        "title": "21. PDFs mit Prawn & HexaPDF",
        "cells": [
          {
            "t": "h",
            "html": "<h2>PDFs aus Ruby</h2><p>Rechnungen, Tickets, Urkunden – früher oder später muss fast jedes Programm ein PDF erzeugen. Ruby hat dafür zwei starke Gems: <strong>Prawn</strong> zeichnet PDFs mit einer freundlichen DSL, und <strong>HexaPDF</strong> kann bestehende PDFs auch <em>öffnen</em> und verändern. Beide sind reines Ruby, laufen also direkt hier in deinem Browser:</p>"
          },
          {
            "t": "c",
            "code": "install_gem \"prawn\"\nrequire \"prawn\"\n\npdf = Prawn::Document.new\npdf.text \"Chunky Bacons Frühstücksclub\", size: 24, style: :bold\npdf.move_down 10\npdf.text \"Mitgliederausweis für Kaz\"\npdf.stroke_horizontal_rule\nshow_pdf pdf"
          },
          {
            "t": "h",
            "html": "<p>Was ist passiert?</p><ul><li><code>Prawn::Document.new</code> beginnt ein leeres Dokument mit einer Seite.</li><li><code>text</code> schreibt einen Absatz – <code>size:</code> und <code>style:</code> sind Keyword-Argumente. Lange Zeilen bricht Prawn selbst um, und ist eine Seite voll, beginnt es eine neue.</li><li><code>move_down 10</code> lässt 10 <strong>Punkte</strong> Abstand: PDF misst in Punkten, 72 pro Zoll (eine A4-Seite ist 595 × 842 gross).</li><li><code>show_pdf</code> ist ein Helfer dieser Seite und zeigt das PDF unter der Zelle. Auf deinem Computer schreibst du es in eine Datei: <code>pdf.render_file \"ausweis.pdf\"</code>.</li></ul><p>Statt vor alles <code>pdf.</code> zu schreiben, kannst du <code>Prawn::Document.generate</code> einen Block geben – am Ende schreibt es die Datei:</p>"
          },
          {
            "t": "c",
            "code": "Prawn::Document.generate(\"speisekarte.pdf\", page_size: \"A4\") do\n  text \"Speisekarte\", size: 28, align: :center\n  move_down 20\n  { \"Speck mit Ei\" => 9.5, \"Pfannkuchen\" => 7.0, \"Kaffee\" => 3.2 }.each do |gericht, preis|\n    float { text gericht }\n    text format(\"%.2f Fr.\", preis), align: :right\n  end\n  start_new_page\n  text \"Seite zwei: das Kleingedruckte\", size: 10\n  number_pages \"<page> / <total>\", at: [bounds.right - 50, 0]\nend\nshow_pdf \"speisekarte.pdf\""
          },
          {
            "t": "h",
            "html": "<p>Im Block funktioniert <code>text</code> ohne <code>pdf.</code>: Prawn führt den Block <em>im</em> Dokument aus (wie der Trick geht, zeigt Lektion 44). <code>float</code> schreibt das Gericht und springt wieder hoch, so landet der Preis rechtsbündig auf derselben Zeile. <code>number_pages</code> setzt am Schluss die Seitenzahlen – <code>&lt;page&gt;</code> und <code>&lt;total&gt;</code> werden pro Seite ausgefüllt. Die Datei <code>speisekarte.pdf</code> erscheint als Download unter der Zelle, und <code>show_pdf</code> nimmt auch ihren Namen.</p><p>Jetzt <strong>HexaPDF</strong>. Es liest PDFs – unsere oder fremde – und schreibt sie wieder. Stempeln wir jede Seite der Speisekarte:</p>"
          },
          {
            "t": "c",
            "code": "install_gem \"hexapdf\"\nrequire \"hexapdf\"\n\ndoc = HexaPDF::Document.open(\"speisekarte.pdf\")\ndoc.pages.each do |seite|\n  leinwand = seite.canvas(type: :overlay)\n  leinwand.fill_color(193, 74, 46)\n  leinwand.font(\"Helvetica\", size: 48)\n  leinwand.text(\"CHUNKY!\", at: [170, 420])\nend\ndoc.write(\"speisekarte-gestempelt.pdf\")\nshow_pdf \"speisekarte-gestempelt.pdf\"\ndoc.pages.count"
          },
          {
            "t": "h",
            "html": "<p><code>seite.canvas(type: :overlay)</code> ist eine Zeichenfläche <em>über</em> dem, was schon auf der Seite steht. Ihr Nullpunkt <code>[0, 0]</code> ist die linke untere Ecke – in PDF zählt y nach oben. <code>fill_color(193, 74, 46)</code> ist Speckrot in RGB.</p><p>Zusammenfügen ist genauso kurz: Jede Seite mehrerer Dokumente in ein neues importieren.</p>"
          },
          {
            "t": "c",
            "code": "beide = HexaPDF::Document.new\n[\"speisekarte.pdf\", \"speisekarte-gestempelt.pdf\"].each do |datei|\n  quelle = HexaPDF::Document.open(datei)\n  quelle.pages.each { |seite| beide.pages << beide.import(seite) }\nend\nbeide.write(\"beide.pdf\")\nshow_pdf beide\nbeide.pages.count"
          },
          {
            "t": "h",
            "html": "<div class='offweb' data-title='Auf deinem Computer'><p><code>gem install prawn hexapdf</code>, und <code>render_file</code> und <code>write</code> speichern echte Dateien. HexaPDF bringt auch ein Kommandozeilen-Werkzeug mit: <code>hexapdf info speisekarte.pdf</code>, <code>hexapdf merge</code>, <code>hexapdf optimize</code>.</p><p><strong>Schriften:</strong> Die 14 Standardschriften von PDF (Helvetica, Times, Courier …) kennen nur westeuropäische Buchstaben. Für andere Schriften – etwa Japanisch – bettest du eine TrueType-Schrift ein: <code>pdf.font \"NotoSansJP-Regular.ttf\"</code> in Prawn, <code>canvas.font(\"NotoSansJP-Regular.ttf\")</code> in HexaPDF.</p><p><strong>Lizenzen:</strong> Prawn steht unter der Ruby-Lizenz oder der GPL. HexaPDF steht unter der <strong>AGPL</strong>: Gibst du ein Programm weiter, das HexaPDF benutzt, oder bietest es als Webdienst an, verlangt die AGPL in aller Regel, dass du auch dessen Quellcode unter der AGPL veröffentlichst – ausser du kaufst die kommerzielle Lizenz von HexaPDF.</p></div><div class='task'><strong>Aufgabe:</strong> Chunky hat sich eine Urkunde verdient. Schreibe mit Prawn <code>urkunde.pdf</code> mit genau <strong>3 Seiten</strong>: <code>Stufe 1</code> auf der ersten, <code>Stufe 2</code> auf der zweiten, <code>Stufe 3</code> auf der dritten.</div>"
          },
          {
            "t": "x",
            "code": "# urkunde.pdf: 3 Seiten – \"Stufe 1\", \"Stufe 2\", \"Stufe 3\"\n",
            "check": "downloads.include?(\"urkunde.pdf\") && code.include?(\"Prawn\") && (require \"hexapdf\"; HexaPDF::Document.open(\"urkunde.pdf\") { |d| d.pages.count } == 3)",
            "hint": "Beginne mit <code>Prawn::Document.generate(\"urkunde.pdf\") do … end</code> und setze <code>start_new_page</code> zwischen die drei <code>text</code>-Zeilen."
          }
        ]
      },
      "en": {
        "title": "21. PDFs with Prawn & HexaPDF",
        "cells": [
          {
            "t": "h",
            "html": "<h2>PDFs from Ruby</h2><p>Invoices, tickets, certificates – sooner or later almost every program has to produce a PDF. Ruby has two strong gems for it: <strong>Prawn</strong> draws PDFs with a friendly DSL, and <strong>HexaPDF</strong> can also <em>open</em> existing PDFs and change them. Both are pure Ruby, so they run right here in your browser:</p>"
          },
          {
            "t": "c",
            "code": "install_gem \"prawn\"\nrequire \"prawn\"\n\npdf = Prawn::Document.new\npdf.text \"Chunky Bacon's Breakfast Club\", size: 24, style: :bold\npdf.move_down 10\npdf.text \"Membership card for Kaz\"\npdf.stroke_horizontal_rule\nshow_pdf pdf"
          },
          {
            "t": "h",
            "html": "<p>What happened?</p><ul><li><code>Prawn::Document.new</code> starts an empty document with one page.</li><li><code>text</code> writes a paragraph – <code>size:</code> and <code>style:</code> are keyword arguments. Prawn wraps long lines by itself and starts a new page when one is full.</li><li><code>move_down 10</code> leaves 10 <strong>points</strong> of space: PDF measures in points, 72 to the inch (an A4 page is 595 × 842).</li><li><code>show_pdf</code> is a helper of this site that shows the PDF below the cell. On your computer you would write it to a file: <code>pdf.render_file \"card.pdf\"</code>.</li></ul><p>Instead of putting <code>pdf.</code> in front of everything, you can give <code>Prawn::Document.generate</code> a block – at the end it writes the file:</p>"
          },
          {
            "t": "c",
            "code": "Prawn::Document.generate(\"menu.pdf\", page_size: \"A4\") do\n  text \"Menu\", size: 28, align: :center\n  move_down 20\n  { \"Bacon & eggs\" => 9.5, \"Pancakes\" => 7.0, \"Coffee\" => 3.2 }.each do |dish, price|\n    float { text dish }\n    text format(\"$%.2f\", price), align: :right\n  end\n  start_new_page\n  text \"Page two: the fine print\", size: 10\n  number_pages \"<page> / <total>\", at: [bounds.right - 50, 0]\nend\nshow_pdf \"menu.pdf\""
          },
          {
            "t": "h",
            "html": "<p>Inside the block, <code>text</code> works without <code>pdf.</code>: Prawn runs the block <em>inside</em> the document (lesson 44 shows how that trick works). <code>float</code> writes the dish and jumps back up, so the price lands on the same line, aligned right. <code>number_pages</code> stamps the page numbers at the end – <code>&lt;page&gt;</code> and <code>&lt;total&gt;</code> are filled in per page. The file <code>menu.pdf</code> appears as a download below the cell, and <code>show_pdf</code> takes its name too.</p><p>Now <strong>HexaPDF</strong>. It reads PDFs – ours or anybody's – and writes them back. Let's stamp every page of the menu:</p>"
          },
          {
            "t": "c",
            "code": "install_gem \"hexapdf\"\nrequire \"hexapdf\"\n\ndoc = HexaPDF::Document.open(\"menu.pdf\")\ndoc.pages.each do |page|\n  canvas = page.canvas(type: :overlay)\n  canvas.fill_color(193, 74, 46)\n  canvas.font(\"Helvetica\", size: 48)\n  canvas.text(\"CHUNKY!\", at: [170, 420])\nend\ndoc.write(\"menu-stamped.pdf\")\nshow_pdf \"menu-stamped.pdf\"\ndoc.pages.count"
          },
          {
            "t": "h",
            "html": "<p><code>page.canvas(type: :overlay)</code> is a drawing surface <em>on top of</em> what is already on the page. Its origin <code>[0, 0]</code> is the bottom left corner – in PDF, y counts upwards. <code>fill_color(193, 74, 46)</code> is bacon red in RGB.</p><p>Merging is just as short: import every page of several documents into a new one.</p>"
          },
          {
            "t": "c",
            "code": "merged = HexaPDF::Document.new\n[\"menu.pdf\", \"menu-stamped.pdf\"].each do |file|\n  source = HexaPDF::Document.open(file)\n  source.pages.each { |page| merged.pages << merged.import(page) }\nend\nmerged.write(\"both.pdf\")\nshow_pdf merged\nmerged.pages.count"
          },
          {
            "t": "h",
            "html": "<div class='offweb' data-title='On your machine'><p><code>gem install prawn hexapdf</code>, and <code>render_file</code> and <code>write</code> save real files. HexaPDF also comes with a command line tool: <code>hexapdf info menu.pdf</code>, <code>hexapdf merge</code>, <code>hexapdf optimize</code>.</p><p><strong>Fonts:</strong> the 14 standard PDF fonts (Helvetica, Times, Courier …) only know Western European letters. For other scripts – Japanese, say – embed a TrueType font: <code>pdf.font \"NotoSansJP-Regular.ttf\"</code> in Prawn, <code>canvas.font(\"NotoSansJP-Regular.ttf\")</code> in HexaPDF.</p><p><strong>Licences:</strong> Prawn comes under Ruby's licence or the GPL. HexaPDF comes under the <strong>AGPL</strong>: if you pass on a program that uses it, or offer one as a web service, the AGPL generally requires you to publish that program's source under the AGPL too – unless you buy HexaPDF's commercial licence.</p></div><div class='task'><strong>Task:</strong> Chunky has earned a certificate. Use Prawn to write <code>certificate.pdf</code> with exactly <strong>3 pages</strong>: <code>Level 1</code> on the first, <code>Level 2</code> on the second, <code>Level 3</code> on the third.</div>"
          },
          {
            "t": "x",
            "code": "# certificate.pdf: 3 pages – \"Level 1\", \"Level 2\", \"Level 3\"\n",
            "check": "downloads.include?(\"certificate.pdf\") && code.include?(\"Prawn\") && (require \"hexapdf\"; HexaPDF::Document.open(\"certificate.pdf\") { |d| d.pages.count } == 3)",
            "hint": "Start with <code>Prawn::Document.generate(\"certificate.pdf\") do … end</code> and put <code>start_new_page</code> between the three <code>text</code> lines."
          }
        ]
      },
      "ja": {
        "title": "21. PrawnとHexaPDFでPDF",
        "cells": [
          {
            "t": "h",
            "html": "<h2>RubyでPDFを作る</h2><p>請求書、チケット、修了証。遅かれ早かれ、ほとんどのプログラムはPDFを作ることになります。Rubyにはそのための強力なgemが2つあります。<strong>Prawn</strong>はわかりやすいDSLでPDFを描き、<strong>HexaPDF</strong>は既存のPDFを<em>開いて</em>変更することもできます。どちらもピュアRubyなので、このブラウザの中でそのまま動きます：</p>"
          },
          {
            "t": "c",
            "code": "install_gem \"prawn\"\nrequire \"prawn\"\n\npdf = Prawn::Document.new\npdf.text \"Chunky Bacon's Breakfast Club\", size: 24, style: :bold\npdf.move_down 10\npdf.text \"Membership card for Kaz\"\npdf.stroke_horizontal_rule\nshow_pdf pdf"
          },
          {
            "t": "h",
            "html": "<p>何が起きたのでしょう？</p><ul><li><code>Prawn::Document.new</code>は、1ページの空のドキュメントを作ります。</li><li><code>text</code>は段落を書きます。<code>size:</code>と<code>style:</code>はキーワード引数です。長い行はPrawnが自動で折り返し、ページがいっぱいになると新しいページを始めます。</li><li><code>move_down 10</code>は10<strong>ポイント</strong>の余白を空けます。PDFの単位はポイントで、1インチが72ポイントです（A4のページは595 × 842）。</li><li><code>show_pdf</code>はこのサイトのヘルパーで、PDFをセルの下に表示します。自分のコンピューターでは、<code>pdf.render_file \"card.pdf\"</code>でファイルに書き出します。</li></ul><p>毎回<code>pdf.</code>を付ける代わりに、<code>Prawn::Document.generate</code>にブロックを渡すこともできます。最後にファイルを書き出してくれます：</p>"
          },
          {
            "t": "c",
            "code": "Prawn::Document.generate(\"menu.pdf\", page_size: \"A4\") do\n  text \"Menu\", size: 28, align: :center\n  move_down 20\n  { \"Bacon & eggs\" => 9.5, \"Pancakes\" => 7.0, \"Coffee\" => 3.2 }.each do |dish, price|\n    float { text dish }\n    text format(\"$%.2f\", price), align: :right\n  end\n  start_new_page\n  text \"Page two: the fine print\", size: 10\n  number_pages \"<page> / <total>\", at: [bounds.right - 50, 0]\nend\nshow_pdf \"menu.pdf\""
          },
          {
            "t": "h",
            "html": "<p>ブロックの中では、<code>pdf.</code>を付けなくても<code>text</code>が使えます。Prawnがブロックをドキュメントの<em>中で</em>実行するからです（この仕掛けはレッスン44で紹介します）。<code>float</code>は料理名を書いたあと元の高さに戻るので、値段が同じ行の右端に並びます。<code>number_pages</code>は最後にページ番号を入れます。<code>&lt;page&gt;</code>と<code>&lt;total&gt;</code>はページごとに埋められます。ファイル<code>menu.pdf</code>はセルの下にダウンロードとして現れ、<code>show_pdf</code>にはファイル名を渡すこともできます。</p><p>次は<strong>HexaPDF</strong>です。自分のPDFでもほかの人のPDFでも読み込んで、また書き出せます。メニューの全ページにスタンプを押してみましょう：</p>"
          },
          {
            "t": "c",
            "code": "install_gem \"hexapdf\"\nrequire \"hexapdf\"\n\ndoc = HexaPDF::Document.open(\"menu.pdf\")\ndoc.pages.each do |page|\n  canvas = page.canvas(type: :overlay)\n  canvas.fill_color(193, 74, 46)\n  canvas.font(\"Helvetica\", size: 48)\n  canvas.text(\"CHUNKY!\", at: [170, 420])\nend\ndoc.write(\"menu-stamped.pdf\")\nshow_pdf \"menu-stamped.pdf\"\ndoc.pages.count"
          },
          {
            "t": "h",
            "html": "<p><code>page.canvas(type: :overlay)</code>は、ページにすでにあるものの<em>上に</em>重ねて描くキャンバスです。原点<code>[0, 0]</code>は左下の角で、PDFではyが上に向かって増えます。<code>fill_color(193, 74, 46)</code>は、RGBで表したベーコンの赤です。</p><p>結合も同じくらい簡単です。複数のドキュメントの全ページを、新しいドキュメントにインポートします。</p>"
          },
          {
            "t": "c",
            "code": "merged = HexaPDF::Document.new\n[\"menu.pdf\", \"menu-stamped.pdf\"].each do |file|\n  source = HexaPDF::Document.open(file)\n  source.pages.each { |page| merged.pages << merged.import(page) }\nend\nmerged.write(\"both.pdf\")\nshow_pdf merged\nmerged.pages.count"
          },
          {
            "t": "h",
            "html": "<div class='offweb' data-title='自分のコンピューターでは'><p><code>gem install prawn hexapdf</code>を実行すれば、<code>render_file</code>や<code>write</code>で本物のファイルとして保存できます。HexaPDFにはコマンドラインツールも付いています：<code>hexapdf info menu.pdf</code>、<code>hexapdf merge</code>、<code>hexapdf optimize</code>。</p><p><strong>フォント：</strong>PDFの14の標準フォント（Helvetica、Times、Courierなど）が扱えるのは、西ヨーロッパの文字だけです。日本語などほかの文字を使うには、TrueTypeフォントを埋め込みます。Prawnでは<code>pdf.font \"NotoSansJP-Regular.ttf\"</code>、HexaPDFでは<code>canvas.font(\"NotoSansJP-Regular.ttf\")</code>です。このノートブックにはフォントファイルがないので、ここでは英語の文字列を使っています。</p><p><strong>ライセンス：</strong>PrawnはRubyライセンスまたはGPLです。HexaPDFは<strong>AGPL</strong>です。HexaPDFを使ったプログラムを配布したり、Webサービスとして提供したりする場合、AGPLでは原則として、そのプログラムのソースコードもAGPLで公開する必要があります。そうしたくない場合は、HexaPDFの商用ライセンスを購入します。</p></div><div class='task'><strong>課題：</strong>Chunkyが修了証をもらいました。Prawnを使って、ちょうど<strong>3ページ</strong>の<code>certificate.pdf</code>を書き出しましょう。1ページ目に<code>Level 1</code>、2ページ目に<code>Level 2</code>、3ページ目に<code>Level 3</code>と書きます。</div>"
          },
          {
            "t": "x",
            "code": "# certificate.pdf：3ページ – \"Level 1\"、\"Level 2\"、\"Level 3\"\n",
            "check": "downloads.include?(\"certificate.pdf\") && code.include?(\"Prawn\") && (require \"hexapdf\"; HexaPDF::Document.open(\"certificate.pdf\") { |d| d.pages.count } == 3)",
            "hint": "<code>Prawn::Document.generate(\"certificate.pdf\") do … end</code>で始めて、3つの<code>text</code>の行の間に<code>start_new_page</code>を入れてみて。"
          }
        ]
      }
    },
    {
      "id": "jpeg",
      "de": {
        "title": "22. JPEG-Fotos mit pure_jpeg",
        "cells": [
          {
            "t": "h",
            "html": "<h2>JPEG – Fotos aus Ruby</h2><p>In Lektion 13 hast du mit <code>chunky_png</code> PNG-Bilder gemalt. PNG speichert jeden Pixel <strong>exakt</strong> – ideal für Logos, Pixel-Art und Screenshots, für Fotos aber riesig. Darum ist fast jedes Foto ein <strong>JPEG</strong>: Es lässt weg, was das Auge kaum bemerkt, und wird dadurch viel kleiner.</p><p>Normalerweise erledigt das eine Bibliothek in C. <a href='https://github.com/peterc/pure_jpeg' target='_blank'>pure_jpeg</a> von Peter Cooper schreibt und liest JPEGs in reinem Ruby – darum läuft es hier im Browser. Malen wir einen Sonnenuntergang, Pixel für Pixel:</p>"
          },
          {
            "t": "c",
            "code": "install_gem \"pure_jpeg\"\nrequire \"pure_jpeg\"\n\nbild = PureJPEG::Source::RawSource.new(96, 64) do |x, y|\n  if (x - 48)**2 + (y - 40)**2 < 18**2\n    [255, 210, 60]                  # die Sonne\n  else\n    [40 + y * 3, 70 + y, 170 - y]   # der Himmel, unten röter\n  end\nend\njpeg = PureJPEG.encode(bild, quality: 85)\nshow_image jpeg\njpeg.to_bytes.bytesize"
          },
          {
            "t": "h",
            "html": "<p><code>RawSource.new(96, 64)</code> ruft den Block für jeden Pixel einmal auf: mit <code>x</code> von 0 bis 95 nach rechts und <code>y</code> von 0 bis 63 nach <em>unten</em> – anders als im PDF der letzten Lektion. Der Block liefert die Farbe als <code>[rot, grün, blau]</code>, jeden Wert von 0 bis 255. Die Sonne ist ein Kreis: alle Punkte, die weniger als 18 Pixel von <code>(48, 40)</code> entfernt sind – Pythagoras, ohne Wurzel.</p><p><code>PureJPEG.encode</code> macht daraus ein JPEG, <code>show_image</code> zeigt es, und <code>to_bytes</code> liefert die fertige Datei: rund 1,4 KB. Die rohen Pixel wären 96 × 64 × 3 = 18&nbsp;432 Bytes, gut dreizehnmal so viel. Wie viel JPEG weglässt, bestimmt <code>quality:</code>, von 1 bis 100:</p>"
          },
          {
            "t": "c",
            "code": "[90, 30, 5].each do |qualitaet|\n  daten = PureJPEG.encode(bild, quality: qualitaet).to_bytes\n  show_image daten\n  puts \"quality #{qualitaet}: #{daten.bytesize} Bytes\"\nend"
          },
          {
            "t": "h",
            "html": "<p>Je kleiner die Zahl, desto kleiner die Datei – und desto deutlicher siehst du <strong>Kästchen</strong>. JPEG zerlegt das Bild in Blöcke von 8 × 8 Pixeln und beschreibt jeden Block als Mischung von Wellenmustern, von ganz glatt bis ganz fein (die <em>diskrete Kosinustransformation</em>). Je tiefer die Qualität, desto mehr feine Wellen rundet es weg. Sanfte Verläufe wie der Himmel überstehen das gut, harte Kanten wie der Sonnenrand nicht. Darum: Fotos als JPEG, Logos und Screenshots als PNG.</p><p>pure_jpeg liest JPEGs auch wieder ein:</p>"
          },
          {
            "t": "c",
            "code": "foto = PureJPEG.read(jpeg.to_bytes)\nmitte = foto[48, 40]   # mitten in der Sonne\n[foto.width, foto.height, mitte.r, mitte.g, mitte.b]"
          },
          {
            "t": "h",
            "html": "<p><code>PureJPEG.read</code> nimmt die Bytes oder einen Dateinamen und gibt ein Bild zurück; <code>foto[x, y]</code> ist ein Pixel mit <code>r</code>, <code>g</code> und <code>b</code>. Die Sonne war <code>[255, 210, 60]</code> – zurück kommt fast dasselbe, aber nicht ganz: JPEG ist <strong>verlustbehaftet</strong>, jedes Speichern verliert ein wenig.</p><p><code>PureJPEG.encode</code> nimmt jedes Objekt, das <code>width</code>, <code>height</code> und <code>[x, y]</code> kennt – auch ein gelesenes Foto. So rechnest du Bilder um, zum Beispiel ins Negativ oder in Graustufen:</p>"
          },
          {
            "t": "c",
            "code": "negativ = PureJPEG::Source::RawSource.new(foto.width, foto.height) do |x, y|\n  punkt = foto[x, y]\n  [255 - punkt.r, 255 - punkt.g, 255 - punkt.b]\nend\nshow_image PureJPEG.encode(negativ)\n\nPureJPEG.encode(foto, grayscale: true).write(\"sonne-grau.jpg\")\nshow_image \"sonne-grau.jpg\"\nPureJPEG.info(\"sonne-grau.jpg\")"
          },
          {
            "t": "h",
            "html": "<p><code>write</code> speichert das JPEG als Datei – sie erscheint als Download unter der Zelle, und <code>show_image</code> nimmt auch ihren Namen. <code>PureJPEG.info</code> liest nur den Kopf der Datei, ohne die Pixel zu entpacken: die Grösse und <code>component_count</code>, 1 Kanal für Graustufen, 3 für Farbe.</p><div class='offweb' data-title='Auf deinem Computer'><p><code>gem install pure_jpeg</code>, und <code>write</code> legt eine echte Datei an. Fotos aus der Kamera liest <code>PureJPEG.read(\"ferien.jpg\")</code> genauso, auch progressive JPEGs. Mit chunky_png geht es in beide Richtungen: <code>PureJPEG.from_chunky_png(png, quality: 80)</code> macht aus einem PNG ein JPEG, und mit <code>foto.each_pixel { |x, y, punkt| … }</code> malst du ein JPEG Pixel für Pixel in ein <code>ChunkyPNG::Image</code>.</p><p>Grenzen: EXIF-Daten (Kamera, Datum, GPS) gehen beim Neu-Speichern verloren, und Ruby rechnet die Wellen langsamer als C – für grosse Fotos nimmst du lieber eine C-Bibliothek wie libvips (Gem <code>ruby-vips</code>). Dafür läuft pure_jpeg überall, wo Ruby läuft, sogar hier. Peter Cooper hat es unter der MIT-Lizenz veröffentlicht.</p></div><div class='task'><strong>Aufgabe:</strong> Chunky schickt eine Postkarte aus den Ferien. Schreibe <code>postkarte.jpg</code>, 80 × 60 Pixel: die obere Hälfte himmelblau <code>[100, 160, 230]</code>, die untere Hälfte grasgrün <code>[60, 160, 60]</code>.</div>"
          },
          {
            "t": "x",
            "code": "# postkarte.jpg: 80 × 60, oben himmelblau, unten grasgrün\n",
            "check": "downloads.include?(\"postkarte.jpg\") && PureJPEG.read(\"postkarte.jpg\").then { |img| [img.width, img.height, img[40, 10], img[40, 50]] }.then { |w, h, oben, unten| w == 80 && h == 60 && oben.b > 180 && oben.b > oben.r + 50 && unten.g > 120 && unten.r < 120 && unten.b < 120 }",
            "hint": "Ein <code>PureJPEG::Source::RawSource.new(80, 60) do |x, y| … end</code>, der für <code>y &lt; 30</code> <code>[100, 160, 230]</code> liefert und sonst <code>[60, 160, 60]</code> – dann <code>PureJPEG.encode(…).write(\"postkarte.jpg\")</code>."
          }
        ]
      },
      "en": {
        "title": "22. JPEG photos with pure_jpeg",
        "cells": [
          {
            "t": "h",
            "html": "<h2>JPEG – photos from Ruby</h2><p>In lesson 13 you painted PNG pictures with <code>chunky_png</code>. PNG keeps every pixel <strong>exactly</strong> – ideal for logos, pixel art and screenshots, but huge for photos. That is why almost every photo is a <strong>JPEG</strong>: it leaves out what the eye barely notices, and gets much smaller for it.</p><p>Usually a library written in C does this. <a href='https://github.com/peterc/pure_jpeg' target='_blank'>pure_jpeg</a> by Peter Cooper writes and reads JPEGs in pure Ruby – which is why it runs here in your browser. Let's paint a sunset, pixel by pixel:</p>"
          },
          {
            "t": "c",
            "code": "install_gem \"pure_jpeg\"\nrequire \"pure_jpeg\"\n\npicture = PureJPEG::Source::RawSource.new(96, 64) do |x, y|\n  if (x - 48)**2 + (y - 40)**2 < 18**2\n    [255, 210, 60]                  # the sun\n  else\n    [40 + y * 3, 70 + y, 170 - y]   # the sky, redder further down\n  end\nend\njpeg = PureJPEG.encode(picture, quality: 85)\nshow_image jpeg\njpeg.to_bytes.bytesize"
          },
          {
            "t": "h",
            "html": "<p><code>RawSource.new(96, 64)</code> calls the block once for every pixel: with <code>x</code> from 0 to 95 going right and <code>y</code> from 0 to 63 going <em>down</em> – unlike the PDF in the last lesson. The block returns the colour as <code>[red, green, blue]</code>, each from 0 to 255. The sun is a circle: every point less than 18 pixels away from <code>(48, 40)</code> – Pythagoras, without the square root.</p><p><code>PureJPEG.encode</code> turns it into a JPEG, <code>show_image</code> shows it, and <code>to_bytes</code> returns the finished file: about 1.4 KB. The raw pixels would be 96 × 64 × 3 = 18,432 bytes, more than thirteen times as much. How much JPEG leaves out is up to <code>quality:</code>, from 1 to 100:</p>"
          },
          {
            "t": "c",
            "code": "[90, 30, 5].each do |quality|\n  data = PureJPEG.encode(picture, quality: quality).to_bytes\n  show_image data\n  puts \"quality #{quality}: #{data.bytesize} bytes\"\nend"
          },
          {
            "t": "h",
            "html": "<p>The smaller the number, the smaller the file – and the clearer the <strong>little squares</strong>. JPEG cuts the picture into blocks of 8 × 8 pixels and describes each block as a mix of wave patterns, from completely smooth to very fine (the <em>discrete cosine transform</em>). The lower the quality, the more of the fine waves it rounds away. Smooth gradients like the sky survive that well, hard edges like the rim of the sun do not. Hence: photos as JPEG, logos and screenshots as PNG.</p><p>pure_jpeg reads JPEGs back in, too:</p>"
          },
          {
            "t": "c",
            "code": "photo = PureJPEG.read(jpeg.to_bytes)\nmiddle = photo[48, 40]   # right in the sun\n[photo.width, photo.height, middle.r, middle.g, middle.b]"
          },
          {
            "t": "h",
            "html": "<p><code>PureJPEG.read</code> takes the bytes or a file name and returns a picture; <code>photo[x, y]</code> is a pixel with <code>r</code>, <code>g</code> and <code>b</code>. The sun was <code>[255, 210, 60]</code> – what comes back is almost the same, but not quite: JPEG is <strong>lossy</strong>, every save loses a little.</p><p><code>PureJPEG.encode</code> takes any object that knows <code>width</code>, <code>height</code> and <code>[x, y]</code> – a photo it has read, too. That is how you transform pictures, into a negative, say, or into greyscale:</p>"
          },
          {
            "t": "c",
            "code": "negative = PureJPEG::Source::RawSource.new(photo.width, photo.height) do |x, y|\n  pixel = photo[x, y]\n  [255 - pixel.r, 255 - pixel.g, 255 - pixel.b]\nend\nshow_image PureJPEG.encode(negative)\n\nPureJPEG.encode(photo, grayscale: true).write(\"sun-gray.jpg\")\nshow_image \"sun-gray.jpg\"\nPureJPEG.info(\"sun-gray.jpg\")"
          },
          {
            "t": "h",
            "html": "<p><code>write</code> saves the JPEG as a file – it appears as a download below the cell, and <code>show_image</code> takes its name too. <code>PureJPEG.info</code> only reads the file's header, without unpacking the pixels: the size, and <code>component_count</code> – 1 channel for greyscale, 3 for colour.</p><div class='offweb' data-title='On your machine'><p><code>gem install pure_jpeg</code>, and <code>write</code> creates a real file. <code>PureJPEG.read(\"holiday.jpg\")</code> reads photos from your camera just the same, progressive JPEGs included. With chunky_png it works both ways: <code>PureJPEG.from_chunky_png(png, quality: 80)</code> turns a PNG into a JPEG, and <code>photo.each_pixel { |x, y, pixel| … }</code> lets you paint a JPEG into a <code>ChunkyPNG::Image</code> pixel by pixel.</p><p>Limits: EXIF data (camera, date, GPS) is lost when you save again, and Ruby computes the waves more slowly than C – for big photos, reach for a C library such as libvips (the <code>ruby-vips</code> gem). In return, pure_jpeg runs wherever Ruby runs, even here. Peter Cooper published it under the MIT licence.</p></div><div class='task'><strong>Task:</strong> Chunky is sending a postcard from the holidays. Write <code>postcard.jpg</code>, 80 × 60 pixels: the top half sky blue <code>[100, 160, 230]</code>, the bottom half grass green <code>[60, 160, 60]</code>.</div>"
          },
          {
            "t": "x",
            "code": "# postcard.jpg: 80 × 60, top half sky blue, bottom half grass green\n",
            "check": "downloads.include?(\"postcard.jpg\") && PureJPEG.read(\"postcard.jpg\").then { |img| [img.width, img.height, img[40, 10], img[40, 50]] }.then { |w, h, top, bottom| w == 80 && h == 60 && top.b > 180 && top.b > top.r + 50 && bottom.g > 120 && bottom.r < 120 && bottom.b < 120 }",
            "hint": "A <code>PureJPEG::Source::RawSource.new(80, 60) do |x, y| … end</code> that returns <code>[100, 160, 230]</code> for <code>y &lt; 30</code> and <code>[60, 160, 60]</code> otherwise – then <code>PureJPEG.encode(…).write(\"postcard.jpg\")</code>."
          }
        ]
      },
      "ja": {
        "title": "22. pure_jpegでJPEG写真",
        "cells": [
          {
            "t": "h",
            "html": "<h2>JPEG – Rubyで写真を作る</h2><p>レッスン13では、<code>chunky_png</code>でPNG画像を描きました。PNGはすべてのピクセルを<strong>正確に</strong>保存します。ロゴやドット絵、スクリーンショットには最適ですが、写真だとファイルがとても大きくなります。そこで、ほとんどの写真は<strong>JPEG</strong>です。JPEGは目にはほとんどわからない部分を省くので、ずっと小さくなります。</p><p>ふつうはC言語で書かれたライブラリがこの仕事をします。Peter Cooperさんの<a href='https://github.com/peterc/pure_jpeg' target='_blank'>pure_jpeg</a>は、JPEGの書き出しも読み込みもピュアRubyで行います。だから、このブラウザの中で動くのです。夕焼けを1ピクセルずつ描いてみましょう：</p>"
          },
          {
            "t": "c",
            "code": "install_gem \"pure_jpeg\"\nrequire \"pure_jpeg\"\n\npicture = PureJPEG::Source::RawSource.new(96, 64) do |x, y|\n  if (x - 48)**2 + (y - 40)**2 < 18**2\n    [255, 210, 60]                  # 太陽\n  else\n    [40 + y * 3, 70 + y, 170 - y]   # 空。下へ行くほど赤くなる\n  end\nend\njpeg = PureJPEG.encode(picture, quality: 85)\nshow_image jpeg\njpeg.to_bytes.bytesize"
          },
          {
            "t": "h",
            "html": "<p><code>RawSource.new(96, 64)</code>は、ピクセルごとに1回ずつブロックを呼び出します。<code>x</code>は右へ0から95まで、<code>y</code>は<em>下へ</em>0から63まで進みます。前のレッスンのPDFとは向きが逆です。ブロックは色を<code>[赤, 緑, 青]</code>で返し、それぞれの値は0から255です。太陽は円です。<code>(48, 40)</code>からの距離が18ピクセルより小さい点をすべて塗ります。平方根を使わないピタゴラスの定理です。</p><p><code>PureJPEG.encode</code>がJPEGを作り、<code>show_image</code>がそれを表示し、<code>to_bytes</code>が完成したファイルを返します。約1.4 KBです。生のピクセルなら96 × 64 × 3 = 18,432バイト、13倍以上になります。JPEGがどれだけ省くかは、1から100までの<code>quality:</code>で決まります：</p>"
          },
          {
            "t": "c",
            "code": "[90, 30, 5].each do |quality|\n  data = PureJPEG.encode(picture, quality: quality).to_bytes\n  show_image data\n  puts \"quality #{quality}: #{data.bytesize} bytes\"\nend"
          },
          {
            "t": "h",
            "html": "<p>数字が小さいほどファイルは小さくなり、<strong>四角いブロック</strong>がはっきり見えてきます。JPEGは画像を8 × 8ピクセルのブロックに分け、それぞれを、なめらかなものから細かいものまでの波の模様の組み合わせとして表します（<em>離散コサイン変換</em>）。品質が低いほど、細かい波をたくさん丸めて捨てます。空のようななめらかなグラデーションはほとんど影響を受けませんが、太陽のふちのようなくっきりした境目はくずれます。だから、写真はJPEG、ロゴやスクリーンショットはPNGで保存します。</p><p>pure_jpegはJPEGを読み込むこともできます：</p>"
          },
          {
            "t": "c",
            "code": "photo = PureJPEG.read(jpeg.to_bytes)\nmiddle = photo[48, 40]   # 太陽のまん中\n[photo.width, photo.height, middle.r, middle.g, middle.b]"
          },
          {
            "t": "h",
            "html": "<p><code>PureJPEG.read</code>はバイト列かファイル名を受け取り、画像を返します。<code>photo[x, y]</code>は<code>r</code>、<code>g</code>、<code>b</code>を持つピクセルです。太陽は<code>[255, 210, 60]</code>でしたが、戻ってくる色はほとんど同じでも、まったく同じではありません。JPEGは<strong>非可逆圧縮</strong>で、保存するたびに少しずつ失われるのです。</p><p><code>PureJPEG.encode</code>は、<code>width</code>、<code>height</code>、<code>[x, y]</code>を持つオブジェクトなら何でも受け取ります。読み込んだ写真もそうです。こうして画像を変換できます。たとえば、ネガにしたり、グレースケールにしたり：</p>"
          },
          {
            "t": "c",
            "code": "negative = PureJPEG::Source::RawSource.new(photo.width, photo.height) do |x, y|\n  pixel = photo[x, y]\n  [255 - pixel.r, 255 - pixel.g, 255 - pixel.b]\nend\nshow_image PureJPEG.encode(negative)\n\nPureJPEG.encode(photo, grayscale: true).write(\"sun-gray.jpg\")\nshow_image \"sun-gray.jpg\"\nPureJPEG.info(\"sun-gray.jpg\")"
          },
          {
            "t": "h",
            "html": "<p><code>write</code>はJPEGをファイルに保存します。ファイルはセルの下にダウンロードとして現れ、<code>show_image</code>にはファイル名を渡すこともできます。<code>PureJPEG.info</code>はピクセルを展開せずに、ファイルの先頭部分だけを読みます。サイズと<code>component_count</code>、つまりグレースケールなら1チャンネル、カラーなら3チャンネルです。</p><div class='offweb' data-title='自分のコンピューターでは'><p><code>gem install pure_jpeg</code>を実行すれば、<code>write</code>で本物のファイルが作られます。カメラで撮った写真も<code>PureJPEG.read(\"holiday.jpg\")</code>で同じように読めます。プログレッシブJPEGも大丈夫です。chunky_pngとは両方向に変換できます。<code>PureJPEG.from_chunky_png(png, quality: 80)</code>はPNGからJPEGを作り、<code>photo.each_pixel { |x, y, pixel| … }</code>を使えばJPEGを1ピクセルずつ<code>ChunkyPNG::Image</code>に描き写せます。</p><p>限界もあります。保存し直すとEXIFデータ（カメラ、日付、GPS）は失われますし、RubyはCより波の計算が遅いので、大きな写真にはlibvips（gemは<code>ruby-vips</code>）のようなCのライブラリが向いています。そのかわり、pure_jpegはRubyが動くところならどこでも、ここでさえ動きます。Peter CooperさんがMITライセンスで公開しています。</p></div><div class='task'><strong>課題：</strong>Chunkyが旅先からポストカードを送ります。80 × 60ピクセルの<code>postcard.jpg</code>を書き出しましょう。上半分は空色<code>[100, 160, 230]</code>、下半分は草色<code>[60, 160, 60]</code>です。</div>"
          },
          {
            "t": "x",
            "code": "# postcard.jpg：80 × 60、上半分は空色、下半分は草色\n",
            "check": "downloads.include?(\"postcard.jpg\") && PureJPEG.read(\"postcard.jpg\").then { |img| [img.width, img.height, img[40, 10], img[40, 50]] }.then { |w, h, top, bottom| w == 80 && h == 60 && top.b > 180 && top.b > top.r + 50 && bottom.g > 120 && bottom.r < 120 && bottom.b < 120 }",
            "hint": "<code>PureJPEG::Source::RawSource.new(80, 60) do |x, y| … end</code>で、<code>y &lt; 30</code>なら<code>[100, 160, 230]</code>、それ以外なら<code>[60, 160, 60]</code>を返すようにしてみて。最後に<code>PureJPEG.encode(…).write(\"postcard.jpg\")</code>だよ。"
          }
        ]
      }
    },
    {
      "id": "pycall",
      "de": {
        "title": "23. PyCall: pandas aus Ruby",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Ruby trifft Python</h2><p>Python hat ein paar Bibliotheken, die alle gern benutzen. Die bekannteste ist <strong>pandas</strong>: eine Tabellenkalkulation, die du mit Code steuerst. Du legst Daten in eine Tabelle, und mit einer Zeile sortierst du sie, zählst eine Spalte zusammen, behältst nur einen Teil der Zeilen oder zählst nach.</p><p>Mit dem Gem <a href='https://github.com/mrkn/pycall.rb' target='_blank'>pycall</a> von Kenta Murata benutzt Ruby Python-Bibliotheken, als wären es Ruby-Objekte. Du schreibst Ruby; pycall reicht jeden Aufruf an Python weiter und bringt die Antwort zurück.</p><p>Hier im Browser läuft Python als <a href='https://pyodide.org' target='_blank'>Pyodide</a> – CPython in WebAssembly, gleich neben unserem Ruby. Es wird geladen, sobald du diese Lektion öffnest (einmalig rund 12 MB). Eine Zelle, die du vorher startest, wartet einfach darauf.</p>"
          },
          {
            "t": "c",
            "code": "require \"pycall\"\n\npd = PyCall.import_module(\"pandas\")\npd.__version__"
          },
          {
            "t": "h",
            "html": "<p><code>PyCall.import_module(\"pandas\")</code> ist Rubys Art, Pythons <code>import pandas as pd</code> zu sagen. Was zurückkommt, <code>pd</code>, ist ein Ruby-Objekt, das für das Python-Modul steht, und alles darin erreichst du mit dem Punkt. <code>pd.__version__</code> ist ein Python-String und kommt als ganz normaler Ruby-String an.</p><p>Die Dokumentation von pandas zeigt Python-Code. Mit einer Handvoll Regeln wird daraus Ruby:</p><table class='cheat'><thead><tr><th>Python</th><th>Ruby mit pycall</th></tr></thead><tbody><tr><td><code>import pandas as pd</code></td><td><code>pd = PyCall.import_module(\"pandas\")</code></td></tr><tr><td><code>pd.DataFrame(data)</code></td><td><code>pd.DataFrame.new(data)</code></td></tr><tr><td><code>sort_values(\"x\", ascending=False)</code></td><td><code>sort_values(\"x\", ascending: false)</code></td></tr><tr><td><code>True  False  None</code></td><td><code>true  false  nil</code></td></tr><tr><td><code>{\"a\": [1, 2]}</code></td><td><code>{\"a\" =&gt; [1, 2]}</code></td></tr><tr><td><code>df[\"price\"]</code></td><td><code>df[\"price\"]</code> <em>gleich</em></td></tr></tbody></table><p>Jetzt die erste Tabelle. In pandas heisst eine Tabelle <strong>DataFrame</strong>, und du kannst sie aus einem Ruby-Hash bauen:</p>"
          },
          {
            "t": "c",
            "code": "fruehstueck = pd.DataFrame.new({\n  \"essen\" => [\"Speck\", \"Eier\", \"Toast\", \"Kaffee\"],\n  \"preis\" => [4.5, 2.0, 1.5, 3.0],\n  \"menge\" => [2, 3, 2, 4]\n})"
          },
          {
            "t": "h",
            "html": "<p>Jeder Schlüssel des Hashs wird eine Spalte, und sein Array füllt sie von oben nach unten – darum müssen alle Arrays gleich lang sein. Die Zahlen 0 bis 3 links sind der <em>Index</em>: pandas nummeriert die Zeilen für dich. Was du unter der Zelle siehst, ist die Tabelle von pandas selbst, genau wie in einem Python-Notebook.</p><p>Eckige Klammern mit dem Namen einer Spalte geben dir diese eine Spalte:</p>"
          },
          {
            "t": "c",
            "code": "fruehstueck[\"preis\"]"
          },
          {
            "t": "h",
            "html": "<p>Eine einzelne Spalte heisst <strong>Series</strong>: die Werte, mit ihren Zeilennummern daneben. Ein falscher Name wie <code>fruehstueck[\"pries\"]</code> lässt Python einen <code>KeyError</code> werfen, und der kommt in Ruby als <code>PyCall::PyError</code> an.</p><p>Mit einer ganzen Series rechnest du auf einmal – ohne Schleife. <code>*</code> multipliziert zwei Spalten Zeile für Zeile (4.5 × 2, 2.0 × 3, …), und <code>[]=</code> legt das Ergebnis als neue Spalte ab:</p>"
          },
          {
            "t": "c",
            "code": "fruehstueck[\"summe\"] = fruehstueck[\"preis\"] * fruehstueck[\"menge\"]\nfruehstueck.sort_values(\"summe\", ascending: false)"
          },
          {
            "t": "h",
            "html": "<p>In reinem Ruby, mit einem Array aus Hashes, wäre das eine Schleife: <code>zeilen.each { |z| z[:summe] = z[:preis] * z[:menge] }</code>. pandas erledigt die ganze Spalte in einem Zug.</p><p><code>sort_values(\"summe\", ascending: false)</code> sortiert nach dieser Spalte, die grösste zuerst. Python schreibt <code>ascending=False</code>; pycall macht aus Rubys Keyword-Argumenten die von Python.</p><p>Ist die Antwort ein einzelner Wert, bekommst du einen Ruby-Wert zurück:</p>"
          },
          {
            "t": "c",
            "code": "gesamt = fruehstueck[\"summe\"].sum\nputs \"Gesamt: #{gesamt} Fr.\"\ngesamt.class"
          },
          {
            "t": "h",
            "html": "<p><code>sum</code> zählt die Spalte zusammen, und das Ergebnis ist ein ganz normales Ruby-<code>Float</code> – du kannst es runden, formatieren oder vergleichen wie jede andere Zahl.</p><p>Zeilen auswählen geht in zwei Schritten. Zuerst stellst du jeder Zeile eine Frage:</p>"
          },
          {
            "t": "c",
            "code": "teuer = fruehstueck[\"preis\"] > 2"
          },
          {
            "t": "h",
            "html": "<p>Die Antwort ist eine Series aus <code>True</code> und <code>False</code>, eine pro Zeile: Liegt dieser Preis über 2? Steckst du diese Series in eckige Klammern, behält pandas nur die Zeilen mit <code>True</code>:</p>"
          },
          {
            "t": "c",
            "code": "fruehstueck[teuer]"
          },
          {
            "t": "h",
            "html": "<p>Speck und Kaffee bleiben übrig. Zurück nach Ruby geht es so: die Spalte nehmen, mit <code>tolist</code> eine Python-Liste daraus machen und mit <code>to_a</code> ein Ruby-Array:</p>"
          },
          {
            "t": "c",
            "code": "fruehstueck[teuer][\"essen\"].tolist.to_a"
          },
          {
            "t": "h",
            "html": "<p>Ab hier ist alles wieder Ruby: <code>map</code>, <code>join</code>, <code>each</code> – was du willst.</p><p>Richtig stark ist pandas beim Zählen und Gruppieren. Hier die Bestellungen eines kleinen Lokals – welcher Tisch was bestellt hat:</p>"
          },
          {
            "t": "c",
            "code": "bestellungen = pd.DataFrame.new({\n  \"tisch\" => [1, 2, 1, 3, 2, 1],\n  \"essen\" => [\"Speck\", \"Eier\", \"Kaffee\", \"Speck\", \"Speck\", \"Toast\"]\n})\nbestellungen[\"essen\"].value_counts"
          },
          {
            "t": "h",
            "html": "<p><code>value_counts</code> zählt, wie oft jeder Wert vorkommt, den häufigsten zuerst: Speck wurde dreimal bestellt. Jetzt pro Tisch. Lies die nächste Zeile von links nach rechts: <code>groupby(\"tisch\")</code> steckt die Zeilen jedes Tischs in eine Gruppe, <code>[\"essen\"]</code> nimmt die Spalte mit dem Essen, und <code>count</code> zählt in jeder Gruppe:</p>"
          },
          {
            "t": "c",
            "code": "bestellungen.groupby(\"tisch\")[\"essen\"].count"
          },
          {
            "t": "h",
            "html": "<p>Tisch 1 hat drei Sachen bestellt, Tisch 2 zwei, Tisch 3 eine. In reinem Ruby, mit einem Array aus Hashes, schriebst du:</p><pre>bestellungen.group_by { |b| b[:tisch] }.transform_values(&amp;:size)</pre><p>pandas macht das für eine ganze Tabelle, und statt <code>count</code> gehen auch <code>sum</code>, <code>mean</code> (der Durchschnitt), <code>max</code> und viele mehr.</p><div class='offweb' data-title='Auf deinem Computer'><p>Du brauchst Python mit pandas (<code>pip install pandas</code>) und das Gem: <code>gem install pycall</code>. Der Code dieser Lektion läuft dann unverändert – pycall lädt die Python-Bibliothek in dein Ruby-Programm, und welches Python es nimmt, bestimmt die Umgebungsvariable <code>PYTHON</code>. Hier im Browser übernimmt eine kleine Brücke diese Rolle und spricht über JavaScript mit Pyodide; Ruby-Blöcke als Python-Funktionen kann sie nicht übergeben.</p><p>Für kleine Tabellen reichen Rubys eigene Mittel – CSV und Hashes – weit. pycall lohnt sich, wenn Python etwas hat, das Ruby fehlt: pandas, scikit-learn, matplotlib. pandas und numpy stehen unter der BSD-Lizenz, Pyodide unter der Mozilla Public License 2.0.</p></div><div class='task'><strong>Aufgabe:</strong> Wie viel hat jeder Gast ausgegeben? Zähle mit <code>groupby</code> den <code>preis</code> pro <code>gast</code> zusammen und mach daraus einen Ruby-Hash <code>ausgaben</code>, etwa <code>{\"Isi\" =&gt; …, \"Kaz\" =&gt; …}</code>.</div>"
          },
          {
            "t": "x",
            "code": "require \"pycall\"\npd = PyCall.import_module(\"pandas\")\n\nrechnung = pd.DataFrame.new({\n  \"gast\"  => [\"Kaz\", \"Isi\", \"Kaz\", \"Isi\", \"Kaz\"],\n  \"preis\" => [4.5, 2.0, 3.0, 4.5, 3.5]\n})\n# ausgaben = ...   (ein Ruby-Hash: Gast => Summe)\n",
            "check": "ausgaben.is_a?(Hash) && ausgaben.transform_values(&:to_f) == { \"Isi\" => 6.5, \"Kaz\" => 11.0 } && code.include?(\"groupby\")",
            "hint": "Schritt für Schritt: Führ zuerst nur <code>rechnung.groupby(\"gast\")[\"preis\"].sum</code> aus und schau es dir an – eine Series mit einer Summe pro Gast. Dann macht <code>.to_dict</code> daraus ein Python-<code>dict</code> und <code>.to_h</code> einen Ruby-Hash."
          }
        ]
      },
      "en": {
        "title": "23. PyCall: pandas from Ruby",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Ruby meets Python</h2><p>Python has a few libraries that everybody wants to use. The best known is <strong>pandas</strong>: think of a spreadsheet you drive with code. You put data into a table, and with one line you sort it, add up a column, keep only some of the rows or count things.</p><p>The <a href='https://github.com/mrkn/pycall.rb' target='_blank'>pycall</a> gem by Kenta Murata lets Ruby use Python libraries as if they were Ruby objects. You write Ruby; pycall hands every call to Python and brings the answer back.</p><p>Here in the browser, Python runs as <a href='https://pyodide.org' target='_blank'>Pyodide</a> – CPython in WebAssembly, right next to our Ruby. It starts loading when you open this lesson (once, about 12 MB). A cell you run before it is ready simply waits.</p>"
          },
          {
            "t": "c",
            "code": "require \"pycall\"\n\npd = PyCall.import_module(\"pandas\")\npd.__version__"
          },
          {
            "t": "h",
            "html": "<p><code>PyCall.import_module(\"pandas\")</code> is Ruby's way of saying Python's <code>import pandas as pd</code>. What comes back, <code>pd</code>, is a Ruby object that stands for the Python module, and you reach everything in it with a dot. <code>pd.__version__</code> is a Python string, and it arrives as an ordinary Ruby string.</p><p>The pandas documentation shows Python code. A handful of rules translate it to Ruby:</p><table class='cheat'><thead><tr><th>Python</th><th>Ruby with pycall</th></tr></thead><tbody><tr><td><code>import pandas as pd</code></td><td><code>pd = PyCall.import_module(\"pandas\")</code></td></tr><tr><td><code>pd.DataFrame(data)</code></td><td><code>pd.DataFrame.new(data)</code></td></tr><tr><td><code>sort_values(\"x\", ascending=False)</code></td><td><code>sort_values(\"x\", ascending: false)</code></td></tr><tr><td><code>True  False  None</code></td><td><code>true  false  nil</code></td></tr><tr><td><code>{\"a\": [1, 2]}</code></td><td><code>{\"a\" =&gt; [1, 2]}</code></td></tr><tr><td><code>df[\"price\"]</code></td><td><code>df[\"price\"]</code> <em>the same</em></td></tr></tbody></table><p>Now our first table. In pandas a table is called a <strong>DataFrame</strong>, and you can build one from a Ruby hash:</p>"
          },
          {
            "t": "c",
            "code": "breakfast = pd.DataFrame.new({\n  \"food\"     => [\"Bacon\", \"Eggs\", \"Toast\", \"Coffee\"],\n  \"price\"    => [4.5, 2.0, 1.5, 3.0],\n  \"quantity\" => [2, 3, 2, 4]\n})"
          },
          {
            "t": "h",
            "html": "<p>Every key of the hash becomes a column, and its array fills that column from top to bottom – so all arrays need the same length. The numbers 0 to 3 on the left are the <em>index</em>: pandas numbers the rows for you. What you see below the cell is pandas' own table, just like in a Python notebook.</p><p>Square brackets with a column's name give you that one column:</p>"
          },
          {
            "t": "c",
            "code": "breakfast[\"price\"]"
          },
          {
            "t": "h",
            "html": "<p>A single column is called a <strong>Series</strong>: the values, with their row numbers next to them. A wrong name such as <code>breakfast[\"prise\"]</code> makes Python raise a <code>KeyError</code>, and it reaches Ruby as a <code>PyCall::PyError</code>.</p><p>You compute with a whole Series at once – no loop needed. <code>*</code> multiplies two columns row by row (4.5 × 2, 2.0 × 3, …), and <code>[]=</code> stores the result as a new column:</p>"
          },
          {
            "t": "c",
            "code": "breakfast[\"total\"] = breakfast[\"price\"] * breakfast[\"quantity\"]\nbreakfast.sort_values(\"total\", ascending: false)"
          },
          {
            "t": "h",
            "html": "<p>In plain Ruby, with an array of hashes, that would be a loop: <code>rows.each { |r| r[:total] = r[:price] * r[:quantity] }</code>. pandas does the whole column in one go.</p><p><code>sort_values(\"total\", ascending: false)</code> sorts by that column, the largest first. Python writes <code>ascending=False</code>; pycall turns Ruby's keyword arguments into Python's.</p><p>When the answer is a single value, you get a Ruby value back:</p>"
          },
          {
            "t": "c",
            "code": "total = breakfast[\"total\"].sum\nputs \"Total: $#{total}\"\ntotal.class"
          },
          {
            "t": "h",
            "html": "<p><code>sum</code> adds up the column, and the result is a plain Ruby <code>Float</code> – you can round it, format it or compare it like any other number.</p><p>Picking rows takes two steps. First, ask every row a question:</p>"
          },
          {
            "t": "c",
            "code": "pricey = breakfast[\"price\"] > 2"
          },
          {
            "t": "h",
            "html": "<p>The answer is a Series of <code>True</code> and <code>False</code>, one per row: is this price above 2? Put that Series into square brackets, and pandas keeps only the rows marked <code>True</code>:</p>"
          },
          {
            "t": "c",
            "code": "breakfast[pricey]"
          },
          {
            "t": "h",
            "html": "<p>Bacon and coffee are left. To get back to Ruby, take the column, turn it into a Python list with <code>tolist</code>, and that into a Ruby array with <code>to_a</code>:</p>"
          },
          {
            "t": "c",
            "code": "breakfast[pricey][\"food\"].tolist.to_a"
          },
          {
            "t": "h",
            "html": "<p>From here on it's all Ruby again: <code>map</code>, <code>join</code>, <code>each</code> – whatever you like.</p><p>Where pandas really shines is counting and grouping. Here are the orders of a small diner – which table ordered what:</p>"
          },
          {
            "t": "c",
            "code": "orders = pd.DataFrame.new({\n  \"table\" => [1, 2, 1, 3, 2, 1],\n  \"food\"  => [\"Bacon\", \"Eggs\", \"Coffee\", \"Bacon\", \"Bacon\", \"Toast\"]\n})\norders[\"food\"].value_counts"
          },
          {
            "t": "h",
            "html": "<p><code>value_counts</code> counts how often each value appears, the most frequent first: bacon was ordered three times. Now per table. Read the next line from left to right: <code>groupby(\"table\")</code> puts the rows of each table into a group, <code>[\"food\"]</code> takes the food column, and <code>count</code> counts within each group:</p>"
          },
          {
            "t": "c",
            "code": "orders.groupby(\"table\")[\"food\"].count"
          },
          {
            "t": "h",
            "html": "<p>Table 1 ordered three things, table 2 two, table 3 one. In plain Ruby, with an array of hashes, you would write:</p><pre>orders.group_by { |o| o[:table] }.transform_values(&amp;:size)</pre><p>pandas does it for a whole table, and instead of <code>count</code> you can use <code>sum</code>, <code>mean</code> (the average), <code>max</code> and many more.</p><div class='offweb' data-title='On your machine'><p>You need Python with pandas (<code>pip install pandas</code>) and the gem: <code>gem install pycall</code>. This lesson's code then runs unchanged – pycall loads the Python library into your Ruby program, and the <code>PYTHON</code> environment variable decides which Python it uses. Here in the browser a small bridge plays that part and talks to Pyodide through JavaScript; it cannot pass Ruby blocks to Python as functions.</p><p>For small tables, Ruby's own tools – CSV and hashes – go a long way. pycall pays off when Python has something Ruby lacks: pandas, scikit-learn, matplotlib. pandas and numpy come under the BSD licence, Pyodide under the Mozilla Public License 2.0.</p></div><div class='task'><strong>Task:</strong> How much did each guest spend? Use <code>groupby</code> to add up <code>price</code> per <code>guest</code>, and turn the result into a Ruby hash <code>spending</code>, such as <code>{\"Isi\" =&gt; …, \"Kaz\" =&gt; …}</code>.</div>"
          },
          {
            "t": "x",
            "code": "require \"pycall\"\npd = PyCall.import_module(\"pandas\")\n\nbill = pd.DataFrame.new({\n  \"guest\" => [\"Kaz\", \"Isi\", \"Kaz\", \"Isi\", \"Kaz\"],\n  \"price\" => [4.5, 2.0, 3.0, 4.5, 3.5]\n})\n# spending = ...   (a Ruby hash: guest => total)\n",
            "check": "spending.is_a?(Hash) && spending.transform_values(&:to_f) == { \"Isi\" => 6.5, \"Kaz\" => 11.0 } && code.include?(\"groupby\")",
            "hint": "Take it step by step: first run <code>bill.groupby(\"guest\")[\"price\"].sum</code> on its own and look at it – a Series with one total per guest. Then <code>.to_dict</code> turns it into a Python <code>dict</code>, and <code>.to_h</code> into a Ruby hash."
          }
        ]
      },
      "ja": {
        "title": "23. PyCall：Rubyからpandas",
        "cells": [
          {
            "t": "h",
            "html": "<h2>RubyとPythonの出会い</h2><p>Pythonには、みんなが使いたがるライブラリがいくつかあります。いちばん有名なのが<strong>pandas</strong>です。コードで操作する表計算ソフトだと思ってください。データを表に入れれば、1行で並べ替えたり、列を合計したり、一部の行だけを残したり、数を数えたりできます。</p><p>村田賢太さんの<a href='https://github.com/mrkn/pycall.rb' target='_blank'>pycall</a> gemを使うと、RubyからPythonのライブラリを、まるでRubyのオブジェクトのように使えます。あなたが書くのはRubyです。pycallが呼び出しをひとつずつPythonに渡し、答えを持ち帰ります。</p><p>このブラウザの中では、Pythonは<a href='https://pyodide.org' target='_blank'>Pyodide</a>として動きます。WebAssemblyで動くCPythonで、私たちのRubyのすぐ隣にいます。このレッスンを開くと読み込みが始まります（初回のみ約12 MB）。準備ができる前に実行したセルは、そのまま待ちます。</p>"
          },
          {
            "t": "c",
            "code": "require \"pycall\"\n\npd = PyCall.import_module(\"pandas\")\npd.__version__"
          },
          {
            "t": "h",
            "html": "<p><code>PyCall.import_module(\"pandas\")</code>は、Pythonの<code>import pandas as pd</code>をRubyで言ったものです。返ってくる<code>pd</code>はPythonのモジュールを表すRubyのオブジェクトで、中のものにはすべてドットで届きます。<code>pd.__version__</code>はPythonの文字列で、ふつうのRubyの文字列として届きます。</p><p>pandasのドキュメントにはPythonのコードが載っています。いくつかの決まりを覚えれば、Rubyに書き直せます：</p><table class='cheat'><thead><tr><th>Python</th><th>pycallを使ったRuby</th></tr></thead><tbody><tr><td><code>import pandas as pd</code></td><td><code>pd = PyCall.import_module(\"pandas\")</code></td></tr><tr><td><code>pd.DataFrame(data)</code></td><td><code>pd.DataFrame.new(data)</code></td></tr><tr><td><code>sort_values(\"x\", ascending=False)</code></td><td><code>sort_values(\"x\", ascending: false)</code></td></tr><tr><td><code>True  False  None</code></td><td><code>true  false  nil</code></td></tr><tr><td><code>{\"a\": [1, 2]}</code></td><td><code>{\"a\" =&gt; [1, 2]}</code></td></tr><tr><td><code>df[\"price\"]</code></td><td><code>df[\"price\"]</code> <em>同じ</em></td></tr></tbody></table><p>では最初の表です。pandasでは表を<strong>DataFrame</strong>と呼び、Rubyのハッシュから作れます：</p>"
          },
          {
            "t": "c",
            "code": "breakfast = pd.DataFrame.new({\n  \"food\"     => [\"Bacon\", \"Eggs\", \"Toast\", \"Coffee\"],\n  \"price\"    => [4.5, 2.0, 1.5, 3.0],\n  \"quantity\" => [2, 3, 2, 4]\n})"
          },
          {
            "t": "h",
            "html": "<p>ハッシュのキーがそれぞれ列になり、その配列が列を上から順に埋めます。ですから、配列はすべて同じ長さでなければなりません。左側の0から3は<em>インデックス</em>で、pandasが行に番号を振ってくれます。セルの下に見えているのはpandas自身の表で、Pythonのノートブックと同じものです。</p><p>角かっこに列の名前を入れると、その列だけが取り出せます：</p>"
          },
          {
            "t": "c",
            "code": "breakfast[\"price\"]"
          },
          {
            "t": "h",
            "html": "<p>1つの列は<strong>Series</strong>と呼ばれます。値と、その横の行番号です。<code>breakfast[\"prise\"]</code>のように名前をまちがえると、Pythonが<code>KeyError</code>を出し、それはRubyに<code>PyCall::PyError</code>として届きます。</p><p>Series全体を一度に計算できるので、ループはいりません。<code>*</code>は2つの列を行ごとに掛け算し（4.5 × 2、2.0 × 3、…）、<code>[]=</code>でその結果を新しい列として保存します：</p>"
          },
          {
            "t": "c",
            "code": "breakfast[\"total\"] = breakfast[\"price\"] * breakfast[\"quantity\"]\nbreakfast.sort_values(\"total\", ascending: false)"
          },
          {
            "t": "h",
            "html": "<p>ふつうのRubyで、ハッシュの配列を使うなら、ループになります：<code>rows.each { |r| r[:total] = r[:price] * r[:quantity] }</code>。pandasは列全体を一度に処理します。</p><p><code>sort_values(\"total\", ascending: false)</code>はその列で、大きい順に並べ替えます。Pythonでは<code>ascending=False</code>と書きます。pycallがRubyのキーワード引数をPythonのキーワード引数に変えてくれます。</p><p>答えが1つの値なら、Rubyの値が返ってきます：</p>"
          },
          {
            "t": "c",
            "code": "total = breakfast[\"total\"].sum\nputs \"Total: $#{total}\"\ntotal.class"
          },
          {
            "t": "h",
            "html": "<p><code>sum</code>は列を合計し、その結果はふつうのRubyの<code>Float</code>です。ほかの数と同じように、丸めたり、整形したり、比べたりできます。</p><p>行を選ぶのは2段階です。まず、すべての行に質問をします：</p>"
          },
          {
            "t": "c",
            "code": "pricey = breakfast[\"price\"] > 2"
          },
          {
            "t": "h",
            "html": "<p>答えは<code>True</code>と<code>False</code>のSeriesで、1行に1つずつです。この値段は2より高い？ このSeriesを角かっこに入れると、pandasは<code>True</code>の行だけを残します：</p>"
          },
          {
            "t": "c",
            "code": "breakfast[pricey]"
          },
          {
            "t": "h",
            "html": "<p>ベーコンとコーヒーが残りました。Rubyに戻るには、列を取り出し、<code>tolist</code>でPythonのリストに、<code>to_a</code>でRubyの配列にします：</p>"
          },
          {
            "t": "c",
            "code": "breakfast[pricey][\"food\"].tolist.to_a"
          },
          {
            "t": "h",
            "html": "<p>ここから先はまたすべてRubyです。<code>map</code>でも<code>join</code>でも<code>each</code>でも、好きに使えます。</p><p>pandasがいちばん力を発揮するのは、数えることとグループ分けです。小さな食堂の注文を見てみましょう。どのテーブルが何を頼んだかです：</p>"
          },
          {
            "t": "c",
            "code": "orders = pd.DataFrame.new({\n  \"table\" => [1, 2, 1, 3, 2, 1],\n  \"food\"  => [\"Bacon\", \"Eggs\", \"Coffee\", \"Bacon\", \"Bacon\", \"Toast\"]\n})\norders[\"food\"].value_counts"
          },
          {
            "t": "h",
            "html": "<p><code>value_counts</code>は、それぞれの値が何回出てくるかを、多い順に数えます。ベーコンは3回注文されました。次はテーブルごとです。次の行は左から右へ読みます。<code>groupby(\"table\")</code>がテーブルごとに行をグループにまとめ、<code>[\"food\"]</code>が料理の列を取り、<code>count</code>がグループごとに数えます：</p>"
          },
          {
            "t": "c",
            "code": "orders.groupby(\"table\")[\"food\"].count"
          },
          {
            "t": "h",
            "html": "<p>テーブル1は3品、テーブル2は2品、テーブル3は1品を頼みました。ふつうのRubyで、ハッシュの配列なら、こう書きます：</p><pre>orders.group_by { |o| o[:table] }.transform_values(&amp;:size)</pre><p>pandasはこれを表全体に対して行います。<code>count</code>の代わりに<code>sum</code>、<code>mean</code>（平均）、<code>max</code>なども使えます。</p><div class='offweb' data-title='自分のコンピューターでは'><p>pandas入りのPython（<code>pip install pandas</code>）とgem（<code>gem install pycall</code>）が必要です。そうすれば、このレッスンのコードはそのまま動きます。pycallはPythonのライブラリをRubyプログラムの中に読み込み、どのPythonを使うかは環境変数<code>PYTHON</code>で決まります。このブラウザでは、小さなブリッジがその役を引き受け、JavaScriptを通してPyodideと話しています。RubyのブロックをPythonの関数として渡すことはできません。</p><p>小さな表なら、Ruby自身の道具、CSVやハッシュでも十分です。pycallが役に立つのは、RubyにないものがPythonにあるとき、つまりpandas、scikit-learn、matplotlibなどです。pandasとnumpyはBSDライセンス、PyodideはMozilla Public License 2.0です。</p></div><div class='task'><strong>課題：</strong>それぞれのお客さんはいくら使ったでしょう？ <code>groupby</code>を使って<code>guest</code>ごとに<code>price</code>を合計し、その結果をRubyのハッシュ<code>spending</code>にしましょう。たとえば<code>{\"Isi\" =&gt; …, \"Kaz\" =&gt; …}</code>のようになります。</div>"
          },
          {
            "t": "x",
            "code": "require \"pycall\"\npd = PyCall.import_module(\"pandas\")\n\nbill = pd.DataFrame.new({\n  \"guest\" => [\"Kaz\", \"Isi\", \"Kaz\", \"Isi\", \"Kaz\"],\n  \"price\" => [4.5, 2.0, 3.0, 4.5, 3.5]\n})\n# spending = ...   （Rubyのハッシュ：客 => 合計）\n",
            "check": "spending.is_a?(Hash) && spending.transform_values(&:to_f) == { \"Isi\" => 6.5, \"Kaz\" => 11.0 } && code.include?(\"groupby\")",
            "hint": "一歩ずついこう。まず<code>bill.groupby(\"guest\")[\"price\"].sum</code>だけを実行して、中身を見てみて。お客さんごとの合計が入ったSeriesだよ。それから<code>.to_dict</code>でPythonの<code>dict</code>に、<code>.to_h</code>でRubyのハッシュにするんだ。"
          }
        ]
      }
    },
    {
      "id": "sympy",
      "de": {
        "title": "24. SymPy: Mathe mit Symbolen",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Mathe mit Symbolen</h2><p>Computer rechnen meist mit Zahlen, und Kommazahlen werden gerundet – probier in Ruby <code>0.1 + 0.2</code>. <a href='https://www.sympy.org' target='_blank'>SymPy</a> rechnet so, wie du auf Papier rechnest: mit Brüchen, Wurzeln und Buchstaben wie <code>x</code>. Es multipliziert Klammern aus, löst Gleichungen und bildet Ableitungen, und jede Antwort ist exakt.</p><p>SymPy ist eine Python-Bibliothek, also benutzen wir es über pycall, genau wie pandas in Lektion 23: <code>PyCall.import_module</code>, ein Punkt für alles darin. Beim ersten Mal lädt es rund 5 MB.</p>"
          },
          {
            "t": "c",
            "code": "require \"pycall\"\nsp = PyCall.import_module(\"sympy\")\n\nputs 0.1 + 0.2\nsp.Rational.new(1, 10) + sp.Rational.new(2, 10)"
          },
          {
            "t": "h",
            "html": "<p>Das Float liegt ein klein wenig daneben; SymPys <code>Rational</code> – eine Klasse, also <code>.new</code>, wie bei <code>DataFrame</code> – ist genau 3/10. (Auch Ruby hat exakte Brüche: <code>1/10r + 2/10r</code>. SymPy geht viel weiter.) Auch Wurzeln bleiben exakt:</p>"
          },
          {
            "t": "c",
            "code": "puts sp.sqrt(8)\nputs sp.sqrt(2) * sp.sqrt(2)\nsp.sqrt(2).evalf(50)"
          },
          {
            "t": "h",
            "html": "<p><code>sqrt(8)</code> wird zu <code>2*sqrt(2)</code> vereinfacht, und √2 · √2 ist genau 2 – nicht 2.0000000000000004. Willst du doch eine Kommazahl, rechnet <code>evalf</code> sie aus, mit so vielen Stellen, wie du willst: hier 50.</p><p>Jetzt die Buchstaben. <code>sp.symbols(\"x\")</code> macht ein <strong>Symbol</strong>: ein <code>x</code>, das für eine beliebige Zahl steht. Du rechnest damit wie mit einer Zahl und bekommst eine Formel zurück:</p>"
          },
          {
            "t": "c",
            "code": "x = sp.symbols(\"x\")\nterm = (x + 1) ** 2\nputs term\nputs sp.expand(term)\nsp.factor(x ** 2 - 9)"
          },
          {
            "t": "h",
            "html": "<p><code>expand</code> multipliziert die Klammern aus: (x + 1)² = x² + 2x + 1. <code>factor</code> geht den umgekehrten Weg und findet die Klammern. SymPy schreibt Potenzen mit <code>**</code>, wie Ruby, und <code>*</code> für «mal»: <code>2*x</code> ist 2x.</p><p>Eine Formel auf einer Zeile liest sich schwer. <code>sp.pretty</code> zeichnet sie so, wie sie im Buch aussieht:</p>"
          },
          {
            "t": "c",
            "code": "puts sp.pretty((x + 1) / (x - 1), use_unicode: false)\nputs\nputs sp.pretty(sp.sqrt(x ** 2 + 1) + 3 * x ** 3, use_unicode: false)"
          },
          {
            "t": "h",
            "html": "<p><code>use_unicode: false</code> zeichnet mit einfachen Zeichen – <code>/</code>, <code>&#92;</code> und <code>-</code> –, die in jeder Schrift sauber untereinanderstehen. <code>3 * x ** 3</code> klappt, obwohl die 3 eine Ruby-Zahl ist: Ruby fragt das <code>x</code>, was zu tun ist (<code>coerce</code>), und pycall gibt die Rechnung an Python weiter.</p><p>Jetzt das Lösen. <code>sp.solve(ausdruck, x)</code> findet jedes <code>x</code>, für das der Ausdruck 0 ist. Für x² − 5x + 6 = 0 schreibst du also:</p>"
          },
          {
            "t": "c",
            "code": "sp.solve(x ** 2 - 5 * x + 6, x)"
          },
          {
            "t": "h",
            "html": "<p>Zwei Antworten, 2 und 3. Prüfen wir sie: <code>subs</code> setzt eine Zahl für <code>x</code> ein. Ein Ruby-Block drumherum funktioniert wie immer:</p>"
          },
          {
            "t": "c",
            "code": "gleichung = x ** 2 - 5 * x + 6\n[2, 3, 4].map { |n| gleichung.subs(x, n) }"
          },
          {
            "t": "h",
            "html": "<p>2 und 3 ergeben 0, sind also Lösungen; 4 ergibt 2, also nicht.</p><p>Zum Schluss ein Hauch Analysis. Die <strong>Ableitung</strong> sagt dir, wie steil eine Kurve an jeder Stelle ist, und <code>sp.diff</code> rechnet sie aus:</p>"
          },
          {
            "t": "c",
            "code": "sp.diff(x ** 3 + 2 * x, x)"
          },
          {
            "t": "h",
            "html": "<p>Die Ableitung von x³ + 2x ist 3x² + 2. Wo die Ableitung 0 ist, ist die Kurve einen Moment lang flach – oben auf einem Hügel oder unten in einem Tal. <code>diff</code> und <code>solve</code> zusammen finden also die Hügel und Täler einer Kurve.</p><div class='offweb' data-title='Auf deinem Computer'><p>Du brauchst Python mit SymPy (<code>pip install sympy</code>) und das Gem: <code>gem install pycall</code>; der Code dieser Lektion läuft dann unverändert. SymPy und mpmath, mit dem es seine Kommazahlen rechnet, stehen unter der BSD-Lizenz.</p></div><div class='task'><strong>Aufgabe:</strong> Wo ist die Kurve x³ − 6x² + 9x flach? Bilde mit <code>sp.diff</code> ihre Ableitung, finde mit <code>sp.solve</code>, wo diese 0 ist, und speichere die Antwort in <code>flach</code>.</div>"
          },
          {
            "t": "x",
            "code": "require \"pycall\"\nsp = PyCall.import_module(\"sympy\")\nx = sp.symbols(\"x\")\n\nkurve = x ** 3 - 6 * x ** 2 + 9 * x\n# flach = ...   (die x, an denen die Kurve flach ist)\n",
            "check": "flach.to_s == \"[1, 3]\" && code.include?(\"diff\") && code.include?(\"solve\")",
            "hint": "<code>sp.diff(kurve, x)</code> ist die Ableitung, 3x² − 12x + 9. Steck sie in <code>sp.solve(…, x)</code>, so wie oben bei x² − 5x + 6."
          }
        ]
      },
      "en": {
        "title": "24. SymPy: maths with symbols",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Maths with symbols</h2><p>Computers usually calculate with numbers, and decimal numbers get rounded – try <code>0.1 + 0.2</code> in Ruby. <a href='https://www.sympy.org' target='_blank'>SymPy</a> calculates the way you do on paper: with fractions, square roots and letters like <code>x</code>. It multiplies out brackets, solves equations and finds derivatives, and every answer is exact.</p><p>SymPy is a Python library, so we use it through pycall, just like pandas in lesson 23: <code>PyCall.import_module</code>, a dot for everything in it. The first time, it loads about 5 MB.</p>"
          },
          {
            "t": "c",
            "code": "require \"pycall\"\nsp = PyCall.import_module(\"sympy\")\n\nputs 0.1 + 0.2\nsp.Rational.new(1, 10) + sp.Rational.new(2, 10)"
          },
          {
            "t": "h",
            "html": "<p>The float is a tiny bit off; SymPy's <code>Rational</code> – a class, so <code>.new</code>, as with <code>DataFrame</code> – is exactly 3/10. (Ruby has exact fractions too: <code>1/10r + 2/10r</code>. SymPy goes much further.) Square roots stay exact as well:</p>"
          },
          {
            "t": "c",
            "code": "puts sp.sqrt(8)\nputs sp.sqrt(2) * sp.sqrt(2)\nsp.sqrt(2).evalf(50)"
          },
          {
            "t": "h",
            "html": "<p><code>sqrt(8)</code> is simplified to <code>2*sqrt(2)</code>, and √2 · √2 is exactly 2 – not 2.0000000000000004. When you do want a decimal, <code>evalf</code> works one out, with as many digits as you like: here 50.</p><p>Now the letters. <code>sp.symbols(\"x\")</code> makes a <strong>symbol</strong>: an <code>x</code> that stands for any number. You calculate with it like with a number, and you get a formula back:</p>"
          },
          {
            "t": "c",
            "code": "x = sp.symbols(\"x\")\nterm = (x + 1) ** 2\nputs term\nputs sp.expand(term)\nsp.factor(x ** 2 - 9)"
          },
          {
            "t": "h",
            "html": "<p><code>expand</code> multiplies out the brackets: (x + 1)² = x² + 2x + 1. <code>factor</code> goes the other way and finds the brackets. SymPy writes powers with <code>**</code>, like Ruby, and <code>*</code> for \"times\": <code>2*x</code> is 2x.</p><p>A formula on one line is hard to read. <code>sp.pretty</code> draws it the way it looks in a book:</p>"
          },
          {
            "t": "c",
            "code": "puts sp.pretty((x + 1) / (x - 1), use_unicode: false)\nputs\nputs sp.pretty(sp.sqrt(x ** 2 + 1) + 3 * x ** 3, use_unicode: false)"
          },
          {
            "t": "h",
            "html": "<p><code>use_unicode: false</code> draws with plain characters – <code>/</code>, <code>&#92;</code> and <code>-</code> – which line up in any font. <code>3 * x ** 3</code> works even though the 3 is a Ruby number: Ruby asks the <code>x</code> what to do (<code>coerce</code>), and pycall hands the sum to Python.</p><p>Now solving. <code>sp.solve(expression, x)</code> finds every <code>x</code> for which the expression is 0. So for x² − 5x + 6 = 0 you write:</p>"
          },
          {
            "t": "c",
            "code": "sp.solve(x ** 2 - 5 * x + 6, x)"
          },
          {
            "t": "h",
            "html": "<p>Two answers, 2 and 3. Let's check them: <code>subs</code> puts a number in for <code>x</code>. A Ruby block works as usual around it:</p>"
          },
          {
            "t": "c",
            "code": "equation = x ** 2 - 5 * x + 6\n[2, 3, 4].map { |n| equation.subs(x, n) }"
          },
          {
            "t": "h",
            "html": "<p>2 and 3 give 0, so they are solutions; 4 gives 2, so it isn't.</p><p>Last, a taste of calculus. The <strong>derivative</strong> tells you how steep a curve is at every point, and <code>sp.diff</code> works it out:</p>"
          },
          {
            "t": "c",
            "code": "sp.diff(x ** 3 + 2 * x, x)"
          },
          {
            "t": "h",
            "html": "<p>The derivative of x³ + 2x is 3x² + 2. Where the derivative is 0, the curve is flat for a moment – at the top of a hill or the bottom of a valley. So <code>diff</code> and <code>solve</code> together find a curve's hills and valleys.</p><div class='offweb' data-title='On your machine'><p>You need Python with SymPy (<code>pip install sympy</code>) and the gem: <code>gem install pycall</code>; the code of this lesson then runs unchanged. SymPy and mpmath, which it computes its decimals with, come under the BSD licence.</p></div><div class='task'><strong>Task:</strong> Where is the curve x³ − 6x² + 9x flat? Take its derivative with <code>sp.diff</code>, find where that is 0 with <code>sp.solve</code>, and store the answer in <code>flat</code>.</div>"
          },
          {
            "t": "x",
            "code": "require \"pycall\"\nsp = PyCall.import_module(\"sympy\")\nx = sp.symbols(\"x\")\n\ncurve = x ** 3 - 6 * x ** 2 + 9 * x\n# flat = ...   (the x where the curve is flat)\n",
            "check": "flat.to_s == \"[1, 3]\" && code.include?(\"diff\") && code.include?(\"solve\")",
            "hint": "<code>sp.diff(curve, x)</code> is the derivative, 3x² − 12x + 9. Put it into <code>sp.solve(…, x)</code>, the way the demo solved x² − 5x + 6."
          }
        ]
      },
      "ja": {
        "title": "24. SymPy：記号で数学",
        "cells": [
          {
            "t": "h",
            "html": "<h2>記号で数学</h2><p>コンピューターはふつう数値で計算し、小数は丸められます。Rubyで<code>0.1 + 0.2</code>を試してみてください。<a href='https://www.sympy.org' target='_blank'>SymPy</a>は、紙の上で計算するのと同じように、分数や平方根、<code>x</code>のような文字のまま計算します。かっこを展開し、方程式を解き、微分をして、答えはいつも正確です。</p><p>SymPyはPythonのライブラリなので、レッスン23のpandasと同じようにpycallを通して使います。<code>PyCall.import_module</code>で取り込み、中のものにはドットで届きます。初回は約5 MBを読み込みます。</p>"
          },
          {
            "t": "c",
            "code": "require \"pycall\"\nsp = PyCall.import_module(\"sympy\")\n\nputs 0.1 + 0.2\nsp.Rational.new(1, 10) + sp.Rational.new(2, 10)"
          },
          {
            "t": "h",
            "html": "<p>Floatはほんの少しずれていますが、SymPyの<code>Rational</code>（クラスなので、<code>DataFrame</code>と同じく<code>.new</code>を使います）はちょうど3/10です。（Rubyにも正確な分数があります：<code>1/10r + 2/10r</code>。SymPyはもっと先まで行けます。）平方根も正確なままです：</p>"
          },
          {
            "t": "c",
            "code": "puts sp.sqrt(8)\nputs sp.sqrt(2) * sp.sqrt(2)\nsp.sqrt(2).evalf(50)"
          },
          {
            "t": "h",
            "html": "<p><code>sqrt(8)</code>は<code>2*sqrt(2)</code>に簡単になり、√2 · √2はちょうど2です。2.0000000000000004ではありません。小数がほしいときは、<code>evalf</code>が好きな桁数で計算します。ここでは50桁です。</p><p>次は文字です。<code>sp.symbols(\"x\")</code>は<strong>シンボル</strong>を作ります。どんな数でも表す<code>x</code>です。数と同じように計算でき、式が返ってきます：</p>"
          },
          {
            "t": "c",
            "code": "x = sp.symbols(\"x\")\nterm = (x + 1) ** 2\nputs term\nputs sp.expand(term)\nsp.factor(x ** 2 - 9)"
          },
          {
            "t": "h",
            "html": "<p><code>expand</code>はかっこを展開します：(x + 1)² = x² + 2x + 1。<code>factor</code>は逆に、かっこを見つけます。SymPyはべき乗をRubyと同じ<code>**</code>で、「かける」を<code>*</code>で書きます。<code>2*x</code>は2xです。</p><p>1行の式は読みにくいものです。<code>sp.pretty</code>は、本に載っているような形で式を描きます：</p>"
          },
          {
            "t": "c",
            "code": "puts sp.pretty((x + 1) / (x - 1), use_unicode: false)\nputs\nputs sp.pretty(sp.sqrt(x ** 2 + 1) + 3 * x ** 3, use_unicode: false)"
          },
          {
            "t": "h",
            "html": "<p><code>use_unicode: false</code>は、<code>/</code>、<code>&#92;</code>、<code>-</code>のような普通の文字で描くので、どんなフォントでもきれいにそろいます。3がRubyの数でも<code>3 * x ** 3</code>は動きます。Rubyが<code>x</code>にどうするか尋ね（<code>coerce</code>）、pycallが計算をPythonに渡すからです。</p><p>次は方程式を解きます。<code>sp.solve(式, x)</code>は、式が0になる<code>x</code>をすべて見つけます。x² − 5x + 6 = 0なら、こう書きます：</p>"
          },
          {
            "t": "c",
            "code": "sp.solve(x ** 2 - 5 * x + 6, x)"
          },
          {
            "t": "h",
            "html": "<p>答えは2と3の2つです。確かめてみましょう。<code>subs</code>は<code>x</code>に数を入れます。まわりのRubyのブロックは、いつもどおりに動きます：</p>"
          },
          {
            "t": "c",
            "code": "equation = x ** 2 - 5 * x + 6\n[2, 3, 4].map { |n| equation.subs(x, n) }"
          },
          {
            "t": "h",
            "html": "<p>2と3は0になるので解です。4は2になるので解ではありません。</p><p>最後に、微分を少しだけ。<strong>導関数</strong>は、曲線がそれぞれの点でどれだけ急かを教えてくれます。<code>sp.diff</code>がそれを計算します：</p>"
          },
          {
            "t": "c",
            "code": "sp.diff(x ** 3 + 2 * x, x)"
          },
          {
            "t": "h",
            "html": "<p>x³ + 2xの導関数は3x² + 2です。導関数が0のところでは、曲線が一瞬だけ平らになります。山のてっぺんか、谷の底です。つまり<code>diff</code>と<code>solve</code>を組み合わせると、曲線の山と谷が見つかります。</p><div class='offweb' data-title='自分のコンピューターでは'><p>SymPy入りのPython（<code>pip install sympy</code>）とgem（<code>gem install pycall</code>）が必要です。そうすれば、このレッスンのコードはそのまま動きます。SymPyと、SymPyが小数の計算に使うmpmathは、BSDライセンスです。</p></div><div class='task'><strong>課題：</strong>曲線x³ − 6x² + 9xが平らになるのはどこでしょう？ <code>sp.diff</code>で導関数を求め、<code>sp.solve</code>でそれが0になるところを見つけて、答えを<code>flat</code>に入れましょう。</div>"
          },
          {
            "t": "x",
            "code": "require \"pycall\"\nsp = PyCall.import_module(\"sympy\")\nx = sp.symbols(\"x\")\n\ncurve = x ** 3 - 6 * x ** 2 + 9 * x\n# flat = ...   （曲線が平らになるx）\n",
            "check": "flat.to_s == \"[1, 3]\" && code.include?(\"diff\") && code.include?(\"solve\")",
            "hint": "<code>sp.diff(curve, x)</code>が導関数で、3x² − 12x + 9になるよ。それを<code>sp.solve(…, x)</code>に入れてみて。上でx² − 5x + 6を解いたのと同じだよ。"
          }
        ]
      }
    },
    {
      "id": "numpy",
      "de": {
        "title": "25. NumPy: ganze Arrays auf einmal",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Ganze Arrays auf einmal</h2><p>Auf <a href='https://numpy.org' target='_blank'>NumPy</a> steht fast alles, was Python mit Zahlen macht – pandas aus Lektion 23 ist darauf gebaut, und scikit-learn in der nächsten Lektion auch. Die Idee ist einfach: ein <strong>Array</strong> aus Zahlen, mit dem du als Ganzes rechnest. Keine Schleife – die läuft in NumPy, in schnellem kompiliertem Code.</p><p>Wir erreichen es wieder über pycall. Hier fünf Temperaturen in Celsius, in einer Zeile in Fahrenheit umgerechnet:</p>"
          },
          {
            "t": "c",
            "code": "require \"pycall\"\nnp = PyCall.import_module(\"numpy\")\n\ntemperaturen = np.array([12.5, 15.0, 9.5, 21.0, 18.5])\ntemperaturen * 9 / 5 + 32"
          },
          {
            "t": "h",
            "html": "<p><code>np.array</code> macht aus einem Ruby-Array ein NumPy-Array. <code>* 9 / 5 + 32</code> wirkt dann auf jede Zahl auf einmal. In reinem Ruby wäre das <code>temperaturen.map { |t| t * 9 / 5 + 32 }</code> – dasselbe Ergebnis, aber NumPy ist viel schneller, sobald es Millionen Zahlen sind.</p><p>Ein Array kann sich auch selbst zusammenfassen. Eine einzelne Zahl kommt als Ruby-Zahl zurück:</p>"
          },
          {
            "t": "c",
            "code": "puts temperaturen.mean\nputs temperaturen.max\ntemperaturen.argmax"
          },
          {
            "t": "h",
            "html": "<p><code>mean</code> ist der Durchschnitt, <code>max</code> der grösste Wert und <code>argmax</code>, <em>wo</em> er steht: an Index 3, ab 0 gezählt. Werte auswählen geht wie in pandas – eine Frage an jedes Element, ein Array aus <code>True</code>/<code>False</code>, und dieses Array in eckigen Klammern:</p>"
          },
          {
            "t": "c",
            "code": "temperaturen[temperaturen > 15]"
          },
          {
            "t": "h",
            "html": "<p>Nur die warmen Tage bleiben übrig. Arrays, ohne sie abzutippen: <code>np.arange</code> zählt wie ein Ruby-Range (das Ende ist nicht dabei), und <code>np.linspace</code> verteilt eine Anzahl Punkte gleichmässig zwischen zwei Werten:</p>"
          },
          {
            "t": "c",
            "code": "puts np.arange(1, 11) ** 2\nnp.linspace(0, 1, 5)"
          },
          {
            "t": "h",
            "html": "<p><code>** 2</code> quadriert alle zehn Zahlen auf einmal.</p><p>Arrays können auch Zeilen und Spalten haben, wie eine Tabelle oder ein Schachbrett. <code>reshape(3, 4)</code> faltet 12 Zahlen in 3 Zeilen zu 4:</p>"
          },
          {
            "t": "c",
            "code": "brett = np.arange(12).reshape(3, 4)\nputs brett\nputs brett.shape\nbrett.sum(axis: 0)"
          },
          {
            "t": "h",
            "html": "<p><code>shape</code> sagt, wie gross das Array ist: 3 Zeilen, 4 Spalten. <code>sum(axis: 0)</code> zählt jede Spalte zusammen (Achse 0 läuft die Zeilen hinunter); mit <code>axis: 1</code> wäre es jede Zeile.</p><p>NumPy bringt auch Zufallszahlen mit. Würfeln wir 6000-mal und zählen, wie oft jede Augenzahl kam:</p>"
          },
          {
            "t": "c",
            "code": "rng = np.random.default_rng(42)\nwuerfe = rng.integers(1, 7, size: 6000)\nnp.bincount(wuerfe)"
          },
          {
            "t": "h",
            "html": "<p><code>default_rng(42)</code> ist ein Zufallsgenerator; die 42 (der <em>Seed</em>) sorgt dafür, dass er jedes Mal dieselben Zahlen liefert, so kannst du das Ergebnis prüfen. <code>integers(1, 7, size: 6000)</code> würfelt 6000-mal – die 7 ist nicht dabei. <code>bincount</code> zählt, wie oft jede Zahl vorkommt, ab 0: keine Nullen, und von jeder Augenzahl rund 1000.</p><p>Zurück nach Ruby geht es wie bei pandas: <code>tolist</code> macht eine Python-Liste, <code>to_a</code> ein Ruby-Array.</p>"
          },
          {
            "t": "c",
            "code": "temperaturen.tolist.to_a.map { |t| t.round }"
          },
          {
            "t": "h",
            "html": "<p>Ab da funktionieren wieder Rubys eigene Methoden – hier <code>map</code> mit <code>round</code>.</p><div class='offweb' data-title='Auf deinem Computer'><p><code>pip install numpy</code> und <code>gem install pycall</code>, und der Code dieser Lektion läuft unverändert. Für Zahlen in Ruby selbst gibt es <a href='https://github.com/ruby-numo/numo-narray' target='_blank'>Numo::NArray</a>, das ganz ähnlich wie NumPy arbeitet. NumPy steht unter der BSD-Lizenz.</p></div><div class='task'><strong>Aufgabe:</strong> Wie viele dieser Prüfungspunkte sind 60 oder mehr? Lass NumPy das machen – ohne Ruby-Schleife – und speichere die Anzahl in <code>bestanden</code>, als Ruby-Zahl.</div>"
          },
          {
            "t": "x",
            "code": "require \"pycall\"\nnp = PyCall.import_module(\"numpy\")\n\npunkte = np.array([55, 72, 61, 48, 90, 67, 59])\n# bestanden = ...   (wie viele Punkte sind 60 oder mehr)\n",
            "check": "bestanden == 4 && bestanden.is_a?(Integer)",
            "hint": "<code>punkte &gt;= 60</code> ergibt ein Array aus <code>True</code> und <code>False</code>. <code>True</code> zählt als 1 und <code>False</code> als 0 – also ist seine <code>sum</code> die Anzahl."
          }
        ]
      },
      "en": {
        "title": "25. NumPy: whole arrays at once",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Whole arrays at once</h2><p><a href='https://numpy.org' target='_blank'>NumPy</a> is the library almost all of Python's number crunching stands on – pandas from lesson 23 is built on it, and so is scikit-learn in the next lesson. Its idea is simple: an <strong>array</strong> of numbers that you calculate with as a whole. No loop – NumPy runs the loop for you, in fast compiled code.</p><p>We reach it through pycall again. Here are five temperatures in Celsius, turned into Fahrenheit in one line:</p>"
          },
          {
            "t": "c",
            "code": "require \"pycall\"\nnp = PyCall.import_module(\"numpy\")\n\ntemps = np.array([12.5, 15.0, 9.5, 21.0, 18.5])\ntemps * 9 / 5 + 32"
          },
          {
            "t": "h",
            "html": "<p><code>np.array</code> makes an array from a Ruby array. <code>* 9 / 5 + 32</code> then works on every number at once. In plain Ruby that would be <code>temps.map { |t| t * 9 / 5 + 32 }</code> – the same result, but NumPy is much faster once there are millions of numbers.</p><p>An array also knows how to sum itself up. A single number comes back as a Ruby number:</p>"
          },
          {
            "t": "c",
            "code": "puts temps.mean\nputs temps.max\ntemps.argmax"
          },
          {
            "t": "h",
            "html": "<p><code>mean</code> is the average, <code>max</code> the largest value, and <code>argmax</code> <em>where</em> it is: at index 3, counting from 0. Picking values works like in pandas – a question for every element, a <code>True</code>/<code>False</code> array, and that array in square brackets:</p>"
          },
          {
            "t": "c",
            "code": "temps[temps > 15]"
          },
          {
            "t": "h",
            "html": "<p>Only the warm days are left. To make arrays without typing them: <code>np.arange</code> counts like a Ruby range (the end is not included), and <code>np.linspace</code> spreads a number of points evenly between two values:</p>"
          },
          {
            "t": "c",
            "code": "puts np.arange(1, 11) ** 2\nnp.linspace(0, 1, 5)"
          },
          {
            "t": "h",
            "html": "<p><code>** 2</code> squares all ten numbers at once.</p><p>Arrays can also have rows and columns, like a table or a chessboard. <code>reshape(3, 4)</code> folds 12 numbers into 3 rows of 4:</p>"
          },
          {
            "t": "c",
            "code": "grid = np.arange(12).reshape(3, 4)\nputs grid\nputs grid.shape\ngrid.sum(axis: 0)"
          },
          {
            "t": "h",
            "html": "<p><code>shape</code> says how big the array is: 3 rows, 4 columns. <code>sum(axis: 0)</code> adds up every column (axis 0 runs down the rows); <code>axis: 1</code> would add up every row instead.</p><p>NumPy also brings random numbers. Let's throw a die 6000 times and count how often each face came up:</p>"
          },
          {
            "t": "c",
            "code": "rng = np.random.default_rng(42)\ndice = rng.integers(1, 7, size: 6000)\nnp.bincount(dice)"
          },
          {
            "t": "h",
            "html": "<p><code>default_rng(42)</code> is a random-number generator; the 42 (the <em>seed</em>) makes it give the same numbers every time, so you can check the result. <code>integers(1, 7, size: 6000)</code> throws 6000 dice – 7 is not included. <code>bincount</code> counts how often each number appears, starting at 0: no zeros, and about 1000 of each face.</p><p>Back to Ruby, as with pandas: <code>tolist</code> makes a Python list, <code>to_a</code> a Ruby array.</p>"
          },
          {
            "t": "c",
            "code": "temps.tolist.to_a.map { |t| t.round }"
          },
          {
            "t": "h",
            "html": "<p>From there on, Ruby's own methods work again – here <code>map</code> with <code>round</code>.</p><div class='offweb' data-title='On your machine'><p><code>pip install numpy</code> and <code>gem install pycall</code>, and the code of this lesson runs unchanged. For numbers in Ruby itself there is <a href='https://github.com/ruby-numo/numo-narray' target='_blank'>Numo::NArray</a>, which works much like NumPy. NumPy comes under the BSD licence.</p></div><div class='task'><strong>Task:</strong> How many of these exam scores are 60 or more? Let NumPy do it – no Ruby loop – and store the count in <code>passed</code>, as a Ruby number.</div>"
          },
          {
            "t": "x",
            "code": "require \"pycall\"\nnp = PyCall.import_module(\"numpy\")\n\nscores = np.array([55, 72, 61, 48, 90, 67, 59])\n# passed = ...   (how many scores are 60 or more)\n",
            "check": "passed == 4 && passed.is_a?(Integer)",
            "hint": "<code>scores &gt;= 60</code> gives an array of <code>True</code> and <code>False</code>. <code>True</code> counts as 1 and <code>False</code> as 0 – so its <code>sum</code> is the count."
          }
        ]
      },
      "ja": {
        "title": "25. NumPy：配列をまるごと計算",
        "cells": [
          {
            "t": "h",
            "html": "<h2>配列をまるごと計算</h2><p>Pythonの数値計算のほとんどは<a href='https://numpy.org' target='_blank'>NumPy</a>の上に成り立っています。レッスン23のpandasもその上に作られていますし、次のレッスンのscikit-learnもそうです。考え方はかんたんで、数の<strong>配列</strong>を、まるごと計算します。ループはいりません。ループはNumPyの中の速いコンパイル済みのコードが回してくれます。</p><p>今回もpycallを通して使います。5つの摂氏の気温を、1行で華氏に変えてみましょう：</p>"
          },
          {
            "t": "c",
            "code": "require \"pycall\"\nnp = PyCall.import_module(\"numpy\")\n\ntemps = np.array([12.5, 15.0, 9.5, 21.0, 18.5])\ntemps * 9 / 5 + 32"
          },
          {
            "t": "h",
            "html": "<p><code>np.array</code>はRubyの配列からNumPyの配列を作ります。<code>* 9 / 5 + 32</code>は、すべての数に一度に効きます。ふつうのRubyなら<code>temps.map { |t| t * 9 / 5 + 32 }</code>で、結果は同じですが、数が何百万にもなるとNumPyのほうがずっと速くなります。</p><p>配列は自分自身をまとめることもできます。1つの数値はRubyの数値として返ってきます：</p>"
          },
          {
            "t": "c",
            "code": "puts temps.mean\nputs temps.max\ntemps.argmax"
          },
          {
            "t": "h",
            "html": "<p><code>mean</code>は平均、<code>max</code>はいちばん大きい値、<code>argmax</code>はそれが<em>どこに</em>あるかで、0から数えてインデックス3です。値の選び方はpandasと同じです。すべての要素に質問をして<code>True</code>/<code>False</code>の配列を作り、それを角かっこに入れます：</p>"
          },
          {
            "t": "c",
            "code": "temps[temps > 15]"
          },
          {
            "t": "h",
            "html": "<p>暖かい日だけが残りました。配列を手で打たずに作るには、Rubyの範囲のように数える<code>np.arange</code>（終わりの数は含みません）と、2つの値のあいだに点を均等に並べる<code>np.linspace</code>があります：</p>"
          },
          {
            "t": "c",
            "code": "puts np.arange(1, 11) ** 2\nnp.linspace(0, 1, 5)"
          },
          {
            "t": "h",
            "html": "<p><code>** 2</code>は10個の数を一度に2乗します。</p><p>配列は、表やチェス盤のように行と列を持つこともできます。<code>reshape(3, 4)</code>は12個の数を、4個ずつ3行に折りたたみます：</p>"
          },
          {
            "t": "c",
            "code": "grid = np.arange(12).reshape(3, 4)\nputs grid\nputs grid.shape\ngrid.sum(axis: 0)"
          },
          {
            "t": "h",
            "html": "<p><code>shape</code>は配列の大きさを教えてくれます。3行4列です。<code>sum(axis: 0)</code>は列ごとに合計します（軸0は行を下へたどります）。<code>axis: 1</code>なら行ごとの合計です。</p><p>NumPyには乱数もあります。サイコロを6000回振って、それぞれの目が何回出たか数えてみましょう：</p>"
          },
          {
            "t": "c",
            "code": "rng = np.random.default_rng(42)\ndice = rng.integers(1, 7, size: 6000)\nnp.bincount(dice)"
          },
          {
            "t": "h",
            "html": "<p><code>default_rng(42)</code>は乱数生成器です。42（<em>シード</em>）のおかげで毎回同じ数が出るので、結果を確かめられます。<code>integers(1, 7, size: 6000)</code>はサイコロを6000回振ります。7は含みません。<code>bincount</code>は0から順に、それぞれの数が何回出たかを数えます。0は出ず、どの目もだいたい1000回です。</p><p>Rubyに戻るのはpandasと同じです。<code>tolist</code>でPythonのリストに、<code>to_a</code>でRubyの配列になります。</p>"
          },
          {
            "t": "c",
            "code": "temps.tolist.to_a.map { |t| t.round }"
          },
          {
            "t": "h",
            "html": "<p>そこから先は、またRubyのメソッドが使えます。ここでは<code>map</code>と<code>round</code>です。</p><div class='offweb' data-title='自分のコンピューターでは'><p><code>pip install numpy</code>と<code>gem install pycall</code>をすれば、このレッスンのコードはそのまま動きます。Ruby自身で数値計算をするなら、NumPyとよく似た<a href='https://github.com/ruby-numo/numo-narray' target='_blank'>Numo::NArray</a>があります。NumPyはBSDライセンスです。</p></div><div class='task'><strong>課題：</strong>この試験の点数のうち、60点以上はいくつあるでしょう？ Rubyのループを使わずにNumPyに数えさせて、その数をRubyの数値として<code>passed</code>に入れましょう。</div>"
          },
          {
            "t": "x",
            "code": "require \"pycall\"\nnp = PyCall.import_module(\"numpy\")\n\nscores = np.array([55, 72, 61, 48, 90, 67, 59])\n# passed = ...   （60点以上がいくつあるか）\n",
            "check": "passed == 4 && passed.is_a?(Integer)",
            "hint": "<code>scores &gt;= 60</code>は<code>True</code>と<code>False</code>の配列になるよ。<code>True</code>は1、<code>False</code>は0として数えられるから、その<code>sum</code>が個数になるんだ。"
          }
        ]
      }
    },
    {
      "id": "sklearn",
      "de": {
        "title": "26. scikit-learn: die Maschine lernen lassen",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Die Maschine lernen lassen</h2><p>Normalerweise schreibst du die Regel, und der Computer befolgt sie. Beim <strong>maschinellen Lernen</strong> ist es umgekehrt: Du zeigst dem Computer Beispiele, und er findet die Regel selbst. <a href='https://scikit-learn.org' target='_blank'>scikit-learn</a> ist Pythons Bibliothek dafür – ein paar Dutzend Lernverfahren, alle gleich benutzt: ein <em>Modell</em> machen, mit <code>fit</code> an Beispiele anpassen, mit <code>predict</code> vorhersagen lassen.</p><p>Es steht auf NumPy und SciPy, darum lädt diese Lektion beim ersten Mal rund 19 MB. Erstes Beispiel: ein Glacestand, der an fünf Tagen die Temperatur und die verkauften Glaces notiert hat. Wie viele verkauft er bei 25 Grad?</p>"
          },
          {
            "t": "c",
            "code": "require \"pycall\"\nlm = PyCall.import_module(\"sklearn.linear_model\")\n\ntemperatur  = [[14], [18], [22], [26], [30]]   # °C, eine Zeile pro Tag\nverkauft = [21, 33, 46, 60, 71]             # verkaufte Glaces\n\nmodel = lm.LinearRegression.new\nmodel.fit(temperatur, verkauft)\nmodel.predict([[25]])"
          },
          {
            "t": "h",
            "html": "<p>Die Beispiele kommen in zwei Teilen. Die Eingaben sind eine Liste von Zeilen, eine pro Beispiel – hier hat jede Zeile nur einen Wert, die Temperatur, darum <code>[14]</code> und nicht einfach <code>14</code>. Die Antworten sind eine einfache Liste, eine pro Zeile. <code>LinearRegression</code> sucht die Gerade, die am besten durch die Punkte passt; <code>fit</code> lernt sie, <code>predict</code> wendet sie an – für 25 Grad etwa 56 Glaces.</p><p>Die Gerade, die das Modell gelernt hat, sind nur zwei Zahlen, und du kannst danach fragen:</p>"
          },
          {
            "t": "c",
            "code": "puts \"Glaces pro Grad: #{model.coef_[0].round(2)}\"\nputs \"Startwert: #{model.intercept_.round(2)}\""
          },
          {
            "t": "h",
            "html": "<p><code>coef_</code> ist, wie steil die Gerade ist: pro Grad etwa 3.2 Glaces mehr. <code>intercept_</code> ist, wo die Gerade bei 0 Grad wäre: unter null. Eine Gerade weiss nicht, dass niemand minus 24 Glaces verkauft – ein Modell kennt nur seine Beispiele, und so kalt war keins. Der <code>_</code> am Ende ist scikit-learns Zeichen für «aus den Daten gelernt».</p><p>Jetzt etwas, das keine Zahl ist: Ist ein Tier eine Katze oder ein Fuchs? Wir haben ein paar vermessen – Gewicht in kg und Ohrenlänge in cm – und lassen einen <strong>Entscheidungsbaum</strong> daraus lernen. Das Schöne an einem Baum: Du kannst lesen, was er gelernt hat.</p>"
          },
          {
            "t": "c",
            "code": "tree = PyCall.import_module(\"sklearn.tree\")\n\ntiere = [[4.0, 6], [3.5, 5], [5.0, 7], [4.5, 6],    # [Gewicht in kg, Ohren in cm]\n           [7.0, 9], [6.5, 10], [8.0, 9], [7.5, 11]]\narten = [\"Katze\"] * 4 + [\"Fuchs\"] * 4\n\nrichter = tree.DecisionTreeClassifier.new(random_state: 0)\nrichter.fit(tiere, arten)\nputs tree.export_text(richter, feature_names: [\"gewicht\", \"ohren\"])"
          },
          {
            "t": "h",
            "html": "<p>Der Baum stellt eine einzige Frage: Sind die Ohren höchstens 8 cm lang? Dann ist es eine Katze, sonst ein Fuchs. Die Grenze hat er selbst gefunden, genau zwischen den längsten Katzenohren (7 cm) und den kürzesten Fuchsohren (9 cm). Lass ihn Tiere beurteilen, die er noch nie gesehen hat:</p>"
          },
          {
            "t": "c",
            "code": "richter.predict([[4.2, 6], [7.2, 10], [5.8, 8]]).tolist.to_a"
          },
          {
            "t": "h",
            "html": "<p>Das dritte ist eine Überraschung: 5.8 kg, schwerer als jede Katze, die wir vermessen haben, und trotzdem sagt der Baum Katze – seine Ohren sind 8 cm lang. Aufs Gewicht hat der Baum nie geschaut, denn die Ohren allein haben all seine Beispiele auseinandergehalten. Ein Modell ist nur so gut wie seine Beispiele: Mit ein paar schweren Katzen und leichten Füchsen darunter hätte er mehr lernen müssen.</p><p>Echte Daten haben mehr als zwei Messwerte. scikit-learn bringt ein paar klassische Datensätze mit; der bekannteste ist <strong>Iris</strong>: 150 Blumen dreier Arten, jede viermal vermessen.</p>"
          },
          {
            "t": "c",
            "code": "datasets = PyCall.import_module(\"sklearn.datasets\")\nselection = PyCall.import_module(\"sklearn.model_selection\")\n\niris = datasets.load_iris\nputs iris.feature_names\nputs iris.target_names\niris.data.shape"
          },
          {
            "t": "h",
            "html": "<p><code>shape</code> sagt (150, 4): 150 Zeilen mit je 4 Messwerten. Wie gut kann ein Baum die Arten auseinanderhalten? Um das ehrlich herauszufinden, verstecken wir beim Lernen einen Teil der Daten: <code>train_test_split</code> hält 30 % zurück. Der Baum lernt vom Rest und wird dann an Blumen geprüft, die er nie gesehen hat:</p>"
          },
          {
            "t": "c",
            "code": "parts = selection.train_test_split(iris.data, iris.target, test_size: 0.3, random_state: 1)\ntrain_x, test_x, train_y, test_y = parts[0], parts[1], parts[2], parts[3]\n\nflowers = tree.DecisionTreeClassifier.new(max_depth: 3, random_state: 0)\nflowers.fit(train_x, train_y)\nflowers.score(test_x, test_y)"
          },
          {
            "t": "h",
            "html": "<p><code>score</code> ist der Anteil der Testblumen, die er richtig erkannt hat – hier etwa 96 %. <code>max_depth: 3</code> erlaubt höchstens drei Fragen hintereinander, so lernt der Baum das allgemeine Muster, statt jede Blume auswendig zu lernen. Mit versteckten Daten prüfen ist die wichtigste Gewohnheit beim maschinellen Lernen: Ein Modell, das nur seine eigenen Beispiele kennt, nützt wenig.</p><div class='offweb' data-title='Auf deinem Computer'><p><code>pip install scikit-learn</code> und <code>gem install pycall</code>, und der Code dieser Lektion läuft unverändert. Für maschinelles Lernen in Ruby selbst gibt es <a href='https://github.com/yoshoku/rumale' target='_blank'>Rumale</a>, das ganz ähnlich wie scikit-learn arbeitet – davon handelt die nächste Lektion. scikit-learn, SciPy und NumPy stehen unter der BSD-Lizenz.</p></div><div class='task'><strong>Aufgabe:</strong> Fünf Schülerinnen haben notiert, wie viele Stunden sie gelernt und wie viele Punkte sie bekommen haben. Bring einer <code>LinearRegression</code> damit etwas bei und sag die Punkte für 6 Stunden voraus. Speichere die Vorhersage in <code>prognose</code>, als Ruby-Zahl.</div>"
          },
          {
            "t": "x",
            "code": "require \"pycall\"\nlm = PyCall.import_module(\"sklearn.linear_model\")\n\nstunden  = [[1], [2], [3], [4], [5]]\npunkte = [52, 59, 66, 73, 80]\n# prognose = ...   (die vorhergesagten Punkte für 6 Stunden)\n",
            "check": "prognose.is_a?(Numeric) && (prognose - 87).abs < 0.01 && code.include?(\"fit\")",
            "hint": "<code>modell = lm.LinearRegression.new</code>, dann <code>modell.fit(stunden, punkte)</code>. <code>modell.predict([[6]])</code> ergibt ein Array mit einer Vorhersage – <code>[0]</code> holt sie als Ruby-Zahl heraus."
          }
        ]
      },
      "en": {
        "title": "26. scikit-learn: letting the machine learn",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Letting the machine learn</h2><p>Usually you write the rule and the computer follows it. In <strong>machine learning</strong> it is the other way round: you show the computer examples, and it finds the rule itself. <a href='https://scikit-learn.org' target='_blank'>scikit-learn</a> is Python's library for that – a few dozen learning methods, all used the same way: make a <em>model</em>, <code>fit</code> it to examples, let it <code>predict</code>.</p><p>It stands on NumPy and SciPy, so the first time this lesson loads about 19 MB. First example: an ice cream stand that wrote down, for five days, the temperature and how many ice creams it sold. How many will it sell at 25 degrees?</p>"
          },
          {
            "t": "c",
            "code": "require \"pycall\"\nlm = PyCall.import_module(\"sklearn.linear_model\")\n\ntemperature  = [[14], [18], [22], [26], [30]]   # °C, one row per day\nsales = [21, 33, 46, 60, 71]             # ice creams sold\n\nmodel = lm.LinearRegression.new\nmodel.fit(temperature, sales)\nmodel.predict([[25]])"
          },
          {
            "t": "h",
            "html": "<p>The examples come in two parts. The inputs are a list of rows, one per example – here each row has only one value, the temperature, so it is <code>[14]</code> and not just <code>14</code>. The answers are a plain list, one per row. <code>LinearRegression</code> looks for the straight line that fits the points best; <code>fit</code> learns it, <code>predict</code> uses it – for 25 degrees, about 56 ice creams.</p><p>The line the model learned is just two numbers, and you can ask for them:</p>"
          },
          {
            "t": "c",
            "code": "puts \"Ice creams per degree: #{model.coef_[0].round(2)}\"\nputs \"Starting point: #{model.intercept_.round(2)}\""
          },
          {
            "t": "h",
            "html": "<p><code>coef_</code> is how steep the line is: about 3.2 more ice creams for every degree. <code>intercept_</code> is where the line would be at 0 degrees: below zero. A line doesn't know that nobody sells minus 24 ice creams – a model only knows its examples, and none were that cold. The trailing <code>_</code> is scikit-learn's mark for \"learned from the data\".</p><p>Now something that is not a number: is an animal a cat or a fox? We measured a few – weight in kg and ear length in cm – and let a <strong>decision tree</strong> learn from them. The nice thing about a tree: you can read what it learned.</p>"
          },
          {
            "t": "c",
            "code": "tree = PyCall.import_module(\"sklearn.tree\")\n\nanimals = [[4.0, 6], [3.5, 5], [5.0, 7], [4.5, 6],    # [weight in kg, ears in cm]\n           [7.0, 9], [6.5, 10], [8.0, 9], [7.5, 11]]\nkinds = [\"cat\"] * 4 + [\"fox\"] * 4\n\njudge = tree.DecisionTreeClassifier.new(random_state: 0)\njudge.fit(animals, kinds)\nputs tree.export_text(judge, feature_names: [\"weight\", \"ears\"])"
          },
          {
            "t": "h",
            "html": "<p>The tree asks one single question: are the ears at most 8 cm long? Then it's a cat, otherwise a fox. It found the boundary itself, halfway between the longest cat ears (7 cm) and the shortest fox ears (9 cm). Let it judge animals it has never seen:</p>"
          },
          {
            "t": "c",
            "code": "judge.predict([[4.2, 6], [7.2, 10], [5.8, 8]]).tolist.to_a"
          },
          {
            "t": "h",
            "html": "<p>The third one is a surprise: 5.8 kg, heavier than every cat we measured, and still the tree says cat – its ears are 8 cm. The tree never looked at the weight, because the ears alone told all its examples apart. A model is only as good as its examples: with a few heavy cats and light foxes among them, it would have had to learn more.</p><p>Real data has more than two measurements. scikit-learn comes with a few classic datasets; the best known is <strong>iris</strong>: 150 flowers of three kinds, each measured four times.</p>"
          },
          {
            "t": "c",
            "code": "datasets = PyCall.import_module(\"sklearn.datasets\")\nselection = PyCall.import_module(\"sklearn.model_selection\")\n\niris = datasets.load_iris\nputs iris.feature_names\nputs iris.target_names\niris.data.shape"
          },
          {
            "t": "h",
            "html": "<p><code>shape</code> says (150, 4): 150 rows, 4 measurements each. How well can a tree tell the kinds apart? To find out honestly, we hide part of the data while it learns: <code>train_test_split</code> keeps 30% back. The tree learns from the rest and is then tested on flowers it has never seen:</p>"
          },
          {
            "t": "c",
            "code": "parts = selection.train_test_split(iris.data, iris.target, test_size: 0.3, random_state: 1)\ntrain_x, test_x, train_y, test_y = parts[0], parts[1], parts[2], parts[3]\n\nflowers = tree.DecisionTreeClassifier.new(max_depth: 3, random_state: 0)\nflowers.fit(train_x, train_y)\nflowers.score(test_x, test_y)"
          },
          {
            "t": "h",
            "html": "<p><code>score</code> is the share of test flowers it got right – here about 96%. <code>max_depth: 3</code> allows at most three questions in a row, so the tree learns the general pattern rather than memorising each flower. Testing on hidden data is the most important habit in machine learning: a model that only knows its own examples is not much use.</p><div class='offweb' data-title='On your machine'><p><code>pip install scikit-learn</code> and <code>gem install pycall</code>, and the code of this lesson runs unchanged. For machine learning in Ruby itself, look at <a href='https://github.com/yoshoku/rumale' target='_blank'>Rumale</a>, which works much like scikit-learn – it is the next lesson. scikit-learn, SciPy and NumPy come under the BSD licence.</p></div><div class='task'><strong>Task:</strong> Five students wrote down how many hours they studied and how many points they got. Teach a <code>LinearRegression</code> with them and predict the points for 6 hours. Store the prediction in <code>forecast</code>, as a Ruby number.</div>"
          },
          {
            "t": "x",
            "code": "require \"pycall\"\nlm = PyCall.import_module(\"sklearn.linear_model\")\n\nhours  = [[1], [2], [3], [4], [5]]\npoints = [52, 59, 66, 73, 80]\n# forecast = ...   (the predicted points for 6 hours)\n",
            "check": "forecast.is_a?(Numeric) && (forecast - 87).abs < 0.01 && code.include?(\"fit\")",
            "hint": "<code>model = lm.LinearRegression.new</code>, then <code>model.fit(hours, points)</code>. <code>model.predict([[6]])</code> gives an array with one prediction – <code>[0]</code> takes it out as a Ruby number."
          }
        ]
      },
      "ja": {
        "title": "26. scikit-learn：機械に学ばせる",
        "cells": [
          {
            "t": "h",
            "html": "<h2>機械に学ばせる</h2><p>ふつうは、あなたがルールを書き、コンピューターがそれに従います。<strong>機械学習</strong>ではその逆です。コンピューターに例を見せると、ルールを自分で見つけます。<a href='https://scikit-learn.org' target='_blank'>scikit-learn</a>はそのためのPythonのライブラリで、数十種類の学習方法があり、どれも同じように使います。<em>モデル</em>を作り、<code>fit</code>で例に合わせ、<code>predict</code>で予測させます。</p><p>NumPyとSciPyの上に成り立っているので、このレッスンは初回に約19 MBを読み込みます。最初の例は、5日間の気温と売れたアイスの数を記録したアイス屋さんです。25度ならいくつ売れるでしょう？</p>"
          },
          {
            "t": "c",
            "code": "require \"pycall\"\nlm = PyCall.import_module(\"sklearn.linear_model\")\n\ntemperature  = [[14], [18], [22], [26], [30]]   # °C、1日1行\nsales = [21, 33, 46, 60, 71]             # 売れたアイスの数\n\nmodel = lm.LinearRegression.new\nmodel.fit(temperature, sales)\nmodel.predict([[25]])"
          },
          {
            "t": "h",
            "html": "<p>例は2つの部分からなります。入力は行のリストで、1つの例が1行です。ここでは各行に気温という値が1つだけなので、<code>14</code>ではなく<code>[14]</code>と書きます。答えはふつうのリストで、1行に1つです。<code>LinearRegression</code>は点にいちばんよく合う直線を探します。<code>fit</code>で学び、<code>predict</code>で使います。25度ならアイスは約56個です。</p><p>モデルが学んだ直線はたった2つの数で、聞けば教えてくれます：</p>"
          },
          {
            "t": "c",
            "code": "puts \"Ice creams per degree: #{model.coef_[0].round(2)}\"\nputs \"Starting point: #{model.intercept_.round(2)}\""
          },
          {
            "t": "h",
            "html": "<p><code>coef_</code>は直線の傾きで、1度ごとにアイスが約3.2個増えます。<code>intercept_</code>は0度のときの直線の位置で、マイナスになります。直線は、アイスがマイナス24個売れることはないと知りません。モデルが知っているのは例だけで、そんなに寒い日の例はなかったからです。最後の<code>_</code>は、scikit-learnの「データから学んだもの」という印です。</p><p>次は数ではないものです。ある動物はネコでしょうか、キツネでしょうか？ 何匹か、体重（kg）と耳の長さ（cm）を測って、<strong>決定木</strong>に学ばせます。木のいいところは、何を学んだのかが読めることです。</p>"
          },
          {
            "t": "c",
            "code": "tree = PyCall.import_module(\"sklearn.tree\")\n\nanimals = [[4.0, 6], [3.5, 5], [5.0, 7], [4.5, 6],    # [体重kg, 耳cm]\n           [7.0, 9], [6.5, 10], [8.0, 9], [7.5, 11]]\nkinds = [\"cat\"] * 4 + [\"fox\"] * 4\n\njudge = tree.DecisionTreeClassifier.new(random_state: 0)\njudge.fit(animals, kinds)\nputs tree.export_text(judge, feature_names: [\"weight\", \"ears\"])"
          },
          {
            "t": "h",
            "html": "<p>木はたった1つの質問をします。耳の長さは8 cm以下か？ そうならネコ、ちがえばキツネです。いちばん長いネコの耳（7 cm）といちばん短いキツネの耳（9 cm）のちょうど真ん中に、境界を自分で見つけました。見たことのない動物を判定させてみましょう：</p>"
          },
          {
            "t": "c",
            "code": "judge.predict([[4.2, 6], [7.2, 10], [5.8, 8]]).tolist.to_a"
          },
          {
            "t": "h",
            "html": "<p>3匹目は意外な結果です。5.8 kgで、測ったどのネコよりも重いのに、耳が8 cmなので木はネコと答えます。木は体重をまったく見ていません。耳だけで、すべての例を見分けられたからです。モデルは例の質と同じだけの良さしかありません。重いネコや軽いキツネが例に混じっていれば、もっと多くのことを学ばなければならなかったでしょう。</p><p>本物のデータには、2つより多くの測定値があります。scikit-learnにはいくつか古典的なデータセットが入っていて、いちばん有名なのが<strong>アイリス</strong>です。3種類の花150本を、それぞれ4か所測ったものです。</p>"
          },
          {
            "t": "c",
            "code": "datasets = PyCall.import_module(\"sklearn.datasets\")\nselection = PyCall.import_module(\"sklearn.model_selection\")\n\niris = datasets.load_iris\nputs iris.feature_names\nputs iris.target_names\niris.data.shape"
          },
          {
            "t": "h",
            "html": "<p><code>shape</code>は(150, 4)、つまり150行で、それぞれ4つの測定値です。木はどれくらい上手に種類を見分けられるでしょう？ 正直に確かめるため、学ぶあいだはデータの一部を隠しておきます。<code>train_test_split</code>が30%を取っておきます。木は残りから学び、そのあと見たことのない花でテストされます：</p>"
          },
          {
            "t": "c",
            "code": "parts = selection.train_test_split(iris.data, iris.target, test_size: 0.3, random_state: 1)\ntrain_x, test_x, train_y, test_y = parts[0], parts[1], parts[2], parts[3]\n\nflowers = tree.DecisionTreeClassifier.new(max_depth: 3, random_state: 0)\nflowers.fit(train_x, train_y)\nflowers.score(test_x, test_y)"
          },
          {
            "t": "h",
            "html": "<p><code>score</code>は、テストの花のうち正しく当てた割合で、ここでは約96%です。<code>max_depth: 3</code>は続けてする質問を最大3つまでにするので、木は花を1本ずつ丸暗記するのではなく、全体の傾向を学びます。隠しておいたデータでテストするのは、機械学習でいちばん大切な習慣です。自分の例しか知らないモデルは、あまり役に立ちません。</p><div class='offweb' data-title='自分のコンピューターでは'><p><code>pip install scikit-learn</code>と<code>gem install pycall</code>をすれば、このレッスンのコードはそのまま動きます。Ruby自身で機械学習をするなら、scikit-learnとよく似た<a href='https://github.com/yoshoku/rumale' target='_blank'>Rumale</a>があります。次のレッスンで使います。scikit-learn、SciPy、NumPyはBSDライセンスです。</p></div><div class='task'><strong>課題：</strong>5人の生徒が、勉強した時間ととれた点数を記録しました。それを使って<code>LinearRegression</code>に学ばせ、6時間勉強したときの点数を予測しましょう。予測をRubyの数値として<code>forecast</code>に入れてください。</div>"
          },
          {
            "t": "x",
            "code": "require \"pycall\"\nlm = PyCall.import_module(\"sklearn.linear_model\")\n\nhours  = [[1], [2], [3], [4], [5]]\npoints = [52, 59, 66, 73, 80]\n# forecast = ...   （6時間のときの予測点数）\n",
            "check": "forecast.is_a?(Numeric) && (forecast - 87).abs < 0.01 && code.include?(\"fit\")",
            "hint": "<code>model = lm.LinearRegression.new</code>のあと、<code>model.fit(hours, points)</code>だよ。<code>model.predict([[6]])</code>は予測が1つ入った配列になるから、<code>[0]</code>でRubyの数値として取り出してね。"
          }
        ]
      }
    },
    {
      "id": "rumale",
      "files": {
        "digits.csv": "assets/data/digits.csv"
      },
      "de": {
        "title": "27. Rumale: maschinelles Lernen in Ruby",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Maschinelles Lernen in reinem Ruby</h2><p>In der letzten Lektion hat Python gelernt. <a href='https://github.com/yoshoku/rumale' target='_blank'>Rumale</a> bringt dieselben Ideen nach Ruby – mit denselben Namen: ein Modell machen, mit <code>fit</code> an Beispiele anpassen, mit <code>predict</code> vorhersagen, mit <code>score</code> prüfen. Geschrieben hat es Atsushi Tatsuma (yoshoku), ganz in Ruby.</p><p>Seine Zahlen hält Rumale in <a href='https://github.com/ruby-numo/numo-narray' target='_blank'>Numo</a>-Arrays, Rubys Gegenstück zu NumPy: <code>Numo::DFloat</code> für Kommazahlen, <code>Numo::Int32</code> für ganze. Das Gem dazu, <a href='https://rubygems.org/gems/numo-narray-alt' target='_blank'>numo-narray-alt</a>, ist in C geschrieben und läuft darum nicht im Browser; hier rechnet an seiner Stelle ein Nachbau in reinem Ruby mit denselben Methoden – nur langsamer.</p><p>Rumale ist in kleine Gems aufgeteilt. Wir brauchen die <strong>nächsten Nachbarn</strong>, und zum Anfang ein Gemüse: Länge und Dicke in Zentimetern.</p>"
          },
          {
            "t": "c",
            "code": "install_gem \"rumale-nearest_neighbors\"\nrequire \"rumale/nearest_neighbors\"\n\n# [Länge, Dicke] in cm\ngemuese = Numo::DFloat[[18, 3], [20, 3.5], [16, 2.5],   # Rüebli\n                       [30, 4.5], [28, 5], [33, 5],      # Gurken\n                       [6, 6], [5, 5.5], [7, 7]]         # Tomaten\nsorte = Numo::Int32[0, 0, 0, 1, 1, 1, 2, 2, 2]\nnamen = [\"Rüebli\", \"Gurke\", \"Tomate\"]\ngemuese.shape"
          },
          {
            "t": "h",
            "html": "<p><code>shape</code> sagt [9, 2]: 9 Zeilen, je 2 Zahlen. Die Antworten muss Rumale als Zahlen bekommen – 0 für Rüebli, 1 für Gurke, 2 für Tomate –, die Namen dazu stehen in einer gewöhnlichen Liste.</p><p>Der <strong>k-nächste-Nachbarn</strong>-Klassifikator ist das einfachste Lernverfahren überhaupt: Um ein neues Gemüse zu beurteilen, sucht er die <code>k</code> ähnlichsten, die er kennt, und lässt sie abstimmen. «Ähnlich» heisst: nahe beieinander, wenn man Länge und Dicke als Punkte aufzeichnet.</p>"
          },
          {
            "t": "c",
            "code": "nachbarn = Rumale::NearestNeighbors::KNeighborsClassifier.new(n_neighbors: 3)\nnachbarn.fit(gemuese, sorte)\ngeraten = nachbarn.predict(Numo::DFloat[[25, 4], [6, 6.5], [15, 3]])\ngeraten.to_a.map { |s| namen[s] }"
          },
          {
            "t": "h",
            "html": "<p>25 cm lang und 4 cm dick liegt am nächsten bei den Gurken, das runde Ding bei den Tomaten, das dünne bei den Rüebli. Gelernt hat <code>fit</code> dabei nichts – es merkt sich nur die Beispiele. Die Arbeit kommt bei <code>predict</code>: alle Abstände messen.</p><p>Jetzt etwas Schwierigeres: Handschrift. <code>digits.csv</code> enthält 1797 von Hand geschriebene Ziffern, gesammelt von <a href='https://archive.ics.uci.edu/dataset/80/optical+recognition+of+handwritten+digits' target='_blank'>UCI</a>. Jede ist ein Bild aus 8×8 Feldern, und jedes Feld eine Zahl von 0 bis 16 – wie viel Tinte darin ist. Die Zahl am Ende der Zeile sagt, welche Ziffer es ist. Die Datei liegt neben deinem Code (im Browser legt der Kurs sie dorthin):</p>"
          },
          {
            "t": "c",
            "code": "zeilen = File.read(\"digits.csv\").lines.map { |zeile| zeile.split(\",\").map(&:to_i) }\nbilder = Numo::DFloat[*zeilen.map { |z| z[0, 64] }]\nziffern = Numo::Int32[*zeilen.map(&:last)]\nbilder.shape"
          },
          {
            "t": "h",
            "html": "<p>1797 Bilder mit je 64 Zahlen. Mit <code>reshape(8, 8)</code> wird eine Zeile wieder zum Bild – zeichnen wir die erste mit Zeichen, die umso dunkler sind, je mehr Tinte im Feld ist:</p>"
          },
          {
            "t": "c",
            "code": "bild = bilder[0, true].reshape(8, 8)\nbild.to_a.each do |reihe|\n  puts reihe.map { |wert| \" .:-=+*#%@\"[(wert * 9 / 16).round] }.join(\" \")\nend\nziffern[0]"
          },
          {
            "t": "h",
            "html": "<p>Eine Null, kein Zweifel. Jetzt lernen und ehrlich prüfen: Die ersten 1000 Bilder bekommt der Klassifikator zum Lernen, an 50 weiteren, die er nie gesehen hat, wird er getestet. (Im Browser rechnet Numo in reinem Ruby – der Test braucht ein paar Sekunden.)</p>"
          },
          {
            "t": "c",
            "code": "lerner = Rumale::NearestNeighbors::KNeighborsClassifier.new(n_neighbors: 3)\nlerner.fit(bilder[0...1000, true], ziffern[0...1000])     # daraus lernen\nlerner.score(bilder[1000...1050, true], ziffern[1000...1050])  # damit testen"
          },
          {
            "t": "h",
            "html": "<p>48 von 50 richtig – mit nichts als Abständen zwischen 64 Zahlen. <code>[0...1000, true]</code> heisst: die Zeilen 0 bis 999, alle Spalten.</p><p>Und jetzt du. Für den Brief darf der Klassifikator aus allen 1797 Bildern lernen – je mehr Beispiele, desto besser. Unten erscheint ein Brief an Chunky; schreib mit der Maus oder dem Finger die Postleitzahl in die roten Kästchen, eine Ziffer pro Kästchen. Jedes Mal, wenn du absetzt, bekommt der Block alle geschriebenen Ziffern – je 64 Zahlen, genau wie eine Zeile aus <code>digits.csv</code> – und seine Antwort wird auf den Brief gestempelt. Probier 8000, 3000 oder 6900:</p>"
          },
          {
            "t": "c",
            "code": "lerner.fit(bilder, ziffern)   # jetzt aus allen 1797\norte = { \"8000\" => \"Zürich\", \"3000\" => \"Bern\", \"4000\" => \"Basel\", \"1200\" => \"Genève\",\n         \"6000\" => \"Luzern\", \"9000\" => \"St. Gallen\", \"7000\" => \"Chur\", \"6900\" => \"Lugano\" }\n\nshow_letter(boxes: 4) do |geschrieben|   # je Kästchen ein Array mit 64 Zahlen\n  plz = lerner.predict(Numo::DFloat[*geschrieben]).to_a.join\n  \"#{plz} #{orte.fetch(plz, \"?\")}\"\nend"
          },
          {
            "t": "h",
            "html": "<p>Unter dem Brief siehst du, was Ruby bekommt: deine Ziffern als 8×8-Bilder. Liest der Klassifikator eine falsch, schau dort nach. Die Ziffern in <code>digits.csv</code> wurden in den 1990er-Jahren mit Stift auf Formulare geschrieben; eine Maus schreibt anders. Schreib gross, füll das Kästchen in der Höhe aus – oder ändere den Code: <code>n_neighbors: 1</code> oder <code>5</code>, und der Brief liest deine Ziffern gleich nochmal.</p><div class='offweb' data-title='Auf deinem Computer'><p><code>gem install rumale</code> installiert alles, auch das echte <a href='https://rubygems.org/gems/numo-narray-alt' target='_blank'>numo-narray-alt</a> (es wird dabei kompiliert); danach genügt <code>require \"rumale\"</code>. Der Code dieser Lektion läuft dort unverändert – nur der Brief braucht diese Seite. <code>digits.csv</code> stammt aus dem Datensatz <em>Optical Recognition of Handwritten Digits</em> von E. Alpaydin und C. Kaynak (<a href='https://archive.ics.uci.edu/dataset/80/optical+recognition+of+handwritten+digits' target='_blank'>UCI</a>, CC BY 4.0); <a href='assets/data/digits.csv' download>hier zum Herunterladen</a>. Rumale steht unter der BSD-Lizenz.</p></div><div class='task'><strong>Aufgabe:</strong> Ruby schreibt auch mit Zeichen. Mach aus dem Bild einer Sieben die 64 Zahlen, die der Klassifikator versteht – <code>#</code> ist 16, <code>.</code> ist 0, Zeile für Zeile –, und lass <code>lerner</code> sagen, was er darin sieht. Speichere seine Antwort in <code>ziffer</code>, als Ruby-Zahl.</div>"
          },
          {
            "t": "x",
            "code": "sieben = <<~BILD\n  .######.\n  ......#.\n  .....#..\n  ....#...\n  ...#....\n  ...#....\n  ..#.....\n  ..#.....\nBILD\n# pixel = ...   (64 Zahlen: # ist 16, . ist 0)\n# ziffer = ...   (was lerner darin sieht, als Ruby-Zahl)\n",
            "check": "ziffer == 7 && code.include?(\"predict\")",
            "hint": "<code>sieben.delete(\"\\n\").chars</code> gibt die 64 Zeichen; <code>map { |z| z == \"#\" ? 16 : 0 }</code> macht Zahlen daraus. <code>lerner.predict(Numo::DFloat[pixel])</code> will eine Tabelle mit einer Zeile pro Bild – hier eine Zeile –, und <code>[0]</code> holt die Antwort heraus."
          }
        ]
      },
      "en": {
        "title": "27. Rumale: machine learning in Ruby",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Machine learning in plain Ruby</h2><p>In the last lesson Python did the learning. <a href='https://github.com/yoshoku/rumale' target='_blank'>Rumale</a> brings the same ideas to Ruby – with the same names: make a model, <code>fit</code> it to examples, let it <code>predict</code>, check it with <code>score</code>. Atsushi Tatsuma (yoshoku) wrote it, all in Ruby.</p><p>Rumale keeps its numbers in <a href='https://github.com/ruby-numo/numo-narray' target='_blank'>Numo</a> arrays, Ruby's counterpart to NumPy: <code>Numo::DFloat</code> for decimals, <code>Numo::Int32</code> for whole numbers. Their gem, <a href='https://rubygems.org/gems/numo-narray-alt' target='_blank'>numo-narray-alt</a>, is written in C, so it does not run in a browser; here a stand-in in plain Ruby with the same methods does its job – just slower.</p><p>Rumale comes in small gems. We need the <strong>nearest neighbours</strong>, and to start, some vegetables: length and thickness in centimetres.</p>"
          },
          {
            "t": "c",
            "code": "install_gem \"rumale-nearest_neighbors\"\nrequire \"rumale/nearest_neighbors\"\n\n# [length, thickness] in cm\nveggies = Numo::DFloat[[18, 3], [20, 3.5], [16, 2.5],   # carrots\n                       [30, 4.5], [28, 5], [33, 5],      # cucumbers\n                       [6, 6], [5, 5.5], [7, 7]]         # tomatoes\nkind = Numo::Int32[0, 0, 0, 1, 1, 1, 2, 2, 2]\nnames = [\"carrot\", \"cucumber\", \"tomato\"]\nveggies.shape"
          },
          {
            "t": "h",
            "html": "<p><code>shape</code> says [9, 2]: 9 rows of 2 numbers. Rumale wants the answers as numbers – 0 for carrot, 1 for cucumber, 2 for tomato – and the names go in an ordinary list.</p><p>The <strong>k-nearest-neighbours</strong> classifier is the simplest learning method there is: to judge a new vegetable, it looks for the <code>k</code> most similar ones it knows and lets them vote. \"Similar\" means close together, if you plot length and thickness as points.</p>"
          },
          {
            "t": "c",
            "code": "neighbours = Rumale::NearestNeighbors::KNeighborsClassifier.new(n_neighbors: 3)\nneighbours.fit(veggies, kind)\nguesses = neighbours.predict(Numo::DFloat[[25, 4], [6, 6.5], [15, 3]])\nguesses.to_a.map { |k| names[k] }"
          },
          {
            "t": "h",
            "html": "<p>25 cm long and 4 cm thick is closest to the cucumbers, the round one to the tomatoes, the thin one to the carrots. <code>fit</code> did not learn anything here – it only remembers the examples. The work comes in <code>predict</code>: measuring every distance.</p><p>Now something harder: handwriting. <code>digits.csv</code> holds 1797 handwritten digits, collected by <a href='https://archive.ics.uci.edu/dataset/80/optical+recognition+of+handwritten+digits' target='_blank'>UCI</a>. Each is a picture of 8×8 squares, and each square a number from 0 to 16 – how much ink is in it. The number at the end of the line says which digit it is. The file is next to your code (in the browser, the course puts it there):</p>"
          },
          {
            "t": "c",
            "code": "rows = File.read(\"digits.csv\").lines.map { |line| line.split(\",\").map(&:to_i) }\npictures = Numo::DFloat[*rows.map { |r| r[0, 64] }]\nlabels = Numo::Int32[*rows.map(&:last)]\npictures.shape"
          },
          {
            "t": "h",
            "html": "<p>1797 pictures of 64 numbers each. <code>reshape(8, 8)</code> turns a row back into a picture – let's draw the first one with characters that get darker the more ink a square has:</p>"
          },
          {
            "t": "c",
            "code": "picture = pictures[0, true].reshape(8, 8)\npicture.to_a.each do |row|\n  puts row.map { |value| \" .:-=+*#%@\"[(value * 9 / 16).round] }.join(\" \")\nend\nlabels[0]"
          },
          {
            "t": "h",
            "html": "<p>A zero, no doubt. Now learn and test honestly: the classifier gets the first 1000 pictures to learn from and is tested on 50 more it has never seen. (In the browser Numo is plain Ruby – the test takes a few seconds.)</p>"
          },
          {
            "t": "c",
            "code": "learner = Rumale::NearestNeighbors::KNeighborsClassifier.new(n_neighbors: 3)\nlearner.fit(pictures[0...1000, true], labels[0...1000])     # learn from these\nlearner.score(pictures[1000...1050, true], labels[1000...1050])  # test on these"
          },
          {
            "t": "h",
            "html": "<p>48 out of 50 right – with nothing but distances between 64 numbers. <code>[0...1000, true]</code> means rows 0 to 999, all columns.</p><p>Now it's your turn. For the letter, the classifier may learn from all 1797 pictures – the more examples, the better. Below, a letter to Chunky appears; with the mouse or a finger, write the postcode into the red boxes, one digit per box. Every time you lift the pen, the block gets all the digits written so far – 64 numbers each, just like a row of <code>digits.csv</code> – and its answer is stamped on the letter. Four-digit postcodes, as in Australia: try 2000, 3000 or 6000:</p>"
          },
          {
            "t": "c",
            "code": "learner.fit(pictures, labels)   # now from all 1797\nplaces = { \"2000\" => \"Sydney\", \"3000\" => \"Melbourne\", \"4000\" => \"Brisbane\", \"5000\" => \"Adelaide\",\n           \"6000\" => \"Perth\", \"7000\" => \"Hobart\", \"0800\" => \"Darwin\", \"2600\" => \"Canberra\" }\n\nshow_letter(boxes: 4) do |written|   # one Array of 64 numbers per box\n  postcode = learner.predict(Numo::DFloat[*written]).to_a.join\n  \"#{postcode} #{places.fetch(postcode, \"?\")}\"\nend"
          },
          {
            "t": "h",
            "html": "<p>Under the letter you see what Ruby gets: your digits as 8×8 pictures. If the classifier misreads one, look there. The digits in <code>digits.csv</code> were written with pens on forms in the 1990s; a mouse writes differently. Write big, fill the box from top to bottom – or change the code: <code>n_neighbors: 1</code> or <code>5</code>, and the letter reads your digits again straight away.</p><div class='offweb' data-title='On your machine'><p><code>gem install rumale</code> installs everything, the real <a href='https://rubygems.org/gems/numo-narray-alt' target='_blank'>numo-narray-alt</a> too (it gets compiled); then <code>require \"rumale\"</code> is all you need. The code of this lesson runs unchanged – only the letter needs this page. <code>digits.csv</code> comes from the dataset <em>Optical Recognition of Handwritten Digits</em> by E. Alpaydin and C. Kaynak (<a href='https://archive.ics.uci.edu/dataset/80/optical+recognition+of+handwritten+digits' target='_blank'>UCI</a>, CC BY 4.0); <a href='assets/data/digits.csv' download>download it here</a>. Rumale comes under the BSD licence.</p></div><div class='task'><strong>Task:</strong> Ruby can write with characters too. Turn the picture of a seven into the 64 numbers the classifier understands – <code>#</code> is 16, <code>.</code> is 0, row by row – and let <code>learner</code> say what it sees. Store its answer in <code>digit</code>, as a Ruby number.</div>"
          },
          {
            "t": "x",
            "code": "seven = <<~PICTURE\n  .######.\n  ......#.\n  .....#..\n  ....#...\n  ...#....\n  ...#....\n  ..#.....\n  ..#.....\nPICTURE\n# pixels = ...   (64 numbers: # is 16, . is 0)\n# digit = ...   (what learner sees in it, as a Ruby number)\n",
            "check": "digit == 7 && code.include?(\"predict\")",
            "hint": "<code>seven.delete(\"\\n\").chars</code> gives the 64 characters; <code>map { |c| c == \"#\" ? 16 : 0 }</code> makes numbers of them. <code>learner.predict(Numo::DFloat[pixels])</code> wants a table, one row per picture – here one row – and <code>[0]</code> takes out the answer."
          }
        ]
      },
      "ja": {
        "title": "27. Rumale：Rubyで機械学習",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Rubyだけで機械学習</h2><p>前のレッスンではPythonが学びました。<a href='https://github.com/yoshoku/rumale' target='_blank'>Rumale</a>は同じ考え方をRubyに持ってきます。名前も同じです。モデルを作り、<code>fit</code>で例に合わせ、<code>predict</code>で予測させ、<code>score</code>で確かめます。作ったのは巽 敦史さん（yoshoku）で、すべてRubyで書かれています。</p><p>Rumaleは数を<a href='https://github.com/ruby-numo/numo-narray' target='_blank'>Numo</a>の配列に入れます。NumPyにあたるRubyのライブラリで、小数は<code>Numo::DFloat</code>、整数は<code>Numo::Int32</code>です。そのgemの<a href='https://rubygems.org/gems/numo-narray-alt' target='_blank'>numo-narray-alt</a>はCで書かれているので、ブラウザーでは動きません。ここでは同じメソッドを持つRubyだけの代役が代わりに計算します。ただし遅めです。</p><p>Rumaleは小さなgemに分かれています。使うのは<strong>最近傍法</strong>です。まずは野菜から。長さと太さ（cm）です。</p>"
          },
          {
            "t": "c",
            "code": "install_gem \"rumale-nearest_neighbors\"\nrequire \"rumale/nearest_neighbors\"\n\n# [長さ, 太さ] cm\nveggies = Numo::DFloat[[18, 3], [20, 3.5], [16, 2.5],   # ニンジン\n                       [30, 4.5], [28, 5], [33, 5],      # キュウリ\n                       [6, 6], [5, 5.5], [7, 7]]         # トマト\nkind = Numo::Int32[0, 0, 0, 1, 1, 1, 2, 2, 2]\nnames = [\"carrot\", \"cucumber\", \"tomato\"]\nveggies.shape"
          },
          {
            "t": "h",
            "html": "<p><code>shape</code>は[9, 2]、つまり9行で、それぞれ2つの数です。Rumaleには答えを数で渡します。0がニンジン、1がキュウリ、2がトマトで、名前はふつうのリストに入れておきます。</p><p><strong>k近傍法</strong>は、いちばん簡単な学習方法です。新しい野菜を判定するとき、知っている中からいちばん似ている<code>k</code>個を探し、多数決をとらせます。「似ている」とは、長さと太さを点として描いたときに近いということです。</p>"
          },
          {
            "t": "c",
            "code": "neighbours = Rumale::NearestNeighbors::KNeighborsClassifier.new(n_neighbors: 3)\nneighbours.fit(veggies, kind)\nguesses = neighbours.predict(Numo::DFloat[[25, 4], [6, 6.5], [15, 3]])\nguesses.to_a.map { |k| names[k] }"
          },
          {
            "t": "h",
            "html": "<p>長さ25 cm、太さ4 cmはキュウリにいちばん近く、丸いものはトマト、細いものはニンジンに近いです。ここで<code>fit</code>は何も学んでいません。例を覚えるだけです。仕事は<code>predict</code>のときにあります。すべての距離を測るのです。</p><p>次はもっと難しいもの、手書き文字です。<code>digits.csv</code>には、<a href='https://archive.ics.uci.edu/dataset/80/optical+recognition+of+handwritten+digits' target='_blank'>UCI</a>が集めた手書きの数字が1797個入っています。どれも8×8マスの絵で、各マスは0から16の数、つまりインクの量です。行の最後の数が、どの数字かを表します。ファイルはコードの隣にあります（ブラウザーではコースがそこに置きます）：</p>"
          },
          {
            "t": "c",
            "code": "rows = File.read(\"digits.csv\").lines.map { |line| line.split(\",\").map(&:to_i) }\npictures = Numo::DFloat[*rows.map { |r| r[0, 64] }]\nlabels = Numo::Int32[*rows.map(&:last)]\npictures.shape"
          },
          {
            "t": "h",
            "html": "<p>64個の数でできた絵が1797枚です。<code>reshape(8, 8)</code>で1行を絵に戻せます。インクが多いマスほど濃い文字を使って、最初の1枚を描いてみましょう：</p>"
          },
          {
            "t": "c",
            "code": "picture = pictures[0, true].reshape(8, 8)\npicture.to_a.each do |row|\n  puts row.map { |value| \" .:-=+*#%@\"[(value * 9 / 16).round] }.join(\" \")\nend\nlabels[0]"
          },
          {
            "t": "h",
            "html": "<p>まちがいなく0です。では学ばせて、正直にテストします。最初の1000枚で学ばせ、見たことのない別の50枚でテストします。（ブラウザーではNumoがRubyだけで計算するので、テストに数秒かかります。）</p>"
          },
          {
            "t": "c",
            "code": "learner = Rumale::NearestNeighbors::KNeighborsClassifier.new(n_neighbors: 3)\nlearner.fit(pictures[0...1000, true], labels[0...1000])     # これで学ぶ\nlearner.score(pictures[1000...1050, true], labels[1000...1050])  # これでテスト"
          },
          {
            "t": "h",
            "html": "<p>50枚中48枚正解です。使ったのは64個の数どうしの距離だけです。<code>[0...1000, true]</code>は、0行目から999行目まで、すべての列という意味です。</p><p>今度はあなたの番です。封筒のためには、1797枚すべてから学ばせます。例が多いほど、よく当たります。下にチャンキーあての封筒が出てきます。マウスや指で、赤い枠に郵便番号を1枠に1文字ずつ書いてください。ペンを離すたびに、ブロックはそれまでに書いた数字をすべて受け取ります。どれも<code>digits.csv</code>の1行と同じ64個の数です。そしてブロックの答えが封筒にスタンプされます。日本の郵便番号は7桁ですが、ここではオーストラリアと同じ4桁です。2000、3000、6000などを書いてみましょう：</p>"
          },
          {
            "t": "c",
            "code": "learner.fit(pictures, labels)   # 今度は1797枚すべてから\nplaces = { \"2000\" => \"Sydney\", \"3000\" => \"Melbourne\", \"4000\" => \"Brisbane\", \"5000\" => \"Adelaide\",\n           \"6000\" => \"Perth\", \"7000\" => \"Hobart\", \"0800\" => \"Darwin\", \"2600\" => \"Canberra\" }\n\nshow_letter(boxes: 4) do |written|   # 枠ごとに64個の数の配列\n  postcode = learner.predict(Numo::DFloat[*written]).to_a.join\n  \"#{postcode} #{places.fetch(postcode, \"?\")}\"\nend"
          },
          {
            "t": "h",
            "html": "<p>封筒の下には、Rubyが受け取るもの、つまりあなたの数字の8×8の絵が見えます。読みまちがえたら、そこを見てみましょう。<code>digits.csv</code>の数字は、1990年代にペンで用紙に書かれたものです。マウスで書くと形が変わります。大きく、枠の上から下までいっぱいに書くか、コードを変えてみましょう。<code>n_neighbors: 1</code>や<code>5</code>にすると、封筒はすぐにもう一度あなたの数字を読みます。</p><div class='offweb' data-title='自分のコンピューターでは'><p><code>gem install rumale</code>で、本物の<a href='https://rubygems.org/gems/numo-narray-alt' target='_blank'>numo-narray-alt</a>も含めてすべてインストールされます（そのときコンパイルされます）。あとは<code>require \"rumale\"</code>だけです。このレッスンのコードはそのまま動きます。封筒だけはこのページが必要です。<code>digits.csv</code>は、E. AlpaydinとC. Kaynakによるデータセット<em>Optical Recognition of Handwritten Digits</em>（<a href='https://archive.ics.uci.edu/dataset/80/optical+recognition+of+handwritten+digits' target='_blank'>UCI</a>、CC BY 4.0）から取りました。<a href='assets/data/digits.csv' download>ここからダウンロード</a>できます。RumaleはBSDライセンスです。</p></div><div class='task'><strong>課題：</strong>Rubyは文字でも絵を描けます。7の絵を、分類器がわかる64個の数にしましょう。<code>#</code>は16、<code>.</code>は0で、1行ずつ順番です。そして<code>learner</code>に何が見えるか言わせ、その答えをRubyの数値として<code>digit</code>に入れてください。</div>"
          },
          {
            "t": "x",
            "code": "seven = <<~PICTURE\n  .######.\n  ......#.\n  .....#..\n  ....#...\n  ...#....\n  ...#....\n  ..#.....\n  ..#.....\nPICTURE\n# pixels = ...   （64個の数：#は16、.は0）\n# digit = ...   （learnerに見えたもの。Rubyの数値で）\n",
            "check": "digit == 7 && code.include?(\"predict\")",
            "hint": "<code>seven.delete(\"\\n\").chars</code>で64個の文字になるよ。<code>map { |c| c == \"#\" ? 16 : 0 }</code>で数にしてね。<code>learner.predict(Numo::DFloat[pixels])</code>は1枚の絵を1行とする表がほしいから、ここでは1行だけ。<code>[0]</code>で答えを取り出してね。"
          }
        ]
      }
    },
    {
      "id": "sequel",
      "de": {
        "title": "28. Sequel: eine Datenbank aus Ruby",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Eine Datenbank aus Ruby</h2><p>Eine <strong>Datenbank</strong> hält Daten in Tabellen – Zeilen und Spalten, wie eine Tabellenkalkulation – und beantwortet Fragen dazu in <strong>SQL</strong>. Mit <a href='https://sequel.jeremyevans.net' target='_blank'>Sequel</a> von Jeremy Evans (der auch Roda aus Lektion 16 geschrieben hat) machst du das alles in Ruby: Du rufst Methoden auf, und Sequel schreibt das SQL.</p><p>Darunter läuft <strong>SQLite</strong>, die kleine Datenbank, die in jedem Handy und jedem Browser steckt. Hier läuft sie direkt in dieser Seite (rund 1 MB, geladen, sobald du die Lektion öffnest) und hält die Datenbank im Speicher – nach dem Neuladen ist sie leer. Bauen wir eine kleine Zeiterfassung:</p>"
          },
          {
            "t": "c",
            "code": "install_gem \"sequel\"\nrequire \"sequel\"\n\nDB = Sequel.sqlite   # eine Datenbank im Speicher\n\nDB.create_table(:eintraege) do\n  primary_key :id\n  String    :projekt, null: false\n  Float     :stunden\n  Date      :tag\n  TrueClass :verrechenbar, default: false\nend\nDB.tables"
          },
          {
            "t": "h",
            "html": "<p><code>Sequel.sqlite</code> öffnet eine Datenbank; <code>DB</code> ist der übliche Name dafür. <code>create_table</code> beschreibt eine Tabelle: <code>primary_key :id</code> nummeriert die Zeilen selbst, und jede Zeile danach ist eine Spalte mit ihrem Typ – Text, Kommazahl, Datum, wahr oder falsch. <code>null: false</code> heisst, dass das Projekt nie leer sein darf.</p><p>Jetzt ein paar Zeilen. <code>DB[:eintraege]</code> ist die Tabelle als <strong>Dataset</strong>, und <code>insert</code> fügt eine Zeile ein:</p>"
          },
          {
            "t": "c",
            "code": "eintraege = DB[:eintraege]\neintraege.insert(projekt: \"Chunky\", stunden: 2.5, tag: Date.new(2026, 10, 5), verrechenbar: true)\neintraege.insert(projekt: \"Bacon\",  stunden: 1.0, tag: Date.new(2026, 10, 5))\neintraege.insert(projekt: \"Chunky\", stunden: 3.0, tag: Date.new(2026, 10, 6), verrechenbar: true)\neintraege.insert(projekt: \"Speck\",  stunden: 0.5, tag: Date.new(2026, 10, 6))\neintraege.count"
          },
          {
            "t": "h",
            "html": "<p>Jedes <code>insert</code> bekommt einen Hash, Spalte für Spalte; was du weglässt (<code>verrechenbar</code> bei Bacon), bekommt seinen Standardwert. Zurücklesen geht wie bei einem Array aus Hashes:</p>"
          },
          {
            "t": "c",
            "code": "eintraege.order(:tag).each do |row|\n  puts \"#{row[:tag]}  #{row[:projekt].ljust(7)} #{row[:stunden]} h #{row[:verrechenbar] ? \"Fr.\" : \"\"}\"\nend\nrow = eintraege.first\n[row.class, row[:tag].class, row[:verrechenbar].class]"
          },
          {
            "t": "h",
            "html": "<p>Jede Zeile ist ein ganz normaler Ruby-Hash, und die Werte haben wieder ihre Ruby-Typen: Der Tag ist ein <code>Date</code>, verrechenbar ist <code>true</code> oder <code>false</code> – obwohl SQLite selbst nur Zahlen und Text kennt.</p><p>Die eigentliche Stärke ist das Fragen. Eine Dataset-Methode gibt ein neues, engeres Dataset zurück, also verkettest du sie wie Ruby-Methoden. <code>sql</code> zeigt, was Sequel schicken wird:</p>"
          },
          {
            "t": "c",
            "code": "chunky = eintraege.where(projekt: \"Chunky\").order(:tag)\nputs chunky.sql\nchunky.map(:stunden)"
          },
          {
            "t": "h",
            "html": "<p>Aus <code>where(projekt: \"Chunky\")</code> wurde <code>WHERE (`projekt` = 'Chunky')</code>, aus <code>order</code> wurde <code>ORDER BY</code>. Gefragt wird erst, wenn du die Zeilen willst – hier mit <code>map(:stunden)</code>, das eine Spalte nimmt.</p><p>Für Vergleiche nimmt <code>where</code> einen Block, in dem Spaltennamen einfach Namen sind. Und SQL kann für dich zählen und zusammenzählen:</p>"
          },
          {
            "t": "c",
            "code": "puts eintraege.where { stunden > 2 }.count\nputs eintraege.sum(:stunden)\neintraege.group_and_count(:projekt).order(:projekt).all"
          },
          {
            "t": "h",
            "html": "<p>Zwei Einträge haben mehr als 2 Stunden; 7.0 Stunden insgesamt; <code>group_and_count</code> zählt die Zeilen jedes Projekts. Jetzt die Frage, für die es jede Zeiterfassung gibt – wie viele Stunden pro Projekt? <code>group</code> legt die Zeilen eines Projekts zusammen, und <code>sum</code> zählt jede Gruppe zusammen:</p>"
          },
          {
            "t": "c",
            "code": "rapport = eintraege.group(:projekt).select(:projekt) { sum(:stunden).as(:total) }.order(:projekt)\nputs rapport.sql\nrapport.all"
          },
          {
            "t": "h",
            "html": "<p>Das ist ein ganzer Rapport in einer SQL-Abfrage: Die Datenbank rechnet, und Ruby bekommt drei kurze Zeilen. Bei vielen tausend Einträgen ist das viel schneller, als alle nach Ruby zu holen.</p><p>Zeilen ändern und löschen geht auch auf einem Dataset – auf allen seinen Zeilen auf einmal:</p>"
          },
          {
            "t": "c",
            "code": "eintraege.where(projekt: \"Bacon\").update(verrechenbar: true)\neintraege.where(projekt: \"Speck\").delete\neintraege.where(verrechenbar: true).map(:projekt)"
          },
          {
            "t": "h",
            "html": "<p><code>update</code> hat jede Bacon-Zeile geändert, <code>delete</code> jede Speck-Zeile gelöscht. Vorsicht: <code>DB[:eintraege].delete</code> ohne <code>where</code> leert die ganze Tabelle.</p><p>Für ein richtiges Programm hat Sequel <strong>Models</strong>: eine Klasse pro Tabelle, ein Objekt pro Zeile, mit deinen eigenen Methoden daran:</p>"
          },
          {
            "t": "c",
            "code": "class Eintrag < Sequel::Model(:eintraege)\n  def zusammenfassung\n    \"#{tag}: #{stunden} h für #{projekt}\"\n  end\nend\n\nEintrag.create(projekt: \"Speck\", stunden: 1.5, tag: Date.new(2026, 10, 7))\nEintrag.order(:tag).map(&:zusammenfassung)"
          },
          {
            "t": "h",
            "html": "<p><code>Sequel::Model(:eintraege)</code> liest die Spalten der Tabelle und gibt der Klasse für jede eine Methode, darum funktionieren <code>tag</code>, <code>stunden</code> und <code>projekt</code> in <code>zusammenfassung</code> einfach so. <code>create</code> fügt eine Zeile ein und gibt sie als Objekt zurück.</p><p>Noch etwas: Die Datenbank wacht selbst über ihre Regeln. Die Projekt-Spalte wurde mit <code>null: false</code> angelegt – versuchen wir, das zu brechen:</p>"
          },
          {
            "t": "c",
            "code": "begin\n  eintraege.insert(stunden: 1.0)   # kein Projekt\nrescue Sequel::NotNullConstraintViolation => error\n  puts \"Abgelehnt: #{error.class}\"\nend\neintraege.count"
          },
          {
            "t": "h",
            "html": "<p>SQLite hat die Zeile abgelehnt, und Sequel hat die Ablehnung in eine Ruby-Exception verwandelt, die du mit <code>rescue</code> fangen kannst. Die Tabelle hat noch ihre vier Zeilen.</p><p>Bis jetzt lag die Datenbank im Speicher: Lädst du die Seite neu, ist sie weg. Gib <code>Sequel.sqlite</code> einen Dateinamen, und die Datenbank ist eine echte SQLite-Datei. <code>create_table?</code> – mit Fragezeichen – legt die Tabelle nur an, wenn es sie noch nicht gibt, also kann die Zelle immer wieder laufen. Führe sie ein paarmal aus:</p>"
          },
          {
            "t": "c",
            "code": "zeiterfassung = Sequel.sqlite(\"zeiterfassung.db\")   # eine Datenbank in einer Datei\nzeiterfassung.create_table?(:eintraege) do\n  primary_key :id\n  String :projekt, null: false\n  Float  :stunden\nend\nzeiterfassung[:eintraege].insert(projekt: \"Chunky\", stunden: 1.5)\nzeiterfassung[:eintraege].count"
          },
          {
            "t": "h",
            "html": "<p>Jeder Lauf fügt eine Zeile hinzu, und die Zahl wächst: Die Zeilen liegen in <code>zeiterfassung.db</code>, nicht in der Zelle. Unter der Ausgabe gibt es die Datei zum Herunterladen – eine echte SQLite-Datenbank, die jedes SQLite-Werkzeug öffnet, etwa <a href='https://sqlitebrowser.org' target='_blank'>DB Browser for SQLite</a>. In einer Lektion hält die Datei, solange die Seite offen ist; in der <strong>Werkstatt</strong> bleibt die Datenbank eines Programms beim Projekt, und eine hochgeladene <code>.db</code>-Datei öffnest du genauso.</p><div class='offweb' data-title='Auf deinem Computer'><p><code>gem install sequel sqlite3</code>. Der Code läuft unverändert, und <code>zeiterfassung.db</code> ist eine Datei neben deinem Programm. Sequel spricht mit demselben Ruby-Code auch mit PostgreSQL und MySQL. Hier im Browser ersetzt ein kleiner Stellvertreter auf <a href='https://sql.js.org' target='_blank'>sql.js</a> – SQLite, nach WebAssembly übersetzt – das sqlite3-Gem, das eine C-Erweiterung ist; Sequel selbst ist das echte Gem. Sequel und sql.js stehen unter der MIT-Lizenz, SQLite ist gemeinfrei.</p></div><div class='task'><strong>Aufgabe:</strong> Hier ist eine frische Datenbank mit fünf Zeiteinträgen. Rechne mit Sequel aus, wie viele Stunden jedes Projekt gebraucht hat, und speichere das in <code>stunden_pro_projekt</code> als Ruby-Hash, etwa <code>{\"Bacon\" =&gt; 1.5, …}</code>.</div>"
          },
          {
            "t": "x",
            "code": "install_gem \"sequel\"\nrequire \"sequel\"\n\nzeit = Sequel.sqlite\nzeit.create_table(:arbeit) do\n  primary_key :id\n  String :projekt\n  Float  :stunden\nend\nzeit[:arbeit].import([:projekt, :stunden],\n  [[\"Chunky\", 2.5], [\"Speck\", 0.5], [\"Bacon\", 1.5], [\"Chunky\", 3.0], [\"Speck\", 1.5]])\n\n# stunden_pro_projekt = ...   (ein Ruby-Hash: Projekt => Stunden)\n",
            "check": "stunden_pro_projekt.is_a?(Hash) && stunden_pro_projekt.transform_values(&:to_f) == { \"Bacon\" => 1.5, \"Chunky\" => 5.5, \"Speck\" => 2.0 } && code.include?(\"group\")",
            "hint": "<code>zeit[:arbeit].group(:projekt)</code> legt die Zeilen jedes Projekts zusammen; <code>.select(:projekt) { sum(:stunden).as(:total) }</code> zählt sie zusammen, wie im Rapport oben. <code>.as_hash(:projekt, :total)</code> macht daraus den Ruby-Hash."
          }
        ]
      },
      "en": {
        "title": "28. Sequel: a database from Ruby",
        "cells": [
          {
            "t": "h",
            "html": "<h2>A database from Ruby</h2><p>A <strong>database</strong> keeps data in tables – rows and columns, like a spreadsheet – and answers questions about it in <strong>SQL</strong>. <a href='https://sequel.jeremyevans.net' target='_blank'>Sequel</a>, by Jeremy Evans (who also wrote Roda from lesson 16), lets you do all of that in Ruby: you call methods, and Sequel writes the SQL.</p><p>Underneath runs <strong>SQLite</strong>, the small database that lives in every phone and browser. Here it runs right in this page (about 1 MB, loaded when you open the lesson) and keeps the database in memory – a reload starts empty. Let's build a little time tracker:</p>"
          },
          {
            "t": "c",
            "code": "install_gem \"sequel\"\nrequire \"sequel\"\n\nDB = Sequel.sqlite   # a database in memory\n\nDB.create_table(:entries) do\n  primary_key :id\n  String    :project, null: false\n  Float     :hours\n  Date      :day\n  TrueClass :billable, default: false\nend\nDB.tables"
          },
          {
            "t": "h",
            "html": "<p><code>Sequel.sqlite</code> opens a database; <code>DB</code> is the usual name for it. <code>create_table</code> describes a table: <code>primary_key :id</code> numbers the rows by itself, and each line after it is a column with its type – text, a decimal number, a date, true or false. <code>null: false</code> means the project may never be empty.</p><p>Now some rows. <code>DB[:entries]</code> is the table as a <strong>dataset</strong>, and <code>insert</code> adds a row:</p>"
          },
          {
            "t": "c",
            "code": "entries = DB[:entries]\nentries.insert(project: \"Chunky\", hours: 2.5, day: Date.new(2026, 10, 5), billable: true)\nentries.insert(project: \"Bacon\",  hours: 1.0, day: Date.new(2026, 10, 5))\nentries.insert(project: \"Chunky\", hours: 3.0, day: Date.new(2026, 10, 6), billable: true)\nentries.insert(project: \"Speck\",  hours: 0.5, day: Date.new(2026, 10, 6))\nentries.count"
          },
          {
            "t": "h",
            "html": "<p>Each <code>insert</code> takes a hash, column by column; what you leave out (<code>billable</code> on the Bacon row) gets its default. Reading back works like an array of hashes:</p>"
          },
          {
            "t": "c",
            "code": "entries.order(:day).each do |row|\n  puts \"#{row[:day]}  #{row[:project].ljust(7)} #{row[:hours]} h #{row[:billable] ? \"$\" : \"\"}\"\nend\nrow = entries.first\n[row.class, row[:day].class, row[:billable].class]"
          },
          {
            "t": "h",
            "html": "<p>Every row is a plain Ruby hash, and the values have their Ruby types again: the day is a <code>Date</code>, billable is <code>true</code> or <code>false</code> – even though SQLite itself only knows numbers and text.</p><p>The real power is asking questions. A dataset method returns a new, narrower dataset, so you chain them like Ruby methods. <code>sql</code> shows what Sequel will send:</p>"
          },
          {
            "t": "c",
            "code": "chunky = entries.where(project: \"Chunky\").order(:day)\nputs chunky.sql\nchunky.map(:hours)"
          },
          {
            "t": "h",
            "html": "<p><code>where(project: \"Chunky\")</code> became <code>WHERE (`project` = 'Chunky')</code>, <code>order</code> became <code>ORDER BY</code>. Nothing is asked until you want the rows – here with <code>map(:hours)</code>, which takes one column.</p><p>For comparisons, <code>where</code> takes a block in which column names are just names. And SQL can count and add up for you:</p>"
          },
          {
            "t": "c",
            "code": "puts entries.where { hours > 2 }.count\nputs entries.sum(:hours)\nentries.group_and_count(:project).order(:project).all"
          },
          {
            "t": "h",
            "html": "<p>Two entries have more than 2 hours; 7.0 hours in total; <code>group_and_count</code> counts the rows of each project. Now the question every time tracker exists for – how many hours per project? <code>group</code> puts the rows of a project together, and <code>sum</code> adds up each group:</p>"
          },
          {
            "t": "c",
            "code": "timesheet = entries.group(:project).select(:project) { sum(:hours).as(:total) }.order(:project)\nputs timesheet.sql\ntimesheet.all"
          },
          {
            "t": "h",
            "html": "<p>That is a whole timesheet in one SQL query: the database does the adding, and Ruby gets three short rows. With many thousands of entries, that is much faster than loading them all into Ruby.</p><p>Changing and removing rows works on a dataset too – on all of its rows at once:</p>"
          },
          {
            "t": "c",
            "code": "entries.where(project: \"Bacon\").update(billable: true)\nentries.where(project: \"Speck\").delete\nentries.where(billable: true).map(:project)"
          },
          {
            "t": "h",
            "html": "<p><code>update</code> changed every Bacon row, <code>delete</code> removed every Speck row. Careful: <code>DB[:entries].delete</code> without a <code>where</code> empties the whole table.</p><p>For a real program, Sequel has <strong>models</strong>: a class per table, an object per row, with your own methods on it:</p>"
          },
          {
            "t": "c",
            "code": "class Entry < Sequel::Model(:entries)\n  def summary\n    \"#{day}: #{hours} h for #{project}\"\n  end\nend\n\nEntry.create(project: \"Speck\", hours: 1.5, day: Date.new(2026, 10, 7))\nEntry.order(:day).map(&:summary)"
          },
          {
            "t": "h",
            "html": "<p><code>Sequel::Model(:entries)</code> reads the table's columns and gives the class a method for each, so <code>day</code>, <code>hours</code> and <code>project</code> just work inside <code>summary</code>. <code>create</code> inserts a row and returns it as an object.</p><p>One more thing: the database guards its rules itself. The project column was declared <code>null: false</code> – let's try to break it:</p>"
          },
          {
            "t": "c",
            "code": "begin\n  entries.insert(hours: 1.0)   # no project\nrescue Sequel::NotNullConstraintViolation => error\n  puts \"Refused: #{error.class}\"\nend\nentries.count"
          },
          {
            "t": "h",
            "html": "<p>SQLite refused the row, and Sequel turned the refusal into a Ruby exception you can <code>rescue</code>. The table still has its four rows.</p><p>So far the database has lived in memory: reload the page and it is gone. Give <code>Sequel.sqlite</code> a file name, and the database is a real SQLite file. <code>create_table?</code> – with a question mark – creates the table only if it is not there yet, so the cell can run again and again. Run it a few times:</p>"
          },
          {
            "t": "c",
            "code": "timelog = Sequel.sqlite(\"timelog.db\")   # a database in a file\ntimelog.create_table?(:entries) do\n  primary_key :id\n  String :project, null: false\n  Float  :hours\nend\ntimelog[:entries].insert(project: \"Chunky\", hours: 1.5)\ntimelog[:entries].count"
          },
          {
            "t": "h",
            "html": "<p>Every run adds a row, and the count grows: the rows are kept in <code>timelog.db</code>, not in the cell. Below the output the file is offered as a download – a real SQLite database that opens in any SQLite tool, such as <a href='https://sqlitebrowser.org' target='_blank'>DB Browser for SQLite</a>. In a lesson the file lasts as long as the page is open; in the <strong>workshop</strong> a program's database is kept with the project, and an uploaded <code>.db</code> file opens the same way.</p><div class='offweb' data-title='On your machine'><p><code>gem install sequel sqlite3</code>. The code runs unchanged, and <code>timelog.db</code> is a file next to your program. Sequel also talks to PostgreSQL and MySQL with the same Ruby code. Here in the browser the sqlite3 gem – a C extension – is replaced by a small stand-in on <a href='https://sql.js.org' target='_blank'>sql.js</a>, SQLite compiled to WebAssembly; Sequel itself is the real gem. Sequel and sql.js come under the MIT licence; SQLite is in the public domain.</p></div><div class='task'><strong>Task:</strong> Here is a fresh database with five time entries. Use Sequel to work out how many hours each project took, and store it in <code>hours_per_project</code> as a Ruby hash, such as <code>{\"Bacon\" =&gt; 1.5, …}</code>.</div>"
          },
          {
            "t": "x",
            "code": "install_gem \"sequel\"\nrequire \"sequel\"\n\nlog = Sequel.sqlite\nlog.create_table(:work) do\n  primary_key :id\n  String :project\n  Float  :hours\nend\nlog[:work].import([:project, :hours],\n  [[\"Chunky\", 2.5], [\"Speck\", 0.5], [\"Bacon\", 1.5], [\"Chunky\", 3.0], [\"Speck\", 1.5]])\n\n# hours_per_project = ...   (a Ruby hash: project => hours)\n",
            "check": "hours_per_project.is_a?(Hash) && hours_per_project.transform_values(&:to_f) == { \"Bacon\" => 1.5, \"Chunky\" => 5.5, \"Speck\" => 2.0 } && code.include?(\"group\")",
            "hint": "<code>log[:work].group(:project)</code> puts each project's rows together; <code>.select(:project) { sum(:hours).as(:total) }</code> adds them up, as in the timesheet above. <code>.as_hash(:project, :total)</code> then makes the Ruby hash."
          }
        ]
      },
      "ja": {
        "title": "28. Sequel：Rubyからデータベース",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Rubyからデータベース</h2><p><strong>データベース</strong>は、表計算のように行と列からなるテーブルにデータを保存し、<strong>SQL</strong>での質問に答えます。Jeremy Evansさん（レッスン16のRodaの作者でもあります）の<a href='https://sequel.jeremyevans.net' target='_blank'>Sequel</a>を使うと、それをすべてRubyでできます。あなたはメソッドを呼ぶだけで、SQLはSequelが書いてくれます。</p><p>その下では、どのスマートフォンにもブラウザにも入っている小さなデータベース、<strong>SQLite</strong>が動いています。ここではこのページの中で動き（約1 MB、レッスンを開くと読み込みます）、データベースはメモリ上にあります。再読み込みすると空に戻ります。小さな時間記録を作ってみましょう：</p>"
          },
          {
            "t": "c",
            "code": "install_gem \"sequel\"\nrequire \"sequel\"\n\nDB = Sequel.sqlite   # メモリ上のデータベース\n\nDB.create_table(:entries) do\n  primary_key :id\n  String    :project, null: false\n  Float     :hours\n  Date      :day\n  TrueClass :billable, default: false\nend\nDB.tables"
          },
          {
            "t": "h",
            "html": "<p><code>Sequel.sqlite</code>はデータベースを開きます。<code>DB</code>はその定番の名前です。<code>create_table</code>はテーブルを定義します。<code>primary_key :id</code>は行に自動で番号を振り、そのあとの各行は型つきの列です。文字列、小数、日付、真か偽。<code>null: false</code>は、プロジェクトが空になってはいけないという意味です。</p><p>では行を追加しましょう。<code>DB[:entries]</code>はテーブルを<strong>データセット</strong>として表し、<code>insert</code>が1行を追加します：</p>"
          },
          {
            "t": "c",
            "code": "entries = DB[:entries]\nentries.insert(project: \"Chunky\", hours: 2.5, day: Date.new(2026, 10, 5), billable: true)\nentries.insert(project: \"Bacon\",  hours: 1.0, day: Date.new(2026, 10, 5))\nentries.insert(project: \"Chunky\", hours: 3.0, day: Date.new(2026, 10, 6), billable: true)\nentries.insert(project: \"Speck\",  hours: 0.5, day: Date.new(2026, 10, 6))\nentries.count"
          },
          {
            "t": "h",
            "html": "<p><code>insert</code>には列ごとのハッシュを渡します。省略した列（Baconの行の<code>billable</code>）にはデフォルト値が入ります。読み出しは、ハッシュの配列と同じように使えます：</p>"
          },
          {
            "t": "c",
            "code": "entries.order(:day).each do |row|\n  puts \"#{row[:day]}  #{row[:project].ljust(7)} #{row[:hours]} h #{row[:billable] ? \"$\" : \"\"}\"\nend\nrow = entries.first\n[row.class, row[:day].class, row[:billable].class]"
          },
          {
            "t": "h",
            "html": "<p>各行はふつうのRubyのハッシュで、値はRubyの型に戻っています。日付は<code>Date</code>、billableは<code>true</code>か<code>false</code>です。SQLite自身は数値と文字列しか知らないのに、です。</p><p>本当の力は、質問をすることにあります。データセットのメソッドは、新しく絞り込んだデータセットを返すので、Rubyのメソッドのようにつなげられます。<code>sql</code>は、Sequelが送るSQLを見せてくれます：</p>"
          },
          {
            "t": "c",
            "code": "chunky = entries.where(project: \"Chunky\").order(:day)\nputs chunky.sql\nchunky.map(:hours)"
          },
          {
            "t": "h",
            "html": "<p><code>where(project: \"Chunky\")</code>は<code>WHERE (`project` = 'Chunky')</code>に、<code>order</code>は<code>ORDER BY</code>になりました。実際に質問するのは、行が必要になったときです。ここでは1つの列を取り出す<code>map(:hours)</code>です。</p><p>比較をするには、<code>where</code>にブロックを渡します。ブロックの中では列名をそのまま書けます。そしてSQLは、数えたり合計したりもしてくれます：</p>"
          },
          {
            "t": "c",
            "code": "puts entries.where { hours > 2 }.count\nputs entries.sum(:hours)\nentries.group_and_count(:project).order(:project).all"
          },
          {
            "t": "h",
            "html": "<p>2時間を超えるエントリーは2つ、合計は7.0時間、<code>group_and_count</code>はプロジェクトごとに行を数えます。では、時間記録がそもそも答えるべき質問です。プロジェクトごとに何時間？ <code>group</code>がプロジェクトごとに行をまとめ、<code>sum</code>がグループごとに合計します：</p>"
          },
          {
            "t": "c",
            "code": "timesheet = entries.group(:project).select(:project) { sum(:hours).as(:total) }.order(:project)\nputs timesheet.sql\ntimesheet.all"
          },
          {
            "t": "h",
            "html": "<p>1つのSQLの問い合わせで、作業報告がまるごとできました。計算はデータベースがして、Rubyには短い3行が届きます。エントリーが何千件もあるなら、全部をRubyに読み込むよりずっと速くなります。</p><p>行の変更や削除も、データセットに対して行えます。そのすべての行に一度に効きます：</p>"
          },
          {
            "t": "c",
            "code": "entries.where(project: \"Bacon\").update(billable: true)\nentries.where(project: \"Speck\").delete\nentries.where(billable: true).map(:project)"
          },
          {
            "t": "h",
            "html": "<p><code>update</code>はBaconの行をすべて変え、<code>delete</code>はSpeckの行をすべて消しました。注意してください。<code>where</code>なしの<code>DB[:entries].delete</code>は、テーブルを空にしてしまいます。</p><p>本格的なプログラムのために、Sequelには<strong>モデル</strong>があります。テーブルごとにクラスを、行ごとにオブジェクトを作り、自分のメソッドを持たせられます：</p>"
          },
          {
            "t": "c",
            "code": "class Entry < Sequel::Model(:entries)\n  def summary\n    \"#{day}: #{hours} h for #{project}\"\n  end\nend\n\nEntry.create(project: \"Speck\", hours: 1.5, day: Date.new(2026, 10, 7))\nEntry.order(:day).map(&:summary)"
          },
          {
            "t": "h",
            "html": "<p><code>Sequel::Model(:entries)</code>はテーブルの列を読み取り、列ごとのメソッドをクラスに作ります。だから<code>summary</code>の中で<code>day</code>、<code>hours</code>、<code>project</code>がそのまま使えます。<code>create</code>は行を追加し、それをオブジェクトとして返します。</p><p>もうひとつ、データベースは自分のルールを自分で守ります。projectの列は<code>null: false</code>で作りました。それを破ってみましょう：</p>"
          },
          {
            "t": "c",
            "code": "begin\n  entries.insert(hours: 1.0)   # プロジェクトなし\nrescue Sequel::NotNullConstraintViolation => error\n  puts \"Refused: #{error.class}\"\nend\nentries.count"
          },
          {
            "t": "h",
            "html": "<p>SQLiteはその行を拒否し、Sequelはその拒否を、<code>rescue</code>で受け止められるRubyの例外に変えました。テーブルには4行がそのまま残っています。</p><p>ここまで、データベースはメモリ上にありました。ページを再読み込みすると消えてしまいます。<code>Sequel.sqlite</code>にファイル名を渡すと、データベースは本物のSQLiteファイルになります。<code>create_table?</code>（クエスチョンマークつき）は、テーブルがまだないときだけ作るので、このセルは何度でも実行できます。何回か実行してみましょう：</p>"
          },
          {
            "t": "c",
            "code": "timelog = Sequel.sqlite(\"timelog.db\")   # ファイルの中のデータベース\ntimelog.create_table?(:entries) do\n  primary_key :id\n  String :project, null: false\n  Float  :hours\nend\ntimelog[:entries].insert(project: \"Chunky\", hours: 1.5)\ntimelog[:entries].count"
          },
          {
            "t": "h",
            "html": "<p>実行するたびに行が増え、数も増えていきます。行はセルではなく<code>timelog.db</code>に保存されているからです。出力の下には、このファイルがダウンロードできるように出ています。本物のSQLiteデータベースなので、<a href='https://sqlitebrowser.org' target='_blank'>DB Browser for SQLite</a>などのSQLiteツールで開けます。レッスンの中では、ファイルはページを開いている間だけ残ります。<strong>工房</strong>では、プログラムのデータベースはプロジェクトと一緒に保存され、アップロードした<code>.db</code>ファイルも同じように開けます。</p><div class='offweb' data-title='自分のコンピューターでは'><p><code>gem install sequel sqlite3</code>をすれば、コードはそのまま動きます。<code>timelog.db</code>はプログラムの隣にあるファイルになります。Sequelは同じRubyのコードでPostgreSQLやMySQLとも話せます。このブラウザでは、C拡張であるsqlite3 gemの代わりに、WebAssemblyにコンパイルしたSQLiteである<a href='https://sql.js.org' target='_blank'>sql.js</a>の上に作った小さな代役が動いています。Sequel自体は本物のgemです。Sequelとsql.jsはMITライセンス、SQLiteはパブリックドメインです。</p></div><div class='task'><strong>課題：</strong>5件の時間記録が入った新しいデータベースがあります。Sequelを使って、プロジェクトごとに何時間かかったかを計算し、<code>{\"Bacon\" =&gt; 1.5, …}</code>のようなRubyのハッシュとして<code>hours_per_project</code>に入れましょう。</div>"
          },
          {
            "t": "x",
            "code": "install_gem \"sequel\"\nrequire \"sequel\"\n\nlog = Sequel.sqlite\nlog.create_table(:work) do\n  primary_key :id\n  String :project\n  Float  :hours\nend\nlog[:work].import([:project, :hours],\n  [[\"Chunky\", 2.5], [\"Speck\", 0.5], [\"Bacon\", 1.5], [\"Chunky\", 3.0], [\"Speck\", 1.5]])\n\n# hours_per_project = ...   （Rubyのハッシュ：プロジェクト => 時間）\n",
            "check": "hours_per_project.is_a?(Hash) && hours_per_project.transform_values(&:to_f) == { \"Bacon\" => 1.5, \"Chunky\" => 5.5, \"Speck\" => 2.0 } && code.include?(\"group\")",
            "hint": "<code>log[:work].group(:project)</code>でプロジェクトごとに行をまとめて、上の作業報告と同じように<code>.select(:project) { sum(:hours).as(:total) }</code>で合計するんだ。最後に<code>.as_hash(:project, :total)</code>でRubyのハッシュになるよ。"
          }
        ]
      }
    },
    {
      "id": "scarpe",
      "de": {
        "title": "29. Shoes-Apps mit Scarpe",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Shoes: kleine Fenster, wenig Code</h2><p><strong>Shoes</strong> ist why the lucky stiffs GUI-Baukasten – dieselbe Feder, von der auch „Chunky Bacon“ stammt. Die Idee: ein Fenster mit Text und Knöpfen soll ein paar Zeilen kosten, nicht ein paar hundert.</p><p><a href='https://github.com/scarpe-team/scarpe' target='_blank'><strong>Scarpe</strong></a> ist die heutige Wiederauflage, und sie ist in zwei Teile geschnitten:</p><ul><li><strong>Lacci</strong> (die Gem <code>lacci</code>) kennt nur die Sprache: <code>stack</code>, <code>para</code>, <code>button</code>. Von Pixeln weiss sie nichts.</li><li>Ein <strong>Display-Service</strong> malt diesen Baum dann wirklich – mit Webview, mit libui, oder eben mit irgendetwas anderem.</li></ul><p>Genau deshalb läuft Shoes hier: Diese Seite bringt ihren eigenen Display-Service mit, der den Baum ins HTML dieser Seite zeichnet. Die Gem darunter ist unverändert die echte.</p>"
          },
          {
            "t": "c",
            "code": "install_gem \"lacci\"\nrequire \"shoes\"\n\nshow_shoes do\n  para \"Hallo aus einer Shoes-App!\"\nend"
          },
          {
            "t": "h",
            "html": "<p>Das Kästchen oben ist eine laufende Shoes-App. <code>show_shoes</code> übernimmt hier die Rolle von <code>Shoes.app</code>.</p><p>Angeordnet wird mit zwei Behältern – mehr braucht Shoes nicht:</p><ul><li><code>stack</code> stapelt seinen Inhalt <strong>untereinander</strong>,</li><li><code>flow</code> reiht ihn <strong>nebeneinander</strong> auf.</li></ul><p>Alles andere sind <em>Drawables</em>: <code>title</code>, <code>para</code>, <code>button</code>, <code>edit_line</code> und so weiter.</p>"
          },
          {
            "t": "c",
            "code": "show_shoes do\n  stack do\n    title \"Chunkys Imbiss\"\n    para \"Speck, Ei und Kaffee.\"\n    flow do\n      button \"Speck\"\n      button \"Ei\"\n      button \"Kaffee\"\n    end\n  end\nend"
          },
          {
            "t": "h",
            "html": "<p>Die Knöpfe tun noch nichts. In Shoes hängst du einen <strong>Block</strong> an einen Knopf, und jedes Drawable, das du in einer Variablen festhältst, kannst du später ändern – <code>para</code> etwa mit <code>replace</code>:</p>"
          },
          {
            "t": "c",
            "code": "show_shoes do\n  stack do\n    @streifen = 0\n    @anzeige = para \"Noch kein Speck.\"\n\n    button \"Speck bestellen\" do\n      @streifen += 1\n      @anzeige.replace(\"#{@streifen} Streifen Speck! 🥓\")\n    end\n  end\nend"
          },
          {
            "t": "h",
            "html": "<p>Drück den Knopf – der Text darüber ändert sich. Und genau hier wird die Zweiteilung interessant: dein Block läuft in <em>Lacci</em>, das daraufhin nur meldet „diese Eigenschaft hat sich geändert“. Der Display-Service hört zu und fasst den passenden DOM-Knoten an. Bei Scarpe auf dem Desktop hört stattdessen Webview oder libui zu – derselbe Code, anderes Fenster.</p><p>Eingaben laufen genauso, nur rückwärts: <code>edit_line</code> meldet jede Änderung an Lacci weiter.</p>"
          },
          {
            "t": "c",
            "code": "show_shoes do\n  stack do\n    @gruss = para \"Wie heisst du?\"\n    edit_line \"\" do |text|\n      @gruss.replace(text.empty? ? \"Wie heisst du?\" : \"Hallo, #{text}!\")\n    end\n  end\nend"
          },
          {
            "t": "h",
            "html": "<p>Auf deinem eigenen Rechner installierst du <code>scarpe</code> statt <code>lacci</code>, schreibst <code>Shoes.app do … end</code> in eine Datei und startest sie mit <code>scarpe meine_app.rb</code> – dann geht ein echtes Fenster auf. Die App selbst bleibt Zeile für Zeile dieselbe.</p><p>Der Display-Service, der hier zeichnet, ist übrigens kein Spezialfall der Seite, sondern ein ganz normaler: rund 250 Zeilen Ruby in <code>shoes_dom.rb</code>. Nach demselben Muster ist auch <a href='https://github.com/Largo/hacketyhack' target='_blank'>Clogs</a> gebaut, ein Shoes auf libui.</p><div class='task'><strong>Aufgabe:</strong> Bau eine Gruss-App. Sie braucht einen <code>title</code>, ein <code>edit_line</code>, einen <code>button</code> und einen weiteren <code>para</code>, der beim Klick den Namen aus dem Eingabefeld begrüsst. Halte das Eingabefeld dafür in einer Variablen fest – <code>@feld.text</code> gibt dir, was drinsteht.</div>"
          },
          {
            "t": "x",
            "code": "show_shoes do\n  stack do\n    # title \"...\"\n    # @feld = edit_line \"\"\n    # @gruss = para \"...\"\n    # button \"Gruess mich\" do\n    #   ...\n    # end\n  end\nend\n",
            "check": "apps >= 1 && shoes_types.include?(\"EditLine\") && shoes_types.include?(\"Button\") && shoes_types.count { |t| t == \"Para\" } >= 2",
            "hint": "Etwa so: <code>@feld = edit_line \"\"</code>, dann <code>@gruss = para \"...\"</code>, und im Knopf-Block <code>@gruss.replace(\"Hallo, #{@feld.text}!\")</code>. <code>title</code> zählt übrigens auch als <code>para</code> – zwei Textzeilen brauchst du trotzdem."
          }
        ]
      },
      "en": {
        "title": "29. Shoes apps with Scarpe",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Shoes: small windows, little code</h2><p><strong>Shoes</strong> is why the lucky stiff's GUI toolkit – the same pen that gave us “Chunky Bacon”. The idea: a window with some text and a button should cost a few lines, not a few hundred.</p><p><a href='https://github.com/scarpe-team/scarpe' target='_blank'><strong>Scarpe</strong></a> is today's revival, and it is cut in two:</p><ul><li><strong>Lacci</strong> (the <code>lacci</code> gem) knows only the language: <code>stack</code>, <code>para</code>, <code>button</code>. It knows nothing about pixels.</li><li>A <strong>display service</strong> then actually paints that tree – with Webview, with libui, or with something else entirely.</li></ul><p>That is exactly why Shoes runs here: this page brings its own display service, which draws the tree into the page's HTML. The gem underneath is the real one, unchanged.</p>"
          },
          {
            "t": "c",
            "code": "install_gem \"lacci\"\nrequire \"shoes\"\n\nshow_shoes do\n  para \"Hello from a Shoes app!\"\nend"
          },
          {
            "t": "h",
            "html": "<p>The box above is a running Shoes app. Here <code>show_shoes</code> plays the part of <code>Shoes.app</code>.</p><p>Layout uses two containers – Shoes needs no more than that:</p><ul><li><code>stack</code> piles its contents <strong>on top of each other</strong>,</li><li><code>flow</code> lines them up <strong>side by side</strong>.</li></ul><p>Everything else is a <em>drawable</em>: <code>title</code>, <code>para</code>, <code>button</code>, <code>edit_line</code> and so on.</p>"
          },
          {
            "t": "c",
            "code": "show_shoes do\n  stack do\n    title \"Chunky's Diner\"\n    para \"Bacon, egg and coffee.\"\n    flow do\n      button \"Bacon\"\n      button \"Egg\"\n      button \"Coffee\"\n    end\n  end\nend"
          },
          {
            "t": "h",
            "html": "<p>Those buttons do nothing yet. In Shoes you hang a <strong>block</strong> on a button, and any drawable you keep in a variable can be changed later – a <code>para</code> with <code>replace</code>, for instance:</p>"
          },
          {
            "t": "c",
            "code": "show_shoes do\n  stack do\n    @strips = 0\n    @display = para \"No bacon yet.\"\n\n    button \"Order bacon\" do\n      @strips += 1\n      @display.replace(\"#{@strips} strips of bacon! 🥓\")\n    end\n  end\nend"
          },
          {
            "t": "h",
            "html": "<p>Press the button – the text above it changes. And this is where the split gets interesting: your block runs in <em>Lacci</em>, which only announces “this property changed”. The display service listens and touches the matching DOM node. In Scarpe on the desktop, Webview or libui listens instead – same code, different window.</p><p>Input works the same way, just backwards: <code>edit_line</code> reports every change back to Lacci.</p>"
          },
          {
            "t": "c",
            "code": "show_shoes do\n  stack do\n    @greeting = para \"What's your name?\"\n    edit_line \"\" do |text|\n      @greeting.replace(text.empty? ? \"What's your name?\" : \"Hello, #{text}!\")\n    end\n  end\nend"
          },
          {
            "t": "h",
            "html": "<p>On your own machine you install <code>scarpe</code> instead of <code>lacci</code>, write <code>Shoes.app do … end</code> in a file and start it with <code>scarpe my_app.rb</code> – and a real window opens. The app itself stays the same, line for line.</p><p>The display service drawing here is not a special case of this site either, but an ordinary one: about 250 lines of Ruby in <code>shoes_dom.rb</code>. <a href='https://github.com/Largo/hacketyhack' target='_blank'>Clogs</a>, a Shoes on libui, is built to the same pattern.</p><div class='task'><strong>Task:</strong> Build a greeting app. It needs a <code>title</code>, an <code>edit_line</code>, a <code>button</code> and one more <code>para</code> that greets the name from the field when clicked. Keep the field in a variable – <code>@field.text</code> gives you what is in it.</div>"
          },
          {
            "t": "x",
            "code": "show_shoes do\n  stack do\n    # title \"...\"\n    # @field = edit_line \"\"\n    # @greeting = para \"...\"\n    # button \"Greet me\" do\n    #   ...\n    # end\n  end\nend\n",
            "check": "apps >= 1 && shoes_types.include?(\"EditLine\") && shoes_types.include?(\"Button\") && shoes_types.count { |t| t == \"Para\" } >= 2",
            "hint": "Something like: <code>@field = edit_line \"\"</code>, then <code>@greeting = para \"...\"</code>, and inside the button block <code>@greeting.replace(\"Hello, #{@field.text}!\")</code>. Note that <code>title</code> counts as a <code>para</code> too – you still need two lines of text."
          }
        ]
      },
      "ja": {
        "title": "29. ScarpeでShoesアプリ",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Shoes：小さなウィンドウを、少ないコードで</h2><p><strong>Shoes</strong>は、why the lucky stiffが作ったGUIツールキットです。「Chunky Bacon」と同じ人の手から生まれました。その考え方はシンプルで、テキストとボタンがいくつかあるだけのウィンドウなら、数百行ではなく数行で書けるべきだ、というものです。</p><p><a href='https://github.com/scarpe-team/scarpe' target='_blank'><strong>Scarpe</strong></a>は、そのShoesを現代によみがえらせたもので、2つの部分に分かれています：</p><ul><li><strong>Lacci</strong>（<code>lacci</code> gem）が知っているのは、<code>stack</code>、<code>para</code>、<code>button</code>といった言語の部分だけです。ピクセルのことは何も知りません。</li><li>こうして組み立てられたツリーを実際に描くのは、<strong>ディスプレイサービス</strong>です。Webviewで描いても、libuiで描いても、まったく別のもので描いてもかまいません。</li></ul><p>だからこそ、Shoesはこのページでも動きます。このページは独自のディスプレイサービスを持っていて、ツリーをページのHTMLとして描き出します。その下で動いているgemは、手を加えていない本物です。</p>"
          },
          {
            "t": "c",
            "code": "install_gem \"lacci\"\nrequire \"shoes\"\n\nshow_shoes do\n  para \"Hello from a Shoes app!\"\nend"
          },
          {
            "t": "h",
            "html": "<p>上の枠は、実際に動いているShoesアプリです。ここでは<code>show_shoes</code>が<code>Shoes.app</code>の役目を果たしています。</p><p>レイアウトには2種類のコンテナを使います。Shoesにはそれだけで十分です：</p><ul><li><code>stack</code>は中身を<strong>縦に積み重ね</strong>、</li><li><code>flow</code>は中身を<strong>横に並べます</strong>。</li></ul><p>それ以外の<code>title</code>、<code>para</code>、<code>button</code>、<code>edit_line</code>などは、すべて<em>drawable</em>（描画される部品）です。</p>"
          },
          {
            "t": "c",
            "code": "show_shoes do\n  stack do\n    title \"Chunky's Diner\"\n    para \"Bacon, egg and coffee.\"\n    flow do\n      button \"Bacon\"\n      button \"Egg\"\n      button \"Coffee\"\n    end\n  end\nend"
          },
          {
            "t": "h",
            "html": "<p>このボタンは、まだ何もしません。Shoesでは、ボタンに<strong>ブロック</strong>を渡します。また、変数に入れておいたdrawableは、あとから変更できます。たとえば<code>para</code>なら<code>replace</code>で書き換えられます：</p>"
          },
          {
            "t": "c",
            "code": "show_shoes do\n  stack do\n    @strips = 0\n    @display = para \"No bacon yet.\"\n\n    button \"Order bacon\" do\n      @strips += 1\n      @display.replace(\"#{@strips} strips of bacon! 🥓\")\n    end\n  end\nend"
          },
          {
            "t": "h",
            "html": "<p>ボタンを押してみてください。その上のテキストが変わります。ここで、2つに分かれた設計がおもしろくなってきます。ブロックは<em>Lacci</em>の中で実行され、Lacciは「このプロパティが変わった」と知らせるだけです。ディスプレイサービスがその知らせを受け取って、対応するDOMノードを書き換えます。デスクトップのScarpeでは、代わりにWebviewやlibuiが知らせを受け取ります。コードは同じで、ウィンドウだけが違うわけです。</p><p>入力も同じしくみで、向きが逆になるだけです。<code>edit_line</code>は、内容が変わるたびにLacciへ知らせます。</p>"
          },
          {
            "t": "c",
            "code": "show_shoes do\n  stack do\n    @greeting = para \"What's your name?\"\n    edit_line \"\" do |text|\n      @greeting.replace(text.empty? ? \"What's your name?\" : \"Hello, #{text}!\")\n    end\n  end\nend"
          },
          {
            "t": "h",
            "html": "<p>自分のコンピューターでは、<code>lacci</code>の代わりに<code>scarpe</code>をインストールし、ファイルに<code>Shoes.app do … end</code>と書いて、<code>scarpe my_app.rb</code>で起動します。すると本物のウィンドウが開きます。アプリのコードは1行も変わりません。</p><p>ちなみに、ここで描画しているディスプレイサービスも、このサイトだけの特別なしかけではなく、ごく普通のものです。<code>shoes_dom.rb</code>に書かれた、250行ほどのRubyにすぎません。libuiの上で動くShoesである<a href='https://github.com/Largo/hacketyhack' target='_blank'>Clogs</a>も、同じパターンで作られています。</p><div class='task'><strong>課題：</strong>あいさつアプリを作りましょう。<code>title</code>、<code>edit_line</code>、<code>button</code>に加えて、ボタンがクリックされたら入力欄の名前にあいさつする<code>para</code>をもう1つ用意してください。入力欄は変数に入れておきましょう。<code>@field.text</code>で中身を取り出せます。</div>"
          },
          {
            "t": "x",
            "code": "show_shoes do\n  stack do\n    # title \"...\"\n    # @field = edit_line \"\"\n    # @greeting = para \"...\"\n    # button \"Greet me\" do\n    #   ...\n    # end\n  end\nend\n",
            "check": "apps >= 1 && shoes_types.include?(\"EditLine\") && shoes_types.include?(\"Button\") && shoes_types.count { |t| t == \"Para\" } >= 2",
            "hint": "たとえばこんな感じ：<code>@field = edit_line \"\"</code>、次に<code>@greeting = para \"...\"</code>、そしてボタンのブロックの中で<code>@greeting.replace(\"Hello, #{@field.text}!\")</code>。ちなみに<code>title</code>も<code>para</code>として数えられるけど、テキストの行が2つ必要なことに変わりはないよ。"
          }
        ]
      }
    },
    {
      "id": "tty",
      "de": {
        "title": "30. TTY: schöne Ausgaben im Terminal",
        "cells": [
          {
            "t": "h",
            "html": "<h2>TTY – Tabellen, Rahmen und Farben aus Zeichen</h2><p>Die Ausgabe unter einer Zelle ist wie ein Terminal: Text, Zeile für Zeile, in einer Schrift, in der jedes Zeichen gleich breit ist. Programme für die Kommandozeile zeichnen genau damit – Tabellen, Rahmen und Bäume aus Strichen, dazu Farben. Das <a href='https://ttytoolkit.org' target='_blank'>TTY-Toolkit</a> von Piotr Murach ist eine Familie aus rund zwanzig kleinen Gems, jedes für eine Aufgabe: <code>tty-table</code>, <code>tty-box</code>, <code>tty-prompt</code> … und <code>pastel</code> für die Farben. Alles reines Ruby. Fangen wir mit Farbe an:</p>"
          },
          {
            "t": "c",
            "code": "install_gem \"pastel\"\nrequire \"pastel\"\n\npastel = Pastel.new(enabled: true)   # hier ist kein Terminal: Farben an\nputs pastel.green(\"12 Tests, 0 Fehler\")\nputs pastel.red.bold(\"2 Fehler!\")\nputs pastel.black.on_yellow(\" Chunky \") + \" \" + pastel.white.on_blue(\" Speck \")\npastel.red(\"Speck\")"
          },
          {
            "t": "h",
            "html": "<p>Die Farben stehen nicht im Text, es sind <strong>Befehle an das Terminal</strong>. Die Zeile mit <code>=&gt;</code> zeigt, was <code>pastel.red(\"Speck\")</code> wirklich liefert: <code>\"\\e[31mSpeck\\e[0m\"</code>. <code>\\e</code> ist das Escape-Zeichen, <code>[31m</code> heisst „ab hier rot“, <code>[0m</code> „wieder normal“. Diese <em>ANSI-Escape-Codes</em> stammen aus den 1970ern, und jedes Terminal versteht sie – diese Seite übrigens auch.</p><p>Die Methoden lassen sich verketten: <code>red.bold</code> ist rot und fett, <code>on_yellow</code> färbt den Hintergrund. Und <code>enabled: true</code>? pastel schaut normalerweise, ob seine Ausgabe in ein Terminal geht. Leitest du sie in eine Datei um (<code>ruby speck.rb &gt; log.txt</code>), wären die Codes nur Zeichensalat, also lässt pastel sie weg. Die Ausgabe einer Zelle ist kein echtes Terminal, darum schalten wir die Farben selbst ein.</p><p>Als Nächstes eine Tabelle:</p>"
          },
          {
            "t": "c",
            "code": "install_gem \"tty-table\"\nrequire \"tty-table\"\n\ntabelle = TTY::Table.new(\n  header: [\"Snack\", \"Preis\", \"Vorrat\"],\n  rows: [[\"Speck\", 4.5, 12], [\"Brezel\", 2.0, 30], [\"Käse\", 6.25, 5]]\n)\n# Linien aus Unicode-Rahmenzeichen, Spalten links- oder rechtsbündig\nputs tabelle.render(:unicode, alignments: [:left, :right, :right], padding: [0, 1])\nputs tabelle.render(:ascii)"
          },
          {
            "t": "h",
            "html": "<p><code>TTY::Table.new</code> bekommt die Kopfzeile und die Zeilen als Arrays. <code>render</code> zeichnet sie, mit einem von drei Stilen: <code>:basic</code> (ohne Linien), <code>:ascii</code> (aus <code>+</code>, <code>-</code> und <code>|</code> – das kann jedes noch so alte Terminal) und <code>:unicode</code> (mit den Rahmenzeichen <code>┌─┐</code>). <code>alignments</code> richtet jede Spalte aus – Zahlen rechtsbündig, damit die Stellen untereinander stehen –, <code>padding: [0, 1]</code> lässt oben und unten keinen, links und rechts ein Zeichen Platz.</p><p>Die Breite jeder Spalte misst tty-table selbst, am längsten Wert. Das ist schwieriger, als es klingt: <code>ä</code> kann ein Zeichen oder zwei sein (a plus Pünktchen), und <code>日本</code> braucht im Terminal doppelt so viel Platz wie <code>ab</code>. Dafür zählt das Gem <code>unicode-display_width</code>, auf dem tty-table aufbaut.</p><p>Rahmen um einen Text zeichnet tty-box:</p>"
          },
          {
            "t": "c",
            "code": "install_gem \"tty-box\"\nrequire \"tty-box\"\n\nputs TTY::Box.frame(\"Bestellung erhalten!\", \"3 Streifen Speck\",\n                    title: { top_left: \" Kiosk \" }, padding: [0, 2], align: :center)\nputs TTY::Box.frame(\"Ausverkauft\", border: :thick, padding: [0, 1])"
          },
          {
            "t": "h",
            "html": "<p><code>frame</code> nimmt eine oder mehrere Zeilen, <code>title</code> setzt eine Überschrift in den Rahmen (auch <code>top_right</code>, <code>bottom_left</code> …), <code>border:</code> wählt die Linie – <code>:light</code>, <code>:thick</code> oder <code>:ascii</code>. Ganze Ordnerbäume zeichnet tty-tree, wie der Befehl <code>tree</code> – hier der Aufbau deines Projekts ab Lektion 32:</p>"
          },
          {
            "t": "c",
            "code": "install_gem \"tty-tree\"\nrequire \"tty-tree\"\n\n# ein Ordner ist ein Hash, eine Datei ein String\nbaum = TTY::Tree.new(\"timelog\" => [\n  \"Gemfile\",\n  { \"lib\" => [\"entry.rb\", \"timesheet.rb\"] },\n  { \"test\" => [\"entry_test.rb\"] }\n])\nputs baum.render"
          },
          {
            "t": "h",
            "html": "<p>Und für einen grossen Auftritt, etwa den Start deines Programms, schreibt tty-font Buchstaben aus Buchstaben (FIGlet-Schriften: <code>:doom</code>, <code>:standard</code>, <code>:block</code>, <code>:straight</code> …):</p>"
          },
          {
            "t": "c",
            "code": "install_gem \"tty-font\"\nrequire \"tty-font\"\n\nputs TTY::Font.new(:doom).write(\"Speck\")"
          },
          {
            "t": "h",
            "html": "<div class='offweb' data-title='Auf deinem Computer'><p>Einige TTY-Gems brauchen ein <strong>echtes</strong> Terminal mit Tastatur und einem Cursor, der zurückspringen kann – darum laufen sie hier nicht. <code>tty-prompt</code> stellt Fragen, auch als Menü, in dem du mit den Pfeiltasten wählst:</p><pre>require \"tty-prompt\"\n\nprompt = TTY::Prompt.new\nname  = prompt.ask(\"Wie heisst du?\")\nsnack = prompt.select(\"Was darf es sein?\", %w[Speck Brezel Käse])\nmehr  = prompt.yes?(\"Noch etwas?\")</pre><p><code>tty-spinner</code> dreht ein Rädchen, solange etwas dauert, <code>tty-progressbar</code> zeigt einen Fortschrittsbalken, und <code>tty-screen</code> verrät, wie breit das Terminal ist. Mit <code>gem install tty</code> bekommst du alle auf einmal. Für Tests gibt es <code>TTY::Prompt::Test</code>, das die Eingaben aus einem String liest.</p></div><div class='task'><strong>Aufgabe:</strong> Chunky schreibt einen Einkaufszettel. Gib ihn als Tabelle mit Unicode-Linien aus: Kopfzeile <code>Artikel</code> und <code>Menge</code>, darunter <code>Speck</code> mit <code>3</code> und <code>Brezel</code> mit <code>2</code>.</div>"
          },
          {
            "t": "x",
            "code": "# Einkaufszettel: Artikel | Menge, Speck 3, Brezel 2 – mit Unicode-Linien\n",
            "check": "[output, result.to_s].join.then { |t| t.include?(\"┌\") && t.match?(/Artikel\\s*│\\s*Menge/) && t.match?(/Speck\\s*│\\s*3/) && t.match?(/Brezel\\s*│\\s*2/) }",
            "hint": "<code>TTY::Table.new(header: [\"Artikel\", \"Menge\"], rows: [[\"Speck\", 3], [\"Brezel\", 2]])</code> – und dann <code>puts</code> mit <code>.render(:unicode)</code>."
          }
        ]
      },
      "en": {
        "title": "30. TTY: good-looking terminal output",
        "cells": [
          {
            "t": "h",
            "html": "<h2>TTY – tables, frames and colours made of characters</h2><p>The output below a cell is like a terminal: text, line by line, in a font where every character is equally wide. Command-line programs draw with exactly that – tables, frames and trees made of lines, plus colours. Piotr Murach's <a href='https://ttytoolkit.org' target='_blank'>TTY toolkit</a> is a family of about twenty small gems, each doing one job: <code>tty-table</code>, <code>tty-box</code>, <code>tty-prompt</code> … and <code>pastel</code> for colours. All pure Ruby. Let's start with colour:</p>"
          },
          {
            "t": "c",
            "code": "install_gem \"pastel\"\nrequire \"pastel\"\n\npastel = Pastel.new(enabled: true)   # this is no terminal: colours on\nputs pastel.green(\"12 tests, 0 failures\")\nputs pastel.red.bold(\"2 failures!\")\nputs pastel.black.on_yellow(\" Chunky \") + \" \" + pastel.white.on_blue(\" Bacon \")\npastel.red(\"bacon\")"
          },
          {
            "t": "h",
            "html": "<p>The colours are not in the text, they are <strong>commands to the terminal</strong>. The <code>=&gt;</code> line shows what <code>pastel.red(\"bacon\")</code> really returns: <code>\"\\e[31mbacon\\e[0m\"</code>. <code>\\e</code> is the escape character, <code>[31m</code> means “red from here on”, <code>[0m</code> “back to normal”. These <em>ANSI escape codes</em> date from the 1970s, and every terminal understands them – so does this page.</p><p>The methods chain: <code>red.bold</code> is red and bold, <code>on_yellow</code> colours the background. And <code>enabled: true</code>? Normally pastel checks whether its output goes to a terminal. Redirect it into a file (<code>ruby bacon.rb &gt; log.txt</code>) and the codes would only be gibberish, so pastel leaves them out. A cell's output is no real terminal, so we switch the colours on ourselves.</p><p>Next, a table:</p>"
          },
          {
            "t": "c",
            "code": "install_gem \"tty-table\"\nrequire \"tty-table\"\n\ntable = TTY::Table.new(\n  header: [\"Snack\", \"Price\", \"Stock\"],\n  rows: [[\"Bacon\", 4.5, 12], [\"Pretzel\", 2.0, 30], [\"Cheese\", 6.25, 5]]\n)\n# lines from Unicode box drawing, columns aligned left or right\nputs table.render(:unicode, alignments: [:left, :right, :right], padding: [0, 1])\nputs table.render(:ascii)"
          },
          {
            "t": "h",
            "html": "<p><code>TTY::Table.new</code> gets the header and the rows as arrays. <code>render</code> draws them in one of three styles: <code>:basic</code> (no lines), <code>:ascii</code> (from <code>+</code>, <code>-</code> and <code>|</code> – any terminal, however old, can do that) and <code>:unicode</code> (with the box-drawing characters <code>┌─┐</code>). <code>alignments</code> aligns each column – numbers to the right, so the digits line up –, <code>padding: [0, 1]</code> leaves no room above and below and one character left and right.</p><p>tty-table measures the width of each column itself, by its longest value. That is harder than it sounds: <code>ä</code> can be one character or two (a plus the dots), and <code>日本</code> takes twice as much room in a terminal as <code>ab</code>. The <code>unicode-display_width</code> gem, which tty-table builds on, counts that.</p><p>Frames around a text come from tty-box:</p>"
          },
          {
            "t": "c",
            "code": "install_gem \"tty-box\"\nrequire \"tty-box\"\n\nputs TTY::Box.frame(\"Order received!\", \"3 strips of bacon\",\n                    title: { top_left: \" Kiosk \" }, padding: [0, 2], align: :center)\nputs TTY::Box.frame(\"Sold out\", border: :thick, padding: [0, 1])"
          },
          {
            "t": "h",
            "html": "<p><code>frame</code> takes one or more lines, <code>title</code> puts a heading into the frame (also <code>top_right</code>, <code>bottom_left</code> …), <code>border:</code> picks the line – <code>:light</code>, <code>:thick</code> or <code>:ascii</code>. Whole folder trees come from tty-tree, like the <code>tree</code> command – here the layout of your project from lesson 32 on:</p>"
          },
          {
            "t": "c",
            "code": "install_gem \"tty-tree\"\nrequire \"tty-tree\"\n\n# a folder is a hash, a file a string\ntree = TTY::Tree.new(\"timelog\" => [\n  \"Gemfile\",\n  { \"lib\" => [\"entry.rb\", \"timesheet.rb\"] },\n  { \"test\" => [\"entry_test.rb\"] }\n])\nputs tree.render"
          },
          {
            "t": "h",
            "html": "<p>And for a grand entrance, say when your program starts, tty-font writes letters made of letters (FIGlet fonts: <code>:doom</code>, <code>:standard</code>, <code>:block</code>, <code>:straight</code> …):</p>"
          },
          {
            "t": "c",
            "code": "install_gem \"tty-font\"\nrequire \"tty-font\"\n\nputs TTY::Font.new(:doom).write(\"Bacon\")"
          },
          {
            "t": "h",
            "html": "<div class='offweb' data-title='On your machine'><p>Some TTY gems need a <strong>real</strong> terminal, with a keyboard and a cursor that can jump back – which is why they do not run here. <code>tty-prompt</code> asks questions, also as a menu you choose from with the arrow keys:</p><pre>require \"tty-prompt\"\n\nprompt = TTY::Prompt.new\nname  = prompt.ask(\"What's your name?\")\nsnack = prompt.select(\"What would you like?\", %w[Bacon Pretzel Cheese])\nmore  = prompt.yes?(\"Anything else?\")</pre><p><code>tty-spinner</code> spins a little wheel while something takes time, <code>tty-progressbar</code> shows a progress bar, and <code>tty-screen</code> tells you how wide the terminal is. <code>gem install tty</code> gets you all of them at once. For tests there is <code>TTY::Prompt::Test</code>, which reads the answers from a string.</p></div><div class='task'><strong>Task:</strong> Chunky is writing a shopping list. Print it as a table with Unicode lines: header <code>Item</code> and <code>Qty</code>, below it <code>Bacon</code> with <code>3</code> and <code>Pretzel</code> with <code>2</code>.</div>"
          },
          {
            "t": "x",
            "code": "# shopping list: Item | Qty, Bacon 3, Pretzel 2 – with Unicode lines\n",
            "check": "[output, result.to_s].join.then { |t| t.include?(\"┌\") && t.match?(/Item\\s*│\\s*Qty/) && t.match?(/Bacon\\s*│\\s*3/) && t.match?(/Pretzel\\s*│\\s*2/) }",
            "hint": "<code>TTY::Table.new(header: [\"Item\", \"Qty\"], rows: [[\"Bacon\", 3], [\"Pretzel\", 2]])</code> – then <code>puts</code> it with <code>.render(:unicode)</code>."
          }
        ]
      },
      "ja": {
        "title": "30. TTY：ターミナルをきれいに",
        "cells": [
          {
            "t": "h",
            "html": "<h2>TTY ― 文字でつくる表・枠・色</h2><p>セルの下の出力はターミナルのようなものです。テキストが一行ずつ、どの文字も同じ幅のフォントで並びます。コマンドラインのプログラムは、まさにそれで絵を描きます。線でできた表や枠や木、そして色。Piotr Murachさんの<a href='https://ttytoolkit.org' target='_blank'>TTYツールキット</a>は、20ほどの小さなgemの集まりで、それぞれがひとつの仕事をします：<code>tty-table</code>、<code>tty-box</code>、<code>tty-prompt</code>……そして色のための<code>pastel</code>。すべて純粋なRubyです。まずは色から：</p>"
          },
          {
            "t": "c",
            "code": "install_gem \"pastel\"\nrequire \"pastel\"\n\npastel = Pastel.new(enabled: true)   # ここはターミナルではないので、色をオンに\nputs pastel.green(\"12 tests, 0 failures\")\nputs pastel.red.bold(\"2 failures!\")\nputs pastel.black.on_yellow(\" Chunky \") + \" \" + pastel.white.on_blue(\" Bacon \")\npastel.red(\"bacon\")"
          },
          {
            "t": "h",
            "html": "<p>色はテキストの中にあるのではなく、<strong>ターミナルへの命令</strong>です。<code>=&gt;</code>の行を見ると、<code>pastel.red(\"bacon\")</code>が本当に返すものがわかります：<code>\"\\e[31mbacon\\e[0m\"</code>。<code>\\e</code>はエスケープ文字、<code>[31m</code>は「ここから赤」、<code>[0m</code>は「元に戻す」という意味です。この<em>ANSIエスケープコード</em>は1970年代からあり、どのターミナルも理解します。このページもです。</p><p>メソッドはつなげられます：<code>red.bold</code>は赤くて太字、<code>on_yellow</code>は背景の色です。では<code>enabled: true</code>は？　pastelはふつう、出力がターミナルに行くかどうかを確かめます。ファイルにリダイレクトする（<code>ruby bacon.rb &gt; log.txt</code>）と、コードはただの文字化けになるので、pastelはそれを省きます。セルの出力は本物のターミナルではないので、ここでは自分で色をオンにしています。</p><p>次は表です：</p>"
          },
          {
            "t": "c",
            "code": "install_gem \"tty-table\"\nrequire \"tty-table\"\n\ntable = TTY::Table.new(\n  header: [\"Snack\", \"Price\", \"Stock\"],\n  rows: [[\"Bacon\", 4.5, 12], [\"Pretzel\", 2.0, 30], [\"Cheese\", 6.25, 5]]\n)\n# 線はUnicodeの罫線、列ごとに左寄せ・右寄せ\nputs table.render(:unicode, alignments: [:left, :right, :right], padding: [0, 1])\nputs table.render(:ascii)"
          },
          {
            "t": "h",
            "html": "<p><code>TTY::Table.new</code>には、見出しと行を配列で渡します。<code>render</code>は3つのスタイルのどれかで描きます：<code>:basic</code>（線なし）、<code>:ascii</code>（<code>+</code>、<code>-</code>、<code>|</code>で。どんなに古いターミナルでも大丈夫）、そして<code>:unicode</code>（罫線文字<code>┌─┐</code>で）。<code>alignments</code>は列ごとの寄せ方です。数字は右寄せにすると桁がそろいます。<code>padding: [0, 1]</code>は上下に余白なし、左右に1文字ぶんの余白です。</p><p>列の幅は、tty-tableがいちばん長い値から自分で測ります。これは思ったより難しいことです。<code>ä</code>は1文字のことも2文字（aと点々）のこともありますし、<code>日本</code>はターミナルで<code>ab</code>の2倍の幅を取ります。それを数えるのが、tty-tableの土台になっている<code>unicode-display_width</code>というgemです。</p><p>テキストを囲む枠はtty-boxで：</p>"
          },
          {
            "t": "c",
            "code": "install_gem \"tty-box\"\nrequire \"tty-box\"\n\nputs TTY::Box.frame(\"Order received!\", \"3 strips of bacon\",\n                    title: { top_left: \" Kiosk \" }, padding: [0, 2], align: :center)\nputs TTY::Box.frame(\"Sold out\", border: :thick, padding: [0, 1])"
          },
          {
            "t": "h",
            "html": "<p><code>frame</code>は1行でも複数行でも受け取ります。<code>title</code>は枠に見出しを入れ（<code>top_right</code>、<code>bottom_left</code>なども）、<code>border:</code>で線を選びます：<code>:light</code>、<code>:thick</code>、<code>:ascii</code>。フォルダの木は、<code>tree</code>コマンドのようにtty-treeで描けます。これはレッスン32からつくるプロジェクトの構成です：</p>"
          },
          {
            "t": "c",
            "code": "install_gem \"tty-tree\"\nrequire \"tty-tree\"\n\n# フォルダはハッシュ、ファイルは文字列\ntree = TTY::Tree.new(\"timelog\" => [\n  \"Gemfile\",\n  { \"lib\" => [\"entry.rb\", \"timesheet.rb\"] },\n  { \"test\" => [\"entry_test.rb\"] }\n])\nputs tree.render"
          },
          {
            "t": "h",
            "html": "<p>そして、たとえばプログラムの起動時に派手に登場したいなら、tty-fontが文字でできた文字を書いてくれます（FIGletフォント：<code>:doom</code>、<code>:standard</code>、<code>:block</code>、<code>:straight</code>など）：</p>"
          },
          {
            "t": "c",
            "code": "install_gem \"tty-font\"\nrequire \"tty-font\"\n\nputs TTY::Font.new(:doom).write(\"Bacon\")"
          },
          {
            "t": "h",
            "html": "<div class='offweb' data-title='自分のパソコンでは'><p>TTYのgemのいくつかは、キーボードと、前に戻れるカーソルのある<strong>本物の</strong>ターミナルが必要です。だからここでは動きません。<code>tty-prompt</code>は質問をします。矢印キーで選ぶメニューにもなります：</p><pre>require \"tty-prompt\"\n\nprompt = TTY::Prompt.new\nname  = prompt.ask(\"What's your name?\")\nsnack = prompt.select(\"What would you like?\", %w[Bacon Pretzel Cheese])\nmore  = prompt.yes?(\"Anything else?\")</pre><p><code>tty-spinner</code>は時間がかかる間くるくる回り、<code>tty-progressbar</code>は進み具合をバーで見せ、<code>tty-screen</code>はターミナルの幅を教えてくれます。<code>gem install tty</code>で全部まとめて入ります。テスト用には、答えを文字列から読む<code>TTY::Prompt::Test</code>があります。</p></div><div class='task'><strong>課題：</strong>Chunkyが買い物メモを書いています。Unicodeの線の表として出力してください：見出しは<code>Item</code>と<code>Qty</code>、その下に<code>Bacon</code>と<code>3</code>、<code>Pretzel</code>と<code>2</code>。</div>"
          },
          {
            "t": "x",
            "code": "# 買い物メモ：Item | Qty、Bacon 3、Pretzel 2 ― Unicodeの線で\n",
            "check": "[output, result.to_s].join.then { |t| t.include?(\"┌\") && t.match?(/Item\\s*│\\s*Qty/) && t.match?(/Bacon\\s*│\\s*3/) && t.match?(/Pretzel\\s*│\\s*2/) }",
            "hint": "<code>TTY::Table.new(header: [\"Item\", \"Qty\"], rows: [[\"Bacon\", 3], [\"Pretzel\", 2]])</code>をつくって、<code>.render(:unicode)</code>を<code>puts</code>してね。"
          }
        ]
      }
    },
    {
      "id": "rubykaigi",
      "de": {
        "title": "31. RubyKaigi & seltsamer Code",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Ruby ist auch eine Gemeinschaft</h2><p>Hinter Ruby stehen Menschen – und die treffen sich. Die grösste Ruby-Konferenz ist die <a href='https://rubykaigi.org' target='_blank'>RubyKaigi</a> in Japan („Kaigi“ heisst Konferenz): seit 2006, inzwischen jedes Jahr in einer anderen Stadt, drei Tage Vorträge auf Japanisch und Englisch, und mittendrin Matz und die Leute, die Ruby selbst weiterentwickeln. Dazu kommen die RubyConf in den USA, die EuRuKo in Europa, Rails World und Meetups in vielen Städten.</p><p>Nicht dabei gewesen? <a href='https://www.rubyevents.org' target='_blank'>RubyEvents.org</a> sammelt die Videos von Tausenden Ruby-Vorträgen, kostenlos und durchsuchbar, und zeigt, welche Konferenzen und Meetups bald stattfinden. In dieser Lektion folgen wir einem Rubyisten durch drei Vorträge: <strong>Tomoya Ishida</strong> (<code>@tompng</code>). Er ist Ruby-Committer und pflegt IRB, das Werkzeug aus Lektion 12.</p>"
          },
          {
            "t": "h",
            "html": "<p>Auf der RubyKaigi 2024 in Okinawa hielt tompng die Keynote <a href='https://www.rubyevents.org/talks/keynote-writing-weird-code' target='_blank'>„Writing Weird Code“</a> – gesprochen auf Japanisch, die Folien auf Englisch. Seine These: Ruby kann wunderbar lesbaren Code – und herrlich seltsamen. Ein paar Ideen aus dem Vortrag, in eigenen Beispielen. Zuerst Schreibweisen, die du schon halb kennst:</p>"
          },
          {
            "t": "c",
            "code": "p %(Speck)              # wie \"Speck\"\np %w[Kaz Isi Chunky]    # ein Array aus Wörtern\np \"RubyKaigi %d\" % 2024 # String#% füllt %d aus\np ?a                    # ein einzelnes Zeichen\np %%%                   # %…% mit % als Klammer: leer\np %%%%%%%               # leer % leer"
          },
          {
            "t": "h",
            "html": "<p><code>%(…)</code> und <code>%w[…]</code> schreiben Strings und Wort-Arrays, <code>?a</code> ein einzelnes Zeichen, und <code>String#%</code> füllt Platzhalter aus. Die Klammer hinter <code>%</code> darf fast jedes Zeichen sein – sogar <code>%</code> selbst: <code>%%%</code> ist ein leerer String, und sieben Prozentzeichen sind „leer % leer“. tompng zeigte: Jede Reihe aus 4n + 3 Prozentzeichen ist gültiges Ruby. Auch Namen dürfen seltsam sein:</p>"
          },
          {
            "t": "c",
            "code": "🦊 = \"Chunky\"\n🥓 = \"Speck\"\nputs \"#{🦊} liebt #{🥓}\"\n\nbeide = <<~EINS + <<~ZWEI\n  Erste Zeile\nEINS\n  Zweite Zeile\nZWEI\nbeide"
          },
          {
            "t": "h",
            "html": "<p>Variablennamen dürfen Unicode sein, sogar Emoji (lesbarer wird es dadurch nicht unbedingt). Und zwei Heredocs in einer Zeile: Ruby liest erst die Zeile zu Ende und holt sich dann die Texte der Reihe nach. Genau solche Fälle brachten IRB früher beim Einrücken durcheinander; seit IRB 1.7.1 kommt es damit klar.</p><p>Reguläre Ausdrücke können mehr, als man denkt – dieser hier erkennt Primzahlen, ohne eine einzige Division im Code:</p>"
          },
          {
            "t": "c",
            "code": "def prim?(zahl)\n  zahl > 1 && (\"x\" * zahl) !~ /\\A(xx+)\\1+\\z/\nend\n\n(1..30).select { |zahl| prim?(zahl) }"
          },
          {
            "t": "h",
            "html": "<p>Aus 9 wird <code>\"xxxxxxxxx\"</code>. <code>(xx+)</code> fängt eine Gruppe aus mindestens zwei x, und <code>\\1+</code> verlangt, dass genau diese Gruppe sich bis zum Ende wiederholt. Das klappt nur, wenn die x sich in gleich grosse Gruppen teilen lassen – wenn die Zahl also zusammengesetzt ist. Die Regex-Maschine probiert dafür jede Gruppengrösse durch: langsam, aber schön. Ein alter Trick aus der Perl-Welt, den tompng im Vortrag zeigte. Und ein Rätsel zum Schluss: Was kommt hier heraus?</p>"
          },
          {
            "t": "c",
            "code": "FUCHS = \"Chunky\"\n\nmodule Wald\n  FUCHS += \" Bacon\"\nend\n\n[FUCHS, Wald::FUCHS]"
          },
          {
            "t": "h",
            "html": "<p><code>FUCHS += \" Bacon\"</code> heisst <code>FUCHS = FUCHS + \" Bacon\"</code>. Das Lesen findet das äussere <code>FUCHS</code>, das Zuweisen legt ein neues <code>Wald::FUCHS</code> an – zwei Konstanten. Solche Fälle muss ein Werkzeug kennen, das Ruby-Code versteht: Die Tests von tompngs Typ-Vervollständigung für IRB prüfen genau diesen.</p><p>Wozu das alles? Im Vortrag nennt tompng drei Gründe: Seltsamer Code ist ein Rätsel, das Spass macht. Wer es knackt, versteht Ruby tiefer. Und seltsamer Code findet Fehler – in IRB, im Parser –, die braven Programmen nie begegnen. Für ihn selbst war ein Wettbewerb für seltsamen Code der Anlass, an IRB und Reline mitzuarbeiten. Im zweiten Teil der Keynote zeigte er sechs Programme zum Thema Okinawa, etwa eine Datei, die zugleich ein Bild einer Osterlilie (BMP) und ein Ruby-Programm ist, und eines, das im Terminal endlos Muster der okinawanischen Minsa-Weberei webt – zu finden auf <a href='https://github.com/tompng/selftrick2024' target='_blank'>GitHub</a>.</p><p>Dieser Wettbewerb heisst <strong>TRICK</strong> (Transcendental Ruby Imbroglio Contest for rubyKaigi). Seit 2013 reichen Rubyistinnen und Rubyisten Programme ein, die die Jury überraschen, begeistern oder zum Lachen bringen sollen; in der Jury sitzt auch Matz. tompng gewann 2022 Gold. Bei <a href='https://www.rubyevents.org/talks/trick-2025-episode-i' target='_blank'>TRICK 2025</a> sass er selbst in der Jury – und belegte trotzdem die Plätze 3, 4 und 5, denn diesmal reichten auch die Juroren Programme ein. Alle Gewinner liegen mit Erklärungen <a href='https://github.com/tric/trick2025' target='_blank'>auf GitHub</a>, unter der MIT-Lizenz.</p>"
          },
          {
            "t": "h",
            "html": "<p>Ein Jahr später, auf der RubyKaigi 2025 in Matsuyama, erzählte tompng in <a href='https://www.rubyevents.org/talks/analyzing-ruby-code-in-irb' target='_blank'>„Analyzing Ruby Code in IRB“</a>, wie IRB deinen Code liest, während du tippst: um ihn einzufärben, um zu erkennen, ob deine Eingabe fertig ist oder noch ein <code>end</code> fehlt, um einzurücken und um zu vervollständigen. Dafür betrachtet IRB den Code auf zwei Arten – als Folge von <strong>Tokens</strong>, den „Wörtern“ des Codes, und als <strong>Syntaxbaum</strong> –, und seltsamer Code ist der Härtetest. Helfen soll <strong>Prism</strong>, der Parser, mit dem Ruby seit Version 3.4 selbst deinen Code liest. Probier ihn aus:</p>"
          },
          {
            "t": "c",
            "code": "require \"prism\"\n\nPrism.lex(\"puts 6 * 7\").value.map { |token, _zustand| token.type }"
          },
          {
            "t": "h",
            "html": "<p><code>Prism.lex</code> zerlegt den Code in Tokens: ein Name, eine Zahl, ein Stern, eine Zahl, das Ende. Daran sieht IRB zum Beispiel, was es wie einfärbt. <code>Prism.parse</code> baut den ganzen Syntaxbaum – und sagt mit <code>success?</code>, ob der Code vollständig und gültig ist:</p>"
          },
          {
            "t": "c",
            "code": "puts Prism.parse(\"def fuchs\").errors.last.message\n\n[\"def fuchs\", \"def fuchs\\nend\", \"[1, 2,\", \"\\\"Speck\"].map do |code|\n  [code, Prism.parse(code).success?]\nend"
          },
          {
            "t": "h",
            "html": "<p>Bei <code>def fuchs</code> fehlt das <code>end</code>, bei <code>[1, 2,</code> die Klammer, bei <code>\"Speck</code> das Anführungszeichen: Hier wartet IRB auf die nächste Zeile. Echtes IRB unterscheidet zusätzlich, ob Code nur <em>unfertig</em> ist oder schon <em>falsch</em> – auch darum ging es im Vortrag. Diese Seite nutzt dieselbe Idee: ⚡ Live startet deinen Code erst, wenn er sich parsen lässt.</p><div class='offweb' data-title='Mach mit'><p>Auf <a href='https://www.rubyevents.org' target='_blank'>RubyEvents.org</a> findest du Vorträge zu fast jedem Thema dieses Kurses – such einmal nach „IRB“, „Prism“ oder „TRICK“. Viele RubyKaigi-Vorträge sind auf Japanisch, ihre Folien aber meist auf Englisch; die Seite des Vortrags auf <a href='https://rubykaigi.org' target='_blank'>rubykaigi.org</a> verlinkt sie. RubyEvents zeigt auch, welche Konferenzen und Meetups bald stattfinden und welche gerade Vorträge suchen. Ruby-Konferenzen freuen sich über neue Gesichter – im Publikum und auf der Bühne.</p></div><div class='task'><strong>Aufgabe:</strong> Bau IRBs Zeilensammler: <code>eingaben(zeilen)</code> bekommt die Zeilen, die jemand nacheinander tippt, und gibt die fertigen Eingaben zurück, so wie IRB sie ausführen würde – die Zeilen einer Eingabe mit <code>\"\\n\"</code> verbunden. <code>eingaben([\"x = 1\", \"def doppelt(n)\", \"  n * 2\", \"end\"])</code> ergibt <code>[\"x = 1\", \"def doppelt(n)\\n  n * 2\\nend\"]</code>.</div>"
          },
          {
            "t": "x",
            "code": "require \"prism\"\n\ndef eingaben(zeilen)\n  # Zeilen sammeln, bis Prism.parse(code).success? ist\nend\n",
            "check": "eingaben([\"x = 1\", \"def doppelt(n)\", \"  n * 2\", \"end\", \"doppelt(x)\"]) == [\"x = 1\", \"def doppelt(n)\\n  n * 2\\nend\", \"doppelt(x)\"] && eingaben([\"[1,\", \"2]\", \"\\\"Speck\", \"\\\"\", \"puts 3\"]) == [\"[1,\\n2]\", \"\\\"Speck\\n\\\"\", \"puts 3\"]",
            "hint": "Ein Puffer für die Zeilen der aktuellen Eingabe: jede Zeile anhängen, <code>puffer.join(\"\\n\")</code> parsen – und wenn das klappt, den Code ins Ergebnis legen und den Puffer leeren."
          }
        ]
      },
      "en": {
        "title": "31. RubyKaigi & weird code",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Ruby is a community, too</h2><p>Behind Ruby there are people – and they meet. The biggest Ruby conference is <a href='https://rubykaigi.org' target='_blank'>RubyKaigi</a> in Japan (\"kaigi\" means conference): running since 2006, nowadays in a different city every year, three days of talks in Japanese and English, with Matz and the people who develop Ruby itself right in the middle. There is also RubyConf in the USA, EuRuKo in Europe, Rails World and meetups in many cities.</p><p>Weren't there? <a href='https://www.rubyevents.org' target='_blank'>RubyEvents.org</a> collects the videos of thousands of Ruby talks, free and searchable, and shows which conferences and meetups are coming up. In this lesson we follow one Rubyist through three talks: <strong>Tomoya Ishida</strong> (<code>@tompng</code>). He is a Ruby committer and maintains IRB, the tool from lesson 12.</p>"
          },
          {
            "t": "h",
            "html": "<p>At RubyKaigi 2024 in Okinawa, tompng gave the keynote <a href='https://www.rubyevents.org/talks/keynote-writing-weird-code' target='_blank'>\"Writing Weird Code\"</a> – spoken in Japanese, with English slides. His point: Ruby can be wonderfully readable – and gloriously weird. A few ideas from the talk, in our own examples. First, notations you half know already:</p>"
          },
          {
            "t": "c",
            "code": "p %(bacon)              # like \"bacon\"\np %w[Kaz Isi Chunky]    # an array of words\np \"RubyKaigi %d\" % 2024 # String#% fills in %d\np ?a                    # a single character\np %%%                   # %…% with % as the bracket: empty\np %%%%%%%               # empty % empty"
          },
          {
            "t": "h",
            "html": "<p><code>%(…)</code> and <code>%w[…]</code> write strings and arrays of words, <code>?a</code> a single character, and <code>String#%</code> fills in placeholders. The bracket after <code>%</code> can be almost any character – even <code>%</code> itself: <code>%%%</code> is an empty string, and seven percent signs are \"empty % empty\". tompng showed that every run of 4n + 3 percent signs is valid Ruby. Names can be weird, too:</p>"
          },
          {
            "t": "c",
            "code": "🦊 = \"Chunky\"\n🥓 = \"bacon\"\nputs \"#{🦊} loves #{🥓}\"\n\nboth = <<~ONE + <<~TWO\n  First line\nONE\n  Second line\nTWO\nboth"
          },
          {
            "t": "h",
            "html": "<p>Variable names may be Unicode, emoji included (which doesn't necessarily make them more readable). And two heredocs on one line: Ruby reads the line to its end first, then picks up the texts one after the other. Cases like this used to confuse IRB's indentation; since IRB 1.7.1 it gets them right.</p><p>Regular expressions can do more than you would think – this one spots prime numbers without a single division in the code:</p>"
          },
          {
            "t": "c",
            "code": "def prime?(number)\n  number > 1 && (\"x\" * number) !~ /\\A(xx+)\\1+\\z/\nend\n\n(1..30).select { |number| prime?(number) }"
          },
          {
            "t": "h",
            "html": "<p>9 becomes <code>\"xxxxxxxxx\"</code>. <code>(xx+)</code> captures a group of at least two x, and <code>\\1+</code> demands that exactly this group repeats to the end. That only works if the x split into groups of equal size – that is, if the number is composite. The regex engine tries every group size to find out: slow, but beautiful. An old trick from the Perl world that tompng showed in his talk. And a puzzle to finish: what comes out here?</p>"
          },
          {
            "t": "c",
            "code": "FOX = \"Chunky\"\n\nmodule Forest\n  FOX += \" Bacon\"\nend\n\n[FOX, Forest::FOX]"
          },
          {
            "t": "h",
            "html": "<p><code>FOX += \" Bacon\"</code> means <code>FOX = FOX + \" Bacon\"</code>. Reading finds the outer <code>FOX</code>, assigning creates a new <code>Forest::FOX</code> – two constants. A tool that understands Ruby code has to know such cases: the tests of tompng's type completion for IRB check exactly this one.</p><p>Why all this? In the talk, tompng gives three reasons: weird code is a puzzle that's fun. Cracking it, you understand Ruby more deeply. And weird code finds bugs – in IRB, in the parser – that well-behaved programs never run into. For him, a contest for weird code is what got him contributing to IRB and Reline. In the second part of the keynote he showed six programs on the theme of Okinawa, such as a file that is a picture of an Easter lily (a BMP) and a Ruby program at the same time, and one that endlessly weaves patterns of Okinawan Minsa weaving in the terminal – they are on <a href='https://github.com/tompng/selftrick2024' target='_blank'>GitHub</a>.</p><p>That contest is called <strong>TRICK</strong> (Transcendental Ruby Imbroglio Contest for rubyKaigi). Since 2013, Rubyists have been sending in programs meant to surprise, excite or amuse the judges, Matz among them. tompng won gold in 2022. At <a href='https://www.rubyevents.org/talks/trick-2025-episode-i' target='_blank'>TRICK 2025</a> he was a judge himself – and still took 3rd, 4th and 5th place, because this time the judges sent in programs too. All the winners are <a href='https://github.com/tric/trick2025' target='_blank'>on GitHub</a> with explanations, under the MIT licence.</p>"
          },
          {
            "t": "h",
            "html": "<p>A year later, at RubyKaigi 2025 in Matsuyama, tompng explained in <a href='https://www.rubyevents.org/talks/analyzing-ruby-code-in-irb' target='_blank'>\"Analyzing Ruby Code in IRB\"</a> how IRB reads your code while you type: to colour it, to tell whether your input is finished or still lacks an <code>end</code>, to indent and to complete. For that, IRB looks at code in two ways – as a sequence of <strong>tokens</strong>, the \"words\" of the code, and as a <strong>syntax tree</strong> – and weird code is the acid test. Helping it is <strong>Prism</strong>, the parser that Ruby itself has used to read your code since version 3.4. Try it:</p>"
          },
          {
            "t": "c",
            "code": "require \"prism\"\n\nPrism.lex(\"puts 6 * 7\").value.map { |token, _state| token.type }"
          },
          {
            "t": "h",
            "html": "<p><code>Prism.lex</code> splits the code into tokens: a name, a number, a star, a number, the end. That is how IRB knows, for example, what to colour how. <code>Prism.parse</code> builds the whole syntax tree – and <code>success?</code> tells whether the code is complete and valid:</p>"
          },
          {
            "t": "c",
            "code": "puts Prism.parse(\"def fox\").errors.last.message\n\n[\"def fox\", \"def fox\\nend\", \"[1, 2,\", \"\\\"bacon\"].map do |code|\n  [code, Prism.parse(code).success?]\nend"
          },
          {
            "t": "h",
            "html": "<p><code>def fox</code> lacks its <code>end</code>, <code>[1, 2,</code> its bracket, <code>\"bacon</code> its quote: here IRB waits for the next line. Real IRB also tells code that is merely <em>unfinished</em> from code that is already <em>wrong</em> – that was part of the talk, too. This page uses the same idea: ⚡ Live only starts your code once it parses.</p><div class='offweb' data-title='Join in'><p>On <a href='https://www.rubyevents.org' target='_blank'>RubyEvents.org</a> you'll find talks on almost every topic of this course – try searching for \"IRB\", \"Prism\" or \"TRICK\". Many RubyKaigi talks are in Japanese, but their slides are mostly in English; the talk's page on <a href='https://rubykaigi.org' target='_blank'>rubykaigi.org</a> links them. RubyEvents also shows which conferences and meetups are coming up and which are looking for talks. Ruby conferences are glad to see new faces – in the audience and on stage.</p></div><div class='task'><strong>Task:</strong> Build IRB's line collector: <code>inputs(lines)</code> gets the lines someone types one after the other and returns the finished inputs, the way IRB would run them – the lines of one input joined with <code>\"\\n\"</code>. <code>inputs([\"x = 1\", \"def double(n)\", \"  n * 2\", \"end\"])</code> gives <code>[\"x = 1\", \"def double(n)\\n  n * 2\\nend\"]</code>.</div>"
          },
          {
            "t": "x",
            "code": "require \"prism\"\n\ndef inputs(lines)\n  # collect lines until Prism.parse(code).success?\nend\n",
            "check": "inputs([\"x = 1\", \"def double(n)\", \"  n * 2\", \"end\", \"double(x)\"]) == [\"x = 1\", \"def double(n)\\n  n * 2\\nend\", \"double(x)\"] && inputs([\"[1,\", \"2]\", \"\\\"bacon\", \"\\\"\", \"puts 3\"]) == [\"[1,\\n2]\", \"\\\"bacon\\n\\\"\", \"puts 3\"]",
            "hint": "A buffer for the lines of the current input: append each line, parse <code>buffer.join(\"\\n\")</code> – and when that works, put the code into the result and empty the buffer."
          }
        ]
      },
      "ja": {
        "title": "31. RubyKaigiと変なコード",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Rubyはコミュニティでもある</h2><p>Rubyの向こうには人がいて、その人たちは集まります。いちばん大きなRubyのカンファレンスは日本の<a href='https://rubykaigi.org' target='_blank'>RubyKaigi</a>です。2006年から続き、今では毎年ちがう街で開かれます。3日間、日本語と英語のトークがあり、その真ん中にはMatzとRuby自体を開発している人たちがいます。ほかにもアメリカのRubyConf、ヨーロッパのEuRuKo、Rails World、そして多くの街のミートアップがあります。</p><p>参加できなかった？ <a href='https://www.rubyevents.org' target='_blank'>RubyEvents.org</a>には何千ものRubyのトーク動画が集められていて、無料で検索して見られます。これから開かれるカンファレンスやミートアップもわかります。このレッスンでは、1人のRubyistの3つのトークをたどります。<strong>石田智也さん</strong>（<code>@tompng</code>）です。Rubyコミッターで、レッスン12で使ったIRBのメンテナーです。</p>"
          },
          {
            "t": "h",
            "html": "<p>沖縄で開かれたRubyKaigi 2024で、tompngさんはキーノート<a href='https://www.rubyevents.org/talks/keynote-writing-weird-code' target='_blank'>「Writing Weird Code」</a>を行いました。発表は日本語、スライドは英語です。言いたいことはこうです：Rubyはとても読みやすいコードも書けるし、とびきり変なコードも書ける。トークのアイデアをいくつか、自分たちの例で試してみましょう。まずは、半分くらいは知っている書き方から：</p>"
          },
          {
            "t": "c",
            "code": "p %(bacon)              # \"bacon\"と同じ\np %w[Kaz Isi Chunky]    # 単語の配列\np \"RubyKaigi %d\" % 2024 # String#%が%dを埋める\np ?a                    # 1文字\np %%%                   # %をかっこにした%…%：空\np %%%%%%%               # 空 % 空"
          },
          {
            "t": "h",
            "html": "<p><code>%(…)</code>と<code>%w[…]</code>は文字列と単語の配列を、<code>?a</code>は1文字を表し、<code>String#%</code>はプレースホルダーを埋めます。<code>%</code>の後ろのかっこには、ほとんどどんな文字でも使えます。<code>%</code>自身でさえも。<code>%%%</code>は空の文字列で、パーセント記号7つは「空 % 空」です。tompngさんは、4n + 3個のパーセント記号の並びはどれも正しいRubyだと示しました。名前も変にできます：</p>"
          },
          {
            "t": "c",
            "code": "🦊 = \"Chunky\"\n🥓 = \"bacon\"\nputs \"#{🦊} loves #{🥓}\"\n\nboth = <<~ONE + <<~TWO\n  First line\nONE\n  Second line\nTWO\nboth"
          },
          {
            "t": "h",
            "html": "<p>変数名にはUnicode、絵文字さえも使えます（読みやすくなるとはかぎりませんが）。そして1行に2つのヒアドキュメント。Rubyはまずその行を最後まで読み、それから本文を順番に拾います。こういうケースは以前、IRBの自動インデントを混乱させていましたが、IRB 1.7.1からは正しく扱えます。</p><p>正規表現は思ったよりたくさんのことができます。これは、コードの中で一度も割り算をせずに素数を見分けます：</p>"
          },
          {
            "t": "c",
            "code": "def prime?(number)\n  number > 1 && (\"x\" * number) !~ /\\A(xx+)\\1+\\z/\nend\n\n(1..30).select { |number| prime?(number) }"
          },
          {
            "t": "h",
            "html": "<p>9は<code>\"xxxxxxxxx\"</code>になります。<code>(xx+)</code>は2つ以上のxのグループをとらえ、<code>\\1+</code>はまさにそのグループが最後までくり返されることを求めます。それができるのは、xを同じ大きさのグループに分けられるとき、つまりその数が合成数のときだけです。正規表現エンジンはそれを確かめるためにすべてのグループの大きさを試します。遅いけれど美しい。Perlの世界の古い技で、tompngさんがトークで紹介しました。最後にクイズです。ここでは何が出てくるでしょう？</p>"
          },
          {
            "t": "c",
            "code": "FOX = \"Chunky\"\n\nmodule Forest\n  FOX += \" Bacon\"\nend\n\n[FOX, Forest::FOX]"
          },
          {
            "t": "h",
            "html": "<p><code>FOX += \" Bacon\"</code>は<code>FOX = FOX + \" Bacon\"</code>という意味です。読むときは外側の<code>FOX</code>が見つかり、代入すると新しい<code>Forest::FOX</code>ができます。定数が2つになるのです。Rubyのコードを理解するツールは、こういうケースを知っていなければなりません。tompngさんが作ったIRBの型補完のテストは、まさにこのケースを確かめています。</p><p>なぜこんなことを？ トークの中でtompngさんは3つの理由を挙げています。変なコードは楽しいパズルであること。それを解くと、Rubyをもっと深く理解できること。そして変なコードは、行儀のよいプログラムでは決して出会わないバグを、IRBやパーサーの中に見つけてくれること。彼自身、変なコードのコンテストがきっかけでIRBとRelineに貢献するようになりました。キーノートの後半では、沖縄をテーマにした6つのプログラムを見せました。たとえば、テッポウユリの画像（BMP）であると同時にRubyプログラムでもあるファイルや、ターミナルの中で沖縄のミンサー織りの模様を永遠に織り続けるプログラムです。<a href='https://github.com/tompng/selftrick2024' target='_blank'>GitHub</a>で見られます。</p><p>そのコンテストは<strong>TRICK</strong>（Transcendental Ruby Imbroglio Contest for rubyKaigi）といいます。2013年から、審査員を驚かせ、わくわくさせ、笑わせるプログラムが応募されてきました。審査員にはMatzもいます。tompngさんは2022年に金賞を取りました。<a href='https://www.rubyevents.org/talks/trick-2025-episode-i' target='_blank'>TRICK 2025</a>では自分も審査員でしたが、それでも3位、4位、5位を取りました。今回は審査員もプログラムを応募したのです。受賞作品はすべて解説つきで<a href='https://github.com/tric/trick2025' target='_blank'>GitHub</a>にあり、MITライセンスです。</p>"
          },
          {
            "t": "h",
            "html": "<p>1年後、松山で開かれたRubyKaigi 2025で、tompngさんは<a href='https://www.rubyevents.org/talks/analyzing-ruby-code-in-irb' target='_blank'>「Analyzing Ruby Code in IRB」</a>の中で、入力中のコードをIRBがどう読んでいるかを話しました。色をつけるため、入力が終わったのか、まだ<code>end</code>が足りないのかを見分けるため、インデントするため、補完するためです。そのためにIRBはコードを2つの見方で調べます。コードの「単語」である<strong>トークン</strong>の並びとして、そして<strong>構文木</strong>として。変なコードはその試金石です。助けになるのが<strong>Prism</strong>、Ruby 3.4からRuby自身がコードを読むのに使っているパーサーです。試してみましょう：</p>"
          },
          {
            "t": "c",
            "code": "require \"prism\"\n\nPrism.lex(\"puts 6 * 7\").value.map { |token, _state| token.type }"
          },
          {
            "t": "h",
            "html": "<p><code>Prism.lex</code>はコードをトークンに分けます。名前、数、星、数、終わり。IRBはこれを見て、たとえば何をどう色づけするかを決めます。<code>Prism.parse</code>は構文木全体を作り、<code>success?</code>でコードが完全で正しいかどうかを教えてくれます：</p>"
          },
          {
            "t": "c",
            "code": "puts Prism.parse(\"def fox\").errors.last.message\n\n[\"def fox\", \"def fox\\nend\", \"[1, 2,\", \"\\\"bacon\"].map do |code|\n  [code, Prism.parse(code).success?]\nend"
          },
          {
            "t": "h",
            "html": "<p><code>def fox</code>には<code>end</code>が、<code>[1, 2,</code>にはかっこが、<code>\"bacon</code>には引用符が足りません。こういうとき、IRBは次の行を待ちます。本物のIRBはさらに、コードがただ<em>途中</em>なのか、もう<em>まちがっている</em>のかも区別します。それもトークのテーマでした。このページも同じ考え方を使っています。⚡ ライブは、コードがパースできるようになってから実行します。</p><div class='offweb' data-title='参加してみよう'><p><a href='https://www.rubyevents.org' target='_blank'>RubyEvents.org</a>には、このコースのほとんどのテーマについてのトークがあります。「IRB」「Prism」「TRICK」で検索してみましょう。RubyKaigiのトークの多くは日本語ですが、スライドはたいてい英語で、<a href='https://rubykaigi.org' target='_blank'>rubykaigi.org</a>のトークのページからリンクされています。RubyEventsでは、これから開かれるカンファレンスやミートアップ、トークを募集中のイベントもわかります。Rubyのカンファレンスは新しい顔を歓迎しています。客席でも、ステージの上でも。</p></div><div class='task'><strong>課題：</strong>IRBの行集めを作りましょう。<code>inputs(lines)</code>は、だれかが1行ずつ入力した行を受け取り、IRBが実行するのと同じように、完成した入力を返します。1つの入力の行は<code>\"\\n\"</code>でつなげます。<code>inputs([\"x = 1\", \"def double(n)\", \"  n * 2\", \"end\"])</code>は<code>[\"x = 1\", \"def double(n)\\n  n * 2\\nend\"]</code>になります。</div>"
          },
          {
            "t": "x",
            "code": "require \"prism\"\n\ndef inputs(lines)\n  # Prism.parse(code).success? になるまで行を集める\nend\n",
            "check": "inputs([\"x = 1\", \"def double(n)\", \"  n * 2\", \"end\", \"double(x)\"]) == [\"x = 1\", \"def double(n)\\n  n * 2\\nend\", \"double(x)\"] && inputs([\"[1,\", \"2]\", \"\\\"bacon\", \"\\\"\", \"puts 3\"]) == [\"[1,\\n2]\", \"\\\"bacon\\n\\\"\", \"puts 3\"]",
            "hint": "今の入力の行をためるバッファを用意して、1行ずつ追加し、<code>buffer.join(\"\\n\")</code>をパースしてみて。うまくいったら、そのコードを結果に入れてバッファを空にするんだよ。"
          }
        ]
      }
    },
    {
      "id": "tl-collections",
      "section": {
        "de": "Aufbaukurs: timelog",
        "en": "Advanced: timelog",
        "ja": "応用コース：timelog"
      },
      "de": {
        "title": "32. Projekt timelog: Collections",
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
        "title": "32. Project timelog: collections",
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
      },
      "ja": {
        "title": "32. timelogプロジェクト：コレクション",
        "cells": [
          {
            "t": "h",
            "html": "<h2>timelogプロジェクト、始動！</h2><p>ここからは、本格的なプログラムをいっしょに作っていきます。作るのは、作業時間を記録するツール<strong>timelog</strong>です。レッスンごとに少しずつ育てていき、最後にはエントリをパースし、レポートを計算し、テストもしっかりそろい、Webインターフェースまで備えたプログラムになります。</p><p>まずはデータの形から始めましょう。作業時間のエントリ1件には、プロジェクトと時間があります。これをハッシュで表します。エントリがたくさんあるなら、ハッシュの配列にします：</p>"
          },
          {
            "t": "c",
            "code": "entries = [\n  { project: \"ProjectX\", hours: 3.5 },\n  { project: \"Intern\",   hours: 2.0 },\n  { project: \"ProjectX\", hours: 3.0 }\n]\nentries.length"
          },
          {
            "t": "h",
            "html": "<p>ここでコレクションのメソッドが本領を発揮します。<code>map</code>は値を取り出し、<code>select</code>は絞り込み、<code>sum</code>は合計します。しかも、どれもつなげて書けます：</p>"
          },
          {
            "t": "c",
            "code": "entries.select { |e| e[:project] == \"ProjectX\" }\n       .sum { |e| e[:hours] }"
          },
          {
            "t": "h",
            "html": "<p>レポート作りの主役は<code>group_by</code>です。要素をグループに振り分けて、グループのハッシュにしてくれます。<code>transform_values</code>と組み合わせれば、たった2行で立派なレポートになります：</p>"
          },
          {
            "t": "c",
            "code": "entries.group_by { |e| e[:project] }"
          },
          {
            "t": "h",
            "html": "<p>ほかにも便利なメソッドがあります。<code>tally</code>は出現回数を数え、<code>sort_by</code>は並べ替え、<code>each_with_object</code>は好きな構造を組み立てます。</p><div class='task'><strong>課題：</strong><code>entries</code>から、各プロジェクトにその<strong>合計時間</strong>を対応させたハッシュ<code>hours</code>を作ってください：<code>{\"ProjectX\"=>6.5, \"Intern\"=>2.0}</code>。ヒント：<code>group_by</code>と<code>transform_values</code>を組み合わせます。</div>"
          },
          {
            "t": "x",
            "code": "entries = [\n  { project: \"ProjectX\", hours: 3.5 },\n  { project: \"Intern\",   hours: 2.0 },\n  { project: \"ProjectX\", hours: 3.0 }\n]\n\n# hours = ...\n",
            "check": "hours == { \"ProjectX\" => 6.5, \"Intern\" => 2.0 }",
            "hint": "こう書けるよ：<code>hours = entries.group_by { |e| e[:project] }.transform_values { |list| list.sum { |e| e[:hours] } }</code>"
          }
        ]
      }
    },
    {
      "id": "tl-parsing",
      "de": {
        "title": "33. Text parsen: Regex",
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
        "title": "33. Parsing text: regex",
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
      },
      "ja": {
        "title": "33. テキストのパース：正規表現",
        "cells": [
          {
            "t": "h",
            "html": "<h2>エントリをパースする：正規表現</h2><p>timelogには、次のような行を読み取れるようになってもらいます：</p><pre><code>2026-09-15 08:30-12:00 ProjectX planning-meeting</code></pre><p>そのためにあるのが<strong>正規表現</strong>（regex）です。正規表現は、テキストの形を表すパターンです。<code>\\d</code>は数字1文字、<code>{2}</code>は「ちょうど2つ」という意味です。そして<code>(?&lt;name&gt;…)</code>を使うと、マッチした部分に名前を付けられます：</p>"
          },
          {
            "t": "c",
            "code": "line = \"2026-09-15 08:30-12:00 ProjectX planning-meeting\"\n\npattern = /(?<date>\\d{4}-\\d{2}-\\d{2}) (?<from>\\d{2}:\\d{2})-(?<to>\\d{2}:\\d{2}) (?<project>\\S+)/\nhit = line.match(pattern)\nhit[:project]"
          },
          {
            "t": "h",
            "html": "<p><code>match</code>は<code>MatchData</code>オブジェクトを返します。名前付きグループは<code>hit[:from]</code>のように取り出せます。何もマッチしなければ<code>nil</code>が返ってきます（<code>if</code>にぴったりです）。データはいらず、マッチするかどうかだけを手早く調べたいなら<code>line.match?(pattern)</code>を使います。</p><p>条件分岐には、Rubyのエレガントな<code>case/when</code>があります。範囲やクラス、さらには正規表現まで理解してくれます：</p>"
          },
          {
            "t": "c",
            "code": "def classify(hours)\n  case hours\n  when 0...4 then \"half day\"\n  when 4...9 then \"full day\"\n  else            \"overtime!\"\n  end\nend\n\nclassify(7.5)"
          },
          {
            "t": "h",
            "html": "<div class='task'><strong>課題：</strong><code>parse_line(line)</code>を書いてください。このメソッドは、名前付きグループを使ってtimelogの行を分解し、<code>{ project:, from:, to: }</code>を返します。マッチしない行には<code>nil</code>を返します。最後の行に<code>parse_line(\"2026-09-15 08:30-12:00 ProjectX meeting\")</code>と書いて試してみましょう。</div>"
          },
          {
            "t": "x",
            "code": "# def parse_line(line)\n#   pattern = /.../  # 名前付きグループ：date、from、to、project\n#   ...\n# end\n",
            "check": "parse_line(\"2026-09-15 08:30-12:00 ProjectX meeting\") == { project: \"ProjectX\", from: \"08:30\", to: \"12:00\" } && parse_line(\"coffee break\").nil? && code.include?(\"(?<\")",
            "hint": "パターンはデモと同じでいいよ。そのあとは<code>hit = line.match(pattern)</code>、<code>return nil unless hit</code>、そして<code>{ project: hit[:project], from: hit[:from], to: hit[:to] }</code>を返そう。"
          }
        ]
      }
    },
    {
      "id": "tl-methods",
      "de": {
        "title": "34. Methoden richtig bauen",
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
        "title": "34. Building methods properly",
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
      },
      "ja": {
        "title": "34. メソッドをきちんと作る",
        "cells": [
          {
            "t": "h",
            "html": "<h2>メソッドをスマートに</h2><p><code>def</code>はもう知っていますね。ここでは、Rubyのコードを読みやすくするための細かな工夫を紹介します。<strong>キーワード引数</strong>を使うと、呼び出しを見ただけで意味がわかるようになります。デフォルト値を決めておけば、その引数は省略できるようになります：</p>"
          },
          {
            "t": "c",
            "code": "def greet(name:, loud: false)\n  text = \"Hello, #{name}\"\n  loud ? text.upcase + \"!\" : text\nend\n\ngreet(name: \"Kaz\", loud: true)"
          },
          {
            "t": "h",
            "html": "<p><code>greet(name: \"Kaz\")</code>と、何を渡しているのかわからない<code>greet(\"Kaz\", true)</code>を比べてみてください。引数がいくつもあるときは、読みやすさの点でキーワード引数のほうがはっきり有利です。ほかにも決まりごとがあります。<code>*rest</code>は任意の数の引数をまとめて受け取ります。<code>?</code>で終わるメソッドはtrueかfalseを返し、<code>!</code>で終わるメソッドは「危険な」バージョンです。そして、最後の行の値が自動的に戻り値になります。</p><p>レッスン9を思い出してください。メソッド呼び出しのかっこは省略できるのでした。これをキーワード引数と組み合わせると、<code>attr_reader :name</code>でおなじみの、宣言的なRubyのスタイルになります。<code>add_entry project: \"X\", from: \"08:30\", to: \"10:00\"</code>は、まるで設定ファイルのように読めます。ただし、式が入れ子になるときは、かっこを付けましょう。</p><p>timelogには時刻の計算が必要です。<code>\"08:30\"</code>を、午前0時から数えて何時間かという数値に直します：</p>"
          },
          {
            "t": "c",
            "code": "def as_hours(time)\n  h, m = time.split(\":\").map(&:to_i)\n  h + m / 60.0\nend\n\nas_hours(\"08:30\")"
          },
          {
            "t": "h",
            "html": "<div class='task'><strong>課題：</strong><code>add_entry(project:, from:, to:, note: nil)</code>を書いてください。戻り値はハッシュ<code>{ project:, from:, to:, note:, hours: }</code>で、<code>hours</code>は<code>as_hours(to)</code>と<code>as_hours(from)</code>の差です。つまり<code>add_entry(project: \"X\", from: \"08:30\", to: \"10:00\")</code>の結果には、<code>hours: 1.5</code>が含まれるはずです。</div>"
          },
          {
            "t": "x",
            "code": "def as_hours(time)\n  h, m = time.split(\":\").map(&:to_i)\n  h + m / 60.0\nend\n\n# def add_entry(project:, from:, to:, note: nil)\n#   ...\n# end\n",
            "check": "e = add_entry(project: \"X\", from: \"08:30\", to: \"10:00\"); e[:hours] == 1.5 && e[:project] == \"X\" && e[:note].nil? && add_entry(project: \"Y\", from: \"09:00\", to: \"17:00\", note: \"docs\")[:note] == \"docs\" && code.include?(\"project:\")",
            "hint": "メソッドの最後の行に<code>{ project: project, from: from, to: to, note: note, hours: as_hours(to) - as_hours(from) }</code>と書けばOKだよ。"
          }
        ]
      }
    },
    {
      "id": "tl-classes",
      "de": {
        "title": "35. Entry & Timesheet",
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
        "title": "35. Entry & Timesheet",
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
      },
      "ja": {
        "title": "35. EntryとTimesheet",
        "cells": [
          {
            "t": "h",
            "html": "<h2>ハッシュからクラスへ</h2><p>最初のうちはハッシュで十分です。でも、データに<em>ふるまい</em>（時間を計算する、自分をきれいに表示する、など）が必要になったら、クラスの出番です。timelogは2つのクラスを中心に組み立てていきます。1件のエントリを表す<code>Entry</code>と、エントリをまとめる<code>Timesheet</code>です。</p>"
          },
          {
            "t": "c",
            "code": "class Entry\n  attr_reader :project, :from, :to, :note\n\n  def initialize(project:, from:, to:, note: nil)\n    @project = project\n    @from = from\n    @to = to\n    @note = note\n  end\n\n  def hours\n    as_hours(@to) - as_hours(@from)\n  end\n\n  def to_s\n    \"#{@project}: #{@from}-#{@to} (#{hours}h)\"\n  end\n\n  private\n\n  def as_hours(time)\n    h, m = time.split(\":\").map(&:to_i)\n    h + m / 60.0\n  end\nend\n\nEntry.new(project: \"ProjectX\", from: \"08:30\", to: \"12:00\").to_s"
          },
          {
            "t": "h",
            "html": "<p>ポイント：<code>as_hours</code>は<code>private</code>にしてあります。外から使う人のいない、内部の細かい処理だからです。<code>to_s</code>は、オブジェクトを文字列にしたときの見た目を決めます。インスタンス変数（<code>@project</code>）はオブジェクトのもの、定数（<code>BIG</code>）はクラスのものです。クラス変数（<code>@@…</code>）やグローバル変数（<code>$…</code>）は、なるべく使わないようにしましょう。あちこちで共有される状態になり、どこで変わったのかを追いかけにくくなるからです。</p>"
          },
          {
            "t": "c",
            "code": "class Timesheet\n  def initialize\n    @entries = []\n  end\n\n  def add(entry)\n    @entries << entry\n    self\n  end\n\n  def count\n    @entries.length\n  end\nend\n\nsheet = Timesheet.new\nsheet.add(Entry.new(project: \"ProjectX\", from: \"08:30\", to: \"12:00\"))\nsheet.count"
          },
          {
            "t": "h",
            "html": "<p><code>add</code>の最後で<code>self</code>を返しているので、<code>sheet.add(a).add(b)</code>のように呼び出しをつなげられます（メソッドチェーン）。</p><div class='task'><strong>課題：</strong><code>Timesheet</code>に<code>total_for(project)</code>を追加しましょう。指定したプロジェクトのエントリをすべて集めて、時間を合計するメソッドです。<code>@entries</code>に<code>select</code>と<code>sum</code>を使います。</div>"
          },
          {
            "t": "x",
            "code": "# 上のデモセルのEntryをここでも使う。\n# 先にそのセルを実行しておこう！\n\nclass Timesheet\n  def initialize\n    @entries = []\n  end\n\n  def add(entry)\n    @entries << entry\n    self\n  end\n\n  # def total_for(project)\n  #   ...\n  # end\nend\n",
            "check": "ts = Timesheet.new.add(Entry.new(project: \"A\", from: \"08:00\", to: \"10:30\")).add(Entry.new(project: \"B\", from: \"10:30\", to: \"11:30\")).add(Entry.new(project: \"A\", from: \"13:00\", to: \"14:00\")); ts.total_for(\"A\") == 3.5 && ts.total_for(\"B\") == 1.0 && ts.total_for(\"C\") == 0",
            "hint": "こう書けるよ：<code>def total_for(project); @entries.select { |e| e.project == project }.sum(&:hours); end</code>。それと、上のEntryのセルを先に実行しておいてね。"
          }
        ]
      }
    },
    {
      "id": "tl-minitest",
      "de": {
        "title": "36. Testen mit Minitest",
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
        "title": "36. Testing with Minitest",
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
      },
      "ja": {
        "title": "36. Minitestでテスト",
        "cells": [
          {
            "t": "h",
            "html": "<h2>テストは頼れる安全ネット</h2><p>Rubyが型をチェックするのは、実行するときだけです。タイプミスがあっても、そのコードが実際に動くまで気づけません。だからこそ、Rubyのプロジェクトに<strong>テスト</strong>は欠かせません。道具はもうそろっています。<strong>Minitest</strong>はRubyに最初から付いてきます。</p><p>テストは<code>Minitest::Test</code>を継承したクラスです。<code>test_</code>で始まるメソッドが、それぞれ1つのテストケースになります。<code>assert_equal expected, actual</code>は、期待する値と実際の値が等しいかどうかを確かめます。このノートブックでは、<code>run_tests</code>でテストを実行します。</p>"
          },
          {
            "t": "c",
            "code": "class Duration\n  attr_reader :minutes\n\n  def initialize(minutes)\n    @minutes = minutes\n  end\n\n  def in_hours\n    minutes / 60.0\n  end\nend\n\nclass TestDuration < Minitest::Test\n  def test_in_hours\n    assert_equal 1.5, Duration.new(90).in_hours\n  end\n\n  def test_zero_minutes\n    assert_equal 0.0, Duration.new(0).in_hours\n  end\nend\n\nrun_tests"
          },
          {
            "t": "h",
            "html": "<p>結果の読み方：<code>2 runs</code>（テストメソッドが2つ）、<code>2 assertions</code>（チェックが2回）、<code>0 failures, 0 errors</code>。すべて成功、オールグリーンです。では、何かが壊れていたら？Minitestは、<em>何</em>が期待されていて、実際には<em>何</em>が返ってきたのかを正確に教えてくれます。</p>"
          },
          {
            "t": "c",
            "code": "class TestBroken < Minitest::Test\n  def test_deliberately_wrong\n    assert_equal 100, Duration.new(90).minutes\n  end\nend\n\nrun_tests"
          },
          {
            "t": "h",
            "html": "<div class='offweb' data-title='自分のコンピューターでは'><p>テストは専用のファイルに書いて、そのファイルを直接実行します。<code>minitest/autorun</code>を読み込んでおくと、プログラムの最後にテストが自動で実行されます。</p><pre><code># test/test_duration.rb\nrequire \"minitest/autorun\"\nrequire_relative \"../lib/duration\"\n\nclass TestDuration < Minitest::Test\n  def test_in_hours\n    assert_equal 1.5, Duration.new(90).in_hours\n  end\nend</code></pre><pre><code>$ ruby test/test_duration.rb\n2 runs, 2 assertions, 0 failures, 0 errors, 0 skips</code></pre><p>ほかにも便利なメソッドがあります。<code>assert</code>、<code>refute</code>、<code>assert_nil</code>、<code>assert_raises</code>、そして共通の準備をまとめて書ける<code>setup</code>です。Minitestのほかにいちばんよく知られているのはRSpecで、独自の書き方（<code>expect(x).to eq(y)</code>）をします。</p></div><div class='task'><strong>課題：</strong>下にあるのはクラス<code>Entry</code>です。<strong>2つ以上</strong>のテストを持つ<code>TestEntry</code>を書きましょう。1つは正しいエントリのテスト、もう1つは正しくないケース（時間がマイナス、またはプロジェクトが空）のテストです。最後に<code>run_tests</code>を実行して、すべて成功させてください。これからは<em>テストのない課題はなし！</em>です。</div>"
          },
          {
            "t": "x",
            "code": "class Entry\n  attr_reader :project, :hours\n\n  def initialize(project, hours)\n    @project = project\n    @hours = hours\n  end\n\n  def valid?\n    hours > 0 && !project.to_s.empty?\n  end\nend\n\n# class TestEntry < Minitest::Test\n#   def test_...\n#   end\n# end\n\n# run_tests\n",
            "check": "defined?(TestEntry) && TestEntry.instance_methods.grep(/\\Atest_/).length >= 2 && output.include?(\"0 failures\") && output.include?(\"0 errors\") && output.include?(\"runs,\")",
            "hint": "たとえば<code>def test_valid; assert Entry.new(\"X\", 2.0).valid?; end</code>と<code>def test_negative_hours; refute Entry.new(\"X\", -1).valid?; end</code>を書いて、最後に<code>run_tests</code>を呼んでみて。"
          }
        ]
      }
    },
    {
      "id": "tl-mixins",
      "de": {
        "title": "37. Enumerable & Data",
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
            "html": "<p><code>Data.define</code> erzeugt eine Klasse mit fixen Feldern, Gleichheit und <code>inspect</code> geschenkt – und die Objekte sind eingefroren (kein versehentliches Ändern). Für veränderliche Fälle gibt es das ältere <code>Struct</code>.</p><p>Die zweite Superkraft: <strong>Enumerable</strong>. Deine Klasse liefert nur <code>each</code> – und bekommt dafür die GESAMTE Collection-Werkzeugkiste: <code>map</code>, <code>select</code>, <code>sum</code>, <code>sort_by</code>, <code>group_by</code> … genau die Methoden aus Lektion 32, jetzt auf deiner eigenen Klasse.</p><div class='task'><strong>Aufgabe:</strong> Mach <code>Timesheet</code> enumerable: <code>include Enumerable</code> plus eine Methode <code>each</code>, die den Block an <code>@eintraege.each</code> weiterreicht. Danach funktioniert die letzte Zeile.</div>"
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
        "title": "37. Enumerable & Data",
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
            "html": "<p><code>Data.define</code> creates a class with fixed fields, equality and <code>inspect</code> for free – and the objects are frozen (no accidental mutation). For mutable cases there's the older <code>Struct</code>.</p><p>The second superpower: <strong>Enumerable</strong>. Your class provides just <code>each</code> – and receives the ENTIRE collection toolbox in return: <code>map</code>, <code>select</code>, <code>sum</code>, <code>sort_by</code>, <code>group_by</code> … exactly the methods from lesson 32, now on your own class.</p><div class='task'><strong>Task:</strong> Make <code>Timesheet</code> enumerable: <code>include Enumerable</code> plus an <code>each</code> method that forwards the block to <code>@entries.each</code>. Then the last line works.</div>"
          },
          {
            "t": "x",
            "code": "class Timesheet\n  # include ...\n\n  def initialize(entries)\n    @entries = entries\n  end\n\n  # def each(&block)\n  #   ...\n  # end\nend\n\nts = Timesheet.new([\n  { project: \"A\", hours: 2.0 },\n  { project: \"B\", hours: 1.0 }\n])\n\n# ts.sum { |e| e[:hours] }\n",
            "check": "Timesheet.include?(Enumerable) && ts.map { |e| e[:project] } == [\"A\", \"B\"] && ts.sum { |e| e[:hours] } == 3.0 && code.include?(\"include Enumerable\") && code.include?(\"def each\")",
            "hint": "<code>include Enumerable</code> into the class, plus <code>def each(&block); @entries.each(&block); end</code>."
          }
        ]
      },
      "ja": {
        "title": "37. EnumerableとData",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Mix-inで手に入る2つの超能力</h2><p>Mix-inにはモジュールのレッスンで出会いましたね。今回は、なかでも特に有名な2つをtimelogで活躍させます。まずは<strong>Comparable</strong>。クラスに<code>&lt;=&gt;</code>（「宇宙船演算子」。-1、0、1のどれかを返す）を用意するだけで、このMix-inが<code>&lt;</code>、<code>&gt;</code>、<code>==</code>、<code>between?</code>などを使えるようにしてくれます。</p><p>あわせて<code>Data</code>も紹介します。変更できない値オブジェクトを作るための、Rubyのクラスです。</p>"
          },
          {
            "t": "c",
            "code": "Duration = Data.define(:minutes) do\n  include Comparable\n\n  def <=>(other)\n    minutes <=> other.minutes\n  end\n\n  def to_s\n    \"#{minutes / 60}h #{minutes % 60}min\"\n  end\nend\n\nbreaks = [Duration.new(minutes: 90), Duration.new(minutes: 45), Duration.new(minutes: 120)]\nbreaks.max.to_s"
          },
          {
            "t": "h",
            "html": "<p><code>Data.define</code>は、決まったフィールドを持つクラスを作ります。等しいかどうかの比較や<code>inspect</code>も自動で付いてきます。しかも、できたオブジェクトは凍結（freeze）されているので、うっかり書き換えてしまう心配もありません。値を書き換えたいときは、昔からある<code>Struct</code>を使います。</p><p>2つ目の超能力は<strong>Enumerable</strong>です。クラスが用意するのは<code>each</code>だけ。それだけで、コレクションの道具箱がまるごと手に入ります。<code>map</code>、<code>select</code>、<code>sum</code>、<code>sort_by</code>、<code>group_by</code>……レッスン32で使ったメソッドが、今度は自分のクラスで使えるのです。</p><div class='task'><strong>課題：</strong><code>Timesheet</code>でEnumerableのメソッドを使えるようにしましょう。<code>include Enumerable</code>を書き、受け取ったブロックを<code>@entries.each</code>にそのまま渡す<code>each</code>メソッドを定義します。そうすれば、最後の行が動くようになります。</div>"
          },
          {
            "t": "x",
            "code": "class Timesheet\n  # include ...\n\n  def initialize(entries)\n    @entries = entries\n  end\n\n  # def each(&block)\n  #   ...\n  # end\nend\n\nts = Timesheet.new([\n  { project: \"A\", hours: 2.0 },\n  { project: \"B\", hours: 1.0 }\n])\n\n# ts.sum { |e| e[:hours] }\n",
            "check": "Timesheet.include?(Enumerable) && ts.map { |e| e[:project] } == [\"A\", \"B\"] && ts.sum { |e| e[:hours] } == 3.0 && code.include?(\"include Enumerable\") && code.include?(\"def each\")",
            "hint": "クラスの中に<code>include Enumerable</code>を書いて、<code>def each(&block); @entries.each(&block); end</code>も足してみて。"
          }
        ]
      }
    },
    {
      "id": "tl-blocks",
      "de": {
        "title": "38. Blocks, Procs & Lambdas",
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
        "title": "38. Blocks, procs & lambdas",
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
      },
      "ja": {
        "title": "38. ブロック、Proc、lambda",
        "cells": [
          {
            "t": "h",
            "html": "<h2>ブロックは、コードの贈り物</h2><p>ブロックはレッスン6からずっと使ってきました。今回はその舞台裏をのぞいてみましょう。メソッドはブロックを受け取り、<code>yield</code>でそれを実行します。ブロックが渡されたかどうかは<code>block_given?</code>でわかります。これを使うと、次のストップウォッチのように、処理を包み込む「ラッパー」メソッドが作れます。</p>"
          },
          {
            "t": "c",
            "code": "def with_timing(name)\n  start = Process.clock_gettime(Process::CLOCK_MONOTONIC)\n  result = yield\n  ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000\n  puts \"#{name}: #{ms.round(1)} ms\"\n  result\nend\n\nwith_timing(\"sum\") { (1..100_000).sum }"
          },
          {
            "t": "h",
            "html": "<p>ブロックそのものはオブジェクトではありません。でも、オブジェクトにすることはできます。<code>proc</code>や<code>lambda</code>を使うと、コードを包んで変数に入れておけます。違いは2つあります。lambdaは引数の数を厳しくチェックし、<code>return</code>してもlambdaから抜けるだけです。procはどちらについてもゆるやかです。また、<code>&amp;:to_s</code>は「このシンボルをブロックにして」という意味の省略記法です。</p>"
          },
          {
            "t": "c",
            "code": "double = ->(x) { x * 2 }\n\n[double.call(21), double.(5), [1, 2, 3].map(&:to_s)]"
          },
          {
            "t": "h",
            "html": "<p>lambdaは<strong>クロージャ</strong>です。作られた場所の環境（変数など）をいっしょに持ち歩きます。timelogのレポートの出力形式にぴったりです。形式のひとつひとつが、小さくまとめられたプログラムになります。</p>"
          },
          {
            "t": "c",
            "code": "formats = {\n  text: ->(e) { \"#{e[:project].ljust(10)} #{e[:hours]}h\" },\n  csv:  ->(e) { \"#{e[:project]};#{e[:hours]}\" }\n}\n\nentry = { project: \"ProjectX\", hours: 3.5 }\nformats[:csv].call(entry)"
          },
          {
            "t": "h",
            "html": "<div class='task'><strong>課題：</strong><code>each_project(entries)</code>を書きましょう。このメソッドはエントリをプロジェクトごとにグループ分けし、<code>(project, list)</code>の組をひとつずつ<strong><code>yield</code>で</strong>ブロックに渡します。いわば、1段上のレベルの<code>each</code>です。</div>"
          },
          {
            "t": "x",
            "code": "# def each_project(entries)\n#   ... group_by ... yield ...\n# end\n\n# テスト:\n# each_project([{ project: \"A\", hours: 1.0 }]) do |project, list|\n#   puts \"#{project}: #{list.length} entries\"\n# end\n",
            "check": "collected = []; each_project([{ project: \"A\", hours: 1.0 }, { project: \"B\", hours: 2.0 }, { project: \"A\", hours: 0.5 }]) { |p, list| collected << [p, list.length] }; collected == [[\"A\", 2], [\"B\", 1]] && code.include?(\"yield\")",
            "hint": "たとえばこう書けるよ：<code>def each_project(entries); entries.group_by { |e| e[:project] }.each { |project, list| yield(project, list) }; end</code>"
          }
        ]
      }
    },
    {
      "id": "tl-errors",
      "de": {
        "title": "39. Fehler behandeln",
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
        "title": "39. Handling errors",
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
      },
      "ja": {
        "title": "39. エラー処理",
        "cells": [
          {
            "t": "h",
            "html": "<h2>うまくいかないときは</h2><p><code>raise</code>で例外を発生させ、<code>rescue</code>でそれを捕まえます。<code>ensure</code>の中身は<em>どんなときでも</em>実行されます（後片付けに便利！）。よくできたプログラムは、自分専用の<strong>エラークラスの一族</strong>を定義します。そうすれば呼び出す側は、関係のないエラーまで握りつぶすことなく、「timelogのエラー全部」をまとめて捕まえられます。</p>"
          },
          {
            "t": "c",
            "code": "module Timelog\n  class Error        < StandardError; end\n  class ParseError   < Error; end\n  class OverlapError < Error; end\nend\n\nbegin\n  raise Timelog::ParseError, \"line 7 is not a time entry\"\nrescue Timelog::Error => e\n  \"caught: #{e.class}: #{e.message}\"\nend"
          },
          {
            "t": "h",
            "html": "<p>例外にするか、戻り値で知らせるか？目安はこうです。「ふつうに起こりうること」（ある行がパターンに合わない）なら<code>nil</code>、「何かが根本的におかしい」（エントリの終わりが始まりより前になっている）なら例外です。継承元はかならず<code>StandardError</code>にして、<code>Exception</code>を直接継承してはいけません。そうしないと、Ctrl-Cまで捕まえてしまいます。それから、一族は自分のモジュールの中に入れておきましょう（<code>Timelog::ParseError</code>）。そうすれば、ほかの誰かのクラスと名前がぶつかることはありません。</p><p><em>一時的な</em>エラー（ネットワークなど！）には<code>retry</code>が使えます。<code>begin</code>ブロックの先頭に戻って、もう一度やり直してくれます。</p>"
          },
          {
            "t": "c",
            "code": "class TimelogError < StandardError; end\n\nattempts = 0\nflaky_service = lambda do\n  attempts += 1\n  raise TimelogError, \"network error\" if attempts < 3\n  \"data received (attempt #{attempts})\"\nend\n\nbegin\n  flaky_service.call\nrescue TimelogError\n  retry if attempts < 5\nend"
          },
          {
            "t": "h",
            "html": "<div class='offweb' data-title='自分のコンピューターでは'><p>実際のリトライ処理では、試すたびに待ち時間を長くしていきます（<em>バックオフ</em>）。ブラウザの中には<code>sleep</code>がないため、上の例では待ち時間を入れていません。</p><pre><code>rescue TimelogError\n  wait = 2 ** attempt   # 1s, 2s, 4s, 8s ...\n  sleep(wait)\n  retry if attempt < 5</code></pre></div><div class='task'><strong>課題：</strong><code>sync_with_retry(service, max:)</code>を書きましょう。このメソッドは<code>service.call</code>を呼び出します。サービスが<code>TimelogError</code>を発生させたら、合計で<code>max</code>回まで試します。それでもだめなら、エラーをそのまま外に伝えます（もう<code>retry</code>しなければいいだけです）。成功したら、その結果を返します。</div>"
          },
          {
            "t": "x",
            "code": "class TimelogError < StandardError; end\n\n# def sync_with_retry(service, max:)\n#   attempts = 0\n#   begin\n#     ...\n#   rescue TimelogError\n#     ...\n#   end\n# end\n",
            "check": "c1 = 0; ok_service = lambda { c1 += 1; raise TimelogError, \"broken\" if c1 < 3; \"ok\" }; res = sync_with_retry(ok_service, max: 5); broke = begin; c2 = 0; always_broken = lambda { c2 += 1; raise TimelogError, \"broken\" }; sync_with_retry(always_broken, max: 2); false; rescue TimelogError; c2 == 2; end; res == \"ok\" && c1 == 3 && broke && code.include?(\"retry\")",
            "hint": "beginブロックの中で、<code>service.call</code>の前に<code>attempts += 1</code>しよう。rescueの中では<code>retry if attempts < max</code>、そうでなければ<code>raise</code>だよ。"
          }
        ]
      }
    },
    {
      "id": "tl-formats",
      "de": {
        "title": "40. Daten speichern: Formate",
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
        "title": "40. Saving data: formats",
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
      },
      "ja": {
        "title": "40. データの保存：フォーマット",
        "cells": [
          {
            "t": "h",
            "html": "<h2>timelogのデータを永続化する</h2><p>これまで、エントリはメモリの中にしかありませんでした。そこで<strong>シリアライズ</strong>の出番です。データをテキストに変換し、またデータに戻すことをいいます。Rubyには、特に大事な3つのフォーマットが最初から付いています。まずは<strong>JSON</strong>。Web APIの共通語です。</p>"
          },
          {
            "t": "c",
            "code": "require \"json\"\n\nentries = [\n  { project: \"ProjectX\", hours: 3.5 },\n  { project: \"Intern\",   hours: 2.0 }\n]\n\ntext = JSON.pretty_generate(entries)\nputs text\nJSON.parse(text, symbolize_names: true) == entries"
          },
          {
            "t": "h",
            "html": "<p><code>symbolize_names: true</code>に注目してください。JSONにはシンボルがないので、これを付けないとキーが文字列で返ってきます。<strong>CSV</strong>は表のためのフォーマットです（Excelでおなじみ！）。</p>"
          },
          {
            "t": "c",
            "code": "require \"csv\"\n\ncsv_text = CSV.generate do |csv|\n  csv << [\"project\", \"hours\"]\n  entries.each { |e| csv << [e[:project], e[:hours]] }\nend\nputs csv_text\n\nCSV.parse(csv_text, headers: true).map { |row| row[\"project\"] }"
          },
          {
            "t": "h",
            "html": "<p>そして<strong>YAML</strong>は、設定ファイルの定番です。人間が読むのも書くのも楽なフォーマットです。</p>"
          },
          {
            "t": "c",
            "code": "require \"yaml\"\n\nconfig = YAML.safe_load(\"rate: 120\\nround_to: 15\\n\")\nconfig[\"rate\"]"
          },
          {
            "t": "h",
            "html": "<p>いよいよ<strong>ファイル</strong>です！自分のコンピューターでは、Rubyは<code>File.write</code>で保存し、<code>File.read</code>で読み込みます。ここブラウザの中では、そのために小さなファイルシステムをシミュレーションしています。専用のファイルウィンドウ（<code>show_files</code>）付きです。</p>"
          },
          {
            "t": "c",
            "code": "File.write(\"notizen.txt\", \"buy bacon!\\ntest timelog.\")\nFile.write(\"projekte/plan.txt\", \"Q4: finish timelog\")\n\nshow_files"
          },
          {
            "t": "h",
            "html": "<p>ファイルをクリックすると、中身をのぞけます。エクスプローラーやFinderと同じですね。ほかの操作も、いつもどおりに使えます。読み込んだり、探したり、あるかどうか確かめたり。</p>"
          },
          {
            "t": "c",
            "code": "[File.read(\"notizen.txt\"),\n Dir.glob(\"**/*.txt\"),\n File.exist?(\"beispiel.csv\")]"
          },
          {
            "t": "h",
            "html": "<div class='offweb' data-title='自分のコンピューターでは'><p>このファイルウィンドウはシミュレーションです。自分のコンピューターでは、同じコードのままディスク上の本物のファイルを扱えます。さらに、便利な道具も使えます。</p><pre><code># Block form closes the file automatically:\nFile.open(\"log.txt\", \"a\") { |f| f.puts \"new entry\" }\n\nPathname.new(\"a/b.json\")    # paths as objects\nTempfile.create(\"test\")     # throwaway files for tests\nStringIO.new(\"...\")         # in-memory \"file\"</code></pre></div><div class='task'><strong>課題：</strong><code>to_csv(entries)</code>（ヘッダー行が<code>project,hours</code>のCSVテキストを返す）と、<code>from_csv(text)</code>（キーがシンボルで、時間の値が<code>Float</code>のハッシュに戻す）を書きましょう。次に、<code>data</code>を<code>File.write</code>で<code>entries.csv</code>に保存し、<code>from_csv(File.read(…))</code>で読み戻します。データが1つも失われずに元どおりになれば成功です。終わったら、上のファイルウィンドウ（⟳）ものぞいてみてください！</div>"
          },
          {
            "t": "x",
            "code": "require \"csv\"\n\ndata = [\n  { project: \"A\", hours: 1.5 },\n  { project: \"B\", hours: 2.0 }\n]\n\n# def to_csv(entries)\n#   ...\n# end\n\n# def from_csv(text)\n#   ...  # ヒント: row[\"hours\"].to_f\n# end\n\n# File.write(\"entries.csv\", to_csv(data))\n# from_csv(File.read(\"entries.csv\"))\n",
            "check": "File.exist?(\"entries.csv\") && from_csv(File.read(\"entries.csv\")) == data && to_csv(data).lines.first.strip == \"project,hours\"",
            "hint": "<code>to_csv</code>と<code>from_csv</code>はデモと同じ要領で書けるよ。そのあと<code>File.write(\"entries.csv\", to_csv(data))</code>で保存して、最後の行を<code>from_csv(File.read(\"entries.csv\"))</code>にしてね。"
          }
        ]
      }
    },
    {
      "id": "tl-cli",
      "de": {
        "title": "41. Kommandozeile & Gems",
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
        "title": "41. Command line & gems",
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
      },
      "ja": {
        "title": "41. コマンドラインとgem",
        "cells": [
          {
            "t": "h",
            "html": "<h2>timelogを本物のツールに</h2><p>自分のコンピューターでは、プログラムはターミナルから起動します：<code>timelog add \"ProjectX\" --from 08:30</code>。プログラム名のあとに書いたものは、すべて文字列の配列として<code>ARGV</code>に入ります。これをきれいに解析するには、標準ライブラリの<strong>OptionParser</strong>が便利です。ここでは、自分で用意した配列で練習しましょう：</p>"
          },
          {
            "t": "c",
            "code": "require \"optparse\"\n\nargv = [\"report\", \"--week\", \"--format\", \"csv\"]\n\noptions = { format: \"text\", week: false }\nparser = OptionParser.new do |p|\n  p.on(\"--week\", \"this week only\")        { options[:week] = true }\n  p.on(\"--format FORMAT\", \"text or csv\")  { |f| options[:format] = f }\nend\n\nrest = parser.parse(argv)\n[options, rest]"
          },
          {
            "t": "h",
            "html": "<p><code>parse</code>はオプションを抜き出して、残ったものを返します。ここではコマンドの<code>\"report\"</code>です。おまけに、説明文つきの<code>--help</code>も自動で使えるようになります。</p>"
          },
          {
            "t": "h",
            "html": "<div class='offweb' data-title='自分のコンピューターでは：スクリプトからgemへ'><p>インストールできるツールには、決まったフォルダー構成と<code>.gemspec</code>ファイルがあります：</p><pre><code>timelog/\n├── lib/timelog.rb        # the code\n├── bin/timelog           # the command (#!/usr/bin/env ruby)\n├── test/test_timelog.rb\n├── timelog.gemspec       # name, version, author, files\n├── Gemfile               # dependencies (Bundler)\n└── Rakefile              # tasks: rake test</code></pre><pre><code>$ bundle install          # fetches deps, writes Gemfile.lock\n$ rake test               # runs the tests\n$ gem build timelog.gemspec\n$ gem install timelog-0.1.0.gem\n$ timelog report --week   # your tool, everywhere!</code></pre><p>終了コードも忘れずに。失敗したときは<code>exit 1</code>で終わらせれば、ツールを呼び出したスクリプトがエラーに気づけます。</p></div><div class='task'><strong>課題：</strong>OptionParserを使って<code>parse_argv(argv)</code>を書きましょう。対応するのは<code>--week</code>と<code>--format FORMAT</code>（デフォルトは<code>\"text\"</code>）です。戻り値はハッシュ<code>{ command:, week:, format: }</code>で、<code>command</code>には残った引数の最初のものが入ります。</div>"
          },
          {
            "t": "x",
            "code": "require \"optparse\"\n\n# def parse_argv(argv)\n#   options = { week: false, format: \"text\" }\n#   ...\n# end\n",
            "check": "a = parse_argv([\"report\", \"--week\"]); b = parse_argv([\"export\", \"--format\", \"csv\"]); c2 = parse_argv([\"add\"]); a == { command: \"report\", week: true, format: \"text\" } && b == { command: \"export\", week: false, format: \"csv\" } && c2 == { command: \"add\", week: false, format: \"text\" }",
            "hint": "デモと同じやり方でいいよ。最後はこうしよう：<code>rest = parser.parse(argv); { command: rest.first, week: options[:week], format: options[:format] }</code>"
          }
        ]
      }
    },
    {
      "id": "tl-pattern",
      "de": {
        "title": "42. Pattern Matching",
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
        "title": "42. Pattern matching",
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
      },
      "ja": {
        "title": "42. パターンマッチ",
        "cells": [
          {
            "t": "h",
            "html": "<h2>モダンなRuby：case/in</h2><p>Ruby 3からは、<code>case/when</code>に加えて、もっと強力な<strong>パターンマッチ</strong>が<code>case/in</code>で使えます。データの<em>形</em>を調べて、同時にそれを分解してくれる仕組みです。コマンドラインのレッスンで出てきたコマンドの配列にぴったりです：</p>"
          },
          {
            "t": "c",
            "code": "command = [\"add\", \"ProjectX\", 3.5]\n\ncase command\nin [\"add\", project, hours]\n  \"New entry: #{project} (#{hours}h)\"\nin [\"report\"]\n  \"Generating report\"\nend"
          },
          {
            "t": "h",
            "html": "<p>パターン<code>[\"add\", project, hours]</code>は、<code>\"add\"</code>で始まる要素3つの配列にだけマッチし、残りの値をその場で変数に入れてくれます。ハッシュも同じように分解できます。型のチェックやガード条件（<code>if</code>）を付けることもできます：</p>"
          },
          {
            "t": "c",
            "code": "entry = { project: \"ProjectX\", hours: 3.5 }\n\ncase entry\nin { project: String => p, hours: Float => h } if h > 0\n  \"#{p}: #{h}h - looks good\"\nin { hours: }\n  \"Invalid hours: #{hours.inspect}\"\nend"
          },
          {
            "t": "h",
            "html": "<p>モダンなRubyのほかの機能も、これとよくなじみます。1行で書ける<em>エンドレスメソッド</em>（<code>def square(x) = x * x</code>）、変数とキーが同じ名前のときのハッシュの省略記法<code>{ project:, hours: }</code>、そして<code>case</code>の外で分解しながら代入する<code>data => { project: }</code>です。</p><div class='task'><strong>課題：</strong><code>case/in</code>を使って、次のように値を返す<code>dispatch(command)</code>を書きましょう：<code>[\"add\", project, hours]</code> → <code>\"Entry: &lt;project&gt; (&lt;hours&gt;h)\"</code>、<code>[\"report\"]</code> → <code>\"Report\"</code>、<code>[\"export\", format]</code> → <code>\"Export as &lt;format&gt;\"</code>、それ以外（<code>else</code>）→ <code>\"Unknown command\"</code>。</div>"
          },
          {
            "t": "x",
            "code": "# def dispatch(command)\n#   case command\n#   in ...\n#   end\n# end\n",
            "check": "dispatch([\"add\", \"X\", 2.5]) == \"Entry: X (2.5h)\" && dispatch([\"report\"]) == \"Report\" && dispatch([\"export\", \"csv\"]) == \"Export as csv\" && dispatch([\"dance\"]) == \"Unknown command\" && code.include?(\"in [\")",
            "hint": "分岐は4つだよ：<code>in [\"add\", project, hours]</code>、<code>in [\"report\"]</code>、<code>in [\"export\", format]</code>、そして<code>else</code>。"
          }
        ]
      }
    },
    {
      "id": "tl-meta",
      "de": {
        "title": "43. Objektmodell & Metaprogrammierung",
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
        "title": "43. Object model & metaprogramming",
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
      },
      "ja": {
        "title": "43. オブジェクトモデルとメタプログラミング",
        "cells": [
          {
            "t": "h",
            "html": "<h2>Rubyはどうやってメソッドを見つけるのか</h2><p><code>object.method</code>を呼び出すと、Rubyは決まった順番でメソッドを探していきます。まずそのオブジェクトの特異クラス（<em>このオブジェクトだけ</em>が持つメソッドの置き場所）、次にそのクラス、次にMix-inしたモジュール、そしてスーパークラスへと上っていきます。この順番は表示させることもできます：</p>"
          },
          {
            "t": "c",
            "code": "oddball = \"a normal string\"\n\ndef oddball.shout\n  upcase + \"!!!\"\nend\n\n[oddball.shout, String.ancestors.first(4)]"
          },
          {
            "t": "h",
            "html": "<p>クラスそのものもオブジェクトなので、コードが<em>コードを作る</em>こともできます。これがメタプログラミングです。<code>define_method</code>は実行時にメソッドを定義し、<code>send</code>は名前が変数に入っているメソッドを呼び出します：</p>"
          },
          {
            "t": "c",
            "code": "class Config\n  def initialize(values)\n    @values = values\n  end\n\n  %w[host port language].each do |field|\n    define_method(field) { @values[field] }\n  end\nend\n\nc = Config.new({ \"host\" => \"idogawa.com\", \"port\" => 8011 })\n[c.host, c.send(\"port\")]"
          },
          {
            "t": "h",
            "html": "<p>Railsなどのフレームワークも、<code>has_many</code>や<code>validates</code>のようなマクロをまさにこうやって作っています。ただし、賢いキツネから大事な忠告をひとつ：<em>凝りに凝ったコードほど、あとで真っ先に消すことになりがちです。</em><code>method_missing</code>というしくみもあります（知らない呼び出しをすべて受け止めます。使うときは必ず<code>respond_to_missing?</code>とセットで）。それでも、はっきり書いた<code>define_method</code>のほうが、ほとんどの場合わかりやすいです。</p><div class='task'><strong>課題：</strong>自分だけのRailsマクロを作りましょう。<code>BaseModel.validates_presence_of(*fields)</code>は、<code>define_method</code>で<code>valid?</code>メソッドを作ります。このメソッドは、指定したフィールドのどれも<code>nil</code>や<code>\"\"</code>でないことを確かめます。下の<code>Booking</code>クラスでは、それをRails風に使います。</div>"
          },
          {
            "t": "x",
            "code": "class BaseModel\n  # def self.validates_presence_of(*fields)\n  #   define_method(:valid?) do\n  #     ...\n  #   end\n  # end\nend\n\nclass Booking < BaseModel\n  attr_accessor :project, :hours\n  # validates_presence_of :project\nend\n",
            "check": "b = Booking.new; b.project = \"X\"; b2 = Booking.new; b2.project = \"\"; b3 = Booking.new; b.valid? && !b2.valid? && !b3.valid? && code.include?(\"define_method\")",
            "hint": "define_methodのブロックの中で<code>fields.all? { |f| value = send(f); !value.nil? && value != \"\" }</code>を使ってみて。それから<code>Booking</code>の中の<code>validates_presence_of :project</code>の行を有効にしよう（先頭の#を消すだけだよ）。"
          }
        ]
      }
    },
    {
      "id": "tl-dsl",
      "de": {
        "title": "44. Eine eigene DSL",
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
            "html": "<p>Im Block ruft <code>gericht \"Speck\", preis: 8</code> in Wahrheit eine Methode der <code>Speisekarte</code> auf – ganz ohne Empfänger davor. Das liest sich wie eine Mini-Sprache. (<code>instance_exec</code> ist die Schwester, die zusätzlich Argumente in den Block reicht.)</p><p><strong>Ehrliche Warnung:</strong> Eine DSL lohnt sich nur, wenn viele Menschen sie oft lesen – sonst tut es ein schlichter Hash genauso gut und ist leichter zu debuggen. Verwandte Bausteine aus der Werkzeugkiste: unsere Formatter-Lambdas aus Lektion 38 waren das <em>Strategy</em>-Muster, und ein <em>Null-Objekt</em> (z. B. ein GastNutzer statt <code>nil</code>) erspart tausend <code>if</code>-Abfragen.</p><div class='task'><strong>Aufgabe:</strong> Baue die timelog-Konfiguration: <code>Timelog.configure { … }</code> führt den Block per <code>instance_eval</code> auf einer neuen <code>Konfiguration</code> aus, <code>Timelog.config</code> gibt sie zurück. Im Block sollen <code>projekt \"Name\", satz: 120</code> und <code>runde_auf 15</code> funktionieren.</div>"
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
        "title": "44. Your own DSL",
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
            "html": "<p>Inside the block, <code>dish \"Bacon\", price: 8</code> really calls a method of the <code>Menu</code> – with no receiver in front. It reads like a mini language. (<code>instance_exec</code> is the sibling that additionally passes arguments into the block.)</p><p><strong>Honest warning:</strong> a DSL only pays off when many people read it often – otherwise a plain hash does the job and is easier to debug. Related building blocks: our formatter lambdas from lesson 38 were the <em>Strategy</em> pattern, and a <em>null object</em> (e.g. a GuestUser instead of <code>nil</code>) saves a thousand <code>if</code> checks.</p><div class='task'><strong>Task:</strong> Build the timelog configuration: <code>Timelog.configure { … }</code> runs the block via <code>instance_eval</code> on a fresh <code>Configuration</code>, <code>Timelog.config</code> returns it. Inside the block, <code>project \"Name\", rate: 120</code> and <code>round_to 15</code> must work.</div>"
          },
          {
            "t": "x",
            "code": "module Timelog\n  class Configuration\n    attr_reader :projects, :grid\n\n    def initialize\n      @projects = {}\n      @grid = 60\n    end\n\n    # def project(name, rate:)\n    #   ...\n    # end\n\n    # def round_to(minutes)\n    #   ...\n    # end\n  end\n\n  # def self.configure(&block)\n  #   ...\n  # end\n\n  # def self.config\n  #   ...\n  # end\nend\n\n# Timelog.configure do\n#   project \"ProjectX\", rate: 120\n#   round_to 15\n# end\n",
            "check": "Timelog.configure { project \"A\", rate: 100\n round_to 30 }; Timelog.config.projects[\"A\"] == 100 && Timelog.config.grid == 30 && code.include?(\"instance_eval\")",
            "hint": "<code>def self.configure(&block); @config = Configuration.new; @config.instance_eval(&block); @config; end</code> and <code>def self.config; @config; end</code>. The DSL methods simply write into <code>@projects</code> / <code>@grid</code>."
          }
        ]
      },
      "ja": {
        "title": "44. 自分だけのDSL",
        "cells": [
          {
            "t": "h",
            "html": "<h2>人気ツールのような設定の書き方</h2><p>Rubyのツールの多くは、エレガントなブロックで設定を書けるようになっています。これを<strong>DSL</strong>（ドメイン固有言語、domain-specific language）と呼びます。その裏にある仕掛けは、たった1つのメソッドです。<code>instance_eval</code>は、ブロックをまるで<em>そのオブジェクトの中に</em>書いたかのように実行します。つまり<code>self</code>が切り替わるのです：</p>"
          },
          {
            "t": "c",
            "code": "class Menu\n  attr_reader :dishes\n\n  def initialize\n    @dishes = {}\n  end\n\n  def dish(name, price:)\n    @dishes[name] = price\n  end\nend\n\ndef menu(&block)\n  m = Menu.new\n  m.instance_eval(&block)\n  m\nend\n\ncard = menu do\n  dish \"Bacon\", price: 8\n  dish \"Egg\",   price: 3\nend\n\ncard.dishes"
          },
          {
            "t": "h",
            "html": "<p>ブロックの中の<code>dish \"Bacon\", price: 8</code>は、前にレシーバーを書いていないのに、実は<code>Menu</code>のメソッドを呼び出しています。まるで小さな言語のように読めますね。（<code>instance_exec</code>はその兄弟分で、ブロックに引数も渡せます。）</p><p><strong>正直に言っておくと：</strong>DSLが割に合うのは、たくさんの人が何度も読む場合だけです。そうでなければ、ただのハッシュで十分ですし、そのほうがデバッグも簡単です。関連する道具もあります。レッスン38のフォーマッター用ラムダは、じつは<em>Strategy</em>パターンでした。また<em>ヌルオブジェクト</em>（たとえば<code>nil</code>の代わりにGuestUserを使う）を使えば、山ほどの<code>if</code>チェックを書かずに済みます。</p><div class='task'><strong>課題：</strong>timelogの設定のしくみを作りましょう。<code>Timelog.configure { … }</code>は、新しく作った<code>Configuration</code>の上で<code>instance_eval</code>を使ってブロックを実行し、<code>Timelog.config</code>はその設定を返します。ブロックの中では<code>project \"Name\", rate: 120</code>と<code>round_to 15</code>が使えるようにします。</div>"
          },
          {
            "t": "x",
            "code": "module Timelog\n  class Configuration\n    attr_reader :projects, :grid\n\n    def initialize\n      @projects = {}\n      @grid = 60\n    end\n\n    # def project(name, rate:)\n    #   ...\n    # end\n\n    # def round_to(minutes)\n    #   ...\n    # end\n  end\n\n  # def self.configure(&block)\n  #   ...\n  # end\n\n  # def self.config\n  #   ...\n  # end\nend\n\n# Timelog.configure do\n#   project \"ProjectX\", rate: 120\n#   round_to 15\n# end\n",
            "check": "Timelog.configure { project \"A\", rate: 100\n round_to 30 }; Timelog.config.projects[\"A\"] == 100 && Timelog.config.grid == 30 && code.include?(\"instance_eval\")",
            "hint": "<code>def self.configure(&block); @config = Configuration.new; @config.instance_eval(&block); @config; end</code>と<code>def self.config; @config; end</code>だよ。DSLのメソッドは、<code>@projects</code>や<code>@grid</code>に書き込むだけでいいんだ。"
          }
        ]
      }
    },
    {
      "id": "tl-quality",
      "de": {
        "title": "45. Codequalität & Debugging",
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
        "title": "45. Code quality & debugging",
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
      },
      "ja": {
        "title": "45. コードの品質とデバッグ",
        "cells": [
          {
            "t": "h",
            "html": "<h2>きれいなコードのための道具</h2><p>チームで開発するときは、<strong>リンター</strong>がコードのスタイルをそろえてくれます。<em>RuboCop</em>は何百ものルールを細かく設定できる大物、<em>Standard</em>は議論いらずの選択肢です（「全員に同じ設定を」）。どのルールよりも大切なのは、チームがカンマの位置で言い争わなくなることです。さらに、ドキュメントコメントには<em>YARD</em>、お好みで<em>RBS</em>や<em>Sorbet</em>による型シグネチャも使えます。</p><div class='offweb' data-title='自分のコンピューターでは'><pre><code>$ gem install standard\n$ standardrb            # checks the style\n$ standardrb --fix      # repairs a lot by itself\n\n# And for breakpoint debugging right in your code:\nrequire \"debug\"\nbinding.break           # or binding.irb - opens a console RIGHT HERE</code></pre></div><p>でも、デバッグはどこでもできます。もちろんここでも。万能の道具は<code>p</code>です。引数を出力して、<em>しかもそれをそのまま返す</em>ので、どんなメソッドチェーンの途中にもこっそり差し込めます：</p>"
          },
          {
            "t": "c",
            "code": "values = [3, 1, 4, 1, 5, 9]\n\nvalues.select { |x| p(x).odd? }.sum"
          },
          {
            "t": "h",
            "html": "<p>ほかにも便利な道具があります。ハッシュを見やすく表示する<code>pp</code>、オブジェクトのありのままの姿を見せる<code>obj.inspect</code>、そして今のメソッドを誰が呼び出したかを教えてくれる<code>caller</code>です。</p><div class='task'><strong>課題：</strong>下のセルには、よくあるバグが隠れています。<code>round_to</code>は分を<strong>いちばん近い</strong>刻みに丸めるはずなのに（<code>round_to(38, 15)</code> → <code>45</code>）、いつも切り捨ててしまいます。バグを見つけて（<code>p</code>を使ってみましょう！）、メソッドを直してください。</div>"
          },
          {
            "t": "x",
            "code": "# このメソッドは「いちばん近い」刻みに丸めるはず。\n# なのにround_to(38, 15)が45ではなく30を返す。なぜ？\n\ndef round_to(minutes, grid)\n  (minutes / grid) * grid\nend\n\nround_to(38, 15)\n",
            "check": "round_to(38, 15) == 45 && round_to(8, 15) == 15 && round_to(7, 15) == 0 && round_to(22, 15) == 15 && round_to(60, 60) == 60",
            "hint": "<code>38 / 15</code>は整数どうしの割り算だよ（答えは2で、余りは消えちゃう！）。先にFloatに変換してから丸めよう：<code>(minutes.to_f / grid).round * grid</code>"
          }
        ]
      }
    },
    {
      "id": "tl-performance",
      "de": {
        "title": "46. Performance & Nebenläufigkeit",
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
        "title": "46. Performance & concurrency",
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
      },
      "ja": {
        "title": "46. パフォーマンスと並行処理",
        "cells": [
          {
            "t": "h",
            "html": "<h2>まず測って、それから最適化</h2><p>黄金律は<strong>決して推測しないこと</strong>です。Rubyの<code>Benchmark</code>を使えば、本当に遅いのはどこかを測れます。たいてい、思っていたのとは別の場所です。定番の例を見てみましょう。文字列に<code>+=</code>を使うと毎回<em>新しい</em>文字列が作られますが、シャベル演算子<code>&lt;&lt;</code>は同じ文字列を伸ばしていきます：</p>"
          },
          {
            "t": "c",
            "code": "require \"benchmark\"\n\nn = 5_000\nplus = Benchmark.realtime do\n  s = \"\"\n  n.times { s += \"x\" }\nend\nshovel = Benchmark.realtime do\n  s = \"\"\n  n.times { s << \"x\" }\nend\n\n{ plus: plus.round(4), shovel: shovel.round(4) }"
          },
          {
            "t": "h",
            "html": "<p>この背景には、<strong>アロケーション</strong>（メモリの割り当て）という大きなテーマがあります。不要な中間オブジェクトは、ひとつひとつが時間とメモリを消費します。そして何より速い最適化は、そもそも実行されないコードです。</p><div class='offweb' data-title='自分のコンピューターでは：プロファイラー'><pre><code>$ gem install benchmark-ips stackprof\n# benchmark-ips: how many times per second? (more telling than one run)\n# stackprof:     WHERE does the program spend its time?</code></pre></div><p><strong>並行処理：</strong><code>Thread</code>を使うと、Rubyは複数のことを「同時に」こなせます。MRIではすべてのスレッドが1つのインタープリターを共有している（<em>GVL</em>）ので、効果が出るのはおもに<em>待ち時間</em>のある処理（ネットワーク、ファイル）です。CPUを使う処理を並列に動かしたいときは<em>Ractor</em>があります。ブラウザには本物のスレッドがないため、ここでの<code>Thread</code>と<code>sleep</code>は<strong>シミュレーション</strong>です（協調的に、仮想の時間で動きます）。でもAPIは本物と同じです：</p>"
          },
          {
            "t": "c",
            "code": "fetches = [\"clients\", \"projects\", \"times\"].map do |name|\n  Thread.new do\n    sleep 1   # ネットワークからのダウンロードのシミュレーション\n    \"#{name}: loaded\"\n  end\nend\n\nfetches.map(&:value)"
          },
          {
            "t": "h",
            "html": "<p>3つの「ダウンロード」を<code>Thread.new</code>で始めて、<code>value</code>で結果を集めました。自分のコンピューターなら、かかる時間は3回ぶんではなく<em>1回</em>ぶんで済みます。しかも、ここでシミュレーションしているスレッドは<code>sleep</code>のたびに順番を譲り合うので、処理が交互に進む様子を出力で確かめることもできます：</p>"
          },
          {
            "t": "c",
            "code": "threads = 2.times.map do |i|\n  Thread.new do\n    3.times do |n|\n      puts \"thread #{i}: step #{n}\"\n      sleep 0.1\n    end\n  end\nend\nthreads.each(&:join)\n\"done\""
          },
          {
            "t": "h",
            "html": "<p>ちなみに、このシミュレーションの中身は<strong>Fiber</strong>でできています。Fiberは、制御を明示的に受け渡しながら協調して動くミニプログラムで、多くの非同期ライブラリの土台になっています。Fiberを直接使うこともできます：</p>"
          },
          {
            "t": "c",
            "code": "narrator = Fiber.new do\n  Fiber.yield \"Chapter 1: Bacon\"\n  Fiber.yield \"Chapter 2: More bacon\"\n  \"The end\"\nend\n\n[narrator.resume, narrator.resume, narrator.resume]"
          },
          {
            "t": "h",
            "html": "<div class='task'><strong>課題：</strong>下の<code>slow_report</code>は、エントリを<strong>プロジェクトごとに1回ずつ</strong>調べ直しています。プロジェクトが多いと、処理量は2乗のペースで増えてしまいます。<code>group_by</code>で<strong>1回だけ</strong>走査して同じ結果を返す<code>fast_report</code>を書きましょう。違いをBenchmarkで測ってみてください！</div>"
          },
          {
            "t": "x",
            "code": "entries = 500.times.map { |i| { project: \"P#{i % 5}\", hours: 1.0 } }\n\ndef slow_report(entries)\n  entries.map { |e| e[:project] }.uniq.to_h do |p|\n    [p, entries.select { |e| e[:project] == p }.sum { |e| e[:hours] }]\n  end\nend\n\n# def fast_report(entries)\n#   ...\n# end\n\n# require \"benchmark\"\n# { slow: Benchmark.realtime { 50.times { slow_report(entries) } }.round(3),\n#   fast: Benchmark.realtime { 50.times { fast_report(entries) } }.round(3) }\n",
            "check": "fast_report(entries) == slow_report(entries) && code.include?(\"group_by\")",
            "hint": "<code>entries.group_by { |e| e[:project] }.transform_values { |l| l.sum { |e| e[:hours] } }</code>を使ってみて。プロジェクトごとに1回ずつじゃなくて、全体を1回たどるだけで済むよ。"
          }
        ]
      }
    },
    {
      "id": "tl-capstone",
      "de": {
        "title": "47. Finale: timelog im Web",
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
            "html": "<h2>🎓 Geschafft!</h2><p>Du hast timelog von der ersten Collection bis zur Weboberfläche gebaut – mit Tests, Fehlerbehandlung, eigener DSL und Metaprogrammierung. Das ist kein Spielzeug-Wissen: Genau diese Bausteine stecken in jedem echten Ruby-Projekt.</p><p><strong>Wie weiter?</strong> Übe mit den <a href='https://koans.idogawa.com'>Ruby Koans</a>, bau timelog auf deinem eigenen Rechner als richtige Gem nach (Lektion 41 zeigt die Struktur) – und wenn du tiefer graben willst: Die Bücher <em>Programming Ruby</em> („Pickaxe“) und <em>Polished Ruby Programming</em> begleiten dich vom Handwerk zur Meisterschaft. CHUNKY BACON! 🦊🥓</p>"
          }
        ]
      },
      "en": {
        "title": "47. Finale: timelog on the web",
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
            "html": "<h2>🎓 You made it!</h2><p>You built timelog from the first collection to a web interface – with tests, error handling, your own DSL and metaprogramming. That's not toy knowledge: exactly these building blocks sit inside every real Ruby project.</p><p><strong>Where next?</strong> Practice with the <a href='https://koans.idogawa.com'>Ruby Koans</a>, rebuild timelog on your own machine as a proper gem (lesson 41 shows the structure) – and if you want to dig deeper: the books <em>Programming Ruby</em> (“the Pickaxe”) and <em>Polished Ruby Programming</em> take you from craft to mastery. CHUNKY BACON! 🦊🥓</p>"
          }
        ]
      },
      "ja": {
        "title": "47. フィナーレ：Webで動くtimelog",
        "cells": [
          {
            "t": "h",
            "html": "<h2>すべてを組み合わせる：Webインターフェース</h2><p>最後に、これまで学んだ<em>すべて</em>をつなげましょう。集計にはコレクション、ルーティングにはRoda、テンプレート言語には<strong>ERB</strong>、そして舞台はミニブラウザです。ERBは、Rubyを埋め込んだHTMLです。<code>&lt;%= … %&gt;</code>は値を差し込み、<code>&lt;% … %&gt;</code>はコードを実行します（ループも書けます！）：</p>"
          },
          {
            "t": "c",
            "code": "install_gem \"roda\"\nrequire \"roda\"\nrequire \"erb\"\n\nENTRIES = [\n  { project: \"ProjectX\", hours: 3.5 },\n  { project: \"Intern\",   hours: 2.0 },\n  { project: \"ProjectX\", hours: 3.0 }\n]\n\nTEMPLATE = ERB.new(<<~HTML)\n  <h1>timelog</h1>\n  <table border='1' cellpadding='6'>\n    <tr><th>Project</th><th>Hours</th></tr>\n    <% report.each do |project, hours| %>\n      <tr>\n        <td><a href='/project/<%= project %>'><%= project %></a></td>\n        <td><%= hours %></td>\n      </tr>\n    <% end %>\n  </table>\nHTML\n\nclass TimelogWeb < Roda\n  route do |r|\n    r.root do\n      report = ENTRIES.group_by { |e| e[:project] }\n                      .transform_values { |l| l.sum { |e| e[:hours] } }\n      TEMPLATE.result(binding)\n    end\n  end\nend\n\nshow_browser TimelogWeb, \"/\""
          },
          {
            "t": "h",
            "html": "<p><code>TEMPLATE.result(binding)</code>は、テンプレートからルートのローカル変数を使えるようにします。こうして<code>report</code>がHTMLまで届くのです。Rails、Sinatra、Rodaのビューも、まさにこの仕組みで動いています（実際には、便利なヘルパーがいろいろ用意されていますが）。</p><div class='task'><strong>課題：</strong>プロジェクト名はもうリンクになっています！ルート<code>r.get \"project\", String do |name| … end</code>を追加しましょう。プロジェクト名を見出しにして、そのプロジェクトの時間をすべて並べた詳細ページを表示します（たとえば<code>map</code>/<code>join</code>を使って）。知らないパスは404のままにしておきます。これでtimelogは完成です。あちこちクリックしてみてください！</div>"
          },
          {
            "t": "x",
            "code": "install_gem \"roda\"\nrequire \"roda\"\nrequire \"erb\"\n\nENTRIES = [\n  { project: \"ProjectX\", hours: 3.5 },\n  { project: \"Intern\",   hours: 2.0 },\n  { project: \"ProjectX\", hours: 3.0 }\n]\n\nclass TimelogWeb < Roda\n  route do |r|\n    r.root do\n      \"<h1>timelog</h1><a href='/project/ProjectX'>ProjectX</a> <a href='/project/Intern'>Intern</a>\"\n    end\n\n    # r.get \"project\", String do |name|\n    #   matching = ENTRIES.select { ... }\n    #   \"<h2>...</h2>...\"\n    # end\n  end\nend\n\nshow_browser TimelogWeb, \"/\"\n",
            "check": "s1, b1 = mock_get(TimelogWeb, \"/\"); s2, b2 = mock_get(TimelogWeb, \"/project/ProjectX\"); s3, _ = mock_get(TimelogWeb, \"/nonsense\"); s1 == 200 && b1.include?(\"ProjectX\") && s2 == 200 && b2.include?(\"ProjectX\") && b2.include?(\"3.5\") && s3 == 404",
            "hint": "たとえばこう書けるよ：<code>r.get \"project\", String do |name|; matching = ENTRIES.select { |e| e[:project] == name }; \"&lt;h2&gt;#{name}&lt;/h2&gt;\" + matching.map { |e| \"#{e[:hours]}h\" }.join(\", \"); end</code>"
          },
          {
            "t": "h",
            "html": "<h2>🎓 完走、おめでとうございます！</h2><p>最初のコレクションからWebインターフェースまで、timelogを自分の手で作り上げました。テストも、エラー処理も、自分だけのDSLも、メタプログラミングも使いこなしました。これはおもちゃの知識ではありません。本物のRubyプロジェクトの中には、どれもまさにこの部品が詰まっています。</p><p><strong>次はどこへ？</strong><a href='https://koans.idogawa.com'>Ruby Koans</a>で腕を磨いたり、自分のコンピューターでtimelogをちゃんとしたgemとして作り直したり（構成はレッスン41で紹介しました）してみてください。もっと深く学びたくなったら、『<em>Programming Ruby</em>』（通称「Pickaxe（つるはし）本」）や『<em>Polished Ruby Programming</em>』といった本が、職人の技から達人の域へと導いてくれるでしょう。ここまで一緒に歩いてくれて、本当にありがとうございました。あなたのRubyの旅は、ここからが本番です。楽しいコードを、たくさん書いてくださいね。CHUNKY BACON! 🦊🥓</p>"
          }
        ]
      }
    }
  ]
});
