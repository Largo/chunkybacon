// Copy of test/make_lessons_json.js that writes into this experiment folder
// (lessons.json here, not in test/), so the shared tree stays untouched.
const fs = require("fs");
const path = require("path");

global.window = {};
require(path.join(__dirname, "..", "..", "html", "lessons.js"));
fs.writeFileSync(path.join(__dirname, "lessons.json"), window.LESSONS_JSON);
console.log("wrote lessons.json (" + window.LESSONS_JSON.length + " chars)");
