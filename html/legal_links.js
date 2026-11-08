// The operator's legal pages (impressum.html, datenschutz.html) are not in
// the repository: each deployment writes its own from the *.example.html
// templates (README, "Legal pages"). A link to one that this deployment does
// not have is hidden - with its separator, when it sits in a span.legal - so
// a fork never shows a dead link. Asked once per page load, then applied to
// every link that appears later (the course footer is redrawn per language).
(function () {
  "use strict";
  var PAGES = ["impressum.html", "datenschutz.html"];
  var missing = {};

  function apply(root) {
    PAGES.forEach(function (page) {
      if (!missing[page]) return;
      root.querySelectorAll('a[href="' + page + '"]').forEach(function (a) {
        (a.closest(".legal") || a).hidden = true;
      });
    });
  }

  Promise.all(PAGES.map(function (page) {
    return fetch(page, { method: "HEAD", cache: "no-cache" })
      .then(function (r) { if (!r.ok) missing[page] = true; })
      .catch(function () { missing[page] = true; });
  })).then(function () {
    apply(document);
    var footer = document.getElementById("footerLicense");
    if (footer) new MutationObserver(function () { apply(footer); }).observe(footer, { childList: true });
  });
})();
