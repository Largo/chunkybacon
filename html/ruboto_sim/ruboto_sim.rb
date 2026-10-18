# The simulated phone of the Ruboto lesson (docs/HANDOVER.md §6u): the part
# of Ruboto and of Android that has to be Ruby. Loaded once into the JRuby
# worker (jruby_worker.js), after jruby_lab.rb.
#
# On a phone, Ruboto's Java classes (RubotoActivity, ScriptLoader) load an
# activity's script and forward every Android callback to Ruby. Here the
# Android classes are Java stand-ins compiled into the JRuby build
# (org.chunkybacon.sim.Device and android.*), and this file plays
# ScriptLoader and Android's activity manager: it binds the script's class to
# a RubotoActivity, calls onCreate, onStart, onResume ... in Android's order,
# and turns the page's taps into clicks on the views.
#
# ScriptLoader's two ways, both kept:
# - a cell that defines `class SomeActivity` with an onCreate is an
#   activity's script: the constant is set to the singleton class of a new
#   RubotoActivity first, so the class body defines its methods on that
#   activity ("Script defines methods on meta class" in ScriptLoader.java) -
#   self is the Activity, as on a phone, and the script runs again for every
#   new instance of the activity (a rotation);
# - start_ruboto_activity with a block makes a plain Ruby class: its instance
#   gets @ruboto_java_instance, and ruboto/base.rb's method_missing passes
#   what it does not define on to the activity.
require "java"
require "json"
require "stringio"

$package_name = "org.ruboto.example"
::RUBOTO_JAVA_PROXIES = {} unless defined?(::RUBOTO_JAVA_PROXIES)
# what a Ruboto app's boot has loaded before the first script; ruboto/widget
# too, so that each app can start from its state after the require (below)
require "ruboto/activity"
require "ruboto/widget"

# Android's exception for an override of onCreate (and friends) that does not
# call super
class SuperNotCalledException < StandardError; end

