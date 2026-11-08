// Language for the pages around the course (welcome.html and the legal
// pages): ?lang=en in the address, else the course's stored choice
// ("chunky_lang", written by shell/app.rb), else the browser's. Japanese
// learners get English here until these pages are translated.
(function () {
  "use strict";
  var SUPPORTED = ["de", "en"];

  function stored() {
    try {
      var v = window.localStorage.getItem("chunky_lang");
      return v ? v.replace(/"/g, "") : null;
    } catch (e) { return null; }
  }

  function pick() {
    var q = new URLSearchParams(location.search).get("lang");
    var want = q || stored() || (navigator.language || "de").slice(0, 2);
    if (want === "ja") want = "en";
    return SUPPORTED.indexOf(want) >= 0 ? want : "de";
  }

  function set(lang) {
    document.documentElement.lang = lang;
    var title = document.querySelector("title[data-" + lang + "]");
    if (title) document.title = title.getAttribute("data-" + lang);
  }

  set(pick());
  document.addEventListener("click", function (e) {
    var b = e.target.closest("[data-set]");
    if (!b) return;
    set(b.getAttribute("data-set"));
    var url = new URL(location.href);
    url.searchParams.set("lang", b.getAttribute("data-set"));
    history.replaceState(null, "", url);
  });
})();
