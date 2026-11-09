// Language for the pages around the course (welcome.html and the legal
// pages): ?lang=en in the address, else the course's stored choice
// ("chunky_lang", written by shell/app.rb), else the browser's
// (navigator.languages, first one this page has: fr-CH -> fr). German and
// English are on every page; Japanese, French and Italian only where the
// page has them - a page without them (the legal pages) shows those
// learners English.
(function () {
  "use strict";
  var OPTIONAL = ["ja", "fr", "it"];
  var SUPPORTED = ["de", "en"].concat(OPTIONAL.filter(function (l) {
    return !!document.querySelector('[data-l="' + l + '"]');
  }));

  function stored() {
    try {
      var v = window.localStorage.getItem("chunky_lang");
      return v ? v.replace(/"/g, "") : null;
    } catch (e) { return null; }
  }

  // the browser's languages in order of preference: the first this page
  // has; else English when one of them is a course language this page
  // lacks; else German
  function browser() {
    var list = (navigator.languages && navigator.languages.length) ? navigator.languages : [navigator.language || "de"];
    var codes = Array.prototype.map.call(list, function (l) { return String(l).slice(0, 2).toLowerCase(); });
    for (var i = 0; i < codes.length; i++) if (SUPPORTED.indexOf(codes[i]) >= 0) return codes[i];
    for (var j = 0; j < codes.length; j++) if (OPTIONAL.indexOf(codes[j]) >= 0) return "en";
    return "de";
  }

  function pick() {
    var want = new URLSearchParams(location.search).get("lang") || stored();
    if (!want) return browser();
    want = want.slice(0, 2).toLowerCase();
    if (OPTIONAL.indexOf(want) >= 0 && SUPPORTED.indexOf(want) < 0) want = "en";
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
