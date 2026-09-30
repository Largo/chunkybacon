// Starts the page shell: the Ruby files named in shell/manifest.txt, joined
// in that order into ONE <script type="text/picoruby"> (PicoRuby runs every
// script tag as a task of its own, concurrently - one tag means every
// definition exists before boot.rb uses it), then the PicoRuby runtime,
// whose loader is patched to read text/picoruby (tools/patch_picoruby_loader.rb)
// so it leaves main.rb (text/ruby) to CRuby. index.html preloads the
// runtime meanwhile.
(function () {
  "use strict";

  function get(path) {
    // no-cache: revalidate, so a deploy is seen on the next load
    return fetch("shell/" + path, { cache: "no-cache" }).then(function (response) {
      if (!response.ok) throw new Error(path + ": HTTP " + response.status);
      return response.text();
    });
  }

  get("manifest.txt").then(function (manifest) {
    var files = manifest.split("\n").map(function (line) { return line.trim(); })
      .filter(function (line) { return line !== "" && line.charAt(0) !== "#"; });
    return Promise.all(files.map(get)).then(function (sources) {
      var ruby = document.createElement("script");
      ruby.type = "text/picoruby";
      ruby.textContent = sources.map(function (source, i) {
        return "# ---- shell/" + files[i] + "\n" + source;
      }).join("\n");
      document.body.appendChild(ruby);
      var runtime = document.createElement("script");
      runtime.src = "assets/picoruby/init.iife.js";
      document.body.appendChild(runtime);
    });
  }).catch(function (error) {
    console.error("the page shell could not be loaded:", error);
    var text = document.getElementById("spinnerText");
    if (text) text.textContent = String(error);
  });
})();
