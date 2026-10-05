# The texts of FriendlyErrors, in German, English and Japanese.
#
# Each entry: first line = the headline, the rest = the explanation.
# `code` in backticks becomes <code> in HTML. %{name} are filled in by the
# rule. German says "du" like the course; Japanese is です・ます (it is the
# page speaking, not Chunky).
module FriendlyErrors
  MESSAGES = {
    # ---------------------------------------------------------- syntax
    syn_missing_end: {
      "de" => "Hier fehlt ein `end`\nDas `%{kw}` in Zeile %{line} ist noch offen – Ruby ist am Ende der Zelle angekommen, ohne sein `end` zu finden. Jedes `def`, `class`, `if`, `do` … braucht sein eigenes `end`.",
      "en" => "An `end` is missing\nThe `%{kw}` on line %{line} is still open – Ruby reached the end of the cell without finding its `end`. Every `def`, `class`, `if`, `do` … needs an `end` of its own.",
      "ja" => "`end` が足りません\n%{line}行目の `%{kw}` が閉じられていません。Rubyはセルの最後まで読みましたが、対応する `end` が見つかりませんでした。`def`・`class`・`if`・`do` などには、それぞれ `end` が1つずつ必要です。"
    },
    syn_else_if: {
      "de" => "In Ruby heißt es `elsif`\nIn Zeile %{line} steht `else if`. Ruby liest das als `else` mit einem ganz neuen `if` darin – und das bräuchte ein eigenes `end`. Schreib stattdessen `elsif`.",
      "en" => "In Ruby it is `elsif`\nLine %{line} says `else if`. Ruby reads that as an `else` with a brand-new `if` inside, which would need an `end` of its own. Write `elsif` instead.",
      "ja" => "Rubyでは `elsif` と書きます\n%{line}行目に `else if` とあります。Rubyはこれを「`else` の中に新しい `if` がある」と読むので、その `if` にも `end` が必要になってしまいます。`elsif` と書いてください。"
    },
    syn_missing_close: {
      "de" => "Ein `%{close}` fehlt\nDas `%{open}` in Zeile %{line} wird nie geschlossen. Zu jeder öffnenden Klammer gehört eine schließende.",
      "en" => "A `%{close}` is missing\nThe `%{open}` on line %{line} is never closed. Every opening bracket needs a closing one.",
      "ja" => "`%{close}` が足りません\n%{line}行目の `%{open}` が閉じられていません。開きかっこには、必ず閉じかっこが必要です。"
    },
    syn_missing_comma: {
      "de" => "Hier fehlt ein Komma\nIn einer Liste stehen Kommas zwischen den Elementen: `[\"Ei\", \"Toast\"]`. In Zeile %{line} hat Ruby ein `,` erwartet – oder die schließende Klammer, die vielleicht in der Zeile davor fehlt.",
      "en" => "A comma is missing\nIn a list, commas go between the elements: `[\"egg\", \"toast\"]`. On line %{line} Ruby expected a `,` – or the closing bracket, which may be missing on the line before.",
      "ja" => "カンマが足りません\n配列の要素はカンマで区切ります: `[\"egg\", \"toast\"]`。%{line}行目でRubyは `,` を期待していました。あるいは、その前の行で閉じかっこが抜けているのかもしれません。"
    },
    syn_unterminated_string: {
      "de" => "Ein String ist nicht geschlossen\nDer Text, der in Zeile %{line} mit `%{quote}` beginnt, hat kein schließendes `%{quote}`. Dadurch wurde alles danach, bis zum Ende der Zelle, zu Text.",
      "en" => "A string is not closed\nThe text that starts with `%{quote}` on line %{line} has no closing `%{quote}`. So everything after it, to the end of the cell, became part of the text.",
      "ja" => "文字列が閉じられていません\n%{line}行目の `%{quote}` で始まる文字列に、閉じる `%{quote}` がありません。そのため、そこからセルの最後までが全部文字列になってしまいました。"
    },
    syn_interpolation_open: {
      "de" => "`\#{` ist nicht geschlossen\nIn Zeile %{line} beginnt `\#{` ein Stück Ruby im Text. Es braucht ein `}` vor dem schließenden Anführungszeichen: `\"Ich mag \#{essen}!\"`.",
      "en" => "`\#{` is not closed\nOn line %{line}, `\#{` starts a piece of Ruby inside the text. It needs a `}` before the closing quote: `\"I love \#{food}!\"`.",
      "ja" => "`\#{` が閉じられていません\n%{line}行目の `\#{` から、文字列の中のRubyコードが始まります。閉じる引用符の前に `}` が必要です: `\"I love \#{food}!\"`。"
    },
    syn_extra_end: {
      "de" => "Ein `end` zu viel\nDas `end` in Zeile %{line} hat nichts mehr zu schließen. Zähl nach: Jedes `def`, `do`, `if` … hat genau ein `end`.",
      "en" => "One `end` too many\nThe `end` on line %{line} has nothing left to close. Count them: every `def`, `do`, `if` … has exactly one `end`.",
      "ja" => "`end` が1つ多すぎます\n%{line}行目の `end` には、閉じるものが残っていません。`def`・`do`・`if` などと `end` の数を数えてみてください。それぞれちょうど1つずつです。"
    },
    syn_class_name: {
      "de" => "Klassennamen beginnen mit einem Großbuchstaben\nSchreib `%{kw} %{cap}` statt `%{kw} %{name}`. Namen von Klassen und Modulen sind in Ruby Konstanten – und Konstanten beginnen groß.",
      "en" => "Class names start with a capital letter\nWrite `%{kw} %{cap}` instead of `%{kw} %{name}`. In Ruby, names of classes and modules are constants, and constants begin with an uppercase letter.",
      "ja" => "クラス名は大文字で始めます\n`%{kw} %{name}` ではなく `%{kw} %{cap}` と書いてください。Rubyではクラスやモジュールの名前は定数で、定数は大文字で始まります。"
    },
    syn_python_colon: {
      "de" => "Hier braucht es keinen Doppelpunkt\nZeile %{line} endet mit `:`. So beginnt in Python ein Block – in Ruby geht es einfach in der nächsten Zeile weiter, und am Schluss steht ein `end`.",
      "en" => "No colon needed here\nLine %{line} ends with `:`. That is how Python opens a block – Ruby simply continues on the next line and closes with an `end`.",
      "ja" => "コロンは要りません\n%{line}行目が `:` で終わっています。これはPythonのブロックの書き方です。Rubyでは次の行にそのまま書き、最後を `end` で閉じます。"
    },
    syn_python_for: {
      "de" => "Das ist Python, nicht Ruby\n`for i in range(...)` gibt es in Ruby so nicht. Für „5-mal“ schreibt man `5.times do |i|` … `end`, für eine Liste `liste.each do |x|` … `end`.",
      "en" => "That's Python, not Ruby\nRuby has no `for i in range(...)`. For \"5 times\" write `5.times do |i|` … `end`, for a list `list.each do |x|` … `end`.",
      "ja" => "これはPythonの書き方です\nRubyには `for i in range(...)` はありません。「5回」なら `5.times do |i|` … `end`、配列なら `list.each do |x|` … `end` と書きます。"
    },
    syn_plusplus: {
      "de" => "Ruby kennt kein `++`\nSchreib `%{var} += 1`.",
      "en" => "Ruby has no `++`\nWrite `%{var} += 1` instead.",
      "ja" => "Rubyには `++` がありません\n代わりに `%{var} += 1` と書いてください。"
    },
    syn_if_brace: {
      "de" => "`%{kw}` endet mit `end`, nicht mit Klammern\nIn Ruby: `%{kw} x > 3` … `end`. Geschweifte Klammern sind für Hashes und Blöcke da.",
      "en" => "`%{kw}` ends with `end`, not braces\nIn Ruby: `%{kw} x > 3` … `end`. Curly braces are for hashes and blocks.",
      "ja" => "`%{kw}` は波かっこではなく `end` で閉じます\nRubyでは `%{kw} x > 3` … `end` と書きます。波かっこ `{}` はハッシュとブロックに使います。"
    },
    syn_hash_rocket: {
      "de" => "Zwischen Schlüssel und Wert fehlt etwas\nIn einem Hash schreibt man `name: \"Chunky\"` (oder `:name => \"Chunky\"`). In Zeile %{line} steht ein Schlüssel ohne beides.",
      "en" => "Key and value need something in between\nIn a hash, write `name: \"Chunky\"` (or `:name => \"Chunky\"`). On line %{line} there is a key with neither.",
      "ja" => "キーと値の間に何かが足りません\nハッシュでは `name: \"Chunky\"`（または `:name => \"Chunky\"`）と書きます。%{line}行目のキーには、どちらもありません。"
    },
    syn_block_pipe: {
      "de" => "Ein `|` fehlt\nBlockparameter stehen zwischen zwei senkrechten Strichen: `do |a, b|`. Der Strich in Zeile %{line} wird nie geschlossen.",
      "en" => "A `|` is missing\nBlock parameters stand between two pipes: `do |a, b|`. The `|` on line %{line} is never closed.",
      "ja" => "`|` が足りません\nブロックの引数は2本の縦棒で囲みます: `do |a, b|`。%{line}行目の `|` が閉じられていません。"
    },
    syn_eq_gt: {
      "de" => "Meintest du `%{op}`?\nIn Zeile %{line} wurde `= %{ch}` als Zuweisung gelesen. Vergleiche schreibt man ohne Leerzeichen: `>=`, `<=`, `==`.",
      "en" => "Did you mean `%{op}`?\nOn line %{line}, `= %{ch}` was read as an assignment. Comparisons are written without a space: `>=`, `<=`, `==`.",
      "ja" => "`%{op}` のことですか？\n%{line}行目の `= %{ch}` は代入として読まれました。比較はスペースを入れずに `>=`・`<=`・`==` と書きます。"
    },
    syn_generic: {
      "de" => "Ruby kann Zeile %{line} nicht lesen\nRubys eigene Worte: „%{msg}“. Oft steckt der eigentliche Fehler kurz davor: ein fehlendes Komma, Anführungszeichen oder eine Klammer.",
      "en" => "Ruby can't read line %{line}\nRuby's own words: “%{msg}”. Often the real mistake is just before it: a missing comma, quote or bracket.",
      "ja" => "Rubyが%{line}行目を読めません\nRuby自身のメッセージ:「%{msg}」。本当の原因は少し前にあることがよくあります。カンマ・引用符・かっこが抜けていないか確かめてください。"
    },

    # ---------------------------------------------------------- NameError
    name_typo: {
      "de" => "Meintest du `%{suggestion}`?\nRuby kennt `%{name}` hier nicht – aber `%{suggestion}` gibt es. Ein Tippfehler?",
      "en" => "Did you mean `%{suggestion}`?\nRuby doesn't know `%{name}` here – but `%{suggestion}` exists. A typo?",
      "ja" => "`%{suggestion}` のことですか？\nここでは `%{name}` という名前が見つかりませんが、`%{suggestion}` ならあります。打ち間違いではありませんか？"
    },
    name_later: {
      "de" => "`%{name}` kommt zu spät\n`%{name}` wird in Zeile %{line} benutzt, bekommt seinen Wert aber erst in Zeile %{def_line}. Ruby führt eine Zelle von oben nach unten aus.",
      "en" => "`%{name}` comes too late\n`%{name}` is used on line %{line} but only gets its value on line %{def_line}. Ruby runs a cell from top to bottom.",
      "ja" => "`%{name}` の定義が遅すぎます\n`%{name}` は%{line}行目で使われていますが、値が入るのは%{def_line}行目です。Rubyはセルを上から順に実行します。"
    },
    name_in_def: {
      "de" => "Methoden sehen keine Variablen von außen\n`%{name}` ist eine lokale Variable außerhalb der Methode `%{meth}`. In einem `def` sind nur seine Parameter sichtbar – gib den Wert hinein: `def %{meth}(%{name})`.",
      "en" => "Methods can't see variables from outside\n`%{name}` is a local variable outside the method `%{meth}`. Inside a `def`, only its parameters are visible – pass the value in: `def %{meth}(%{name})`.",
      "ja" => "メソッドの中からは外の変数が見えません\n`%{name}` はメソッド `%{meth}` の外にあるローカル変数です。`def` の中で見えるのは引数だけなので、引数として渡してください: `def %{meth}(%{name})`。"
    },
    name_python_kw: {
      "de" => "In Ruby heißt das `%{ruby}`\n`%{name}` schreibt man in Ruby klein: `true`, `false`, `nil`.",
      "en" => "In Ruby that's `%{ruby}`\nRuby spells `%{name}` in lowercase: `true`, `false`, `nil`.",
      "ja" => "Rubyでは `%{ruby}` と書きます\nRubyでは `%{name}` を小文字で書きます: `true`・`false`・`nil`。"
    },
    name_elseif: {
      "de" => "In Ruby heißt es `elsif`\n`%{name}` gibt es nicht – Ruby schreibt `elsif` (ohne e, ohne Leerzeichen).",
      "en" => "In Ruby it is `elsif`\nThere is no `%{name}` – Ruby writes `elsif` (no e, no space).",
      "ja" => "Rubyでは `elsif` と書きます\n`%{name}` はありません。Rubyでは `elsif` です（e もスペースも入りません）。"
    },
    name_unknown: {
      "de" => "Ruby kennt `%{name}` nicht\nEs gibt (noch) keine Variable und keine Methode namens `%{name}`. Gib ihr zuerst einen Wert (`%{name} = …`) – oder, wenn es Text sein soll, setz es in Anführungszeichen: `\"%{name}\"`.",
      "en" => "Ruby doesn't know `%{name}`\nThere is no variable or method called `%{name}` (yet). Give it a value first (`%{name} = …`) – or, if it is meant as text, put it in quotes: `\"%{name}\"`.",
      "ja" => "`%{name}` が見つかりません\n`%{name}` という変数もメソッドも（まだ）ありません。先に値を入れるか（`%{name} = …`）、文字列のつもりなら引用符で囲んでください: `\"%{name}\"`。"
    },
    const_typo: {
      "de" => "Meintest du `%{suggestion}`?\nEs gibt keine Klasse oder Konstante `%{name}`, aber `%{suggestion}`.",
      "en" => "Did you mean `%{suggestion}`?\nThere is no class or constant `%{name}`, but there is `%{suggestion}`.",
      "ja" => "`%{suggestion}` のことですか？\n`%{name}` というクラスや定数はありませんが、`%{suggestion}` ならあります。"
    },
    const_case: {
      "de" => "Groß und klein zählt\nWas mit einem Großbuchstaben beginnt, ist in Ruby eine Konstante. Meintest du die Variable `%{suggestion}`?",
      "en" => "Upper and lower case matter\nIn Ruby, a name that starts with a capital letter is a constant. Did you mean the variable `%{suggestion}`?",
      "ja" => "大文字と小文字は区別されます\nRubyでは大文字で始まる名前は定数です。変数 `%{suggestion}` のことですか？"
    },
    const_unknown: {
      "de" => "`%{name}` ist nicht definiert\nEs gibt keine Klasse oder Konstante `%{name}`. Steht sie in einer anderen Zelle? Dann führ die zuerst aus (▶). Soll es Text sein, setz es in Anführungszeichen: `\"%{name}\"`.",
      "en" => "`%{name}` is not defined\nThere is no class or constant `%{name}`. Is it defined in another cell? Run that one first (▶). If it is meant as text, put it in quotes: `\"%{name}\"`.",
      "ja" => "`%{name}` が定義されていません\n`%{name}` というクラスや定数はありません。別のセルで定義しているなら、先にそのセルを実行（▶）してください。文字列のつもりなら引用符で囲んでください: `\"%{name}\"`。"
    },

    # ---------------------------------------------------------- nil
    nil_hash_key: {
      "de" => "`%{expr}` ist nil\nDer Hash `%{hash}` hat keinen Schlüssel %{key}, darum liefert `%{expr}` nil – und nil hat keine Methode `%{meth}`. %{keys}",
      "en" => "`%{expr}` is nil\nThe hash `%{hash}` has no key %{key}, so `%{expr}` gives nil – and nil has no method `%{meth}`. %{keys}",
      "ja" => "`%{expr}` が nil です\nハッシュ `%{hash}` にキー %{key} がないので、`%{expr}` は nil になります。nil には `%{meth}` メソッドがありません。%{keys}"
    },
    keys_are: {
      "de" => "Seine Schlüssel sind: %{list}.",
      "en" => "Its keys are: %{list}.",
      "ja" => "このハッシュのキーは %{list} です。"
    },
    keys_are_symbols: {
      "de" => "Seine Schlüssel sind Symbole (%{list}) – schreib `%{fix}` statt `%{expr}`.",
      "en" => "Its keys are symbols (%{list}) – write `%{fix}` instead of `%{expr}`.",
      "ja" => "キーはシンボルです（%{list}）。`%{expr}` ではなく `%{fix}` と書いてください。"
    },
    keys_maybe: {
      "de" => "Vielleicht ist der Schlüssel anders geschrieben?",
      "en" => "Maybe the key is spelled differently?",
      "ja" => "キーの綴りが違っていませんか？"
    },
    nil_ivar: {
      "de" => "`%{ivar}` ist nil\nEine Instanzvariable ist nil, bis ihr etwas zugewiesen wird. Steht `%{ivar} = …` in `initialize`?",
      "en" => "`%{ivar}` is nil\nAn instance variable is nil until something is assigned to it. Is there an `%{ivar} = …` in `initialize`?",
      "ja" => "`%{ivar}` が nil です\nインスタンス変数は、何かを代入するまで nil のままです。`initialize` の中に `%{ivar} = …` がありますか？"
    },
    nil_ivar_typo: {
      "de" => "`%{ivar}` ist nil – meintest du `%{suggestion}`?\nEine Instanzvariable, der nie etwas zugewiesen wurde, ist einfach nil – Ruby meldet keinen Tippfehler. Zugewiesen wird aber `%{suggestion}`.",
      "en" => "`%{ivar}` is nil – did you mean `%{suggestion}`?\nAn instance variable that was never assigned is simply nil – Ruby doesn't report the typo. But `%{suggestion}` is assigned.",
      "ja" => "`%{ivar}` が nil です。`%{suggestion}` のことですか？\n一度も代入されていないインスタンス変数は、エラーにならずに nil になります。代入されているのは `%{suggestion}` のほうです。"
    },
    nil_bang: {
      "de" => "`%{var}` ist nil, weil `%{bang}` nil zurückgab\nMethoden mit `!` wie `%{bang}` ändern das Objekt selbst und geben nil zurück, wenn sich nichts geändert hat. Nimm `%{plain}` (ohne `!`), um das Ergebnis zu bekommen.",
      "en" => "`%{var}` is nil because `%{bang}` returned nil\nMethods with a `!` like `%{bang}` change the object itself and return nil when nothing changed. Use `%{plain}` (without `!`) to get the result.",
      "ja" => "`%{bang}` が nil を返したため、`%{var}` が nil です\n`%{bang}` のように `!` が付くメソッドはオブジェクト自体を変更し、何も変わらなかったときは nil を返します。結果がほしいときは `!` のない `%{plain}` を使ってください。"
    },
    nil_puts: {
      "de" => "`%{var}` ist nil – `%{call}` gibt nil zurück\n`%{call}` schreibt seinen Wert hin, gibt aber nil zurück. Speichere den Wert selbst: `%{var} = …` ohne `%{call}`.",
      "en" => "`%{var}` is nil – `%{call}` returns nil\n`%{call}` prints its value but gives back nil. Store the value itself: `%{var} = …` without `%{call}`.",
      "ja" => "`%{call}` は nil を返すので、`%{var}` が nil です\n`%{call}` は値を表示しますが、戻り値は nil です。値そのものを保存してください: `%{call}` を付けずに `%{var} = …`。"
    },
    nil_find: {
      "de" => "`%{expr}` hat nichts gefunden\n`%{finder}` gibt nil zurück, wenn kein Element passt – und nil hat keine Methode `%{meth}`. Prüfe die Bedingung im Block, oder fang den Fall ab: `&.%{meth}`.",
      "en" => "`%{expr}` found nothing\n`%{finder}` returns nil when no element matches – and nil has no method `%{meth}`. Check the condition in the block, or handle the case: `&.%{meth}`.",
      "ja" => "`%{expr}` は何も見つけられませんでした\n`%{finder}` は、条件に合う要素がないと nil を返します。nil には `%{meth}` メソッドがありません。ブロックの条件を確かめるか、`&.%{meth}` でその場合に備えてください。"
    },
    nil_index: {
      "de" => "`%{expr}` ist nil\nDie Liste hat kein Element an Position %{idx} – Arrays zählen ab 0, das letzte ist `[-1]`. Und nil hat keine Methode `%{meth}`.",
      "en" => "`%{expr}` is nil\nThe list has no element at position %{idx} – arrays count from 0, the last one is `[-1]`. And nil has no method `%{meth}`.",
      "ja" => "`%{expr}` が nil です\n配列の%{idx}番目には要素がありません。配列は0から数え、最後の要素は `[-1]` です。nil には `%{meth}` メソッドがありません。"
    },
    nil_generic: {
      "de" => "`%{expr}` ist hier nil\n…und nil hat keine Methode `%{meth}`. Schau, woher `%{expr}` seinen Wert bekommt: eine Variable, der nie etwas zugewiesen wurde? Eine Methode, die nichts zurückgibt?",
      "en" => "`%{expr}` is nil here\n…and nil has no method `%{meth}`. Look at where `%{expr}` gets its value: a variable that was never assigned? A method that returns nothing?",
      "ja" => "ここでは `%{expr}` が nil です\nnil には `%{meth}` メソッドがありません。`%{expr}` の値がどこから来るのか確かめてください。代入されていない変数や、何も返さないメソッドではありませんか？"
    },

    # ---------------------------------------------------------- NoMethodError
    method_typo: {
      "de" => "Meintest du `%{suggestion}`?\n%{klass} hat keine Methode `%{meth}`, aber `%{suggestion}`.",
      "en" => "Did you mean `%{suggestion}`?\n%{klass} has no method `%{meth}`, but it has `%{suggestion}`.",
      "ja" => "`%{suggestion}` のことですか？\n%{klass} には `%{meth}` メソッドはありませんが、`%{suggestion}` ならあります。"
    },
    method_wrong_type: {
      "de" => "`%{meth}` gibt es für %{owner}, nicht für %{klass}\n`%{expr}` ist %{article} %{klass} (`%{value}`). %{fix}",
      "en" => "`%{meth}` belongs to %{owner}, not to %{klass}\n`%{expr}` is %{article} %{klass} (`%{value}`). %{fix}",
      "ja" => "`%{meth}` は %{klass} ではなく %{owner} のメソッドです\n`%{expr}` は %{klass}（`%{value}`）です。%{fix}"
    },
    fix_to_s: {
      "de" => "Mach zuerst Text daraus: `%{expr}.to_s.%{meth}`.",
      "en" => "Turn it into text first: `%{expr}.to_s.%{meth}`.",
      "ja" => "先に文字列に変換してください: `%{expr}.to_s.%{meth}`。"
    },
    fix_to_i: {
      "de" => "Mach zuerst eine Zahl daraus: `%{expr}.to_i`.",
      "en" => "Turn it into a number first: `%{expr}.to_i`.",
      "ja" => "先に数値に変換してください: `%{expr}.to_i`。"
    },
    fix_map: {
      "de" => "Für jedes Element einzeln: `%{expr}.map(&:%{meth})`.",
      "en" => "To call it on every element: `%{expr}.map(&:%{meth})`.",
      "ja" => "要素ごとに呼ぶなら: `%{expr}.map(&:%{meth})`。"
    },
    fix_none: { "de" => "", "en" => "", "ja" => "" },
    method_before_def: {
      "de" => "`%{meth}` wird erst später definiert\nDu rufst `%{meth}` in Zeile %{line} auf, das `def` steht aber erst in Zeile %{def_line}. Ruby muss das `def` zuerst lesen – setz den Aufruf darunter.",
      "en" => "`%{meth}` is defined later\nYou call `%{meth}` on line %{line}, but its `def` is on line %{def_line}. Ruby has to read the `def` first – move the call below it.",
      "ja" => "`%{meth}` は後で定義されています\n%{line}行目で `%{meth}` を呼んでいますが、その `def` は%{def_line}行目にあります。Rubyは先に `def` を読む必要があるので、呼び出しをその下に移してください。"
    },
    method_unknown: {
      "de" => "Es gibt keine Methode `%{meth}`\nRuby kennt hier keine Methode `%{meth}`. Ist sie in einer anderen Zelle definiert? Dann führ die zuerst aus (▶).",
      "en" => "There is no method `%{meth}`\nRuby knows no method `%{meth}` here. Is it defined in another cell? Then run that one first (▶).",
      "ja" => "`%{meth}` というメソッドはありません\nここでは `%{meth}` というメソッドが見つかりません。別のセルで定義しているなら、先にそのセルを実行（▶）してください。"
    },
    attr_missing: {
      "de" => "`%{klass}` hat kein `%{meth}`\nVon außen sieht man die Instanzvariable `@%{meth}` erst mit `attr_reader :%{meth}` in der Klasse.",
      "en" => "`%{klass}` has no `%{meth}`\nThe instance variable `@%{meth}` can only be read from outside once the class says `attr_reader :%{meth}`.",
      "ja" => "`%{klass}` には `%{meth}` がありません\nインスタンス変数 `@%{meth}` を外から読むには、クラスに `attr_reader :%{meth}` を書く必要があります。"
    },

    # ---------------------------------------------------------- ArgumentError
    arity: {
      "de" => "`%{meth}` will %{expected}, bekommt aber %{given}\n`def %{sig}` (Zeile %{def_line}) nimmt %{expected}. Der Aufruf in Zeile %{line} gibt %{given} mit.",
      "en" => "`%{meth}` wants %{expected} but got %{given}\n`def %{sig}` (line %{def_line}) takes %{expected}. The call on line %{line} passes %{given}.",
      "ja" => "`%{meth}` には%{expected}が必要ですが、%{given}が渡されました\n`def %{sig}`（%{def_line}行目）は%{expected}を受け取ります。%{line}行目の呼び出しでは%{given}が渡されています。"
    },
    arity_nodef: {
      "de" => "`%{meth}` will %{expected}, bekommt aber %{given}\nSchau dir den Aufruf in Zeile %{line} an: Stimmt die Zahl der Werte in den Klammern?",
      "en" => "`%{meth}` wants %{expected} but got %{given}\nLook at the call on line %{line}: is the number of values in the parentheses right?",
      "ja" => "`%{meth}` には%{expected}が必要ですが、%{given}が渡されました\n%{line}行目の呼び出しを見てください。かっこの中の値の数は合っていますか？"
    },
    missing_kw: {
      "de" => "`%{meth}` braucht %{kws}\nSchlüsselwort-Argumente schreibt man beim Aufruf mit Namen aus: `%{meth}(%{example})`.",
      "en" => "`%{meth}` needs %{kws}\nKeyword arguments are written out by name in the call: `%{meth}(%{example})`.",
      "ja" => "`%{meth}` には %{kws} が必要です\nキーワード引数は、呼び出すときに名前を付けて書きます: `%{meth}(%{example})`。"
    },
    unknown_kw: {
      "de" => "`%{meth}` kennt %{kws} nicht\n%{known}",
      "en" => "`%{meth}` doesn't know %{kws}\n%{known}",
      "ja" => "`%{meth}` は %{kws} を知りません\n%{known}"
    },
    known_kws: {
      "de" => "Seine Schlüsselwörter sind: %{list}.",
      "en" => "Its keywords are: %{list}.",
      "ja" => "使えるキーワードは %{list} です。"
    },
    int_parse: {
      "de" => "%{text} ist keine Zahl\n`%{fn}()` nimmt nur Text, der genau wie eine Zahl aussieht. (`.to_i` wäre nachsichtiger: es gibt 0 statt eines Fehlers.)",
      "en" => "%{text} is not a number\n`%{fn}()` only accepts text that looks exactly like a number. (`.to_i` is more forgiving: it gives 0 instead of an error.)",
      "ja" => "%{text} は数値ではありません\n`%{fn}()` は、数値そのものに見える文字列しか受け付けません。（`.to_i` ならエラーにならず 0 を返します。）"
    },
    comparison: {
      "de" => "%{a} und %{b} lassen sich nicht vergleichen\nZum Sortieren (oder für `max`/`min`) müssen die Werte von einer Sorte sein. Hier sind %{a} und %{b} gemischt – wandle sie zuerst um, z. B. mit `to_i` oder `to_s`.",
      "en" => "%{a} and %{b} can't be compared\nSorting (or `max`/`min`) needs values of one kind. Here %{a} and %{b} are mixed – convert them first, e.g. with `to_i` or `to_s`.",
      "ja" => "%{a} と %{b} は比較できません\n並べ替え（や `max`/`min`）には同じ種類の値が必要です。ここでは %{a} と %{b} が混ざっています。先に `to_i` や `to_s` などで変換してください。"
    },

    # ---------------------------------------------------------- TypeError
    str_plus: {
      "de" => "Text und %{other} lassen sich nicht addieren\nIn Zeile %{line} trifft ein String mit `+` auf %{other_a}. Ruby wandelt das nicht von selbst um. Nimm Interpolation: `\"… \#{%{operand}}\"` – oder `%{operand}.to_s`.",
      "en" => "Text and %{other} don't add up\nOn line %{line}, a String meets %{other_a} with `+`. Ruby doesn't convert it by itself. Use interpolation: `\"… \#{%{operand}}\"` – or `%{operand}.to_s`.",
      "ja" => "文字列と%{other}は足せません\n%{line}行目で、文字列と%{other}が `+` で結ばれています。Rubyは自動では変換しません。式展開 `\"… \#{%{operand}}\"` か、`%{operand}.to_s` を使ってください。"
    },
    num_plus_str: {
      "de" => "Mit Text kann man nicht rechnen\nIn Zeile %{line} trifft eine Zahl auf einen String. Steckt im Text eine Zahl, wandle ihn um: `%{operand}.to_i`. Willst du Text, nimm `to_s` oder Interpolation.",
      "en" => "Numbers and text don't mix\nOn line %{line}, a number meets a String. If the text holds a number, convert it: `%{operand}.to_i`. If you want text, use `to_s` or interpolation.",
      "ja" => "文字列のままでは計算できません\n%{line}行目で、数値と文字列が出会っています。文字列の中身が数値なら `%{operand}.to_i` で変換し、文字列がほしいなら `to_s` か式展開を使ってください。"
    },
    nil_operand: {
      "de" => "Eine Seite ist nil\nIn Zeile %{line} bekommt `%{op}` den Wert nil. Woher kommt er – ein fehlender Hash-Schlüssel, eine Variable ohne Wert?",
      "en" => "One side is nil\nOn line %{line}, `%{op}` gets nil. Where does it come from – a missing hash key, a variable without a value?",
      "ja" => "片方が nil です\n%{line}行目の `%{op}` に nil が渡されています。その値はどこから来ていますか？ハッシュのキーがない、変数に値が入っていない、などが考えられます。"
    },
    array_key: {
      "de" => "Ein Array ist kein Hash\n`[%{key}]` fragt ein Array nach einem Schlüssel, aber Arrays kennen nur Positionen (0, 1, 2 …). Ist es eine Liste von Hashes? Dann nimm zuerst einen heraus: `%{expr}[0][%{key}]` – oder alle: `%{expr}.map { |e| e[%{key}] }`.",
      "en" => "An Array is not a Hash\n`[%{key}]` asks an Array for a key, but arrays only know positions (0, 1, 2 …). Is it a list of hashes? Then pick one first: `%{expr}[0][%{key}]` – or all of them: `%{expr}.map { |e| e[%{key}] }`.",
      "ja" => "配列はハッシュではありません\n`[%{key}]` は配列にキーを尋ねていますが、配列が知っているのは位置（0, 1, 2 …）だけです。ハッシュの配列なら、まず1つ取り出すか（`%{expr}[0][%{key}]`）、全部に対して `%{expr}.map { |e| e[%{key}] }` と書きます。"
    },
    type_generic: {
      "de" => "Falsche Sorte Wert\nRuby wollte hier %{want}, hat aber %{got} bekommen (Zeile %{line}).",
      "en" => "Wrong kind of value\nRuby wanted %{want} here but got %{got} (line %{line}).",
      "ja" => "値の種類が違います\nRubyはここで%{want}を期待していましたが、%{got}が渡されました（%{line}行目）。"
    },

    # ---------------------------------------------------------- others
    zero_div: {
      "de" => "Teilen durch null\nIn Zeile %{line} wird durch 0 geteilt. %{extra}",
      "en" => "Division by zero\nOn line %{line} something is divided by 0. %{extra}",
      "ja" => "0で割っています\n%{line}行目で0による割り算が起きています。%{extra}"
    },
    zero_div_empty: {
      "de" => "Ist die Liste leer? Dann ist `%{expr}` 0. Fang den Fall ab: `return 0 if %{list}.empty?`.",
      "en" => "Is the list empty? Then `%{expr}` is 0. Handle that case: `return 0 if %{list}.empty?`.",
      "ja" => "配列が空ではありませんか？その場合 `%{expr}` は0です。`return 0 if %{list}.empty?` のように、その場合に備えてください。"
    },
    zero_div_plain: {
      "de" => "Prüfe den Teiler vorher – oder rechne mit Kommazahlen: `1.0 / 0` ergibt `Infinity` statt eines Fehlers.",
      "en" => "Check the divisor first – or use floats: `1.0 / 0` gives `Infinity` instead of an error.",
      "ja" => "先に割る数を確かめてください。小数で計算すると、`1.0 / 0` はエラーではなく `Infinity` になります。"
    },
    frozen: {
      "de" => "`%{value}` ist eingefroren\nDieses %{klass}-Objekt lässt sich nicht ändern (es ist „frozen“ – z. B. durch `.freeze`). Arbeite mit einer Kopie (`.dup`) oder baue einen neuen Wert: `+` statt `<<`, `map` statt `map!`.",
      "en" => "`%{value}` is frozen\nThis %{klass} can't be changed (it is frozen – e.g. by `.freeze`). Work on a copy (`.dup`) or build a new value: `+` instead of `<<`, `map` instead of `map!`.",
      "ja" => "`%{value}` は凍結されています\nこの %{klass} は変更できません（`.freeze` などで凍結されています）。コピー（`.dup`）を使うか、新しい値を作ってください。`<<` の代わりに `+`、`map!` の代わりに `map` が使えます。"
    },
    no_pattern: {
      "de" => "Kein `in` hat gepasst\nDer Wert `%{value}` passt auf keines der Muster im `case` (Zeile %{line}). Ein `else`-Zweig fängt alles Übrige auf.",
      "en" => "No `in` matched\nThe value `%{value}` fits none of the patterns of the `case` on line %{line}. An `else` branch catches everything else.",
      "ja" => "どの `in` にも一致しませんでした\n値 `%{value}` は、%{line}行目の `case` のどのパターンにも一致しません。`else` を書けば、残りのすべてを受け止められます。"
    },
    key_error: {
      "de" => "Den Schlüssel %{key} gibt es nicht\n`fetch` besteht auf vorhandenen Schlüsseln. %{keys}",
      "en" => "The key %{key} doesn't exist\n`fetch` insists on keys that exist. %{keys}",
      "ja" => "キー %{key} は存在しません\n`fetch` は存在するキーしか受け付けません。%{keys}"
    },
    index_error: {
      "de" => "Position %{idx} gibt es nicht\nDie Liste hat nur %{size} Elemente – Positionen 0 bis %{last}.",
      "en" => "Position %{idx} doesn't exist\nThe list has only %{size} elements – positions 0 to %{last}.",
      "ja" => "%{idx}番目の要素はありません\nこの配列の要素は%{size}個だけで、位置は0から%{last}までです。"
    },
    stack: {
      "de" => "`%{meth}` ruft sich endlos selbst auf\nEine Methode, die sich selbst aufruft (Rekursion), braucht einen Fall, in dem sie aufhört – z. B. `return 1 if n <= 1` ganz oben.",
      "en" => "`%{meth}` calls itself forever\nA method that calls itself (recursion) needs a case where it stops – e.g. `return 1 if n <= 1` at the top.",
      "ja" => "`%{meth}` が自分自身を延々と呼び続けています\n自分自身を呼ぶメソッド（再帰）には、止まる条件が必要です。たとえば先頭に `return 1 if n <= 1` のように書きます。"
    },
    loop_var: {
      "de" => "Diese Schleife hört vielleicht nie auf\nDie `%{kw}`-Schleife in Zeile %{line} prüft `%{var}`, aber `%{var}` ändert sich darin nie. Mit ▶ würde sie laufen, bis die Seite hängt – zähl `%{var}` in der Schleife weiter, z. B. `%{var} += 1`.",
      "en" => "This loop may never stop\nThe `%{kw}` loop on line %{line} checks `%{var}`, but `%{var}` never changes inside it. With ▶ it would run until the page freezes – update `%{var}` inside the loop, e.g. `%{var} += 1`.",
      "ja" => "このループは終わらないかもしれません\n%{line}行目の `%{kw}` ループは `%{var}` を調べていますが、ループの中で `%{var}` が変わりません。▶ で実行するとページが固まるまで動き続けます。ループの中で `%{var} += 1` のように `%{var}` を更新してください。"
    },
    loop_no_break: {
      "de" => "Diese Schleife hört nie auf\n`loop do` in Zeile %{line} läuft, bis ein `break` kommt – und darin steht keins.",
      "en" => "This loop never stops\n`loop do` on line %{line} runs until it hits a `break` – and there is none inside.",
      "ja" => "このループは終わりません\n%{line}行目の `loop do` は `break` に出会うまで続きますが、中に `break` がありません。"
    },
    own_error: {
      "de" => "Dein eigener %{klass} wurde nicht aufgefangen\nIn Zeile %{line} wird `%{klass}` ausgelöst, und kein `rescue` fängt ihn. Pack den Aufruf in `begin` … `rescue %{klass}` … `end`.",
      "en" => "Your own %{klass} was not rescued\nOn line %{line}, `%{klass}` is raised and no `rescue` catches it. Wrap the call in `begin` … `rescue %{klass}` … `end`.",
      "ja" => "自分で定義した %{klass} が捕まえられていません\n%{line}行目で `%{klass}` が発生しましたが、それを受け止める `rescue` がありません。呼び出しを `begin` … `rescue %{klass}` … `end` で囲んでください。"
    },
    load_error: {
      "de" => "`%{name}` lässt sich nicht laden\nEs gibt keine Bibliothek namens `%{name}`. Stimmt die Schreibweise? Der Name im `require` ist nicht immer der Gem-Name (das Gem `chunky_png` lädt man mit `require \"chunky_png\"`, `pure_jpeg` mit `require \"pure_jpeg\"`).",
      "en" => "`%{name}` can't be loaded\nThere is no library called `%{name}`. Is it spelled right? The name in `require` is not always the gem's name.",
      "ja" => "`%{name}` を読み込めません\n`%{name}` というライブラリはありません。綴りは合っていますか？ `require` に書く名前は、gemの名前と同じとは限りません。"
    },

    # ---------------------------------------------------------- added after the first corpus run
    syn_times_x: {
      "de" => "Ruby multipliziert mit `*`\nSchreib `%{a} * %{b}` – das `x` liest Ruby als Namen.",
      "en" => "Ruby multiplies with `*`\nWrite `%{a} * %{b}` – Ruby reads the `x` as a name.",
      "ja" => "Rubyのかけ算は `*` です\n`%{a} * %{b}` と書いてください。`x` は名前として読まれてしまいます。"
    },
    str_numeric: {
      "de" => "`%{var}` ist Text, keine Zahl\n`%{var}` ist `%{value}` – die Anführungszeichen machen daraus einen String. Schreib die Zahl ohne Anführungszeichen (`%{var} = %{bare}`) oder wandle um: `%{var}.to_i %{op} %{operand}`.",
      "en" => "`%{var}` is text, not a number\n`%{var}` is `%{value}` – the quotes make it a String. Write the number without quotes (`%{var} = %{bare}`), or convert it: `%{var}.to_i %{op} %{operand}`.",
      "ja" => "`%{var}` は数値ではなく文字列です\n`%{var}` の値は `%{value}` です。引用符で囲むと文字列になります。引用符なしで `%{var} = %{bare}` と書くか、`%{var}.to_i %{op} %{operand}` のように変換してください。"
    },
    nil_hash_default: {
      "de" => "`%{expr}` ist beim ersten Mal nil\nEin leerer Hash hat für jeden neuen Schlüssel erst einmal nil – und mit nil kann `%{meth}` nicht rechnen. Gib dem Hash einen Startwert: `%{hash} = %{fix}`.",
      "en" => "`%{expr}` is nil the first time\nAn empty hash gives nil for every new key – and `%{meth}` can't work with nil. Give the hash a starting value: `%{hash} = %{fix}`.",
      "ja" => "最初は `%{expr}` が nil です\n空のハッシュは、新しいキーに対して nil を返します。nil に `%{meth}` は使えません。ハッシュに初期値を指定してください: `%{hash} = %{fix}`。"
    },
    nil_match: {
      "de" => "`%{var}` ist nil – das Muster hat nicht gepasst\n`match` gibt nil zurück, wenn der Text nicht zum Muster passt. Fang diesen Fall ab, bevor du `%{var}` benutzt: `return nil unless %{var}`.",
      "en" => "`%{var}` is nil – the pattern didn't match\n`match` returns nil when the text doesn't fit the pattern. Handle that case before using `%{var}`: `return nil unless %{var}`.",
      "ja" => "パターンに一致しなかったため、`%{var}` が nil です\n`match` は、文字列がパターンに合わないと nil を返します。`%{var}` を使う前に、その場合に備えてください: `return nil unless %{var}`。"
    },
    arity_lambda: {
      "de" => "`%{name}` will %{expected}, bekommt aber %{given}\nDas Lambda in Zeile %{def_line} nimmt %{expected}; der Aufruf in Zeile %{line} gibt %{given} mit. Lambdas sind da so streng wie Methoden.",
      "en" => "`%{name}` wants %{expected} but got %{given}\nThe lambda on line %{def_line} takes %{expected}; the call on line %{line} passes %{given}. Lambdas are as strict about this as methods.",
      "ja" => "`%{name}` には%{expected}が必要ですが、%{given}が渡されました\n%{def_line}行目のラムダは%{expected}を受け取ります。%{line}行目の呼び出しでは%{given}が渡されています。ラムダは、この点でメソッドと同じくらい厳密です。"
    },
    kw_positional: {
      "de" => "`%{meth}` will Schlüsselwörter, keine bloßen Werte\n`%{meth}` nimmt %{kws} – mit Namen. Schreib: `%{meth}(%{example})`.",
      "en" => "`%{meth}` wants keywords, not bare values\n`%{meth}` takes %{kws} – by name. Write: `%{meth}(%{example})`.",
      "ja" => "`%{meth}` には値だけでなくキーワードが必要です\n`%{meth}` は %{kws} を名前付きで受け取ります。`%{meth}(%{example})` と書いてください。"
    },
    w_main: { "de" => "Ruby", "en" => "Ruby", "ja" => "Ruby" },

    # ---------------------------------------------------------- labels
    lbl_nil: { "de" => "das ist nil", "en" => "this is nil", "ja" => "ここが nil です" },
    lbl_unknown: { "de" => "unbekannt", "en" => "unknown here", "ja" => "見つかりません" },
    lbl_open: { "de" => "hier geöffnet", "en" => "opened here", "ja" => "ここで開いています" },
    lbl_here: { "de" => "hier", "en" => "here", "ja" => "ここ" },
    lbl_call: { "de" => "dieser Aufruf", "en" => "this call", "ja" => "この呼び出し" },
    lbl_loop: { "de" => "ändert sich nie", "en" => "never changes", "ja" => "変わりません" },
    lbl_type: { "de" => "das ist %{klass}", "en" => "this is %{klass}", "ja" => "ここは %{klass} です" },

    # words used inside texts
    w_args: { "de" => ["kein Argument", "1 Argument", "%{n} Argumente"],
              "en" => ["no arguments", "1 argument", "%{n} arguments"],
              "ja" => ["引数なし", "引数1個", "引数%{n}個"] },
    w_or: { "de" => " oder ", "en" => " or ", "ja" => "または" },
    w_and: { "de" => " und ", "en" => " and ", "ja" => "と" },
    w_min_args: { "de" => "mindestens %{n}", "en" => "at least %{n}", "ja" => "%{n}以上" },
    w_other: { "de" => { "Integer" => "Zahlen", "Float" => "Kommazahlen", "NilClass" => "nil", "Array" => "Arrays", "Hash" => "Hashes", "Symbol" => "Symbole" },
               "en" => { "Integer" => "numbers", "Float" => "numbers", "NilClass" => "nil", "Array" => "arrays", "Hash" => "hashes", "Symbol" => "symbols" },
               "ja" => { "Integer" => "数値", "Float" => "数値", "NilClass" => "nil", "Array" => "配列", "Hash" => "ハッシュ", "Symbol" => "シンボル" } },
    w_other_a: { "de" => { "Integer" => "eine Zahl", "Float" => "eine Kommazahl", "NilClass" => "nil", "Array" => "ein Array", "Hash" => "einen Hash", "Symbol" => "ein Symbol" },
                 "en" => { "Integer" => "a number", "Float" => "a number", "NilClass" => "nil", "Array" => "an array", "Hash" => "a hash", "Symbol" => "a symbol" },
                 "ja" => {} },
    w_article: { "de" => "ein", "en" => "a", "ja" => "" },
    w_owner: { "de" => { "String" => "Strings", "Array" => "Arrays", "Hash" => "Hashes", "Integer" => "Zahlen", "Float" => "Zahlen" },
               "en" => { "String" => "strings", "Array" => "arrays", "Hash" => "hashes", "Integer" => "numbers", "Float" => "numbers" },
               "ja" => { "String" => "String", "Array" => "Array", "Hash" => "Hash", "Integer" => "Integer", "Float" => "Float" } },
    w_original: { "de" => "Rubys Meldung", "en" => "Ruby's message", "ja" => "Rubyのメッセージ" }
  }.freeze
end
