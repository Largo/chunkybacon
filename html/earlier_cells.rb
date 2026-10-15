# The cells above: all cells of a lesson share one binding, so a cell needs
# what the cells above it defined - variables, methods, classes, required
# gems. A learner who opens a lesson and runs its fourth cell first would
# get a NameError for every name the first three make. So ▶ (and ⏯, and a
# live run) first runs, quietly and top to bottom, the cells above that have
# not run in this binding yet with the code they show now; main.rb's
# run_cell does that, the shell says which ran (shell/app.rb). docs/HANDOVER.md
# §6p.
#
# - "Ran" means: run for real, with ▶, ⏯ or as one of these, in this
#   binding (a new lesson, a language switch and a reset make a new one),
#   without an error. A live run is a rehearsal and records nothing; a cell
#   that failed runs again next time.
# - A cell edited after it ran counts as not run: its new code runs.
# - The exercise, while it still holds its starter code, is left out: there
#   is nothing of the learner's in it yet, a starter is meant to fail, and
#   demo cells never use the exercise's names (they differ on purpose).
module EarlierCells
  module_function

  # [[index, code], ...] of the code cells above +idx+ to run first, in
  # order. +cells+: the lesson's cells (lessons.js: "t", "code"); +ran+:
  # index => the code that ran; the block gives a cell's code as its editor
  # shows it now.
  def before(idx, cells, ran)
    list = []
    cells.each_with_index do |cell, i|
      break if i >= idx
      next unless cell["t"] == "c" || cell["t"] == "x"

      code = yield(i).to_s
      next if ran[i] == code
      next if cell["t"] == "x" && starter?(cell, code)

      list << [i, code]
    end
    list
  end

  # the exercise as the lesson gave it, up to blank lines and indentation
  def starter?(cell, code)
    squeeze(code) == squeeze(cell["code"])
  end

  def squeeze(code) = code.to_s.lines.map(&:strip).reject(&:empty?).join("\n")
end
