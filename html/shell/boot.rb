# Last in the manifest: the page comes up. shell/loader.js adds the shell
# once the document is parsed, so it normally starts right away; the unit
# tests' stub document says "loading" and starts it when they choose.
module ChunkyShell
  def self.boot
    $shell = App.new.start
  rescue StandardError => e
    JS.global[:console].error("shell failed to start: #{e.class}: #{e.message}")
  end
end

if JS.document[:readyState] == "loading"
  JS.document.addEventListener("DOMContentLoaded") { ChunkyShell.boot }
else
  ChunkyShell.boot
end
