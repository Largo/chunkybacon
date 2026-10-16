# What the page keeps in localStorage. storage.js times every chunky_* key
# and carries it into a progress file or a connected folder. A cell's code
# is saved when the kernel (main.rb) runs it, through App#save_code.
require 'json'

module ChunkyShell
  module Store
    CODE_PREFIX = "chunky_cell_"
    # the key a cell's code had before fingerprints: chunky_cell_<lang>_<id>_<idx>
    LEGACY_CODE_KEY = /^chunky_cell_([a-z]+)_(.+)_([0-9]+)$/
    # Where the code cells of the lessons from before fingerprints sit now:
    # id => { old index => index now }, the same in de, en and ja. The
    # show_objects demos went in before the exercises of arrays, hashes and
    # klassen (2026-10), then new demo cells before the exercises of most
    # lessons (2026-10-16). A change that moves code cells again updates
    # this table: node tools/legacy_cell_moves.js prints it (and
    # test/shell/course_store_view_test.rb checks it); a lesson not in it
    # kept its indices.
    LEGACY_MOVES = {
      "hallo" => { 5 => 7 },
      "rechnen" => { 5 => 13 },
      "variablen" => { 5 => 9 },
      "strings" => { 5 => 13 },
      "wenn" => { 3 => 13 },
      "schleifen" => { 5 => 13 },
      "arrays" => { 7 => 16 },
      "hashes" => { 3 => 14 },
      "methoden" => { 6 => 11 },
      "klassen" => { 3 => 12 },
      "module" => { 8 => 12 },
      "html" => { 7 => 13 },
      "bigdecimal" => { 9 => 11 },
      "tl-mixins" => { 3 => 5 },
      "tl-cli" => { 4 => 5 },
      "tl-pattern" => { 5 => 7 },
      "tl-meta" => { 5 => 7 },
      "tl-quality" => { 3 => 5 }
    }.freeze

    def self.get(key, default = "")
      value = JSG.w.localStorage.getItem(key)
      value.nil? || value == "" || value == "null" ? default : value
    end

    def self.set(key, value) = JSG.w.localStorage.setItem(key, value)
    def self.remove(key) = JSG.w.localStorage.removeItem(key)

    # A cell's saved code: chunky_cell_<lang>_<id>_<idx>@<fingerprint of the
    # cell's starter code>. When a lesson's cells change - cells inserted
    # before this one, its starter rewritten - the cell now at idx has
    # another fingerprint and opens with its starter; what was saved for
    # the old cell stays in storage, unused, instead of landing in the
    # wrong cell.
    def self.code_key(lang, id, idx, starter) = "#{CODE_PREFIX}#{lang}_#{id}_#{idx}@#{fingerprint(starter)}"

    # A polynomial hash of the bytes, mod 2^31 - 1, in base 36 (at most six
    # characters). PicoRuby has each_byte (probed); the numbers stay well
    # inside its 64-bit Integer.
    def self.fingerprint(code)
      hash = 0
      code.to_s.each_byte { |byte| hash = (hash * 31 + byte) % 2_147_483_647 }
      hash.to_s(36)
    end

    # Saved code under a key without a fingerprint - this browser's from
    # before, or one that an old progress file or a folder brings in - moves
    # to the fingerprinted key of the cell it was saved for (LEGACY_MOVES).
    # Where that key exists already, the newer of the two stays (storage.js's
    # change times). The old key is removed, so storage.js sends its removal
    # along and an old copy cannot bring it back. A key this course has no
    # cell for stays as it is.
    def self.migrate_code_keys(course)
      legacy = JSG.w.Object.keys(JSG.w.localStorage).to_a.select do |key|
        key.start_with?(CODE_PREFIX) && !key.include?("@")
      end
      return if legacy.empty?

      times = change_times
      legacy.each do |key|
        target = legacy_target(course, key)
        next if target.nil?

        code = JSG.w.localStorage.getItem(key)
        set(target, code) if JSG.w.localStorage.getItem(target).nil? || changed_at(times, key) > changed_at(times, target)
        remove(key)
      end
    end

    # the fingerprinted key a key without one belongs to, or nil
    def self.legacy_target(course, key)
      m = key.match(LEGACY_CODE_KEY)
      return nil if m.nil? || !course.lang?(m[1])

      id = m[2]
      lesson = course.index(id)
      return nil if lesson.nil?

      idx = m[3].to_i
      moves = LEGACY_MOVES[id]
      idx = moves[idx] || idx if moves
      cell = course.cells(lesson, m[1])[idx]
      return nil if cell.nil? || !%w[c x].include?(cell.t)

      code_key(m[1], id, idx, cell.code)
    end

    # storage.js's change times (key => ms since 1970), nil if unreadable
    def self.change_times
      times = JSG.w.JSON.parse(get("chunkysync_times", "{}"))
      times.is_a?(JS::Object) ? times : nil
    rescue StandardError
      nil
    end

    def self.changed_at(times, key)
      time = times.nil? ? nil : times[key]
      time.nil? ? 0 : time
    end

    # finished lesson ids; JavaScript parses (PicoRuby's JSON.parse is slow)
    def self.done_ids
      list = JSG.w.JSON.parse(get("chunky_done", "[]"))
      list.is_a?(JS::Object) ? list.to_a : []
    rescue StandardError
      []
    end

    def self.mark_done(id)
      ids = done_ids
      return if ids.include?(id)

      ids << id
      set("chunky_done", JSON.generate(ids))
    end
  end
end
