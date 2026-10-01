# frozen_string_literal: true

require "test_helper"
require "net/http"

class ServerTest < Minitest::Test
  include InTmpDir

  APP = lambda do |env|
    case env["PATH_INFO"]
    when "/" then [200, { "content-type" => "text/html" }, ["<h1>Chunkys Imbiss</h1>"]]
    when "/echo" then [201, { "x-method" => env["REQUEST_METHOD"] }, [env["rack.input"].read]]
    when "/kaputt" then raise ArgumentError, "kein Speck"
    else [404, {}, ["nicht da"]]
    end
  end

  def setup
    super
    @server = ChunkyBacon::Server.new(APP).start
  end

  def teardown
    @server.stop
    super
  end

  def test_serves_the_app_on_this_computer_only
    assert_match %r{\Ahttp://127\.0\.0\.1:\d+/\z}, @server.url
    response = Net::HTTP.get_response(URI(@server.url))
    assert_equal "200", response.code
    assert_equal "<h1>Chunkys Imbiss</h1>", response.body
    assert_equal "text/html", response["content-type"]
  end

  def test_hands_over_method_and_body
    response = Net::HTTP.post(URI(@server.url("/echo")), "speck=3", "content-type" => "application/x-www-form-urlencoded")
    assert_equal "201", response.code
    assert_equal "POST", response["x-method"]
    assert_equal "speck=3", response.body
  end

  def test_an_error_in_the_app_is_a_500_that_names_it
    response = nil
    _, err = capture_io { response = Net::HTTP.get_response(URI(@server.url("/kaputt"))) }
    assert_equal "500", response.code
    assert_includes response.body, "ArgumentError: kein Speck"
    assert_includes err, "kein Speck"
  end

  def test_unknown_paths_are_the_apps_404
    assert_equal "404", Net::HTTP.get_response(URI(@server.url("/weg"))).code
  end

  def test_show_browser_starts_a_server_and_names_its_address
    before = ChunkyBacon.servers.size
    _, err = capture_io { assert_nil show_browser(APP, "/") }
    server = ChunkyBacon.servers.last
    assert_equal before + 1, ChunkyBacon.servers.size
    assert_includes err, server.url("/")
    assert_equal "200", Net::HTTP.get_response(URI(server.url)).code
  ensure
    ChunkyBacon.servers.pop&.stop if ChunkyBacon.servers.size > before.to_i
  end
end
