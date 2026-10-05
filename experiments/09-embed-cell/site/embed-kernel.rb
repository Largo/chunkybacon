# What the course's kernel (main.rb) does differently in an embedded cell.
# embed-frame.js evaluates this once ChunkyApp is up, before the first run.
class ChunkyApp
  # The course keeps a cell's code in localStorage (chunky_cell_<lang>_<id>_<n>).
  # An embed keeps nothing: its code lives in the address. In the sandboxed
  # embed there is no localStorage at all - touching it raises SecurityError.
  def store(_key, _value) = nil
end
