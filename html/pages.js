// Language for the pages around the course (welcome.html and the legal
// pages): ?lang=en in the address, else the course's stored choice
// ("chunky_lang", written by shell/app.rb), else the browser's. A page
// without Japanese text (the legal pages) shows Japanese learners English.
(function () {
  "use strict";
  var hasJa = !!document.querySelector('[data-l="ja"]');
  var SUPPORTED = hasJa ? ["de", "en", "ja"] : ["de", "en"];

  function stored() {
    try {
      var v = window.localStorage.getItem("chunky_lang");
      return v ? v.replace(/"/g, "") : null;
    } catch (e) { return null; }
  }

  function pick() {
    var q = new URLSearchParams(location.search).get("lang");
    var want = q || stored() || (navigator.language || "de").slice(0, 2);
    if (want === "ja" && !hasJa) want = "en";
    return SUPPORTED.indexOf(want) >= 0 ? want : "de";
  }

  function set(lang) {
    document.documentElement.lang = lang;
    var title = document.querySelector("title[data-" + lang + "]");
    if (title) document.title = title.getAttribute("data-" + lang);
    relink();
  }

  // Links to the course ("learn" in the HTML) open it in the language read
  // here - at index.html on a static host without /learn (welcome.html asks).
  var course = "learn";
  function relink() {
    var lang = document.documentElement.lang;
    document.querySelectorAll("a[data-href], a[href^=\"learn\"]").forEach(function (a) {
      var href = a.getAttribute("data-href") || a.getAttribute("href");
      a.setAttribute("data-href", href);
      var hash = href.split("#")[1];
      a.setAttribute("href", course + "?lang=" + lang + (hash ? "#" + hash : ""));
    });
  }

  set(pick());
  if (window.chunkyCourse) window.chunkyCourse.then(function (c) { course = c; relink(); });
  document.addEventListener("click", function (e) {
    var b = e.target.closest("[data-set]");
    if (!b) return;
    set(b.getAttribute("data-set"));
    var url = new URL(location.href);
    url.searchParams.set("lang", b.getAttribute("data-set"));
    history.replaceState(null, "", url);
  });
})();
