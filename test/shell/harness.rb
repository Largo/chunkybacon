# Loads the page shell (html/shell/, the files and order of manifest.txt -
# exactly what shell/loader.js hands PicoRuby) under CRuby, on the `js`
# stub in stubs/js.rb. SHELL_DIR points it at another copy of the shell
# (tools/shell_metrics.rb tests its desugared variant that way).
require "minitest/autorun"

LESSONS_JSON = File.expand_path("../lessons.json", __dir__)
abort "test/lessons.json is missing - run: node test/make_lessons_json.js" unless File.file?(LESSONS_JSON)

$LOAD_PATH.unshift(File.expand_path("stubs", __dir__))
require "js"

SHELL_DIR = ENV.fetch("SHELL_DIR", File.expand_path("../../html/shell", __dir__))
SHELL_FILES = File.readlines(File.join(SHELL_DIR, "manifest.txt"), chomp: true)
                  .map(&:strip).reject { |line| line.empty? || line.start_with?("#") }
SHELL_FILES.each { |file| load File.join(SHELL_DIR, file) }

# A fresh page for every test: DOM from index.html, empty localStorage,
# the course from test/lessons.json, a recording ChunkyBridge.
module ShellTest
  def fresh_page(hash: "", storage: {})
    JS.reset!
    window.location["hash"] = hash
    window.storage.merge!(storage)
    JS.console_errors.clear
  end

  def window = JS.window.__target
  def doc = window.document_node
  def byid(id) = doc.js_getElementById(id)
  def find(selector) = doc.js_querySelector(selector)
  def find_all(selector) = doc.js_querySelectorAll(selector).js_list
  def calls(name) = window.calls.select { |c| c.first == name }
  def bubble = byid("chunkyText").text
  def bubble_state = byid("chunkyChat").attrs["class"]

  def start(hash: "", storage: {})
    fresh_page(hash: hash, storage: storage)
    ChunkyShell::App.new.start
  end

  def click(node, **fields)
    event = { "target" => node }.merge(fields.transform_keys(&:to_s))
    prevented = false
    node_and_up(node).each do |target|
      prevented |= JS.fire(target.wrap, "click", event)
    end
    prevented
  end

  # the shell listens on containers (delegation): an event bubbles up
  def node_and_up(node)
    list = []
    while node
      list << node
      node = node.parent
    end
    list << window
  end

  def fire(type, detail = {})
    JS.fire(JS.window, type, "detail" => detail)
  end
end
