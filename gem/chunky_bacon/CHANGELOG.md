# Changelog

## Unreleased

- `show_plot` / `show_plot fig`, as in the course's matplotlib lesson: the
  current (or that) matplotlib figure, through the pycall gem, saved as
  `chunky-plot-N.png`, opened and closed.

## 0.1.3

- `show_image` takes JPEGs, as the course's lesson 22 (pure_jpeg) makes
  them: what `PureJPEG.encode` returns (anything with `to_bytes`), and the
  bytes of a JPEG, GIF or WebP, saved with their own extension.

## 0.1.2

- The homepage is the course itself, https://chunkybacon.idogawa.com (also
  in the README, the license notes and `chunkybacon help`); the source stays
  on GitHub. The aliases `chunkybacon` and `chunky-bacon` 0.1.1 link it too.

## 0.1.1

- The course is named by its English title, "Learn Ruby with Chunky Bacon",
  in the gem's description, README and license notes.
- The course's lesson 13 now starts with `install_gem "chunky_bacon"`.

## 0.1.0

- The course's helpers on a computer: `install_gem`, `show_image`,
  `show_pdf`, `download_file`, `show_browser` (with a small built-in server),
  `mock_get`, `show_irb`, `show_files`, `run_tests`; `show_three` and
  `show_shoes` explain what to do instead.
- `chunkybacon` shows Chunky; `chunkybacon run [FILE]` runs a program with
  the helpers loaded.
- In the course page (ruby.wasm) the page's own helpers stay.
- Code MIT; the fox drawing (`lib/chunky_bacon/fox.txt`) CC BY-SA 4.0.
- Also installable as `chunkybacon` and `chunky-bacon` (alias gems).
