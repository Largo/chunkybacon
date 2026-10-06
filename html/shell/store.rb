# What the page keeps in localStorage. storage.js times every chunky_* key
# and carries it into a progress file or a connected folder. A cell's code
# is saved when the kernel (main.rb) runs it, through App#save_code.
require 'json'

module ChunkyShell
  module Store
    CODE_PREFIX = "chunky_cell_"
    # the key a cell's code had before fingerprints: chunky_cell_<lang>_<id>_<idx>
    LEGACY_CODE_KEY = /^chunky_cell_([a-z]+)_(.+)_([0-9]+)$/
    # Lessons whose cells moved while the keys had no fingerprint: id =>
    # [the first old index that moved, by how many]. The show_objects demo
    # and its prose went in before the exercise, in de, en and ja alike
    # (2026-10). A later change to a lesson's cells needs no entry here.
    LEGACY_SHIFTS = { "arrays" => [7, 2], "hashes" => [3, 2], "klassen" => [3, 2] }.freeze

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
    # to the fingerprinted key of the cell it was saved for (LEGACY_SHIFTS).
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
      shift = LEGACY_SHIFTS[id]
      idx += shift[1] if shift && idx >= shift[0]
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
