# What the page keeps in localStorage. storage.js times every chunky_* key
# and carries it into a progress file or a connected folder. The kernel
# (main.rb) writes the cells' code keys itself when it runs them.
require 'json'

module ChunkyShell
  module Store
    def self.get(key, default = "")
      value = JSG.w.localStorage.getItem(key)
      value.nil? || value == "" || value == "null" ? default : value
    end

    def self.set(key, value) = JSG.w.localStorage.setItem(key, value)
    def self.remove(key) = JSG.w.localStorage.removeItem(key)
    def self.code_key(lang, id, idx) = "chunky_cell_#{lang}_#{id}_#{idx}"

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
