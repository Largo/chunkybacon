# chunky_bacon

The companion gem of **[Ruby lernen mit Chunky Bacon](https://github.com/Largo/chunkybacon)**,
an interactive Ruby course that runs in the browser.

In the course, notebook cells and the workshop have helpers like `show_image`,
`show_browser` and `download_file`. This gem gives your own computer the same
helpers, so a program you wrote in the course runs unchanged with plain Ruby.

```sh
gem install chunky_bacon     # or: gem install chunkybacon - the same gem
chunkybacon                  # Chunky shouts
chunkybacon run              # runs main.rb with the helpers loaded
chunkybacon run spiel.rb     # ... or another file
```

In your own code:

```ruby
require "chunky_bacon"

require "chunky_png"
image = ChunkyPNG::Image.new(64, 64, ChunkyPNG::Color.rgb(232, 114, 42))
show_image image             # saves chunky-image-1.png and opens it
```

## The helpers

What the course page showed below the cell becomes a file in the program's
folder, opened in your system's viewer. Status lines go to stderr, so they
never mix with your program's output.

| Helper | On your computer |
|---|---|
| `install_gem "name"` | installs the gem unless it is there, and activates it |
| `show_image image` | saves `chunky-image-N.png` (ChunkyPNG image, PNG bytes or a path) and opens it |
| `show_pdf pdf` | saves `chunky-document-N.pdf` (Prawn/HexaPDF document, bytes or a path) and opens it |
| `download_file data, "name"` | saves the data as `name` in the program's folder |
| `show_browser App, "/path"` | starts the Rack app (Sinatra, Roda, ...) on 127.0.0.1 and opens it; after the program's last line the server runs on until Ctrl+C |
| `mock_get App, "/path"` | `[status, body]` without any server |
| `show_irb` | an IRB session; `exit` returns to the program |
| `show_files` | lists the files in the program's folder |
| `run_tests` | runs the Minitest tests defined so far |
| `show_three`, `show_shoes` | explain how to do it on a computer (they need the course page for now) |

`CHUNKYBACON_OPEN=0` stops the viewer and the browser from opening (CI, a
machine without a desktop); the files are saved either way. Inside the course
page the gem keeps the page's own helpers and only adds the fox.

## License

The code is MIT ([LICENSE](LICENSE)). The drawing of Chunky, the fox
(`lib/chunky_bacon/fox.txt`), is CC BY-SA 4.0 like the course's other content
([LICENSE-ASSETS](LICENSE-ASSETS)). The course's lesson texts are not part of
this gem.
