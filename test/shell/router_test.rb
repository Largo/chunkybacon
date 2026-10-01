require_relative "harness"

# Addresses: /#methoden on a static host, /de/methoden when server/app.rb
# serves the page with permalinks (ChunkyBridge.permalinks, the base path).
class RouterTest < Minitest::Test
  include ShellTest

  def nav_href(id) = find("#lessonNav a[data-id='#{id}']").attrs["href"]
  def active_id = find("#lessonNav a.active")&.attrs&.fetch("data-id")
  def pathname = window.location["pathname"]

  # the page at +path+ (and +hash+), served with permalinks
  def start_at(path, hash: "", lang: "de", storage: {})
    start(hash: hash, storage: storage) do
      window.props["ChunkyBridge"]["permalinks"] = "/"
      window.props["ChunkyBridge"]["lang"] = lang
      window.location["pathname"] = path
    end
  end

  def test_links_and_places_in_both_kinds_of_address
    plain = ChunkyShell::Router.new(nil)
    refute plain.permalinks?
    assert_equal "#methoden", plain.href("de", "methoden")
    served = ChunkyShell::Router.new("/")
    assert served.permalinks?
    assert_equal "/de/", served.prefix("de")
    assert_equal "/en/werkstatt", served.href("en", "werkstatt")
  end

  def test_a_permalink_opens_its_lesson
    start_at("/de/methoden")
    assert_equal "methoden", active_id
    assert_equal "/de/methoden", pathname
    assert_equal "", window.location["hash"]
    assert_equal "/de/klassen", nav_href("klassen")
    assert_equal "/de/werkstatt", byid("workshopLink").attrs["href"]
    assert_empty calls("pushState")
    assert_empty JS.console_errors
  end

  def test_a_bare_address_gets_the_lesson_the_learner_left_off_at
    start_at("/", storage: { "chunky_current" => "arrays" })
    assert_equal "arrays", active_id
    assert_equal "/de/arrays", pathname
    assert_empty calls("pushState"), "no history entry"
  end

  def test_a_lesson_opened_from_a_link_is_where_the_learner_left_off
    start_at("/de/klassen")
    assert_equal "klassen", window.storage["chunky_current"]
    start(hash: "#hashes")
    assert_equal "hashes", window.storage["chunky_current"], "on a static host too"
  end

  def test_an_old_hash_link_becomes_a_permalink
    start_at("/", hash: "#klassen")
    assert_equal "klassen", active_id
    assert_equal "/de/klassen", pathname
    assert_equal "", window.location["hash"]
  end

  def test_choosing_a_lesson_adds_a_history_entry
    start_at("/de/methoden")
    click(find("#lessonNav a[data-id='klassen']"))
    assert_equal [["pushState", "/de/klassen"]], calls("pushState")
    assert_equal "/de/klassen", pathname
    assert_equal "", window.location["hash"], "no hash on the way"
  end

  def test_back_and_forward_follow_the_path
    start_at("/de/methoden")
    window.location["pathname"] = "/de/hashes"
    JS.fire(JS.window, "popstate")
    assert_equal "hashes", active_id
    assert_empty calls("pushState"), "back does not add an entry"
  end

  def test_switching_the_language_changes_the_path
    start_at("/de/methoden")
    byid("langSelect").props["value"] = "en"
    JS.fire(byid("langSelect").wrap, "change")
    assert_equal "/en/methoden", pathname
    assert_equal "/en/klassen", nav_href("klassen")
    assert_empty calls("pushState"), "the same lesson, so no new entry"
  end

  def test_the_workshop_has_a_permalink_too
    start_at("/de/methoden")
    assert click(byid("workshopLink")), "a plain click stays on the page"
    assert_equal [["pushState", "/de/werkstatt"]], calls("pushState")
    assert_includes doc.js_get("body").attrs["class"], "in-workshop"
    window.calls.clear
    start_at("/de/werkstatt")
    assert_includes doc.js_get("body").attrs["class"], "in-workshop"
  end

  def test_the_next_lesson_link_is_a_permalink
    start_at("/de/hallo")
    idx = find(".cell.exercise .run-cell").attrs["data-idx"].to_i
    fire("chunky:ran", { "idx" => idx, "outcome" => "pass", "elapsed" => 0.2, "auto" => false, "own" => 0.2 })
    assert_equal "/de/rechnen", byid("nextLessonLink").attrs["href"]
  end

  def test_without_permalinks_everything_stays_on_the_hash
    start(hash: "#methoden")
    assert_equal "#klassen", nav_href("klassen")
    assert_equal "#werkstatt", byid("workshopLink").attrs["href"]
    click(find("#lessonNav a[data-id='klassen']"))
    assert_equal "klassen", window.location["hash"].delete_prefix("#")
    assert_equal "/", pathname
    assert_empty calls("pushState")
  end
end
