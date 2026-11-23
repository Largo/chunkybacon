# SimThread (html/sandbox_sim.rb): the browser's threads, fibers taking
# turns at sleep. It only loads where JS is defined, and it replaces
# Thread, so each case runs in a Ruby of its own with a stand-in JS.
require "minitest/autorun"
require "open3"
require "rbconfig"

class SimThreadTest < Minitest::Test
  SIM = File.expand_path("../html/sandbox_sim.rb", __dir__)

  def sim(code)
    script = "JS = Module.new\nrequire #{SIM.dump}\nabort 'no SimThread' unless Thread == SimThread\n#{code}"
    out, err, status = Open3.capture3(RbConfig.ruby, "-e", script)
    assert status.success?, err
    out
  end

  def test_threads_take_turns_at_sleep_and_lose_updates_without_a_lock
    assert_equal "5\n", sim(<<~RUBY)
      count = 0
      3.times.map { Thread.new { 5.times { c = count; sleep 0.01; count = c + 1 } } }.each(&:join)
      p count
    RUBY
  end

  def test_a_mutex_makes_the_others_wait_their_turn
    assert_equal "15\n1\n", sim(<<~RUBY)
      m = Mutex.new
      count = 0
      3.times.map { Thread.new { 5.times { m.synchronize { c = count; sleep 0.01; count = c + 1 } } } }.each(&:join)
      p count
      p Thread.new { m.lock; m.unlock; 1 }.value
    RUBY
  end

  def test_pop_waits_for_a_push_or_close
    assert_equal "[0, 1, 2]\n6\n", sim(<<~RUBY)
      q = Queue.new
      Thread.new { 3.times { |i| sleep 0.1; q << i }; q.close }
      got = []
      while (x = q.pop); got << x; end
      p got
      jobs = Queue.new
      6.times { |i| jobs << i }
      jobs.close
      done = Queue.new
      3.times.map { |w| Thread.new { while (j = jobs.pop); sleep 0.05; done << [w, j]; end } }.each(&:join)
      p done.size
    RUBY
  end

  def test_a_thread_can_join_another
    assert_equal ":inner\n", sim(<<~RUBY)
      p Thread.new { Thread.new { sleep 0.2; :inner }.value }.value
    RUBY
  end

  def test_waiting_with_nobody_left_to_wake_it_is_a_deadlock
    assert_equal "ThreadError: No live threads left. Deadlock?\n", sim(<<~RUBY)
      begin
        Queue.new.pop
      rescue ThreadError => e
        puts "ThreadError: \#{e.message}"
      end
    RUBY
  end
end