module RubotoSim
  Device = Java::OrgChunkybaconSim::Device
  Bundle = Java::AndroidOs::Bundle
  Intent = Java::AndroidContent::Intent
  JRubotoActivity = Java::OrgRuboto::RubotoActivity
  JRubotoDialog = Java::OrgRuboto::RubotoDialog
  ScriptInfo = Java::OrgRuboto::ScriptInfo
  AdapterView = Java::AndroidWidget::AdapterView
  CompoundButton = Java::AndroidWidget::CompoundButton
  EditText = Java::AndroidWidget::EditText
  SeekBar = Java::AndroidWidget::SeekBar
  Spinner = Java::AndroidWidget::Spinner
  FILE = "chunky.rb"
  # Android checks that these call super (SuperNotCalledException)
  SUPER_REQUIRED = %i[onCreate onStart onRestart onResume onPause onStop onDestroy].freeze
  MAX_TIMERS = 500

  # an activity on the stack: the Java component, the Ruby object that gets
  # the callbacks (the component itself on the singleton way), its class name
  # +orientation+: the one it was made for (a rotation while it was stopped
  # recreates it when it comes back); +saved+: its last onSaveInstanceState
  Entry = Struct.new(:java, :ruby, :name, :intent, :orientation, :saved)

  class << self
    attr_reader :stack

    attr_writer :bind

    def booted? = !@scripts.nil?

    def boot(bind = nil)
      JRubotoActivity.__persistent__ = true
      @conversions = View.constant_conversions.dup
      @bind = bind
      @scripts = {}
      wipe
    end

    # a new page, or ↺: no app, no data
    def wipe
      Device.wipe
      @install = 0
      @stack = []
      @main = nil
      @label = nil
      @crash = nil
      @home = false
      nil
    end

    # ---- a cell ----

    # The classes of a cell that are activities: a top-level `class Name`
    # (no superclass) with a `def onCreate` in it. ScriptLoader also finds
    # the class by a regular expression on the script; this follows the
    # nesting by indentation, so a class inside the activity is not taken.
    def activity_names(code)
      classes_with(code) { |stack, line| line.match?(/\A\s*def[ \t]+onCreate\b/) && stack.size == 1 && stack.first[2] }
    end

    # the top-level classes a cell opens (`class Name` lines at depth 1)
    def class_names(code)
      classes_with(code) { |stack, _| stack.size == 1 }
    end

    # walks the lines with a stack of [name, indent, plain?] for the open
    # `class`/`module` lines; the names of the outermost ones for which the
    # block says yes
    def classes_with(code)
      stack = []
      names = []
      code.each_line do |line|
        indent = line[/\A[ \t]*/].size
        if (m = line.match(/\A[ \t]*(class|module)[ \t]+([A-Z]\w*)(.*)$/)) && !line.include?(" end")
          stack << [m[2], indent, m[1] == "class" && !m[3].match?(/\A\s*</)]
          names << stack.first[0] if stack.size == 1 && yield(stack, line) && stack.first[2]
          next
        end
        stack.pop if line.match?(/\A[ \t]*end\b/) && stack.any? && stack.last[1] == indent
        names << stack.first[0] if stack.any? && yield(stack, line)
      end
      names.uniq
    end

    # Before the cell runs: each activity class it defines gets a new
    # RubotoActivity, whose singleton class the class body then reopens.
    def prepare(code)
      names = activity_names(code)
      fresh_process unless names.empty?
      # what to put back if the cell fails (rollback): a broken rerun must
      # not replace the script of the app that keeps running
      @undo = names.to_h do |name|
        [name, [(Object.const_get(name) if Object.const_defined?(name, false)), @scripts[name]]]
      end
      names.to_h do |name|
        component = new_component(name, code)
        [name, component]
      end
    end

    # the cell failed: its activities' constants and scripts as before it
    def rollback
      (@undo || {}).each do |name, (constant, script)|
        Object.send(:remove_const, name) if Object.const_defined?(name, false)
        Object.const_set(name, constant) if constant
        if script then @scripts[name] = script else @scripts.delete(name) end
      end
      @undo = nil
    end

    # a cell that reopens a running activity's class (no onCreate of its own)
    # changes it from now on: its code goes along when the activity is made
    # anew (a rotation), after the activity's own script
    def reopened(code, prepared)
      (class_names(code) - prepared.keys).each do |name|
        @scripts[name] << code if @scripts[name] && !@scripts[name].include?(code)
      end
    end

    # A new app runs in a new process: Ruboto's symbol table (ruboto/widget.rb
    # adds :vertical and friends with each ruboto_import_widgets, and warns
    # when a symbol is there already) is as right after the require
    def fresh_process
      View.instance_variable_set(:@convert_constants, @conversions.dup)
    end

    # After the cell ran (not quietly): the first activity it defined is the
    # app's main activity; installing it ends the app that ran before (as a
    # reinstall does: no callbacks) and starts it.
    def install(prepared)
      return false if prepared.empty?

      name, component = prepared.first
      @main = name
      @label = name.sub(/Activity\z/, "").gsub(/([a-z])([A-Z])/, '\1 \2')
      @label = name if @label.empty?
      fresh_install
      push(Entry.new(component, component, name, launcher_intent(name)), nil)
      after_input
      true
    end

    # a new app on an upright phone, with a log of its own; an input the page
    # sent for the app before it is ignored (+install+ in the snapshot)
    def fresh_install
      Device.reset
      Device.clearLog
      Device.setOrientation(Device::PORTRAIT)
      @install += 1
      @stack = []
      @crash = nil
      @home = false
    end

    # the exercise's check has tapped through the app: the learner gets it
    # fresh, as if just installed (its preferences too)
    def relaunch
      return unless @main && @scripts[@main] && !@crash

      Device.clearPreferences
      fresh_install
      push(instantiate(@main, nil, launcher_intent(@main)), nil)
      after_input
    end

    # ---- the page's input ----

    # One input from the page's phone (JSON), then the screen as it is now.
    # What the app prints goes to logcat, as System.out does on a phone.
    def input(json)
      event = JSON.parse(json)
      old = $stdout
      $stdout = out = StringIO.new
      begin
        # an input for an app that has been replaced since (the page sent it
        # before the newer run's answer came)
        stale = event.key?("install") && event["install"].to_i != @install
        guarded { dispatch(event) } unless stale
      ensure
        $stdout = old
        out.string.each_line { |line| Device.log("I", "System.out", line.chomp) }
      end
      snapshot
    end

    def dispatch(event)
      # the phone's clock: the time that passed since the last screen first
      # (a Runnable due meanwhile runs before the tap)
      run_due(Device.now + event["ms"].to_i.clamp(0, 60_000)) if event["ms"]
      top = @stack.last
      case event["action"]
      when "tick"
        nil
      when "close"     # the crash dialog's button
        @crash = nil
        @home = true
      when "launch"    # the app's icon on the home screen
        return if @main.nil? || @crash
        if @home && top
          @home = false
          restart(top)
        elsif !top
          @home = false
          push(instantiate(@main, nil, launcher_intent(@main)), nil)
        end
      when "home"
        return if @home || !top
        Device.dialog&.dismiss
        pause_and_stop(top)
        @home = true
      when "back"
        return if @home || !top
        dialog = Device.dialog
        if dialog
          dialog.cancel if dialog.isCancelable
        elsif @stack.size == 1 && !ruby_method?(top, :onBackPressed)
          # Android 12 and newer: Back on the app's first screen moves the
          # app to the background, as Home does - the activity is not ended
          Device.log("I", "ActivityTaskManager", "Back on the root activity: moving #{$package_name} to the background")
          pause_and_stop(top)
          @home = true
        else
          call(top, :onBackPressed)
        end
      when "rotate"
        Device.setOrientation(Device.getOrientation == Device::PORTRAIT ? Device::LANDSCAPE : Device::PORTRAIT)
        recreate(top) if top && !@home
      else
        return if @home || !top
        view_input(top, event)
      end
      after_input
    end

    # what an input or a start leaves to do: finished activities, started
    # intents, Runnables due now
    def after_input
      settle
      run_due(Device.now)
    end

    # the activity's own Ruby defines +name+ (not Java's, not Ruboto's)
    def ruby_method?(entry, name)
      method = entry.ruby.method(name)
      method.source_location&.first == FILE
    rescue NameError
      false
    end

    def view_input(top, event)
      case event["action"]
      when "dialog"
        dialog = Device.dialog
        dialog.simClick(event["which"].to_i) if dialog.respond_to?(:simClick)
        return
      when "menu"
        menu = top.java.simMenu
        item = menu && event["index"].to_i < menu.size ? menu.getItem(event["index"].to_i) : nil
        return unless item&.isEnabled

        call(top, :onOptionsItemSelected, item) unless Java::OrgChunkybaconSim::SimMenu.clickListener(item)
        return
      end
      view = Device.view(event["sim"].to_i)
      return unless view && on_screen?(top, view) && view.isEnabled

      case event["action"]
      when "click" then view.performClick
      when "longclick" then view.performLongClick
      when "text" then view.setText(event["text"].to_s) if view.is_a?(EditText)
      when "seek" then view.simDrag(event["value"].to_i) if view.is_a?(SeekBar)
      when "item" then view.simItemClick(event["index"].to_i) if view.is_a?(AdapterView)
      when "select" then view.setSelection(event["index"].to_i) if view.is_a?(AdapterView)
      end
    end

    # the view is drawn now: in the top activity's views, or the dialog's
    def on_screen?(top, view)
      roots = [top.java.simContentView, Device.dialog&.simView].compact
      node = view
      until node.nil?
        return false unless node.getVisibility.zero?
        return true if roots.any? { |root| root.equal?(node) }

        node = node.getParent
      end
      false
    end

    # ---- the activity manager ----

    def launcher_intent(name)
      Intent.new.tap { |i| i.putExtra(ScriptInfo::CLASS_NAME_KEY, name) }
    end

    # a new RubotoActivity for the script of +name+; with +code+, the
    # singleton way: the constant is its singleton class while the script runs
    def new_component(name, code, java_class = JRubotoActivity)
      component = java_class.new
      component.getScriptInfo.setRubyClassName(name)
      component.getScriptInfo.setRubyInstance(component)
      return component unless code

      @scripts[name] = [code]
      Object.send(:remove_const, name) if Object.const_defined?(name, false)
      Object.const_set(name, component.singleton_class)
      component
    end

    # the script again, for a new instance of its activity (Ruboto evaluates
    # it for every component); what it prints goes to logcat
    def reload(name, java_class = JRubotoActivity)
      scripts = @scripts[name]
      component = new_component(name, scripts.first, java_class)
      @scripts[name] = scripts
      fresh_process
      scripts.each do |code|
        # the other activities of the same code must not be reopened: they
        # may be running (their class is their activity's singleton class)
        others = class_names(code).select { |other| other != name && @scripts.key?(other) }
        held = others.to_h { |other| [other, Object.const_get(other)] }
        begin
          held.each_key do |other|
            Object.send(:remove_const, other)
            Object.const_set(other, JRubotoActivity.new.singleton_class)
          end
          eval(code, @bind, FILE, 1) # rubocop:disable Security/Eval
        ensure
          held.each do |other, constant|
            Object.send(:remove_const, other) if Object.const_defined?(other, false)
            Object.const_set(other, constant)
          end
        end
      end
      component
    end

    def push(entry, saved)
      entry.java.setIntent(entry.intent) if entry.intent
      entry.java.setTheme(Java::android.R::style::Theme_Dialog) if entry.java.is_a?(JRubotoDialog)
      entry.orientation = Device.getOrientation
      @stack << entry
      ::RUBOTO_JAVA_PROXIES[entry.ruby] = entry.ruby
      call(entry, :onCreate, saved)
      # finish() in onCreate: Android goes straight to onDestroy (settle)
      return if entry.java.isFinishing

      call(entry, :onStart)
      call(entry, :onRestoreInstanceState, saved) if saved
      call(entry, :onResume)
      menu(entry)
      first_selections(entry.java.simContentView)
    end

    # a stopped activity comes back - made anew if the phone turned meanwhile
    def restart(entry)
      return recreate_stopped(entry) if entry.orientation != Device.getOrientation

      call(entry, :onRestart)
      call(entry, :onStart)
      call(entry, :onResume)
      menu(entry)
    end

    # Android 9 and newer save the state after onStop (and whenever an
    # activity stops without finishing: Home, a screen on top, a rotation)
    def pause_and_stop(entry, saved = Bundle.new)
      call(entry, :onPause)
      call(entry, :onStop)
      save(entry, saved)
    end

    def save(entry, saved = Bundle.new)
      call(entry, :onSaveInstanceState, saved)
      entry.saved = saved
    end

    # Android reports a Spinner's first item as selected after the first
    # layout pass
    def first_selections(view)
      return unless view

      view.simInitialSelection if view.is_a?(Spinner)
      return unless view.is_a?(Java::AndroidView::ViewGroup)

      view.getChildCount.times { |i| first_selections(view.getChildAt(i)) }
    end

    # an activity's dialog dies with it; Android logs the leaked window
    def drop_dialog(entry)
      dialog = Device.dialog
      return unless dialog

      Device.log("E", "WindowManager", "Activity #{$package_name}.#{entry.name} has leaked window " \
                                       "#{dialog.getClass.getSimpleName} that was originally added here")
      dialog.dismiss
    end

    def destroy(entry)
      call(entry, :onDestroy)
      ::RUBOTO_JAVA_PROXIES.delete(entry.ruby)
    end

    # a configuration change: Android ends the activity and makes a new one,
    # which gets the Bundle the old one saved
    def recreate(entry)
      saved = pause_and_stop(entry)
      drop_dialog(entry)
      destroy(entry)
      @stack.pop
      fresh = instantiate(entry.name, entry.java.is_a?(JRubotoDialog) ? JRubotoDialog : nil, entry.intent)
      push(fresh, saved)
    end

    # the phone turned while this activity was stopped: it is made anew as it
    # comes back, with the state it saved when it stopped
    def recreate_stopped(entry)
      destroy(entry)
      @stack.delete(entry)
      fresh = instantiate(entry.name, entry.java.is_a?(JRubotoDialog) ? JRubotoDialog : nil, entry.intent)
      push(fresh, entry.saved || Bundle.new)
    end

    # a new instance of activity +name+ (an intent's, or a recreation)
    def instantiate(name, java_class, intent)
      java_class ||= JRubotoActivity
      if @scripts[name]
        component = reload(name, java_class)
        Entry.new(component, component, name, intent)
      else
        klass = Object.const_defined?(name) ? Object.const_get(name) : nil
        raise NameError, "uninitialized constant #{name} (the activity's class)" unless klass.is_a?(Class)

        component = java_class.new
        component.getScriptInfo.setRubyClassName(name)
        instance = klass.new
        instance.instance_variable_set(:@ruboto_java_instance, component)
        component.getScriptInfo.setRubyInstance(instance)
        Entry.new(component, instance, name, intent)
      end
    end

    # the options menu: built again when the activity asked (invalidateOptionsMenu)
    def menu(entry)
      return unless entry.java.simMenuDirty

      menu = entry.java.simNewMenu
      # the menu shows only when both answer true
      shown = call(entry, :onCreateOptionsMenu, menu) && call(entry, :onPrepareOptionsMenu, menu)
      menu.clear unless shown
    end

    # what the app asked for: activities that finished, intents it started
    def settle
      20.times do
        finishing = Device.takeFinishing
        started = Device.takeStarted
        break unless finishing || started

        finished(finishing) if finishing
        start(started) if started
      end
      top = @stack.last
      menu(top) if top && !@home
    end

    def finished(java)
      entry = @stack.find { |e| e.java.equal?(java) }
      return unless entry

      if entry.java.simState == "created"
        # finished in onCreate: no onStart, onResume, onPause, onStop
        @stack.delete(entry)
        destroy(entry)
        @home = true if @stack.empty?
      elsif entry.equal?(@stack.last)
        # Android's order: this one pauses, the one below comes back, then
        # this one stops and ends
        call(entry, :onPause) unless @home
        drop_dialog(entry)
        @stack.pop
        below = @stack.last
        restart(below) if below && !@home
        call(entry, :onStop) unless @home
        destroy(entry)
        @home = true unless below
      else
        @stack.delete(entry)
        destroy(entry)
      end
    end

    def start(intent)
      name = intent.getStringExtra(ScriptInfo::CLASS_NAME_KEY)
      raise ArgumentError, "the intent names no activity class: #{intent}" unless name

      below = @stack.last
      call(below, :onPause) if below
      dialog = intent.getTargetClass&.getName == JRubotoDialog.java_class.name
      entry = instantiate(name, dialog ? JRubotoDialog : nil, intent)
      push(entry, nil)
      return unless below

      call(below, :onStop)
      save(below)
    end

    # one callback; Android's check that the override called super
    def call(entry, name, *args)
      entry.java.simTakeSuperCalled
      result = entry.ruby.__send__(name, *args)
      if SUPER_REQUIRED.include?(name) && !entry.java.simTakeSuperCalled
        error = SuperNotCalledException.new("Activity {#{$package_name}/#{entry.name}} did not call through to super.#{name}()")
        # the line of the method that forgot it, for the cell's error mark
        file, line = entry.ruby.method(name).source_location rescue nil
        error.set_backtrace(["#{file}:#{line}:in '#{name}'", *caller]) if file == FILE
        raise error
      end
      result
    end

    # the Runnables a Handler posted, up to the time +until_ms+
    def run_due(until_ms)
      MAX_TIMERS.times do
        task = Device.takeDue(until_ms)
        break unless task

        task.run
        settle
      end
      Device.advanceTo(until_ms)
    end

    # ---- crashes ----

    # an exception in the app ends it, as on a phone: logcat gets Android's
    # FATAL EXCEPTION, the screen the "has stopped" dialog
    def guarded
      yield
    rescue Exception => e # rubocop:disable Lint/RescueException - the app's code, all of it
      crash(e)
      nil
    end

    def crash(error)
      error = error.cause if error.is_a?(Java::JavaLang::RuntimeException) && error.cause.is_a?(Exception)
      lines = ["FATAL EXCEPTION: main", "Process: #{$package_name}",
               "#{error.class}: #{error.message}"]
      (error.backtrace || []).grep(/\A#{Regexp.escape(FILE)}:/o).first(8).each { |l| lines << "\tat #{l}" }
      Device.log("E", "AndroidRuntime", lines.join("\n"))
      @stack = []
      Device.reset
      @crash = @label || "App"
      @home = false
    end

    def crashed? = !@crash.nil?

    # ---- what the page draws ----

    def snapshot(all = false)
      top = @home ? nil : @stack.last
      device = Device.snapshot(top&.java, @label, @crash, all)
      %({"home":#{@home || @stack.empty?},"app":#{JSON.generate(@label)},"install":#{@install},"device":#{device}})
    end

    # the same for a test: the page still gets the log lines and toasts
    def peek
      top = @home ? nil : @stack.last
      %({"home":#{@home || @stack.empty?},"app":#{JSON.generate(@label)},"install":#{@install},"device":#{Device.peek(top&.java, @label, @crash)}})
    end

    def phone = (@phone ||= Phone.new)
  end

  # The phone as a test sees it (the exercises' probes): read the screen,
  # tap, type, go back, rotate, let time pass - as a user would, through the
  # same inputs as the page's phone.
  class Phone
    def screen = JSON.parse(RubotoSim.peek)

    def activity = screen.dig("device", "activity")

    def title = activity&.fetch("title", nil)

    # the class of the activity on top (nil on the home screen or after a crash)
    def app = (RubotoSim.stack.last&.name unless screen["home"])

    # every text on the screen, in drawing order: texts, buttons, fields, list items
    def texts
      out = []
      walk(activity && activity["content"]) do |view|
        next if view["visibility"]

        out << view["text"] if view["text"] && !view["text"].empty?
        out.concat(view["items"]) if view["items"]
      end
      dialog = screen.dig("device", "dialog")
      if dialog
        out.concat([dialog["title"], dialog["message"]].compact)
        out.concat(dialog["items"] || [])
        out.concat((dialog["buttons"] || []).map { |b| b["text"] })
      end
      out
    end

    def text = texts.join("\n")

    def views(type = nil)
      list = []
      walk(activity && activity["content"]) { |v| list << v if type.nil? || v["type"] == type }
      list
    end

    def find(label)
      views.find { |v| v["text"] == label.to_s || v["hint"] == label.to_s } or
        raise ArgumentError, "nothing on the screen says #{label.inspect} (it shows: #{texts.inspect})"
    end

    def tap(label) = send_input("action" => "click", "sim" => find(label)["sim"])

    def type(label, text) = send_input("action" => "text", "sim" => find(label)["sim"], "text" => text.to_s)

    def type_in(index, text)
      field = views("EditText")[index] or raise ArgumentError, "there is no text field number #{index}"
      send_input("action" => "text", "sim" => field["sim"], "text" => text.to_s)
    end

    def back = send_input("action" => "back")
    def home = send_input("action" => "home")
    def launch = send_input("action" => "launch")
    def rotate = send_input("action" => "rotate")
    def wait(ms) = send_input("action" => "tick", "ms" => ms)

    def menu(title)
      items = activity&.fetch("menu", []) || []
      item = items.find { |i| i["title"] == title.to_s } or raise ArgumentError, "the menu has no #{title.inspect}"
      send_input("action" => "menu", "index" => item["index"])
    end

    def toasts = RubotoSim::Device.toastTexts.to_a.map(&:to_s)
    def log = RubotoSim::Device.logLines.to_a.map(&:to_s)
    def crashed? = RubotoSim.crashed?

    # the drawable an ImageView shows (the first, or the one with +id+)
    def image(id = nil)
      view = views("ImageView").find { |v| id.nil? || v["id"] == id }
      view && view["drawable"]
    end

    private

    def send_input(event)
      RubotoSim.input(JSON.generate(event))
      self
    end

    def walk(view, &block)
      return unless view

      yield view
      (view["children"] || []).each { |child| walk(child, &block) }
    end
  end
end

# the phone, for a cell or a check: phone.tap "+1"
def phone = RubotoSim.phone

# The cells of a lesson with "android": true (jruby_worker.js): ChunkyLab.run
# with the activity manager around it. A cell that defines an activity
# installs and starts it (not when it runs quietly, as one of the cells
# above); the answer then carries the phone's screen. +probe+: the
# exercise's code that tests the app, run after the cell (its inspect goes
# to the check, as the IronRuby lesson's does).
module ChunkyLab
  def self.run_android(code, quiet = false, probe = nil)
    fresh unless @bind
    RubotoSim.bind = @bind
    old = $stdout
    $stdout = StringIO.new if quiet
    installing = installed = false
    # the check starts the app as installed anew: no preferences of an earlier check
    RubotoSim::Device.clearPreferences if probe
    fields = begin
      prepared = RubotoSim.prepare(code)
      value = eval(code, @bind, FILE, 1)
      RubotoSim.reopened(code, prepared)
      unless quiet
        installing = true
        installed = RubotoSim.install(prepared)
      end
      { status: "ok", inspect: inspect_of(value) }
    rescue Exception => e # rubocop:disable Lint/RescueException - the learner's code, all of it
      # the app's own start failed (onCreate ...): it crashed, as on a phone
      if installing
        RubotoSim.crash(e)
        installed = true
      else
        RubotoSim.rollback
      end
      { status: "error", errorClass: e.class.name.to_s, line: line_of(e), message: e.message.to_s }
    end
    if probe && fields[:status] == "ok"
      fields[:probe] = begin
        inspect_of(eval(probe, @bind, "probe.rb", 1))
      rescue Exception => e # rubocop:disable Lint/RescueException
        "#<#{e.class}: #{e.message}>"
      end
      # the probe tapped and turned the app: the learner's starts fresh
      RubotoSim.guarded { RubotoSim.relaunch } if installed
    end
    $stdout = old
    fields[:phone] = RubotoSim.snapshot(true) if installed
    answer(fields)
  end

  class << self
    alias fresh_without_phone fresh
    # a new lesson page, or ↺: the phone starts empty too
    def fresh
      fresh_without_phone
      RubotoSim.wipe if RubotoSim.booted?
      nil
    end
  end
end
