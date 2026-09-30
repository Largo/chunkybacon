// Writes test/lessons.json (gitignored) from html/lessons.js, for the CRuby
// harnesses (check_harness.rb, gems_harness.rb) and the shell's unit tests
// (test/shell/). The same as the node -e line in the README, as a file.
//   node test/make_lessons_json.js
const fs = require("fs");
const path = require("path");

global.window = {};
require(path.join(__dirname, "..", "html", "lessons.js"));
fs.writeFileSync(path.join(__dirname, "lessons.json"), window.LESSONS_JSON);
console.log("wrote test/lessons.json (" + window.LESSONS_JSON.length + " chars)");
