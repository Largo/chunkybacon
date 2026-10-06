# ruby2d 1.0.0 (https://www.ruby2d.com, MIT, LICENSE.md next to this
# file): the gem's Ruby files, unchanged, in the order its ruby2d/core.rb
# requires them. Written by tools/vendor_ruby2d.rb - do not edit; the
# page's changes are in html/ruby2d.rb, which loads after this.

# ---------- lib/ruby2d/exceptions.rb ----------

module Ruby2D
  # Ruby2D::Error
  class Error < StandardError
  end
end

# ---------- lib/ruby2d/warnings.rb ----------

module Ruby2D
  # Messages already emitted by `warn`, so a bad value produced every frame in a
  # render loop warns a single time rather than flooding the console. Keyed by
  # the message string.
  @warned_messages = {}

  # Emit a warning at most once per distinct message. Mirrors the native
  # extension's `R2D_Log(R2D_WARN, ...)`: a bold-yellow `[WARN]` tag
  # (`String#warning` shares the C side's `1;33`) followed by the message, on
  # stderr — so Ruby and C warnings render identically. `Kernel#warn` isn't
  # available under mruby, so write to `$stderr` directly.
  def self.warn(message)
    return if @warned_messages.key?(message)

    @warned_messages[message] = true
    $stderr.puts "#{'[WARN]'.warning} #{message}"
  end

  # Emit an informational diagnostic, mirroring the native extension's
  # `R2D_Log(R2D_INFO, ...)`: a bold-blue `[INFO]` tag (`String#info` and the C
  # side both use `1;34`) followed by the message, on stderr. Like the C side,
  # INFO is suppressed unless diagnostics are enabled (`set(diagnostics: true)`)
  # and — unlike `warn` — it never dedupes, so every diagnostic event prints.
  def self.info(message)
    return unless DSL.window? && DSL.window.diagnostics

    $stderr.puts "#{'[INFO]'.info} #{message}"
  end
end

# ---------- lib/ruby2d/window/class_methods.rb ----------

# Ruby2D::Window::ClassMethods

module Ruby2D
  class Window
    # Class-level accessors that delegate to the DSL window instance
    module ClassMethods
      # Get the current window instance
      def current
        DSL.window
      end

      # Get the window title
      def title
        DSL.window.title
      end

      # Get the background color
      def background
        DSL.window.background
      end

      # Get the window width
      def width
        DSL.window.width
      end

      # Get the window height
      def height
        DSL.window.height
      end

      # Get the viewport width
      def viewport_width
        DSL.window.viewport_width
      end

      # Get the viewport height
      def viewport_height
        DSL.window.viewport_height
      end

      # Get the viewport scaling mode
      def viewport_mode
        DSL.window.viewport_mode
      end

      # Get the display width
      def display_width
        DSL.window.display_width
      end

      # Get the display height
      def display_height
        DSL.window.display_height
      end

      # Get the display width in physical pixels
      def display_pixel_width
        DSL.window.display_pixel_width
      end

      # Get the display height in physical pixels
      def display_pixel_height
        DSL.window.display_pixel_height
      end

      # Get whether the window is resizable
      def resizable
        DSL.window.resizable
      end

      # Get whether high DPI mode is enabled
      def highdpi
        DSL.window.highdpi
      end

      # Get the pixel scale
      def pixel_scale
        DSL.window.pixel_scale
      end

      # Get the total number of rendered frames
      def frames
        DSL.window.frames
      end

      # Get the current frames per second
      def fps
        DSL.window.fps
      end

      # Get the most recent frame's delta time, in seconds (clamped to 0.1s).
      # The same value passed to an `update do |dt|` block; the time source
      # every animation advances on.
      def delta_time
        DSL.window.delta_time
      end

      # Get the FPS cap
      def fps_cap
        DSL.window.fps_cap
      end

      # Get the mouse x position
      def mouse_x
        DSL.window.mouse_x
      end

      # Get the mouse y position
      def mouse_y
        DSL.window.mouse_y
      end

      # Get the mouse position as [x, y]
      def mouse_position
        DSL.window.mouse_position
      end

      # Get whether diagnostics are enabled
      def diagnostics
        DSL.window.diagnostics
      end

      # Get whether FPS display is enabled
      def show_fps
        DSL.window.show_fps
      end

      # Take a screenshot, saving to `path` (or a timestamped file if omitted)
      def screenshot(path = nil)
        DSL.window.screenshot(path)
      end

      # Get a window attribute by name
      def get(sym)
        DSL.window.get(sym)
      end

      # Set window attributes
      def set(opts)
        DSL.window.set(opts)
      end

      # Register an event handler
      def on(event = nil, **filters, &proc)
        DSL.window.on(event, **filters, &proc)
      end

      # Remove an event handler
      def off(event_descriptor)
        DSL.window.off(event_descriptor)
      end

      # Add an object to the window
      def add(object)
        DSL.window.add(object)
      end

      # Remove an object from the window
      def remove(object)
        DSL.window.remove(object)
      end

      # Register an interactive object
      def register_interactive(object)
        DSL.window.register_interactive(object)
      end

      # Unregister an interactive object
      def unregister_interactive(object)
        DSL.window.unregister_interactive(object)
      end

      # Clear all objects from the window
      def clear
        DSL.window.clear
      end

      # Set the update callback
      def update(&proc)
        DSL.window.update(&proc)
      end

      # Set the render callback
      def render(&proc)
        DSL.window.render(&proc)
      end

      # Show the window
      def show
        DSL.window.show
      end

      # Get the current cursor state
      def cursor
        DSL.window.cursor
      end

      # Set the cursor: `:visible`, `:hidden`, or a system cursor name
      def cursor=(name)
        DSL.window.cursor = name
      end

      # Close the window
      def close
        DSL.window.close
      end

      # Check if the window is ready for rendering
      def render_ready_check
        return if shown?

        raise Error,
              'Attempting to draw before the window is ready. Please put calls to render() inside of a render block.'
      end
    end
  end
end

# ---------- lib/ruby2d/window/key_events.rb ----------

# Ruby2D::Window::KeyEvents

module Ruby2D
  class Window
    # Keyboard input event handling
    module KeyEvents
      # Key down event method for class pattern
      def key_pressed?(key)
        @keys_down.include? key
      end

      # Key held event method for class pattern
      def key_held?(key)
        @keys_held.include? key
      end

      # Key up event method for class pattern
      def key_released?(key)
        @keys_up.include? key
      end

      # Key callback method. `key` arrives already normalized (lowercased):
      # from `dispatch_events` via the cached scancode-name table, or from a
      # direct caller passing a lowercase key name.
      def key_callback(type, key)
        # All key events
        fire_event_handlers(:key) { KeyEvent.new(type, key) }

        case type
        # When key is pressed, fired once
        when :down
          handle_key_down type, key
        # When key is being held down, fired every frame
        when :held
          handle_key_held type, key
        # When key released, fired once
        when :up
          handle_key_up type, key
        end
      end

      private

      def handle_key_down(type, key)
        close if @close_on_esc && key == 'escape'

        @keys_down << key unless @keys_down.include? key

        fire_event_handlers(:key_down) { KeyEvent.new(type, key) }
      end

      def handle_key_held(type, key)
        @keys_held << key unless @keys_held.include? key

        fire_event_handlers(:key_held) { KeyEvent.new(type, key) }
      end

      def handle_key_up(type, key)
        @keys_up << key unless @keys_up.include? key

        fire_event_handlers(:key_up) { KeyEvent.new(type, key) }
      end

      def init_key_event_stores
        # Event stores for class pattern
        @keys_down = []
        @keys_held = []
        @keys_up   = []
        # Scancode → frozen lowercased name, filled lazily by `key_name`
        @key_names = []
      end
    end
  end
end

# ---------- lib/ruby2d/window/mouse_events.rb ----------

# Ruby2D::Window::MouseEvents

module Ruby2D
  class Window
    # Mouse input event handling
    module MouseEvents
      # Mouse down event method for class pattern
      def mouse_pressed?(btn)
        @mouse_buttons_down.include? btn
      end

      # Mouse up event method for class pattern
      def mouse_released?(btn)
        @mouse_buttons_up.include? btn
      end

      # Mouse held event method for class pattern
      def mouse_held?(btn)
        @mouse_buttons_held.include? btn
      end

      # Current mouse position as a [x, y] pair, for the common case where
      # both coordinates are needed together.
      def mouse_position
        [@mouse_x, @mouse_y]
      end

      # True while the cursor is over the window. Toggles on :mouse_enter /
      # :mouse_leave; starts false until SDL reports the first enter event.
      def mouse_inside?
        @mouse_inside
      end

      # Mouse scroll event method for class pattern
      def mouse_scrolled?
        @mouse_scroll_event
      end

      # Get the scroll direction
      def mouse_scroll_direction
        @mouse_scroll_direction
      end

      # Get the scroll delta x
      def mouse_scroll_delta_x
        @mouse_scroll_delta_x
      end

      # Get the scroll delta y
      def mouse_scroll_delta_y
        @mouse_scroll_delta_y
      end

      # Mouse move event method for class pattern
      def mouse_moved?
        @mouse_move_event
      end

      # Get the mouse move delta x
      def mouse_move_delta_x
        @mouse_move_delta_x
      end

      # Get the mouse move delta y
      def mouse_move_delta_y
        @mouse_move_delta_y
      end

      # Mouse callback method, called by the native and web extentions
      def mouse_callback(type, button, direction, x, y, delta_x, delta_y)
        # All mouse events
        fire_event_handlers(:mouse) { MouseEvent.new(type, button, direction, x, y, delta_x, delta_y) }

        case type
        # When mouse button pressed
        when :down
          handle_mouse_down type, button, x, y
        # When mouse button released
        when :up
          handle_mouse_up type, button, x, y
        # When mouse button is being held down, fired every frame
        when :held
          handle_mouse_held type, button, x, y
        # When mouse scrolling, wheel or trackpad
        when :scroll
          handle_mouse_scroll type, direction, delta_x, delta_y
        # When mouse motion / movement
        when :move
          handle_mouse_move type, x, y, delta_x, delta_y
        # When cursor enters the window
        when :enter
          handle_mouse_enter type
        # When cursor leaves the window
        when :leave
          handle_mouse_leave type
        end
      end

      private

      def handle_mouse_down(type, button, x, y)
        @mouse_buttons_down << button unless @mouse_buttons_down.include? button

        fire_event_handlers(:mouse_down) { MouseEvent.new(type, button, nil, x, y, nil, nil) }

        dispatch_object_mouse_down(button, x, y)
      end

      def handle_mouse_up(type, button, x, y)
        @mouse_buttons_up << button unless @mouse_buttons_up.include? button

        fire_event_handlers(:mouse_up) { MouseEvent.new(type, button, nil, x, y, nil, nil) }

        dispatch_object_mouse_up(button, x, y)
      end

      def handle_mouse_held(type, button, x, y)
        @mouse_buttons_held << button unless @mouse_buttons_held.include? button

        fire_event_handlers(:mouse_held) { MouseEvent.new(type, button, nil, x, y, nil, nil) }

        dispatch_object_mouse_held(button, x, y)
      end

      def handle_mouse_scroll(type, direction, delta_x, delta_y)
        @mouse_scroll_event     = true
        @mouse_scroll_direction = direction
        @mouse_scroll_delta_x   = delta_x
        @mouse_scroll_delta_y   = delta_y

        fire_event_handlers(:mouse_scroll) { MouseEvent.new(type, nil, direction, nil, nil, delta_x, delta_y) }

        dispatch_object_mouse_scroll(@mouse_x, @mouse_y, direction, delta_x, delta_y)
      end

      def handle_mouse_move(type, x, y, delta_x, delta_y)
        @mouse_move_event   = true
        @mouse_move_delta_x = delta_x
        @mouse_move_delta_y = delta_y

        fire_event_handlers(:mouse_move) { MouseEvent.new(type, nil, nil, x, y, delta_x, delta_y) }

        dispatch_object_mouse_move(x, y, delta_x, delta_y)
      end

      def handle_mouse_enter(type)
        @mouse_inside = true
        fire_event_handlers(:mouse_enter) { MouseEvent.new(type, nil, nil, nil, nil, nil, nil) }
      end

      def handle_mouse_leave(type)
        @mouse_inside = false
        fire_event_handlers(:mouse_leave) { MouseEvent.new(type, nil, nil, nil, nil, nil, nil) }
      end

      def init_mouse_event_stores
        @mouse_buttons_down = []
        @mouse_buttons_up   = []
        @mouse_buttons_held = []
        @mouse_scroll_event     = false
        @mouse_scroll_direction = nil
        @mouse_scroll_delta_x   = 0
        @mouse_scroll_delta_y   = 0
        @mouse_move_event   = false
        @mouse_move_delta_x = 0
        @mouse_move_delta_y = 0
        @mouse_inside       = false
      end
    end
  end
end

# ---------- lib/ruby2d/window/gamepad_events.rb ----------

# Ruby2D::Window::GamepadEvents

module Ruby2D
  class Window
    # Multi-gamepad input handling. Owns the `gamepads` collection and the
    # callback the C extension calls for every SDL gamepad event. Holds no
    # ambient single-pad state — every event carries the `Gamepad` it came
    # from, and polling lives on each `Gamepad` instance.
    module GamepadEvents
      # Default location for the user's gamepad mappings file. Loaded
      # automatically from `show` if it exists.
      DEFAULT_GAMEPAD_MAPPINGS_PATH = "#{File.expand_path('~')}/.ruby2d/gamepads.txt".freeze

      # Internal dispatch structs for filter matching. Never exposed to user
      # code — handlers receive unpacked args (gamepad / button / axis / value),
      # not the struct.
      GamepadConnectData = Struct.new(:gamepad) do
        def gamepad?(other) = gamepad.equal?(other)
      end

      GamepadButtonData = Struct.new(:gamepad, :button) do
        def gamepad?(other) = gamepad.equal?(other)
        def button?(name)   = button == name
      end

      GamepadAxisData = Struct.new(:gamepad, :axis, :value) do
        def gamepad?(other) = gamepad.equal?(other)
        def axis?(name)     = axis == name
      end

      # Connected gamepads in connect order. Stable: index 0 is the
      # first-connected pad still present.
      def gamepads
        @gamepads
      end

      # Load gamepad mappings from a file or string. Smart-parses the
      # argument: if it points at an existing file, loads it via
      # `SDL_AddGamepadMappingsFromFile`; otherwise treats it as a single
      # mapping string and forwards to `SDL_AddGamepadMapping`.
      def add_gamepad_mapping(path_or_string)
        if File.file?(path_or_string)
          Ext.window_load_gamepad_mappings_file(self, path_or_string)
        else
          Ext.window_add_gamepad_mapping(self, path_or_string)
        end
      end

      # Auto-load mappings from the default user file. Called from `show`.
      def load_default_gamepad_mappings
        return unless File.exist?(DEFAULT_GAMEPAD_MAPPINGS_PATH)

        Ext.window_load_gamepad_mappings_file(self, DEFAULT_GAMEPAD_MAPPINGS_PATH)
      end

      # Called from C for every gamepad event. Type is one of:
      # :connect, :disconnect, :button_down, :button_held, :button_up, :axis.
      # `data` is the button name (button events), axis name (axis events),
      # or nil (connect/disconnect). `value` is the dead-zone-applied axis
      # value, or nil. `name` is the gamepad's display name on connect/
      # disconnect, otherwise nil.
      def gamepad_callback(which, type, data, value, name = nil)
        case type
        when :connect
          handle_gamepad_connect(which, name)
        when :disconnect
          handle_gamepad_disconnect(which)
        when :button_down
          handle_gamepad_button_down(which, data)
        when :button_held
          handle_gamepad_button_held(which, data)
        when :button_up
          handle_gamepad_button_up(which, data)
        when :axis
          handle_gamepad_axis(which, data, value)
        end
      end

      def init_gamepad_event_stores
        @gamepads = []
        @gamepads_by_id = {}
      end

      def clear_gamepad_frame_state
        @gamepads.each(&:_clear_frame_state)
      end

      private

      def handle_gamepad_connect(id, name)
        return if @gamepads_by_id.key?(id)

        pad = Gamepad.new(self, id, name)
        @gamepads << pad
        @gamepads_by_id[id] = pad

        fire_event_handlers(:gamepad_connect) { GamepadConnectData.new(pad) }
      end

      def handle_gamepad_disconnect(id)
        pad = @gamepads_by_id.delete(id)
        return unless pad

        @gamepads.delete(pad)
        pad._disconnect

        fire_event_handlers(:gamepad_disconnect) { GamepadConnectData.new(pad) }
      end

      def handle_gamepad_button_down(id, button)
        pad = @gamepads_by_id[id] or return
        pad._apply_button_down(button)
        fire_event_handlers(:gamepad_button_down) { GamepadButtonData.new(pad, button) }
      end

      def handle_gamepad_button_held(id, button)
        pad = @gamepads_by_id[id] or return
        pad._apply_button_held(button)
        fire_event_handlers(:gamepad_button_held) { GamepadButtonData.new(pad, button) }
      end

      def handle_gamepad_button_up(id, button)
        pad = @gamepads_by_id[id] or return
        pad._apply_button_up(button)
        fire_event_handlers(:gamepad_button_up) { GamepadButtonData.new(pad, button) }
      end

      # Suppress the event when the dead-zoned value didn't change since the
      # last event for that axis — avoids spamming handlers with motion
      # entirely inside the dead zone. `_apply_axis` returns the new value
      # when it changed, or nil otherwise.
      def handle_gamepad_axis(id, axis, raw_value)
        pad = @gamepads_by_id[id] or return
        new_value = pad._apply_axis(axis, raw_value)
        return if new_value.nil?

        fire_event_handlers(:gamepad_axis) { GamepadAxisData.new(pad, axis, new_value) }
      end
    end
  end
end

# ---------- lib/ruby2d/window/object_events.rb ----------

# Ruby2D::Window::ObjectEventDispatch

module Ruby2D
  class Window
    # Per-object event dispatching for interactive renderables
    module ObjectEventDispatch
      # Initialize stores for object-level interaction state
      def init_object_event_stores
        @interactive_objects = []
        @hovered_object = nil
        @pressed_objects = {}
      end

      # Register an object as interactive (has event handlers)
      def register_interactive(object)
        return if @interactive_objects.include?(object)

        index = @interactive_objects.index { |obj| obj.z > object.z }
        if index
          @interactive_objects.insert(index, object)
        else
          @interactive_objects.push(object)
        end
      end

      # Unregister an object (no more event handlers)
      def unregister_interactive(object)
        @interactive_objects.delete(object)
        cleanup_interaction_state(object)
      end

      # Clear pressed/hover refs when an object is removed
      def cleanup_interaction_state(object)
        @hovered_object = nil if @hovered_object == object

        @pressed_objects.delete_if { |_btn, info| info[:object] == object }
      end

      # Find the topmost interactive object at the given coordinates. A
      # Renderable is only hit-tested while it's in the scene graph: a shape
      # built with `add: false` (or one that's been removed) has handlers but
      # is not drawn, so it must not silently swallow clicks or shadow visible
      # objects beneath it. Hidden objects (`visible = false`) stay in the
      # scene graph and keep receiving events, as documented. Button and other
      # self-managing interactives aren't scene-graph members by design (their
      # visual is) and register/unregister themselves, so they're exempt.
      def topmost_interactive_at(x, y)
        # This runs on every mouse-move event, so the common cases must not
        # allocate: the enumerator + pair-array sort below costs ~12µs per
        # event on wasm mruby even with zero interactive objects.
        objs = @interactive_objects
        size = objs.size
        return nil if size.zero?

        # @interactive_objects is kept sorted by z at registration, but an
        # object's z (or its wrapped visual's z) can change at runtime. Verify
        # the order in one allocation-free pass; while it holds (nearly every
        # frame), hit-test top-down by iterating backwards in place — among
        # equal-z objects the highest index (most recently registered) is
        # checked first, matching the stable sort in the fallback.
        in_order = true
        i = 1
        while i < size
          if objs[i - 1].z > objs[i].z
            in_order = false
            break
          end
          i += 1
        end

        if in_order
          i = size - 1
          while i >= 0
            obj = objs[i]
            unless obj.is_a?(Renderable) && !@object_set.key?(obj)
              return obj if obj.contains?(x, y)
            end
            i -= 1
          end
          return nil
        end

        # A runtime z change broke the registration order: re-establish it with
        # a sort stable on the array's current index, preserving registration
        # order among equal-z objects (most recently registered stays topmost).
        objs.each_with_index.sort_by { |obj, idx| [obj.z, idx] }.reverse_each do |obj, _idx|
          next if obj.is_a?(Renderable) && !@object_set.key?(obj)
          return obj if obj.contains?(x, y)
        end
        nil
      end

      # Dispatch mouse down to the topmost interactive object
      def dispatch_object_mouse_down(button, x, y)
        obj = topmost_interactive_at(x, y)
        return unless obj

        @pressed_objects[button] = { object: obj, x: x, y: y }
        obj._fire_event(:mouse_down, MouseEvent.new(:down, button, nil, x, y, nil, nil))
      end

      # Dispatch mouse up. `:mouse_up` mirrors `:mouse_down`: it fires on the
      # originally-pressed object regardless of release location, and also on
      # the topmost interactive object under the cursor at release. When the
      # press and release are on the same object, only one `:mouse_up` fires
      # (and `:click` follows).
      def dispatch_object_mouse_up(button, x, y)
        obj = topmost_interactive_at(x, y)
        press = @pressed_objects.delete(button)
        event = MouseEvent.new(:up, button, nil, x, y, nil, nil)

        obj._fire_event(:mouse_up, event) if obj
        if press && press[:object] != obj
          press[:object]._fire_event(:mouse_up, event)
        end

        if press && obj == press[:object]
          obj._fire_event(:click, MouseEvent.new(:click, button, nil, x, y, nil, nil))
        end
      end

      # Dispatch mouse move: update hover state, handle drag
      def dispatch_object_mouse_move(x, y, delta_x, delta_y)
        obj = topmost_interactive_at(x, y)

        # Update hover state
        if obj != @hovered_object
          if @hovered_object
            @hovered_object._fire_event(:hover_out, MouseEvent.new(:hover_out, nil, nil, x, y, nil, nil))
          end
          if obj
            obj._fire_event(:hover, MouseEvent.new(:hover, nil, nil, x, y, nil, nil))
          end
          @hovered_object = obj
        end

        # Handle drag for each pressed button
        @pressed_objects.each do |button, info|
          drag_obj = info[:object]
          next unless drag_obj.interactive?(:drag)

          drag_obj._fire_event(:drag, MouseEvent.new(:drag, button, nil, x, y, delta_x, delta_y))
        end
      end

      # Dispatch mouse held to the object originally pressed with this button.
      # Stays on the originally pressed object even if the cursor drags off,
      # mirroring :drag's "this interaction belongs to this object" semantics.
      def dispatch_object_mouse_held(button, x, y)
        press = @pressed_objects[button]
        return unless press

        press[:object]._fire_event(:mouse_held, MouseEvent.new(:held, button, nil, x, y, nil, nil))
      end

      # Dispatch scroll to the topmost interactive object under the cursor.
      # Hit-tests fresh (like :mouse_down/:mouse_up) rather than reusing the
      # hover state, which mouse_move updates only on movement — scrolling
      # without first moving would otherwise target the wrong object or nothing.
      def dispatch_object_mouse_scroll(x, y, direction, delta_x, delta_y)
        obj = topmost_interactive_at(x, y)
        return unless obj

        obj._fire_event(:mouse_scroll, MouseEvent.new(:scroll, nil, direction, x, y, delta_x, delta_y))
      end
    end
  end
end

# ---------- lib/ruby2d/gamepad.rb ----------

# Ruby2D::Gamepad

module Ruby2D
  # A connected gamepad. Lives from connect to disconnect; reconnects produce
  # a new object. Identity-based equality (default Ruby behavior) makes
  # `Gamepad` instances stable hash keys for per-pad state.
  #
  # Disconnected pads remain safe to poll: `held?` etc. return `false`,
  # `axis` returns `0.0`, and feedback methods return `false` silently.
  class Gamepad
    # SDL3 enum values for symbol → integer translation. These mirror the
    # `R2D_BUTTON_*` and `R2D_AXIS_*` constants in `ruby2d.h`. The C side
    # already speaks symbols for events; these are only needed for capability
    # queries that go from Ruby through to SDL.
    BUTTON_ENUM = {
      south:           0,
      east:            1,
      west:            2,
      north:           3,
      back:            4,
      guide:           5,
      start:           6,
      left_stick:      7,
      right_stick:     8,
      left_shoulder:   9,
      right_shoulder:  10,
      dpad_up:         11,
      dpad_down:       12,
      dpad_left:       13,
      dpad_right:      14,
      misc1:           15,
      paddle1:         16,
      paddle2:         17,
      paddle3:         18,
      paddle4:         19,
      touchpad:        20,
      misc2:           21,
      misc3:           22,
      misc4:           23,
      misc5:           24,
      misc6:           25
    }.freeze

    AXIS_ENUM = {
      left_x:        0,
      left_y:        1,
      right_x:       2,
      right_y:       3,
      left_trigger:  4,
      right_trigger: 5
    }.freeze

    # Sticks only — triggers (0.0..1.0) are exempt because they rest at zero
    # and rarely drift. 0.05 should cover typical worst-case stick drift.
    DEFAULT_DEAD_ZONE = 0.05

    TRIGGER_AXES = %i[left_trigger right_trigger].freeze

    # Ordered list of axis names. `axes` always returns the full hash so the
    # shape is stable.
    AXIS_NAMES = AXIS_ENUM.keys.freeze

    attr_reader :id, :name, :type
    attr_accessor :dead_zone

    def initialize(window, id, name)
      @window = window
      @id = id
      @name = name || ''
      @connected = true
      @dead_zone = DEFAULT_DEAD_ZONE

      # Cached per-connection metadata. `type` and capabilities don't change
      # while the pad is connected, so we read them once and avoid the SDL
      # round-trip on every call.
      @type = Ext.window_gamepad_type(window, id)
      caps = Ext.window_gamepad_caps(window, id)
      @cap_rumble          = caps & 0x1 != 0
      @cap_rumble_triggers = caps & 0x2 != 0
      @cap_led             = caps & 0x4 != 0

      # Per-button and per-axis presence is also cached at connect — one SDL
      # call per known enum, then `has?(:button, name)` / `has?(:axis, name)`
      # are pure hash reads. Cheap (~27 calls total) and matches the
      # "capability checks are cached at connect time" rule in USAGE.md.
      @btn_present  = BUTTON_ENUM.each_with_object({}) do |(sym, enum), h|
        h[sym] = Ext.window_gamepad_has_button(window, id, enum)
      end
      @axis_present = AXIS_ENUM.each_with_object({}) do |(sym, enum), h|
        h[sym] = Ext.window_gamepad_has_axis(window, id, enum)
      end

      # Frame-scoped event sets. Pressed/released/axes_moved are cleared by
      # `_clear_frame_state`; held is also cleared and refilled each frame
      # from the C-side held loop.
      @buttons_down  = []
      @buttons_up    = []
      @buttons_held  = []
      @axes_moved    = []

      # Sticky axis values populated by motion events.
      @axis_values = {}
      AXIS_NAMES.each { |a| @axis_values[a] = 0.0 }
      @raw_axis_values = @axis_values.dup
    end

    def connected? = @connected

    # Capability check. Forms:
    #   pad.has?(:rumble)
    #   pad.has?(:rumble_triggers)
    #   pad.has?(:led)
    #   pad.has?(:button, :paddle1)
    #   pad.has?(:axis, :left_trigger)
    def has?(capability, name = nil)
      return false unless @connected

      case capability
      when :rumble           then @cap_rumble
      when :rumble_triggers  then @cap_rumble_triggers
      when :led              then @cap_led
      when :button           then @btn_present[name]  || false
      when :axis             then @axis_present[name] || false
      else                        false
      end
    end

    # Battery — live query, since charge level changes during play. Returns
    # one of `:wired`, `:full`, `:medium`, `:low`, `:empty`, or `nil` when
    # SDL can't determine the state.
    def battery
      return nil unless @connected

      state, percent = Ext.window_gamepad_battery(@window, @id)
      case state
      when :wired then :wired
      when :on_battery
        case percent
        when -1 then :medium  # plugged into a battery slot but no level reported
        when 0..9 then :empty
        when 10..29 then :low
        when 30..74 then :medium
        else :full
        end
      end
    end

    # Polling — currently held / current axis position.
    def held?(button) = @buttons_held.include?(button)

    def axis(name, raw: false)
      return 0.0 unless AXIS_ENUM.key?(name)

      v = (raw ? @raw_axis_values : @axis_values)[name]
      v || 0.0
    end

    def buttons_held = @buttons_held.dup

    def axes
      AXIS_NAMES.each_with_object({}) { |a, h| h[a] = @axis_values[a] || 0.0 }
    end

    # Polling — frame-scoped transitions. Cleared each frame by
    # `_clear_frame_state`.
    def pressed?(button)  = @buttons_down.include?(button)
    def released?(button) = @buttons_up.include?(button)
    def axis_moved?(axis) = @axes_moved.include?(axis)
    def axes_moved        = @axes_moved.dup

    # Feedback. `rumble`, `rumble_triggers`, and `set_led` return `false` when
    # the pad is disconnected or the SDL call fails — never raise. `led=` is a
    # convenience alias of `set_led`; being a Ruby assignment it evaluates to the
    # assigned value, not the success Boolean, so use `set_led` when you need it.
    #
    # `rumble(strength:, duration:)` is the simple form; the low/high form
    # exposes the dual-motor pattern most pads expose.
    def rumble(strength: nil, low: nil, high: nil, duration: 0.2)
      return false unless @connected

      if strength
        low ||= strength
        high ||= strength
      end
      low  ||= 0.0
      high ||= 0.0
      Ext.window_gamepad_rumble(@window, @id, low.to_f, high.to_f, duration.to_f)
    end

    def rumble_triggers(left: 0.0, right: 0.0, duration: 0.2)
      return false unless @connected

      Ext.window_gamepad_rumble_triggers(@window, @id,
                   left.to_f, right.to_f, duration.to_f)
    end

    # Set the LED color from an `[r, g, b]` triple. Returns `false` on failure.
    def set_led(rgb)
      return false unless @connected
      r, g, b = rgb
      Ext.window_gamepad_set_led(@window, @id, r.to_i, g.to_i, b.to_i)
    end

    # Convenience setter form of `set_led`. As a Ruby assignment it returns the
    # assigned value, not the success Boolean — call `set_led` if you need that.
    def led=(rgb)
      set_led(rgb)
    end

    # Snapshot of the underlying joystick's raw input state — buttons,
    # axes (raw -32768..32767), and hats (SDL hat bitmask). Bypasses any
    # gamepad mapping. Intended for mapping-generation tools that need to
    # observe the physical hardware before SDL remaps it. Returns `nil`
    # when the pad is disconnected.
    def joystick_state
      return nil unless @connected

      arr = Ext.window_gamepad_joystick_state(@window, @id) or return nil
      { buttons: arr[0], axes: arr[1], hats: arr[2] }
    end

    # Read-only snapshot of low-level metadata SDL exposes about the pad —
    # useful when adding a custom mapping for an unrecognized device, or
    # diagnosing why a connected device behaves oddly. Returns `nil` when
    # the pad is disconnected.
    #
    # Keys:
    #   :guid           — 32-char SDL GUID hex string (the same string used
    #                     in `gamepads.txt` mapping entries)
    #   :vendor_id      — USB-style vendor ID (Integer; format as `%04x`)
    #   :product_id     — USB-style product ID (Integer; format as `%04x`)
    #   :version        — product version (Integer; format as `%04x`)
    #   :serial         — String, or nil if SDL has no serial for this pad
    #   :connection     — :wired, :wireless, or :unknown
    #   :real_type      — the underlying gamepad type before any user mapping
    #                     remaps it (:xbox / :playstation / :nintendo /
    #                     :generic / :unknown)
    #   :num_touchpads  — count of touchpad surfaces (PS4/PS5 = 1, most = 0)
    #   :mapping        — the resolved SDL gamepad mapping string, or nil
    def debug_info
      return nil unless @connected

      arr = Ext.window_gamepad_debug_info(@window, @id) or return nil
      {
        guid:          arr[0],
        vendor_id:     arr[1],
        product_id:    arr[2],
        version:       arr[3],
        serial:        arr[4],
        connection:    arr[5],
        real_type:     arr[6],
        num_touchpads: arr[7],
        mapping:       arr[8]
      }
    end

    # ----- Internal: dispatch hooks called from gamepad_callback -----

    def _apply_button_down(button)
      return unless @connected
      @buttons_down << button unless @buttons_down.include?(button)
      @buttons_held << button unless @buttons_held.include?(button)
    end

    def _apply_button_held(button)
      return unless @connected
      @buttons_held << button unless @buttons_held.include?(button)
    end

    def _apply_button_up(button)
      return unless @connected
      @buttons_up << button unless @buttons_up.include?(button)
      @buttons_held.delete(button)
    end

    # Returns the dead-zoned value (which is what handlers receive), or `nil`
    # if the value didn't move outside the dead-zoned region — letting the
    # caller suppress event emission for motion entirely inside the dead zone.
    def _apply_axis(axis, raw_value)
      return nil unless @connected
      return nil unless AXIS_ENUM.key?(axis)

      previous = @axis_values[axis] || 0.0
      dz = apply_dead_zone(axis, raw_value)

      @raw_axis_values[axis] = raw_value
      @axis_values[axis] = dz

      if dz != previous
        @axes_moved << axis unless @axes_moved.include?(axis)
        dz
      else
        nil
      end
    end

    def _clear_frame_state
      @buttons_down.clear
      @buttons_up.clear
      @buttons_held.clear
      @axes_moved.clear
    end

    def _disconnect
      @connected = false
      @buttons_down.clear
      @buttons_up.clear
      @buttons_held.clear
      @axes_moved.clear
      AXIS_NAMES.each do |a|
        @axis_values[a] = 0.0
        @raw_axis_values[a] = 0.0
      end
    end

    private

    def apply_dead_zone(axis, value)
      return value if @dead_zone <= 0.0 || TRIGGER_AXES.include?(axis)
      value.abs < @dead_zone ? 0.0 : value
    end
  end
end

# ---------- lib/ruby2d/window.rb ----------

# Ruby2D::Window

module Ruby2D
  # The application window
  class Window
    # Event structures
    EventDescriptor       = Struct.new(:type, :id)
    ObjectEventDescriptor = Struct.new(:object, :type, :id)
    MouseEvent            = Struct.new(:type, :button, :direction, :x, :y, :delta_x, :delta_y) do
      def button?(name) = button == name
      def position      = [x, y]
      def delta         = [delta_x, delta_y]
    end
    KeyEvent              = Struct.new(:type, :key) do
      def key?(name) = key == name.to_s.downcase
    end

    include KeyEvents
    include MouseEvents
    include GamepadEvents
    include ObjectEventDispatch
    extend ClassMethods

    attr_reader :title, :width, :height, :fps_cap, :fps, :frames, :delta_time,
                :background, :icon, :resizable,
                :highdpi, :pixel_scale,
                :viewport_width, :viewport_height, :viewport_mode,
                :render_mode,
                :mouse_x, :mouse_y, :diagnostics, :show_fps, :close_on_esc

    # Accepted `fps_cap` values, shared by the strict constructor check and the
    # lenient runtime setter so the two messages can't drift apart.
    FPS_CAP_VALUES = 'nil, a positive number, :infinity, or Float::INFINITY'

    # Recognized `viewport:` modes. The native parser silently falls back to
    # letterbox for anything else, so validate here to surface typos rather than
    # let `viewport_mode` report a value the renderer never applied. Must match
    # R2D_ParseViewportMode in ext/ruby2d/window.c.
    VIEWPORT_MODES = %i[letterbox stretch integer overscan expand fixed].freeze

    # Create a window
    def initialize(title: 'Ruby 2D', width: 640, height: 480, fps_cap: nil)
      # Ruby 2D is single-window by design: per-object events and the top-level
      # DSL all route through one shared `DSL.window`. A second window would
      # silently steal that pointer and strand the first window's objects and
      # event handlers, so refuse to create one.
      if Ruby2D::DSL.window?
        raise Error,
              'A window already exists. Ruby 2D supports a single window per ' \
              'process (it may have been created automatically on first use of ' \
              'a Window class method or the top-level DSL).'
      end

      # Title of the window
      @title = title

      # Window size
      @width  = width
      @height = height

      # Frames per second upper limit, and the actual FPS. Valid: nil (no cap),
      # a positive number, or Float::INFINITY (uncapped). The constructor is
      # strict; the runtime setter (#set) warns and falls back instead.
      fps_cap = normalize_fps_cap(fps_cap)
      unless fps_cap_valid?(fps_cap)
        raise Error, "fps_cap must be #{FPS_CAP_VALUES}, got #{fps_cap.inspect}"
      end
      @fps_cap = fps_cap
      @fps = 0

      # Total number of frames that have been rendered
      @frames = 0

      # Whether the frame loop is running, i.e. between `show` and the window
      # closing. Frame-scoped work like `screenshot` needs an end-of-frame to
      # land on, so it consults this rather than doing nothing at all.
      @running = false

      # Renderable objects currently in the window, like a linear scene graph
      @objects = []
      @object_set = {}

      init_window_defaults
      init_event_stores
      init_event_registrations
      init_procs_and_dsl

      Ext.window_create(self)

      Ruby2D::DSL.window = self
    end

    # Track window shown state in a class instance variable
    @shown = false

    class << self
      attr_reader :shown
      alias_method :shown?, :shown

      attr_writer :shown
    end

    def display_width
      Ext.window_get_display_dimensions(self)
      @display_width
    end

    def display_height
      Ext.window_get_display_dimensions(self)
      @display_height
    end

    def display_pixel_width
      Ext.window_get_display_dimensions(self)
      @display_pixel_width
    end

    def display_pixel_height
      Ext.window_get_display_dimensions(self)
      @display_pixel_height
    end

    # Get a window attribute by name. `:window` returns the Window itself (the
    # DSL escape hatch to the full API); any other symbol reads that attribute.
    def get(sym)
      case sym
      when :window then self
      else public_send(sym)
      end
    end

    # Set window attributes
    def set(opts)
      # Store new window attributes, or ignore if nil
      set_any_window_properties opts
      set_any_window_dimensions opts

      Ext.window_set_size(self) if Window.shown? && (opts[:width] || opts[:height])

      if Window.shown? && (opts[:viewport] || opts[:viewport_width] || opts[:viewport_height] || !opts[:pixel_scale].nil?)
        Ext.window_set_viewport_mode(self)
      end

      if opts.key?(:fps_cap)
        cap = normalize_fps_cap(opts[:fps_cap])
        if fps_cap_valid?(cap)
          @fps_cap = cap
        else
          Ruby2D.warn "fps_cap must be #{FPS_CAP_VALUES}, got #{opts[:fps_cap].inspect}; ignoring (no cap)."
          @fps_cap = nil
        end
        Ext.window_set_fps_cap(self, @fps_cap) if Window.shown?
      end

      unless opts[:render_mode].nil?
        unless %i[continuous on_demand].include?(opts[:render_mode])
          raise Error, "`render_mode` must be :continuous or :on_demand, got #{opts[:render_mode].inspect}"
        end
        @render_mode = opts[:render_mode]
        Ext.window_set_render_mode(self) if Window.shown?
      end

      @close_on_esc = opts[:close_on_esc] unless opts[:close_on_esc].nil?

      self.cursor = opts[:cursor] unless opts[:cursor].nil?

      unless opts[:show_fps].nil?
        @show_fps = opts[:show_fps]
        Ext.window_show_fps(self, @show_fps)
      end

      unless opts[:diagnostics].nil?
        @diagnostics = opts[:diagnostics]
        Ext.window_diagnostics(self, @diagnostics)
      end
    end

    # Add an object to the window
    def add(object)
      case object
      when nil
        raise Error, "Cannot add `#{object.class}` to window!"
      when Array
        object.each { |x| add_object(x) }
      else
        add_object(object)
      end
    end

    # Remove an object from the window
    def remove(object)
      raise Error, "Cannot remove `#{object.class}` from window!" if object.nil?
      return false unless @objects.delete(object)

      @object_set.delete(object)
      unregister_interactive(object)
      true
    end

    # Clear all objects from the window
    def clear
      @objects.clear
      @object_set.clear
      init_object_event_stores
    end

    # Set the update callback
    def update(&proc)
      raise Error, '`update` requires a block' unless proc
      @update_proc = proc
      # Cache whether the block takes a delta-time arg; the arity never changes
      # after assignment, so the per-frame loop reads this instead of recomputing.
      @update_wants_dt = !proc.arity.zero?
      true
    end

    # Set the render callback. `z:` places the block in the scene's z-order:
    # `:foreground` (default) draws it on top of every object, `:background`
    # behind them, or a number interleaves it at that depth on the same scale
    # as object `z` (objects with `z` at or below it draw first, then the
    # block, then the rest).
    def render(z: :foreground, &proc)
      raise Error, '`render` requires a block' unless proc
      @render_proc = proc
      @render_z = render_z_for(z)
      true
    end

    # Monotonic seconds since engine start — a cross-platform, overflow-safe
    # clock for cooldowns, scheduling, and "time since" math. Unlike `Time.now`
    # it never jumps or jitters, and reads the same on CRuby and mruby/web.
    # For per-frame motion, prefer the `dt` argument to `update`.
    def elapsed
      Ext.now
    end

    # Maps event types to the predicate used in the kwarg form of `on` —
    # e.g. `on key_down: :escape` filters via `event.key?(:escape)`. For
    # gamepad events the entries map to the *primary* predicate (the one a
    # bare scalar matcher targets); hash matchers like
    # `{ gamepad: pad1, button: :south }` derive the predicate from each key.
    EVENT_FILTER_PREDICATES = {
      key_down: :key?, key_held: :key?, key_up: :key?,
      mouse_down: :button?, mouse_held: :button?, mouse_up: :button?,
      gamepad_button_down: :button?, gamepad_button_held: :button?,
      gamepad_button_up:   :button?, gamepad_axis: :axis?
    }.freeze

    # Gamepad events dispatch an internal data struct, but user blocks
    # receive the unpacked args (gamepad / button / axis / value). This map
    # describes the unpack for each gamepad event type.
    GAMEPAD_EVENT_UNPACK = {
      gamepad_connect:     ->(d) { [d.gamepad] },
      gamepad_disconnect:  ->(d) { [d.gamepad] },
      gamepad_button_down: ->(d) { [d.gamepad, d.button] },
      gamepad_button_held: ->(d) { [d.gamepad, d.button] },
      gamepad_button_up:   ->(d) { [d.gamepad, d.button] },
      gamepad_axis:        ->(d) { [d.gamepad, d.axis, d.value] }
    }.freeze

    # Set an event handler. Forms:
    #
    #   on(:key_down) { |event| ... }                              # all events of type
    #   on(key_down: :escape) { ... }                              # filtered by value
    #   on(key_down: [:left, :a]) { ... }                          # array → match any
    #   on(key_down: :left, gamepad_button_down: :dpad_left) { }   # multi-event
    #   on(gamepad_button_down: { gamepad: pad1, button: :south }) # hash → AND match
    def on(event = nil, **filters, &proc)
      raise Error, '`on` requires a block' unless proc
      if event.is_a?(Symbol) && filters.empty?
        register_event_handler(event, wrap_for_event(event, proc))
      elsif event.nil? && !filters.empty?
        descriptors = filters.map do |type, matcher|
          register_event_handler(type, build_filter_wrapper(type, matcher, proc))
        end
        descriptors.size == 1 ? descriptors.first : descriptors
      else
        raise Error, '`on` requires either an event symbol or event filters'
      end
    end

    private def register_event_handler(event, proc)
      raise Error, "`#{event}` is not a valid event type" unless @events.key? event

      # Only one close handler is allowed; registering a new one replaces the old
      @events[:close].clear if event == :close

      event_id = new_event_key
      @events[event][event_id] = proc
      EventDescriptor.new(event, event_id)
    end

    # Wrap a user proc for direct (no-filter) registration. Gamepad events
    # unpack the dispatch struct into multi-arg form; everything else passes
    # the event struct straight through.
    private def wrap_for_event(type, proc)
      unpack = GAMEPAD_EVENT_UNPACK[type]
      return proc unless unpack

      ->(d) { proc.call(*unpack.call(d)) }
    end

    # Wrap a user proc with a filter matcher. Hash matchers AND every
    # `key?(value)` predicate; scalar/array matchers fall through to the
    # event type's primary predicate. Gamepad event handlers also unpack
    # the dispatch struct into multi-arg form.
    private def build_filter_wrapper(type, matcher, proc)
      unpack = GAMEPAD_EVENT_UNPACK[type]
      args = unpack ? ->(e) { unpack.call(e) } : ->(e) { [e] }

      if matcher.is_a?(Hash)
        unless unpack
          raise Error, "`#{type}` does not support hash filters with `on event: { ... }`"
        end
        ->(e) {
          if matcher.all? { |k, v| e.send(:"#{k}?", v) }
            proc.call(*args.call(e))
          end
        }
      else
        predicate = EVENT_FILTER_PREDICATES[type] or
          raise Error, "`#{type}` does not support filtering with `on event: value`"
        values = Array(matcher)
        ->(e) {
          if values.any? { |v| e.send(predicate, v) }
            proc.call(*args.call(e))
          end
        }
      end
    end

    # Remove an event handler (or several). Accepts a descriptor returned by
    # `on`, or an array of them (as `on` returns when given multiple filters).
    def off(event_descriptor)
      return event_descriptor.each { |d| off(d) } if event_descriptor.is_a?(Array)

      case event_descriptor
      when ObjectEventDescriptor
        event_descriptor.object.off(event_descriptor)
      when EventDescriptor
        @events[event_descriptor.type].delete(event_descriptor.id)
      else
        raise Error,
              "Cannot remove event handler: expected a descriptor returned by `on`, got #{event_descriptor.inspect}"
      end
    end

    # Update callback method, called by the native and web extentions
    def update_callback
      # Monotonic seconds since the previous update. Clamped to 0.1s so a paused
      # window or stalled frame doesn't teleport the simulation when updates
      # resume; zero on the first frame. `Ext.now` (SDL_GetTicksNS, and
      # performance.now on web) is the single clock used on every runtime — the
      # same source as the public `elapsed`. A wall clock like Time.now would
      # jitter and stutter dt-scaled motion.
      now = Ext.now
      if @last_update_time
        dt = now - @last_update_time
        @delta_time = dt > 0.1 ? 0.1 : dt
      else
        @delta_time = 0.0
      end
      @last_update_time = now

      update if @overrides_update

      if @update_wants_dt
        @update_proc.call(@delta_time)
      else
        @update_proc.call
      end

      # Frame-scoped polling state (pressed/released, axes_moved, scroll/move
      # flags) lives one frame and is cleared here every tick — independent of
      # whether the user is on the DSL or class pattern, so both can poll.
      clear_event_stores
    end

    # Iterate the z-sorted scene graph and render each visible object, splicing
    # the user's render block into the same z-order at `@render_z`: objects with
    # `z` at or below it draw first, then the block, then the rest. The default
    # `:foreground` (+∞) draws the block last, on top of everything; `:background`
    # (-∞) draws it first. Called from the native extension once per frame via
    # `tick`. Each object draws via its zero-arg `_render_scene` hook, not the
    # public keyword `render`: on wasm mruby a zero-arg call into a
    # keyword-heavy method still pays ~5µs of keyword setup, so 100 sprites
    # would burn half a millisecond per frame on pure dispatch.
    def render_objects
      # Fast paths for the symbolic block positions: with the block pinned at
      # +∞ (`:foreground`, the default) or -∞ (`:background`) no object can
      # ever sort after (resp. before) it, so the per-object `z` read and
      # compare in the interleaving loop below could never fire — skip them.
      if @render_z == Float::INFINITY
        @objects.each { |obj| obj._render_scene if obj.visible? }
        render_callback
      elsif @render_z == -Float::INFINITY
        render_callback
        @objects.each { |obj| obj._render_scene if obj.visible? }
      else
        block_drawn = false
        @objects.each do |obj|
          if !block_drawn && obj.z > @render_z
            render_callback
            block_drawn = true
          end
          obj._render_scene if obj.visible?
        end
        render_callback unless block_drawn
      end
    end

    # Run the user's render block (and the overridden `render` method under the
    # class pattern). Spliced into the scene by `render_objects`.
    def render_callback
      render if @overrides_render

      @render_proc.call
    end

    # Close callback method, called by the native extension
    def close_callback
      @events[:close].each_value(&:call)
    end

    # One frame: poll events, update, render.
    def tick
      Ext.poll_events(self)
      # drain_events returns nil (not an empty array) on event-less frames
      raw = Ext.drain_events(self)
      dispatch_events(raw) if raw

      update_callback

      if Ext.begin_frame(self)
        render_objects
      end

      Ext.end_frame(self)
    end

    # Show the window
    def show
      raise Error, 'Window#show called multiple times; Ruby 2D supports a single window per process' if Window.shown?

      @close = false
      load_default_gamepad_mappings

      if RUBY_ENGINE == 'ruby'
        # CRuby: window_show creates the window and returns — Ruby owns the loop.
        # Mark shown only after it succeeds; on failure it raises, so shown? stays
        # false and no frame dereferences a NULL renderer.
        Ext.window_show(self)
        Window.shown = true
        @running = true
        tick until @close
      else
        # mruby/WASM: window_show creates the window AND runs the loop, blocking
        # until close. Mark shown first so live updates (request_render, set title,
        # etc.) work during the run; a creation failure raises before the loop.
        Window.shown = true
        @running = true
        Ext.window_show(self)
      end

      @running = false
    end

    # Take a screenshot, saving to `path` (or a timestamped file if omitted).
    #
    # The write is deferred to the end of the current frame, after the scene is
    # drawn but before it is presented, so the capture is this frame rather than
    # the last one. `path` therefore comes back before the file exists; it lands
    # by the time the next `update` runs. Requesting one also forces the frame to
    # render, so a capture in `:on_demand` mode never grabs a parked frame, and
    # capturing and closing in the same tick still writes the file.
    #
    # A closed window has no end-of-frame left to write on, so that raises rather
    # than returning a path to a file that will never appear.
    #
    # A no-op on the web, returning nil: the only filesystem there is Emscripten's
    # in-memory one, so a capture would cost a framebuffer read and a PNG encode
    # to produce a file nobody can open, and that vanishes on reload.
    def screenshot(path = nil)
      return if Ruby2D.web?

      if Window.shown? && !@running
        raise Error, '`screenshot` called after the window closed; the file is ' \
                     'written at the end of a frame, so nothing would be saved'
      end

      path ||= "./screenshot-#{Time.now.utc.strftime('%Y-%m-%d--%H-%M-%S')}.png"
      Ext.window_screenshot(self, path)
    end

    # Get the current cursor state
    def cursor
      return :hidden unless Ext.window_cursor_visible(self)

      @cursor_style || :default
    end

    # Set the cursor: `:visible`, `:hidden`, or a system cursor name
    def cursor=(name)
      case name
      when :visible
        @cursor_style = :default
        Ext.window_show_cursor(self)
      when :hidden
        @cursor_style = nil
        Ext.window_hide_cursor(self)
      else
        name = name.to_sym
        @cursor_style = name
        Ext.window_set_system_cursor(self, name.to_s)
      end
    end

    # Close the window. A no-op on the web, where a page can't close itself —
    # only the person viewing it can — so there's nothing to shut down: the
    # `:close` handler doesn't fire, the window isn't marked closed, and the
    # loop keeps running. The user's own quit still arrives as a `:close`
    # event, which is handled in the event loop rather than here.
    def close
      return if Ruby2D.web?

      close_callback
      Ext.window_close(self)
      @close = true
    end

    # Request that the next tick render a frame. No-op in :continuous mode.
    # Safe to call from any thread.
    def request_render
      Ext.window_request_render(self) if Window.shown?
    end

    # Private instance methods

    private

    # Resolve a render-block `z:` to a numeric depth. `:foreground` puts the
    # block on top of every object, `:background` behind them; a number places
    # it at that depth on the same scale as object `z`.
    def render_z_for(z)
      case z
      when :foreground then Float::INFINITY
      when :background then -Float::INFINITY
      when Numeric then z
      else
        raise Error, "render `z:` must be a number, :foreground, or :background, got #{z.inspect}"
      end
    end

    # Event buffer stride and category/type constants (match C-side defines)
    EVT_STRIDE  = 12
    EVT_KEY     = 1
    EVT_MOUSE   = 2
    EVT_GAMEPAD = 3
    EVT_CLOSE   = 4

    KEY_TYPE_MAP   = { 1 => :down, 2 => :held, 3 => :up }.freeze
    MOUSE_TYPE_MAP = { 1 => :down, 2 => :up, 3 => :scroll, 4 => :move,
                       5 => :held, 6 => :enter, 7 => :leave }.freeze
    MOUSE_BTN_MAP  = { 1 => :left, 2 => :middle, 3 => :right, 4 => :x1, 5 => :x2 }.freeze
    SCROLL_DIR_MAP = { 0 => :normal, 1 => :inverted }.freeze
    GP_AXIS_MAP    = { 0 => :left_x, 1 => :left_y, 2 => :right_x, 3 => :right_y,
                       4 => :left_trigger, 5 => :right_trigger }.freeze
    GP_BUTTON_MAP  = { 0 => :south, 1 => :east, 2 => :west, 3 => :north,
                       4 => :back, 5 => :guide, 6 => :start,
                       7 => :left_stick, 8 => :right_stick,
                       9 => :left_shoulder, 10 => :right_shoulder,
                       11 => :dpad_up, 12 => :dpad_down,
                       13 => :dpad_left, 14 => :dpad_right,
                       15 => :misc1, 16 => :paddle1, 17 => :paddle2,
                       18 => :paddle3, 19 => :paddle4, 20 => :touchpad,
                       21 => :misc2, 22 => :misc3, 23 => :misc4,
                       24 => :misc5, 25 => :misc6 }.freeze

    def dispatch_events(raw)
      i = 0
      while i < raw.size
        cat = raw[i]
        case cat
        when EVT_KEY
          key_callback(KEY_TYPE_MAP[raw[i + 1]], key_name(raw[i + 2]))
        when EVT_MOUSE
          mouse_callback(
            MOUSE_TYPE_MAP[raw[i + 1]], MOUSE_BTN_MAP[raw[i + 3]],
            SCROLL_DIR_MAP[raw[i + 4]],
            raw[i + 6], raw[i + 7], raw[i + 8], raw[i + 9]
          )
        when EVT_GAMEPAD
          gp_type = raw[i + 1]
          gp_id   = raw[i + 2]
          case gp_type
          when 1 then gamepad_callback(gp_id, :connect, nil, nil, raw[i + 11])
          when 2 then gamepad_callback(gp_id, :disconnect, nil, nil, nil)
          when 3
            axis_sym = GP_AXIS_MAP[raw[i + 5]]
            raw_val  = raw[i + 10]
            value    = raw_val > 0 ? raw_val / 32767.0 : raw_val / 32768.0
            gamepad_callback(gp_id, :axis, axis_sym, value, nil)
          when 4 then gamepad_callback(gp_id, :button_down, GP_BUTTON_MAP[raw[i + 3]], nil, nil)
          when 5 then gamepad_callback(gp_id, :button_up, GP_BUTTON_MAP[raw[i + 3]], nil, nil)
          when 6 then gamepad_callback(gp_id, :button_held, GP_BUTTON_MAP[raw[i + 3]], nil, nil)
          end
        when EVT_CLOSE
          close_callback
          Ext.window_close(self)
          @close = true
        end
        i += EVT_STRIDE
      end
    end

    # Fire every handler registered for `type`, building a fresh event object
    # per handler via the block (a handler may mutate the event it receives, so
    # handlers don't share one). Skips the values-array allocation when no
    # handlers are registered — the common case on per-event hot paths, where
    # it costs ~1µs per empty event type on wasm mruby.
    def fire_event_handlers(type)
      handlers = @events[type]
      return if handlers.empty?

      handlers.values.each { |e| e.call(yield) }
    end

    # Resolve an SDL scancode to its cached, frozen, lowercased name. The
    # held-key path sends only the integer scancode each frame; the name is
    # looked up (and downcased + frozen) once per distinct key and reused, so
    # no per-frame key-name string is allocated.
    def key_name(code)
      @key_names[code] ||= Ext.scancode_name(code).downcase.freeze
    end

    # Generate a new event key (ID)
    def new_event_key
      @event_key += 1
    end

    # Add an object to the window, used by the public `add` method
    def add_object(object)
      return false if @object_set.key?(object)

      index = @objects.bsearch_index { |obj| obj.z > object.z }
      @objects.insert(index || @objects.size, object)
      @object_set[object] = true

      # Re-register for correct z-order if the object is interactive
      if object.respond_to?(:interactive?) && object.interactive?
        @interactive_objects.delete(object)
        register_interactive(object)
      end

      true
    end

    def set_any_window_properties(opts)
      @background = Color.new(opts[:background]) if Color.valid? opts[:background]
      if opts[:title]
        @title = opts[:title]
        Ext.window_set_title(self) if Window.shown?
      end
      if opts[:icon]
        @icon = opts[:icon]
        Ext.window_set_icon(self) if Window.shown?
      end
      unless opts[:resizable].nil?
        @resizable = opts[:resizable]
        Ext.window_set_resizable(self) if Window.shown?
      end
    end

    def set_any_window_dimensions(opts)
      # Before `show`, the viewport auto-follows width/height (its documented
      # default of "same as width/height"). After `show`, a bare `set width:` is
      # a live resize: leave the fixed logical viewport alone so it letterboxes
      # into the new window size instead of being silently overwritten. Only
      # `:expand` tracks the window on resize, and that is handled C-side.
      if opts[:width]
        @width = opts[:width]
        @viewport_width = @width unless opts[:viewport_width] || Window.shown?
      end
      if opts[:height]
        @height = opts[:height]
        @viewport_height = @height unless opts[:viewport_height] || Window.shown?
      end
      @viewport_width  = opts[:viewport_width]  if opts[:viewport_width]
      @viewport_height = opts[:viewport_height] if opts[:viewport_height]
      if opts[:viewport]
        unless VIEWPORT_MODES.include?(opts[:viewport])
          raise Error, "Invalid viewport mode #{opts[:viewport].inspect}; expected one of #{VIEWPORT_MODES.inspect}"
        end
        @viewport_mode = opts[:viewport]
      end
      # highdpi is baked into the native window at creation and re-read once at
      # `show`; it cannot change afterward. Keep the reader honest — never mutate
      # @highdpi post-show — and warn only when the call would actually differ.
      unless opts[:highdpi].nil?
        if Window.shown?
          if opts[:highdpi] != @highdpi
            Ruby2D.warn 'highdpi is fixed when the window is created and cannot change after `show`; ignoring.'
          end
        else
          @highdpi = opts[:highdpi]
        end
      end
      @pixel_scale     = opts[:pixel_scale] unless opts[:pixel_scale].nil?
    end

    # The symbol :infinity is an ergonomic alias for Float::INFINITY (uncapped);
    # normalize it so the rest of the pipeline only sees nil / number / INFINITY.
    def normalize_fps_cap(value)
      value == :infinity ? Float::INFINITY : value
    end

    # A valid (normalized) fps_cap is nil (no cap) or a positive number —
    # including Float::INFINITY, which is positive. 0, negatives, NaN, and other
    # types are rejected.
    def fps_cap_valid?(value)
      value.nil? || (value.is_a?(Numeric) && value > 0)
    end

    def clear_event_stores
      @keys_down.clear
      @keys_held.clear
      @keys_up.clear
      @mouse_buttons_down.clear
      @mouse_buttons_up.clear
      @mouse_buttons_held.clear
      @mouse_scroll_event     = false
      @mouse_scroll_direction = nil
      @mouse_scroll_delta_x   = 0
      @mouse_scroll_delta_y   = 0
      @mouse_move_event   = false
      @mouse_move_delta_x = 0
      @mouse_move_delta_y = 0
      clear_gamepad_frame_state
    end

    def init_window_defaults
      # Window background color
      @background = Color.new([0.0, 0.0, 0.0, 1.0])

      # Window icon
      @icon = nil

      # Window characteristics
      @resizable = false
      @highdpi = true
      @pixel_scale = false

      # Size of the window's viewport (the drawable area)
      @viewport_width = @width
      @viewport_height = @height

      # Viewport scaling mode for resizable windows
      @viewport_mode = :letterbox

      # Render mode: :continuous renders every tick up to fps_cap; :on_demand
      # only renders when request_render is called or the OS signals a redraw.
      @render_mode = :continuous

      # Size of the computer's display
      @display_width = nil
      @display_height = nil
      @display_pixel_width = nil
      @display_pixel_height = nil
    end

    def init_event_stores
      init_key_event_stores
      init_mouse_event_stores
      init_gamepad_event_stores
      init_object_event_stores
    end

    def init_event_registrations
      # Mouse X and Y position in the window
      @mouse_x = 0
      @mouse_y = 0

      # Unique ID for the input event being registered
      @event_key = 0

      # Registered input events
      @events = {
        key: {},
        key_down: {},
        key_held: {},
        key_up: {},
        mouse: {},
        mouse_up: {},
        mouse_down: {},
        mouse_held: {},
        mouse_scroll: {},
        mouse_move: {},
        mouse_enter: {},
        mouse_leave: {},
        gamepad_connect: {},
        gamepad_disconnect: {},
        gamepad_button_down: {},
        gamepad_button_held: {},
        gamepad_button_up: {},
        gamepad_axis: {},
        close: {}
      }
    end

    def init_procs_and_dsl
      # The window update block
      @update_proc = proc {}
      @update_wants_dt = false

      # The window render block, and where it sits in the z-order (see `render`)
      @render_proc = proc {}
      @render_z = Float::INFINITY

      # Per-frame delta-time state, populated each `update_callback`.
      @last_update_time = nil
      @delta_time = 0.0

      # Detect the "class pattern": a Window subclass overriding `update` and/or
      # `render`. Each is detected independently so overriding only one still
      # works — an overridden `update` runs even when `render` is left alone, and
      # vice versa. The base `update`/`render` are the DSL setters defined on
      # Ruby2D::Window, so an un-overridden method finds that owner and is
      # skipped in the frame loop (its DSL proc still runs).
      @overrides_update = overrides?(:update)
      @overrides_render = overrides?(:render)

      # Whether diagnostic messages should be printed
      @diagnostics = false
      @show_fps = false
      @close_on_esc = false
    end

    # Whether `name` (`:update` or `:render`) is a class-pattern override rather
    # than Ruby 2D's own DSL setter.
    #
    # This asks which *class* in the ancestry defines the method, skipping any
    # module Window itself drags along. A module prepended to Window fronts the
    # setter the same way a subclass override does, so reading the immediate
    # owner would mistake instrumentation — wrapping `update` to count frames or
    # hook a screenshot into someone else's app — for the class pattern, and
    # call the setter with no block every frame, which raises. A module mixed
    # into a subclass still counts: that side of the chain is the user's own
    # code, so an `update` there is an override like any other.
    def overrides?(name)
      wrappers = Window.ancestors - [Window]
      owner = self.class.ancestors.find do |mod|
        !wrappers.include?(mod) && mod.instance_methods(false).include?(name)
      end
      owner != Window
    end
  end
end

# ---------- lib/ruby2d/interactive.rb ----------

# Ruby2D::Interactive

module Ruby2D
  # Per-object event handling for objects that participate in Window's
  # interactive registry. Provides `on` / `off` / `interactive?` and the
  # `_fire_event` dispatch entry point. Mixed into `Renderable` and `Button`.
  #
  # Including objects must expose `x`, `y`, `z`, `width`, `height`, and
  # `contains?(x, y)` so `Window::ObjectEventDispatch` can hit-test them.
  module Interactive
    # Per-object events that take a value matcher (button) in the kwarg form.
    # `:hover`, `:hover_out`, and `:mouse_scroll` carry no matchable field.
    OBJECT_EVENT_FILTER_PREDICATES = {
      mouse_down: :button?, mouse_held: :button?, mouse_up: :button?,
      click: :button?, drag: :button?
    }.freeze

    # The full per-object event vocabulary: the filterable events above plus the
    # three that carry no matchable field. Derived from the predicates map so the
    # two can't drift, and mirrors what Window::ObjectEventDispatch fires.
    OBJECT_EVENTS = (OBJECT_EVENT_FILTER_PREDICATES.keys + %i[hover hover_out mouse_scroll]).freeze

    # Register a per-object event handler. Two forms:
    #
    #   obj.on(:click) { |event| ... }
    #   obj.on(click: :left) { ... }                   # filtered
    #   obj.on(click: [:left, :right]) { ... }         # array → match any
    #   obj.on(mouse_down: :left, click: :left) { ... }  # multi-event
    def on(event = nil, **filters, &proc)
      raise Error, '`on` requires a block' unless proc
      if event.is_a?(Symbol) && filters.empty?
        raise Error, "`#{event}` is not a valid object event" unless OBJECT_EVENTS.include?(event)
        register_object_event_handler(event, proc)
      elsif event.nil? && !filters.empty?
        descriptors = filters.map do |type, matcher|
          predicate = OBJECT_EVENT_FILTER_PREDICATES[type] or
            raise Error, "`#{type}` does not support filtering with `on event: value`"
          values = Array(matcher)
          wrapped = ->(e) { proc.call(e) if values.any? { |v| e.send(predicate, v) } }
          register_object_event_handler(type, wrapped)
        end
        descriptors.size == 1 ? descriptors.first : descriptors
      else
        raise Error, '`on` requires either an event symbol or event filters'
      end
    end

    # Remove a per-object event handler (or several, given an array).
    def off(descriptor)
      return descriptor.each { |d| off(d) } if descriptor.is_a?(Array)

      unless descriptor.is_a?(Window::ObjectEventDescriptor)
        raise Error,
              "Cannot remove event handler: expected a descriptor returned by `on`, got #{descriptor.inspect}"
      end

      return unless @_object_events

      handlers = @_object_events[descriptor.type]
      return unless handlers

      handlers.delete(descriptor.id)
      @_object_events.delete(descriptor.type) if handlers.empty?

      Window.unregister_interactive(self) unless interactive?
    end

    # Check if this object has any event handlers
    def interactive?(event = nil)
      return false unless @_object_events

      if event
        @_object_events.key?(event) && !@_object_events[event].empty?
      else
        @_object_events.any? { |_type, handlers| !handlers.empty? }
      end
    end

    # Dispatch an event to stored handlers (called by Window)
    def _fire_event(type, event)
      return unless @_object_events

      handlers = @_object_events[type]
      return unless handlers

      # Snapshot the values: a handler may register another handler for the same
      # event type mid-dispatch, which would otherwise mutate the hash we're
      # iterating ("can't add a new key into hash during iteration").
      handlers.values.each { |proc| proc.call(event) }
    end

    private

    def register_object_event_handler(event, proc)
      @_object_events ||= {}
      @_object_events[event] ||= {}
      id = (@_object_event_key = (@_object_event_key || 0) + 1)
      @_object_events[event][id] = proc
      Window.register_interactive(self)
      Window::ObjectEventDescriptor.new(self, event, id)
    end
  end
end

# ---------- lib/ruby2d/renderable.rb ----------

# Ruby2D::Renderable

module Ruby2D
  # Shared behavior for all renderable objects
  module Renderable
    # Per-object event handling (`on` / `off` / `interactive?` / `_fire_event`).
    include Interactive

    # Resolve an input color to a single Color. If given a per-vertex array or
    # Color::Set, returns the first color. nil returns nil. Used to derive a
    # single stroke color from a fill that may be per-vertex.
    def self.resolve_single_color(input)
      return nil if input.nil?
      c = Color.set(input)
      c.is_a?(Color::Set) ? Color.new(c.first) : c
    end

    # Resolve an input color allowing a Color::Set of exactly `vertex_count`
    # entries or a single color. nil returns white. Raises ArgumentError for
    # a Color::Set of the wrong length. Used by shapes that support per-vertex
    # gradients along their outline or fill.
    def self.resolve_color_or_default(input, vertex_count, label: nil)
      return Color.new('white') if input.nil?
      c = Color.set(input)
      if c.is_a?(Color::Set) && c.length != vertex_count
        prefix = label ? "`#{label}` " : ''
        raise ArgumentError,
              "#{prefix}requires #{vertex_count} colors, one for each vertex. #{c.length} were given."
      end
      c
    end

    # Normalize any color input into a flat RGBA array with `vertices` entries.
    # Accepts names, hex, [r,g,b,a], Color, Color::Set, per-vertex arrays, or nil
    # (which defaults to white). `opacity`, if given, overrides the alpha of each
    # vertex. `label:` optionally supplies a class label used in the error message.
    # Used by class-level `.render` methods.
    def self.flatten_color(input, vertices, opacity = nil, label: nil)
      fast = flatten_per_vertex(input, vertices, opacity)
      return fast if fast

      # `for_render`'s shared cached instance is safe here: this method only
      # reads the color into a flat float array, so it can never escape.
      c = Color.for_render(input.nil? ? 'white' : input)
      flatten_resolved_color(c, vertices, opacity, label: label)
    end

    # Validate an array of `[x, y]` pairs and flatten it to a flat float
    # array in one pass. Replaces an `all?` validation followed by a
    # `flat_map`, which walked the points twice and allocated a throwaway
    # pair per vertex; on a per-frame `.render` of a few thousand points that
    # overhead is comparable to the draw itself. `while`, not blocks — this
    # is a per-draw-call path and block calls dominate on wasm mruby.
    def self.flatten_points(points)
      n = points.length
      coords = Array.new(n * 2)
      i = 0
      while i < n
        point = points[i]
        raise ArgumentError, 'points must be an array of [x, y] pairs' \
          unless point.is_a?(Array) && point.length == 2

        coords[i * 2] = point[0].to_f
        coords[i * 2 + 1] = point[1].to_f
        i += 1
      end
      coords
    end

    # Flatten a per-vertex color array straight into the `vertices`×4 float
    # array, skipping `Color::Set` entirely. The general path builds a Set,
    # which allocates and parses one `Color` per vertex via `Color.new` —
    # bypassing the render cache that makes the single-color path cheap. A
    # per-frame `.render` pays that in full every frame, and for the hex
    # strings the examples favor it is the most expensive color form there
    # is. Numeric tuples are read directly; everything else resolves through
    # `Color.for_render`, whose shared instance is safe here because it is
    # read into floats immediately and never stored.
    #
    # Returns `nil` — falling back to the general path — for anything
    # unusual: a mismatched length, an out-of-range channel, an element that
    # isn't a valid color. Those still raise and warn from the one place
    # below, so this stays a pure fast path and never the error authority.
    def self.flatten_per_vertex(input, vertices, opacity)
      return nil unless input.is_a?(Array) && input.length == vertices && vertices.positive?
      # A flat `[r, g, b(, a)]` is a single color for every vertex, not a
      # list of them — its first element is the only Numeric case here.
      return nil if input[0].is_a?(Numeric)
      return nil if opacity.is_a?(Array) && opacity.length != vertices

      opacity_array = opacity.is_a?(Array)
      flat = Array.new(vertices * 4)
      i = 0
      while i < vertices
        el = input[i]
        if el.instance_of?(Array)
          # `instance_of?` mirrors `Color.valid?` — an Array subclass is not
          # the plain-array form and must take the general path.
          n = el.length
          return nil unless n == 3 || n == 4

          r = el[0]
          g = el[1]
          b = el[2]
          a = n == 4 ? el[3] : 1.0
          return nil unless r.is_a?(Numeric) && g.is_a?(Numeric) &&
                            b.is_a?(Numeric) && a.is_a?(Numeric)
          # Out of range is `Color#channel`'s business: it warns and clamps.
          return nil unless r >= 0.0 && r <= 1.0 && g >= 0.0 && g <= 1.0 &&
                            b >= 0.0 && b <= 1.0 && a >= 0.0 && a <= 1.0

          r = r.to_f
          g = g.to_f
          b = b.to_f
          a = a.to_f
        elsif el.is_a?(Color)
          r = el.r
          g = el.g
          b = el.b
          a = el.a
        else
          # Validate first so an invalid element still raises from the
          # general path, with the message it has always produced.
          return nil unless Color.valid?(el)

          c = Color.for_render(el)
          r = c.r
          g = c.g
          b = c.b
          a = c.a
        end

        j = i * 4
        flat[j] = r
        flat[j + 1] = g
        flat[j + 2] = b
        flat[j + 3] = (opacity_array ? opacity[i] : opacity) || a
        i += 1
      end
      flat
    end

    # Flatten an already-resolved `Color`/`Color::Set` into the `vertices`×4
    # float array. Split from `flatten_color` so the immediate-mode `.render`
    # paths can resolve the color once — to choose the single-color fast path —
    # without parsing it a second time when they fall back to the per-vertex array.
    def self.flatten_resolved_color(c, vertices, opacity = nil, label: nil)
      if c.is_a?(Color::Set) && c.length != vertices
        prefix = label ? "`#{label}` " : ''
        raise ArgumentError,
              "#{prefix}requires #{vertices} colors, one for each vertex. #{c.length} were given."
      end
      if opacity.is_a?(Array) && opacity.length != vertices
        prefix = label ? "`#{label}` " : ''
        raise ArgumentError,
              "#{prefix}requires #{vertices} opacity values, one for each vertex. #{opacity.length} were given."
      end

      flat = Array.new(vertices * 4)
      opacity_array = opacity.is_a?(Array)
      vertices.times do |i|
        col = c.vertex(i)
        flat[i * 4]     = col.r
        flat[i * 4 + 1] = col.g
        flat[i * 4 + 2] = col.b
        flat[i * 4 + 3] = (opacity_array ? opacity[i] : opacity) || col.a
      end
      flat
    end

    attr_reader :x, :y, :z, :width, :height, :color, :x_align, :y_align
    attr_accessor :visible,
                  :padding_top, :padding_right, :padding_bottom, :padding_left
    alias_method :visible?, :visible

    # Set all four padding edges to the same value. Padding is the distance,
    # in pixels, between the object and the window edge it's anchored to.
    # No effect on `:center`-aligned axes or un-aligned axes.
    def padding=(value)
      @padding_top = @padding_right = @padding_bottom = @padding_left = value
    end

    # Set horizontal alignment intent (`:left`, `:center`, `:right`, or `nil`).
    # Resolution is deferred to draw time against `Window.viewport_width`.
    def x_align=(sym)
      @x_align = sym&.to_sym
    end

    # Set vertical alignment intent (`:top`, `:center`, `:bottom`, or `nil`).
    # Resolution is deferred to draw time against `Window.viewport_height`.
    def y_align=(sym)
      @y_align = sym&.to_sym
    end

    # Resolve symbolic alignment to numeric x/y. Called from the render path of
    # each shape that opts into alignment. Requires the window to be open —
    # `Window.viewport_width` and `viewport_height` are only correct after
    # `show` starts. The `case` computes a bounding-box top-left position;
    # `_alignment_anchor_dx`/`_dy` then shift it to the shape's own anchor
    # (zero for top-left shapes, half-extent for center-anchored Circle/Ellipse).
    def _resolve_alignment
      return unless @x_align || @y_align

      dx = _alignment_anchor_dx
      dy = _alignment_anchor_dy
      @_resolving_alignment = true
      begin
        if @x_align
          span = Window.viewport_width
          self.x = (case @x_align
                    when :left   then (@padding_left || 0)
                    when :center then (span - width) / 2.0
                    when :right  then span - width - (@padding_right || 0)
                    else raise ArgumentError, "Unknown x alignment: #{@x_align.inspect}"
                    end) + dx
        end
        if @y_align
          span = Window.viewport_height
          self.y = (case @y_align
                    when :top    then (@padding_top || 0)
                    when :center then (span - height) / 2.0
                    when :bottom then span - height - (@padding_bottom || 0)
                    else raise ArgumentError, "Unknown y alignment: #{@y_align.inspect}"
                    end) + dy
        end
      ensure
        @_resolving_alignment = false
      end
    end

    # Offset from the bounding-box top-left (what `_resolve_alignment` computes)
    # to the shape's position anchor, split into x/y components to avoid boxing a
    # throwaway pair each aligned frame. Top-left-anchored shapes (Rectangle,
    # Image, Text, …) need none; center-anchored shapes override to half their
    # extent so `:left` hugs the wall with the bounding box, like a rectangle.
    def _alignment_anchor_dx
      0
    end

    def _alignment_anchor_dy
      0
    end

    # Resolve construction-time padding kwargs into per-edge values. The
    # uniform `padding:` seeds all four edges; per-edge kwargs override
    # individual slots. Called from each shape's `initialize` after
    # `_extract_alignment`.
    def _apply_padding(padding, top, right, bottom, left)
      base = padding || 0
      @padding_top    = top    || base
      @padding_right  = right  || base
      @padding_bottom = bottom || base
      @padding_left   = left   || base
    end

    # Reject negative construction-time dimensions (width, height, radius, …).
    # A negative extent is a setup mistake: it renders but disagrees with hit
    # testing, since `contains?` assumes positive geometry. Zero is allowed
    # (collapse-to-point). Runtime setters are deliberately left unguarded so an
    # animation whose size momentarily dips below zero degrades to nothing for
    # that frame rather than crashing the app — see USAGE.md.
    def _validate_dimensions(**dims)
      dims.each do |name, value|
        next unless value.is_a?(Numeric) && value.negative?
        raise ArgumentError, "#{self.class} #{name} must be zero or positive, got #{value}"
      end
    end

    # Extract symbolic alignment from a constructor (x, y) pair, store the
    # intent, and return numeric placeholders to use until the first draw.
    def _extract_alignment(x, y)
      self.x_align = x if x.is_a?(Symbol)
      self.y_align = y if y.is_a?(Symbol)
      [x.is_a?(Symbol) ? 0 : x, y.is_a?(Symbol) ? 0 : y]
    end

    # Reject a non-numeric position on a shape with no single anchor to align.
    # Bounding-box shapes (Image, Text, Rectangle, Circle, Ellipse) accept a
    # symbol like `:center` as alignment intent; the centroid-anchored vertex
    # shapes (Triangle, Quad, Polygon, Polyline) and the pixel-buffer Canvas have
    # nothing to align, so a symbol there is a setup mistake. Raise a clear error
    # rather than let it reach the centroid arithmetic (a bare `Symbol#-`
    # NoMethodError) or the native renderer (a cryptic type error at draw time).
    # Returns the value so a setter can validate and assign in one expression.
    def _require_numeric_position(axis, value)
      return value if value.is_a?(Numeric)
      raise Error,
            "#{self.class} #{axis} must be a number; #{self.class} doesn't support " \
            "symbolic alignment (e.g. #{axis}: :center) — use a bounding-box shape " \
            'like Text, Image, or Rectangle for that'
    end

    # Set the z position (depth) of the object. Re-inserts at the new depth only
    # if the object was actually in the scene graph — `Window#remove` returns
    # false for an object built with `add: false` or already removed, so changing
    # its `z` updates the value without silently adding it to the window.
    def z=(z)
      was_added = remove
      @z = z
      add if was_added
    end

    # Add the object to the window's scene graph. This governs iteration and
    # z-ordering, not visibility. Use #show / #hide (or the `visible` accessor)
    # to toggle frame-by-frame drawing without affecting scene-graph membership.
    def add
      Window.add(self)
    end

    # Remove the object from the window's scene graph.
    def remove
      Window.remove(self)
    end

    # Mark the object visible. Preserves scene-graph position and z-order; the
    # window's render loop will draw it on subsequent frames.
    def show
      @visible = true
    end

    # Mark the object hidden. Stays in the scene graph (and contains?/events
    # continue to work). Visually equivalent to opacity 0 but with zero draw
    # cost.
    def hide
      @visible = false
    end

    # Scene-graph draw hook, called once per frame per visible object. This
    # fallback forwards to `render` so a custom renderable only has to define
    # `render`; every built-in shape overrides or aliases it to skip the
    # keyword handling of its public `render`, which costs ~5µs per call on
    # wasm mruby even when no keywords are passed. Public — like the other
    # underscore-prefixed internals — so the scene loop can call it directly:
    # a `send` there costs real time at thousands of objects per frame. Shapes
    # that alias it from a private `render` re-publicize the alias with
    # `public :_render_scene`, since aliases inherit the original visibility.
    def _render_scene
      render
    end

    # Set the color value
    def color=(color)
      @color = Color.new(color)
    end

    # Allow British English spelling of color
    alias colour color

    def colour=(color)
      self.color = color
    end

    # Get the opacity (alpha) of the object's fill color. For per-vertex
    # `Color::Set` fills, returns the alpha of the first color.
    def opacity
      @color&.opacity
    end

    # Set the opacity (alpha) of the object's color. Fades the fill and, on
    # shapes that have one, the stroke too — matching how a construction-time
    # `opacity:` applies to both. For per-vertex `Color::Set` colors, sets every
    # vertex's alpha to the same value. To fade fill and stroke independently,
    # set each color's opacity directly: `obj.color.opacity = a` and
    # `obj.stroke_color.opacity = b`.
    def opacity=(value)
      @color.opacity = value
      @stroke_color.opacity = value if instance_variable_defined?(:@stroke_color) && @stroke_color
    end

    # Map a query point into this object's unrotated coordinate frame. Each
    # shape's `render` rotates geometry about `(rx, ry)` by `@rotate` degrees
    # before drawing; `contains?` calls this first so hit-testing matches what
    # the user sees. Returns the point unchanged when there's no rotation (or
    # the object has no rotation pivot, e.g. `BitmapText`).
    def _unrotate(px, py)
      rotate = instance_variable_defined?(:@rotate) ? @rotate : nil
      return [px, py] if rotate.nil? || rotate == 0

      cx = rx; cy = ry
      rad = -rotate * Math::PI / 180.0
      sa = Math.sin(rad); ca = Math.cos(rad)
      dx = px - cx; dy = py - cy
      [dx * ca - dy * sa + cx, dx * sa + dy * ca + cy]
    end

    # Even-odd ray-cast point-in-polygon test over a flat `[x0, y0, x1, y1, ...]`
    # coordinate array. This is the shared hit-test for every filled polygonal
    # shape (`Triangle`, `Quad`, `Polygon`) so `contains?` means "inside the
    # rendered fill" consistently — matching the fill for simple polygons (convex
    # and concave). Self-intersecting input isn't fully supported by the fill
    # renderer, so the test can diverge from the drawn pixels there. The boundary
    # is half-open (top/right edges read as outside), as in rasterization.
    def _point_in_polygon?(coords, px, py)
      n = coords.length / 2
      inside = false
      j = n - 1
      n.times do |i|
        xi = coords[i * 2]; yi = coords[i * 2 + 1]
        xj = coords[j * 2]; yj = coords[j * 2 + 1]
        if (yi > py) != (yj > py) &&
           px < (xj - xi) * (py - yi) / (yj - yi).to_f + xi
          inside = !inside
        end
        j = i
      end
      inside
    end

    # Hit-test a point against the stroked band of segment (x1, y1)-(x2, y2):
    # true when (px, py) lies within the rectangle the stroke actually draws.
    # `half_sq` is the squared half-stroke-width tolerance. The point must
    # project onto the segment (0 <= t <= 1) *and* fall within the half-width
    # perpendicular, so the hit region matches the drawn (butt-capped) rectangle
    # and does not overhang the ends. Shared stroke hit-test for `Line` and
    # `Polyline`; compares squared distances to skip the square root on this
    # per-event, per-segment path.
    def _point_on_segment?(px, py, x1, y1, x2, y2, half_sq)
      dx = x2 - x1
      dy = y2 - y1
      len_sq = dx * dx + dy * dy
      return false if len_sq.zero? # zero-length segment draws nothing

      # fdiv (not /) so integer coordinates don't trigger integer floor
      # division, which would snap t to 0/1 and mis-measure the projection.
      t = ((px - x1) * dx + (py - y1) * dy).fdiv(len_sq)
      return false if t < 0.0 || t > 1.0 # past an end — outside the drawn rect

      cx = x1 + t * dx
      cy = y1 + t * dy
      ex = px - cx; ey = py - cy
      ex * ex + ey * ey <= half_sq
    end

    # Check if the object contains the given point
    def contains?(x, y)
      x, y = _unrotate(x, y)
      x >= @x && x <= (@x + @width) && y >= @y && y <= (@y + @height)
    end

  end
end

# ---------- lib/ruby2d/color.rb ----------

# Ruby2D::Color

module Ruby2D
  # A color from a keyword, hex value, or RGBA array
  class Color
    # An array of colors
    class Set
      include Enumerable

      # Create a color set from an array of colors
      def initialize(colors)
        raise Error, 'a Color::Set requires at least one color, got an empty array' if colors.empty?

        @colors = colors.map { |c| Color.new(c) }
      end

      # Get a color by index
      def [](index)
        @colors[index]
      end

      # Get the number of colors in the set
      def length
        @colors.length
      end

      # Iterate over each color
      def each(&block)
        @colors.each(&block)
      end

      # Get the first color, or the first `n` colors if a count is given
      def first(*args)
        @colors.first(*args)
      end

      # Get the last color, or the last `n` colors if a count is given
      def last(*args)
        @colors.last(*args)
      end

      # Get the opacity of the first color
      def opacity
        @colors.first.opacity
      end

      # Set the opacity for all colors
      def opacity=(opacity)
        unless opacity.is_a?(Numeric)
          raise ArgumentError, "opacity must be a number between 0.0 and 1.0, got #{opacity.inspect}"
        end

        @colors.each do |color|
          color.opacity = opacity
        end
      end

      # The color for the i-th vertex. Paired with `Color#vertex` so per-vertex
      # rendering code can uniformly call `color.vertex(i)` whether it holds a
      # single `Color` (every vertex is the same) or a `Color::Set`.
      def vertex(i)
        @colors[i]
      end
    end

    attr_accessor :r, :g, :b, :a

    # Bounded cache of parsed color strings, keyed by the user input.
    # `'random'` is never cached (re-randomized on each call).
    PARSE_CACHE_MAX = 256
    @parse_cache = {}

    # Bounded cache of shared Color instances for immediate-mode `.render`
    # calls, keyed by the color string. See `Color.for_render`.
    RENDER_CACHE_MAX = 256
    @render_cache = {}

    # Based on clrs.cc
    NAMED_COLORS = {
      'navy' => '#001F3F',
      'blue' => '#0074D9',
      'aqua' => '#7FDBFF',
      'teal' => '#39CCCC',
      'olive' => '#3D9970',
      'green' => '#2ECC40',
      'lime' => '#01FF70',
      'yellow' => '#FFDC00',
      'orange' => '#FF851B',
      'red' => '#FF4136',
      'brown' => '#663300',
      'fuchsia' => '#F012BE',
      'purple' => '#B10DC9',
      'maroon' => '#85144B',
      'white' => '#FFFFFF',
      'silver' => '#DDDDDD',
      'gray' => '#AAAAAA',
      'black' => '#111111',
      'random' => ''
    }.freeze

    # Create a color from a keyword, hex string, array, or Color
    def initialize(color)
      raise Error, "#{color.inspect} is not a valid color" unless self.class.valid? color

      case color
      when String
        init_from_string color
      when Array
        @r = channel(color[0])
        @g = channel(color[1])
        @b = channel(color[2])
        @a = color.length == 4 ? channel(color[3]) : 1.0
      when Color
        @r = color.r
        @g = color.g
        @b = color.b
        @a = color.a
      end
    end

    class << self
      # Create a Color or Color::Set from the given value
      def set(colors)
        # Already a Color::Set (e.g. re-applying a gradient fill): pass through.
        return colors if colors.is_a?(Color::Set)

        # A non-empty array of valid colors becomes a `Color::Set`. An empty
        # array is not a valid gradient, so it falls through to `Color.new`,
        # which raises a clear "not a valid color" at the mistake site.
        if colors.is_a?(Array) && !colors.empty? && colors.all? { |el| Color.valid? el }
          Color::Set.new(colors)
        # Otherwise, return single color
        else
          Color.new(colors)
        end
      end

      # Resolve a color for an immediate-mode class-level `.render` call.
      # Behaves like `.set`, except string colors and flat `[r, g, b(, a)]`
      # numeric arrays return a shared cached Color instance, skipping the
      # validation re-scan and object allocation `.new` pays on every call —
      # those two forms are the common case in per-frame draws, and on the web
      # (mruby/wasm) that per-call cost dominates the frame budget. The cached
      # instance is read and forwarded to the native draw call immediately; it
      # must never be stored on an object or handed to user code (a later
      # mutation would corrupt every subsequent lookup) — use `.set` anywhere
      # the color is kept. `'random'` is never cached, so each call still
      # rolls a fresh color.
      def for_render(colors)
        if colors.is_a?(String)
          cached = @render_cache[colors]
          return cached if cached
          return Color.new(colors) if colors == 'random'

          @render_cache.shift if @render_cache.size >= RENDER_CACHE_MAX
          @render_cache[colors] = Color.new(colors)
        elsif colors.is_a?(Array) && colors[0].is_a?(Numeric) && rgba_array?(colors)
          # ^ The two inline checks pre-screen the non-match cases (an array of
          # colors starts with a String/Array/Color, never a Numeric) so this
          # per-draw-call path only pays the `rgba_array?` method call when the
          # input is almost certainly a cacheable [r, g, b(, a)] array.
          # Array keys are looked up by value, so mutating a previously seen
          # array can't corrupt the mapping — it just misses and inserts a new
          # entry. The stored key is a frozen copy for the same reason.
          cached = @render_cache[colors]
          return cached if cached

          c = Color.new(colors)
          @render_cache.shift if @render_cache.size >= RENDER_CACHE_MAX
          @render_cache[colors.dup.freeze] = c
        else
          set(colors)
        end
      end

      # A flat `[r, g, b]` or `[r, g, b, a]` numeric array — the array form a
      # single color takes (an array of *colors* is a `Color::Set`, and its
      # elements are never bare Numerics). `while`, not blocks — this guards
      # the per-draw-call render path and block calls dominate on wasm mruby.
      def rgba_array?(colors)
        return false unless colors.is_a?(Array)

        n = colors.length
        return false unless n == 3 || n == 4

        i = 0
        while i < n
          return false unless colors[i].is_a?(Numeric)
          i += 1
        end
        true
      end

      # Check if the string is a valid hex color value
      # Byte comparisons, not slicing: `valid?` calls this on every `Color.new`
      # and on every per-vertex color of every immediate-mode draw, and the
      # readable form (`[0]`, `[1..]`, `.chars`, plus a fresh literal for the
      # allowed set) allocated about ten short-lived strings each time.
      def hex?(color_string)
        return false unless color_string.instance_of?(String) &&
                            color_string.getbyte(0) == 35 # '#'

        len = color_string.length
        return false unless len == 4 || len == 7 || len == 9

        i = 1
        while i < len
          b = color_string.getbyte(i)
          return false unless (b >= 48 && b <= 57) ||   # 0-9
                              (b >= 65 && b <= 70) ||   # A-F
                              (b >= 97 && b <= 102)     # a-f

          i += 1
        end
        true
      end

      # Check if the value is a valid color
      def valid?(color)
        color.is_a?(Color) ||             # color object
          NAMED_COLORS.key?(color) ||     # keyword
          hex?(color) ||                  # hexadecimal value
          (                               # [r, g, b] or [r, g, b, a] numbers
            color.instance_of?(Array) &&
            (color.length == 3 || color.length == 4) &&
            color.all? { |el| el.is_a?(Numeric) }
          )
      end

      # Parse a color string into a frozen `[r, g, b, a]` tuple, caching the
      # result. Named colors and hex strings are cached; `'random'` is not.
      # Callers must not mutate the returned array.
      def parse_string(color)
        # Check the cache first so the hot path (a previously-seen named or hex
        # color) returns before the `'random'` literal comparison, which would
        # otherwise allocate a fresh `'random'` string on every call. `'random'`
        # is never cached, so it still falls through to a fresh value below.
        cached = @parse_cache[color]
        return cached if cached

        return [rand, rand, rand, 1.0] if color == 'random'

        source = hex?(color) ? color : NAMED_COLORS[color]
        rgba = hex_to_f(source).freeze
        @parse_cache.shift if @parse_cache.size >= PARSE_CACHE_MAX
        @parse_cache[color] = rgba
      end

      private

      # Convert a hex color (e.g. #FFF, #FFF000, #FFF000FF) to [r, g, b, a]
      # floats in 0.0..1.0.
      def hex_to_f(hex_color)
        hex = hex_color[1..]
        hex = hex.chars.map { |c| c * 2 }.join if hex.length == 3
        rgba = hex.chars.each_slice(2).map { |pair| pair.join.to_i(16) }
        rgba << 255 if rgba.length == 3
        rgba.map { |n| n / 255.0 }
      end
    end

    # Get the opacity
    def opacity
      @a
    end

    # Set the opacity. Must be a single number; per-vertex opacity (an array)
    # is only supported by shapes that handle it explicitly, such as Polyline.
    # The value is clamped to 0.0..1.0 so an animation that momentarily drives
    # opacity out of range degrades to fully transparent/opaque rather than
    # wrapping the Uint8 alpha cast into a wrong, near-opaque byte.
    def opacity=(opacity)
      unless opacity.is_a?(Numeric)
        raise ArgumentError, "opacity must be a number between 0.0 and 1.0, got #{opacity.inspect}"
      end

      @a = opacity.clamp(0.0, 1.0)
    end

    # Return the color components as an array
    def to_a
      [@r, @g, @b, @a]
    end

    # The color for the i-th vertex. A single `Color` represents "every vertex
    # is the same color," so every index returns self. Mirrors `Color::Set#vertex`
    # so per-vertex rendering code can call `color.vertex(i)` without branching.
    def vertex(_i)
      self
    end

    private

    def init_from_string(color)
      @r, @g, @b, @a = self.class.parse_string(color)
    end

    # Interpret a color channel on the 0.0..1.0 scale — the graphics-programming
    # convention also used internally and by the renderer. Both integers and
    # floats are taken at face value on this scale, so `1` is full intensity and
    # `0` is none; for 0..255 byte values, use a hex string like `'#FF8000'`. An
    # out-of-range value warns once and clamps to the nearest bound so the stored
    # color always stays in range.
    def channel(value)
      return value.to_f if value >= 0.0 && value <= 1.0

      Ruby2D.warn("color value #{value} is out of range; components must be 0.0..1.0")
      value < 0.0 ? 0.0 : 1.0
    end
  end

  # Allow British English spelling of color
  Colour = Color
end

# ---------- lib/ruby2d/audio.rb ----------

module Ruby2D
  class Audio
    attr_reader :path

    # Create an audio object from a file
    def initialize(path, loop: false)
      @path = path.to_s
      raise Error, "Cannot find audio file `#{@path}`" unless File.exist? @path

      @loop = loop ? true : false
      @ext_audio = Ext.audio_load(@path)
    end

    # Play the sound
    def play
      Ext.audio_play(@ext_audio, @loop)
    end

    # Pause the music
    def pause
      Ext.audio_pause(@ext_audio)
    end

    # Resume paused music
    def resume
      Ext.audio_resume(@ext_audio)
    end

    # Stop the sound
    def stop(ms_fade = 0)
      Ext.audio_stop(@ext_audio, ms_fade)
    end

    # Whether the audio loops on play
    def looping?
      @loop
    end

    # Set looping
    def loop=(value)
      @loop = value ? true : false
      Ext.audio_set_loop(@ext_audio, @loop)
    end

    # Returns the length in seconds
    def length
      Ext.audio_length(@ext_audio)
    end

    # Get the volume of the sound, 0.0 to 1.0
    def volume
      Ext.audio_get_volume(@ext_audio)
    end

    # Set the volume of the sound, 0.0 to 1.0
    def volume=(volume)
      Ext.audio_set_volume(@ext_audio, volume.clamp(0.0, 1.0))
    end

    class << self
      # Get the mixer volume, 0.0 to 1.0
      def volume
        Ext.audio_get_mixer_volume
      end

      # Set the mixer volume, 0.0 to 1.0
      def volume=(volume)
        Ext.audio_set_mixer_volume(volume.clamp(0.0, 1.0))
      end
    end

  end
end

# ---------- lib/ruby2d/circle.rb ----------

# Ruby2D::Circle

module Ruby2D
  # A circle
  class Circle
    include Renderable

    attr_accessor :radius, :sectors, :rotate, :fill, :stroke_width
    attr_reader :x, :y, :stroke_color
    alias_method :stroke_colour, :stroke_color

    # Set the x position (the center). Pass a symbol (`:left`, `:center`,
    # `:right`) to set alignment intent — resolved at draw time against the
    # window, with the circle's bounding box hugging the chosen edge.
    def x=(value)
      return self.x_align = value if value.is_a?(Symbol)
      @x_align = nil unless @_resolving_alignment
      @x = value
    end

    # Set the y position (the center). Pass a symbol (`:top`, `:center`,
    # `:bottom`) to set alignment intent.
    def y=(value)
      return self.y_align = value if value.is_a?(Symbol)
      @y_align = nil unless @_resolving_alignment
      @y = value
    end

    # Create a circle
    def initialize(x: 0, y: 0, z: 0, radius: 50, sectors: 30,
                   rotate: 0, rx: nil, ry: nil,
                   color: nil, colour: nil, opacity: nil,
                   fill: true, stroke_width: 0, stroke_color: nil, stroke_colour: nil,
                   add: true, visible: true,
                   padding: nil, padding_top: nil, padding_right: nil,
                   padding_bottom: nil, padding_left: nil)
      x, y = _extract_alignment(x, y)
      _apply_padding(padding, padding_top, padding_right, padding_bottom, padding_left)
      _validate_dimensions(radius: radius)
      @x = x
      @y = y
      @z = z
      @radius = radius
      @sectors = sectors
      @rotate = rotate
      @_user_rx = rx
      @_user_ry = ry
      self.color = color || colour || 'white'
      self.opacity = opacity unless opacity.nil?
      @fill = fill
      @stroke_width = stroke_width
      self.stroke_color = stroke_color || stroke_colour || (color || colour)
      self.stroke_color.opacity = opacity unless opacity.nil?
      @visible = visible
      self.add if add
    end

    # Set the stroke color. Single-color only — a per-vertex array is rejected.
    def stroke_color=(c)
      resolved = c.nil? ? nil : Color.set(c)
      if resolved.is_a?(Color::Set)
        raise ArgumentError, "`#{self.class}` does not support per-vertex stroke colors; pass a single color"
      end

      @stroke_color = resolved || Color.new('white')
      @_stroke_cc = nil
    end
    alias_method :stroke_colour=, :stroke_color=

    # Get the rotation center x coordinate
    def rx
      @_user_rx.nil? ? @x : @_user_rx
    end

    # Get the rotation center y coordinate
    def ry
      @_user_ry.nil? ? @y : @_user_ry
    end

    # Set the rotation center x coordinate
    def rx=(val)
      @_user_rx = val
    end

    # Set the rotation center y coordinate
    def ry=(val)
      @_user_ry = val
    end

    # Bounding-box width and height (the diameter)
    def width
      @radius * 2
    end

    def height
      @radius * 2
    end

    # Set the color value. Single-color only — a per-vertex color array is
    # rejected with a clear message rather than a generic "not a valid color".
    def color=(color)
      c = Color.set(color)
      if c.is_a?(Color::Set)
        raise ArgumentError, "`#{self.class}` does not support per-vertex colors; pass a single color"
      end

      @color = c
      @_cc = nil # invalidate cached color components
    end

    # Check if the circle contains the given point. Compares squared distance
    # to squared radius to skip the square root on this per-event hit path. A
    # negative radius (reachable via the unguarded runtime setter) contains
    # nothing, matching the old `sqrt(...) <= @radius` behavior the squared form
    # would otherwise lose.
    def contains?(x, y)
      return false if @radius.negative?
      x, y = _unrotate(x, y) if @rotate != 0
      dx = x - @x
      dy = y - @y
      dx * dx + dy * dy <= @radius * @radius
    end

    # Render a circle without creating an instance
    def self.render(x: 0, y: 0, radius: 50, sectors: 30, rotate: 0,
                    rx: nil, ry: nil, color: nil, colour: nil, opacity: nil,
                    fill: true, stroke_width: 0, stroke_color: nil, stroke_colour: nil)
      fill_input = color || colour
      explicit_stroke = stroke_color || stroke_colour
      stroke_input = explicit_stroke || fill_input
      # Reject a per-vertex stroke color, matching the instance setter — circles
      # have a single stroke color. Only check when the stroke is drawn or an
      # explicit stroke color was given, so an invalid one still raises.
      if (stroke_width > 0 || !explicit_stroke.nil?) && !stroke_input.nil? &&
         Color.set(stroke_input).is_a?(Color::Set)
        raise ArgumentError, "`#{self}` does not support per-vertex stroke colors; pass a single color"
      end

      Window.render_ready_check
      # Resolve the fill color once (as Quad#draw_immediate does). The common
      # case — a single Color with scalar opacity — reads the resolved
      # channels directly; only a `Color::Set` or per-vertex opacity array
      # pays for the flattened array (and gets the arity errors it raises).
      # `for_render` returns a shared cached instance — read-only here.
      resolved = Color.for_render(fill_input.nil? ? 'white' : fill_input)
      uniform = !resolved.is_a?(Color::Set) && !opacity.is_a?(Array)
      c = uniform ? nil : Renderable.flatten_resolved_color(resolved, 1, opacity, label: self)

      if rotate != 0
        cx = rx || x
        cy = ry || y
        rad = rotate * Math::PI / 180.0
        sa = Math.sin(rad); ca = Math.cos(rad)
        dx = x - cx; dy = y - cy
        x = dx * ca - dy * sa + cx
        y = dx * sa + dy * ca + cy
      end

      if fill
        if uniform
          Ext.draw_circle(x, y, radius, sectors,
                          resolved.r, resolved.g, resolved.b, opacity || resolved.a)
        else
          Ext.draw_circle(x, y, radius, sectors, c[0], c[1], c[2], c[3])
        end
      end
      # Resolve the stroke color only when actually stroking.
      if stroke_width > 0
        sc = Renderable.resolve_single_color(stroke_input) || Color.new('white')
        sc = Color.new(sc)
        sc.opacity = opacity if opacity
        Ext.stroke_circle(x, y, radius, sectors, stroke_width, sc.r, sc.g, sc.b, sc.a)
      end
    end

    private

    # Circle is center-anchored, so shift the alignment resolver's bounding-box
    # top-left result by the radius to land on the center.
    def _alignment_anchor_dx
      @radius
    end

    def _alignment_anchor_dy
      @radius
    end

    def render
      _resolve_alignment
      ensure_cc
      ensure_scc if @stroke_width && @stroke_width > 0

      x = @x; y = @y

      if @rotate != 0
        cx = rx; cy = ry
        rad = @rotate * Math::PI / 180.0
        sa = Math.sin(rad); ca = Math.cos(rad)
        dx = x - cx; dy = y - cy
        x = dx * ca - dy * sa + cx
        y = dx * sa + dy * ca + cy
      end

      if @fill
        cc = @_cc
        Ext.draw_circle(x, y, @radius, @sectors, cc[0], cc[1], cc[2], cc[3])
      end

      if @stroke_width && @stroke_width > 0
        scc = @_stroke_cc
        Ext.stroke_circle(x, y, @radius, @sectors, @stroke_width, scc[0], scc[1], scc[2], scc[3])
      end
    end

    # Scene-graph draw hook (see Renderable#_render_scene). Circle's `render` is
    # already zero-arg, so the hook is the same method under the scene name.
    alias_method :_render_scene, :render
    public :_render_scene

    # Build/rebuild flat color cache for the native extension
    def ensure_cc
      if @_cc.nil? || @_cc[0] != @color.r || @_cc[1] != @color.g || @_cc[2] != @color.b || @_cc[3] != @color.a
        @_cc = [@color.r, @color.g, @color.b, @color.a]
      end
    end

    # Build/rebuild flat stroke color cache for the native extension
    def ensure_scc
      c = @stroke_color
      if @_stroke_cc.nil? || @_stroke_cc[0] != c.r || @_stroke_cc[1] != c.g || @_stroke_cc[2] != c.b || @_stroke_cc[3] != c.a
        @_stroke_cc = [c.r, c.g, c.b, c.a]
      end
    end
  end
end

# ---------- lib/ruby2d/ellipse.rb ----------

# Ruby2D::Ellipse

module Ruby2D
  # An ellipse
  class Ellipse
    include Renderable

    attr_accessor :xradius, :yradius, :sectors, :rotate, :fill, :stroke_width
    attr_reader :x, :y, :stroke_color
    alias_method :stroke_colour, :stroke_color

    # Set the x position (the center). Pass a symbol (`:left`, `:center`,
    # `:right`) to set alignment intent — resolved at draw time against the
    # window, with the ellipse's bounding box hugging the chosen edge.
    def x=(value)
      return self.x_align = value if value.is_a?(Symbol)
      @x_align = nil unless @_resolving_alignment
      @x = value
    end

    # Set the y position (the center). Pass a symbol (`:top`, `:center`,
    # `:bottom`) to set alignment intent.
    def y=(value)
      return self.y_align = value if value.is_a?(Symbol)
      @y_align = nil unless @_resolving_alignment
      @y = value
    end

    # Create an ellipse
    def initialize(x: 0, y: 0, z: 0, xradius: 50, yradius: 30, sectors: 30,
                   rotate: 0, rx: nil, ry: nil,
                   color: nil, colour: nil, opacity: nil,
                   fill: true, stroke_width: 0, stroke_color: nil, stroke_colour: nil,
                   add: true, visible: true,
                   padding: nil, padding_top: nil, padding_right: nil,
                   padding_bottom: nil, padding_left: nil)
      x, y = _extract_alignment(x, y)
      _apply_padding(padding, padding_top, padding_right, padding_bottom, padding_left)
      _validate_dimensions(xradius: xradius, yradius: yradius)
      @x = x
      @y = y
      @z = z
      @xradius = xradius
      @yradius = yradius
      @sectors = sectors
      @rotate = rotate
      @_user_rx = rx
      @_user_ry = ry
      self.color = color || colour || 'white'
      self.opacity = opacity unless opacity.nil?
      @fill = fill
      @stroke_width = stroke_width
      self.stroke_color = stroke_color || stroke_colour || (color || colour)
      self.stroke_color.opacity = opacity unless opacity.nil?
      @visible = visible
      self.add if add
    end

    # Get the rotation center x coordinate
    def rx
      @_user_rx.nil? ? @x : @_user_rx
    end

    # Get the rotation center y coordinate
    def ry
      @_user_ry.nil? ? @y : @_user_ry
    end

    # Set the rotation center x coordinate
    def rx=(val)
      @_user_rx = val
    end

    # Set the rotation center y coordinate
    def ry=(val)
      @_user_ry = val
    end

    # Bounding-box width and height (the axis diameters)
    def width
      @xradius * 2
    end

    def height
      @yradius * 2
    end

    # Set the fill color. Single-color only — a per-vertex color array is
    # rejected with a clear message rather than a generic "not a valid color".
    def color=(color)
      c = Color.set(color)
      if c.is_a?(Color::Set)
        raise ArgumentError, "`#{self.class}` does not support per-vertex colors; pass a single color"
      end

      @color = c
      @_cc = nil
    end

    # Set the stroke color. Single-color only — a per-vertex array is rejected.
    def stroke_color=(c)
      resolved = c.nil? ? nil : Color.set(c)
      if resolved.is_a?(Color::Set)
        raise ArgumentError, "`#{self.class}` does not support per-vertex stroke colors; pass a single color"
      end

      @stroke_color = resolved || Color.new('white')
      @_stroke_cc = nil
    end
    alias_method :stroke_colour=, :stroke_color=

    # Check if the ellipse contains the given point
    def contains?(x, y)
      x, y = _unrotate(x, y)
      dx = x - @x
      dy = y - @y
      rx = @xradius.to_f
      ry = @yradius.to_f
      # A zero radius collapses the ellipse on that axis, so the point must lie
      # exactly on it — mirrors Circle, which is "inside" only at the center
      # when radius is 0. (The plain formula would divide by zero here.)
      return false if rx == 0 && dx != 0
      return false if ry == 0 && dy != 0
      tx = rx == 0 ? 0.0 : (dx * dx) / (rx * rx)
      ty = ry == 0 ? 0.0 : (dy * dy) / (ry * ry)
      tx + ty <= 1.0
    end

    # Render an ellipse without creating an instance
    def self.render(x: 0, y: 0, xradius: 50, yradius: 30, sectors: 30, rotate: 0,
                    rx: nil, ry: nil, color: nil, colour: nil, opacity: nil,
                    fill: true, stroke_width: 0, stroke_color: nil, stroke_colour: nil)
      fill_input = color || colour
      explicit_stroke = stroke_color || stroke_colour
      stroke_input = explicit_stroke || fill_input
      # Reject a per-vertex stroke color, matching the instance setter — ellipses
      # have a single stroke color. Only check when the stroke is drawn or an
      # explicit stroke color was given, so an invalid one still raises.
      if (stroke_width > 0 || !explicit_stroke.nil?) && !stroke_input.nil? &&
         Color.set(stroke_input).is_a?(Color::Set)
        raise ArgumentError, "`#{self}` does not support per-vertex stroke colors; pass a single color"
      end

      Window.render_ready_check
      c = Renderable.flatten_color(fill_input, 1, opacity)

      # `rotate` (degrees) tilts the ellipse and, given a pivot other than the
      # center, orbits its center around that pivot — matching Quad/Triangle.
      # `rad` is passed to the draw so the rim itself tilts.
      rad = rotate * Math::PI / 180.0
      if rotate != 0
        cx = rx || x
        cy = ry || y
        sa = Math.sin(rad); ca = Math.cos(rad)
        dx = x - cx; dy = y - cy
        x = dx * ca - dy * sa + cx
        y = dx * sa + dy * ca + cy
      end

      Ext.draw_ellipse(x, y, xradius, yradius, rad, sectors, c[0], c[1], c[2], c[3]) if fill
      # Resolve the stroke color only when actually stroking.
      if stroke_width > 0
        sc = Renderable.resolve_single_color(stroke_input) || Color.new('white')
        sc = Color.new(sc)
        sc.opacity = opacity if opacity
        Ext.stroke_ellipse(x, y, xradius, yradius, rad, sectors, stroke_width, sc.r, sc.g, sc.b, sc.a)
      end
    end

    private

    # Ellipse is center-anchored, so shift the alignment resolver's bounding-box
    # top-left result by each radius to land on the center.
    def _alignment_anchor_dx
      @xradius
    end

    def _alignment_anchor_dy
      @yradius
    end

    def render
      _resolve_alignment
      ensure_cc
      ensure_scc if @stroke_width && @stroke_width > 0

      x = @x; y = @y

      rad = @rotate * Math::PI / 180.0
      if @rotate != 0
        cx = rx; cy = ry
        sa = Math.sin(rad); ca = Math.cos(rad)
        dx = x - cx; dy = y - cy
        x = dx * ca - dy * sa + cx
        y = dx * sa + dy * ca + cy
      end

      if @fill
        cc = @_cc
        Ext.draw_ellipse(x, y, @xradius, @yradius, rad, @sectors, cc[0], cc[1], cc[2], cc[3])
      end

      if @stroke_width && @stroke_width > 0
        scc = @_stroke_cc
        Ext.stroke_ellipse(x, y, @xradius, @yradius, rad, @sectors, @stroke_width,
                           scc[0], scc[1], scc[2], scc[3])
      end
    end

    # Scene-graph draw hook (see Renderable#_render_scene). Ellipse's `render` is
    # already zero-arg, so the hook is the same method under the scene name.
    alias_method :_render_scene, :render
    public :_render_scene

    def ensure_cc
      if @_cc.nil? || @_cc[0] != @color.r || @_cc[1] != @color.g || @_cc[2] != @color.b || @_cc[3] != @color.a
        @_cc = [@color.r, @color.g, @color.b, @color.a]
      end
    end

    def ensure_scc
      c = @stroke_color
      if @_stroke_cc.nil? || @_stroke_cc[0] != c.r || @_stroke_cc[1] != c.g || @_stroke_cc[2] != c.b || @_stroke_cc[3] != c.a
        @_stroke_cc = [c.r, c.g, c.b, c.a]
      end
    end
  end
end

# ---------- lib/ruby2d/font.rb ----------

# Ruby2D::Font

module Ruby2D
  # System-font discovery: list the available fonts, resolve a name to a file
  # path, and locate the bundled default. Font *files* are opened and cached
  # natively (see `R2D_FontCacheGet` in the C extension), keyed by path, size,
  # and style — there are no Ruby-side `Font` instances.
  class Font
    class << self
      # List all fonts, names only
      def all
        all_paths.map { |path| path.split('/').last.chomp('.ttf').downcase }.uniq.sort
      end

      # Find a font file path from its name (case-insensitive, matching `all`)
      def path(font_name)
        font_name = font_name.to_s.downcase
        # Match against the file's basename (as `all` computes names), not the
        # whole path — otherwise a directory component like 'fonts' matches.
        all_paths.find { |path| path.split('/').last.chomp('.ttf').downcase.include?(font_name) }
      end

      # Get full path to the default font
      def default
        if RUBY_ENGINE == 'mruby'
          # Native and WASM builds bundle fonts at ruby2d/fonts/ relative to the binary
          'ruby2d/fonts/outfit/outfit.ttf'
        else
          File.expand_path('../../assets/resources/fonts/outfit/outfit.ttf', __dir__)
        end
      end

      private

      # Get all fonts with full file paths
      def all_paths
        # memoize so we only calculate once
        @all_paths ||= platform_font_paths
      end

      # Compute and return all platform font file paths, removing variants by style
      def platform_font_paths
        fonts = find_os_font_files.reject do |f|
          f.downcase.include?('bold') ||
            f.downcase.include?('italic')  ||
            f.downcase.include?('oblique') ||
            f.downcase.include?('narrow')  ||
            f.downcase.include?('black')
        end
        fonts.sort_by { |f| f.downcase.chomp '.ttf' }
      end

      # Return all font files in the platform's font location
      def find_os_font_files
        return [] unless directory

        if RUBY_ENGINE == 'mruby'
          # MRuby does not have `Dir` defined
          `find #{directory} -name *.ttf`.split("\n")
        else
          # If CRuby and/or non-Bash shell (like cmd.exe)
          Dir["#{directory}/**/*.ttf"]
        end
      end

      # Mapping of OS names to platform-specific font file locations
      OS_FONT_PATHS = {
        macos: '/Library/Fonts',
        linux: '/usr/share/fonts',
        windows: 'C:/Windows/Fonts',
        openbsd: '/usr/X11R6/lib/X11/fonts'
      }.freeze

      # Get the fonts directory for the current platform
      def directory
        @directory ||= OS_FONT_PATHS[host_os]
      end

      # Identify the host OS, mirroring AssetsTarget.host_os but returning a symbol.
      # Uses RbConfig when available (CRuby), falls back to uname (mruby).
      def host_os
        if Object.const_defined?(:RbConfig)
          host = RbConfig::CONFIG['host_os'].downcase
          return :windows if host.match?(/mswin|mingw|cygwin/)
          return :macos   if host.include?('darwin')
          return :linux   if host.include?('linux')
          return :openbsd if host.include?('openbsd')
        else
          uname = `uname`.strip
          return :macos   if uname.include?('Darwin')
          return :linux   if uname.include?('Linux')
          return :windows if uname.include?('MINGW')
          return :openbsd if uname.include?('OpenBSD')
        end
      rescue IOError
        nil
      end
    end
  end
end

# ---------- lib/ruby2d/image.rb ----------

# Ruby2D::Image

module Ruby2D
  # An image drawn in the window
  class Image
    include Renderable

    # Image uses `tint` instead of `color` — the image already has its own
    # colors in the texture; tint modulates them.
    undef_method :color, :color=, :colour, :colour=

    attr_reader :path
    attr_accessor :width, :height, :rotate

    # Set the x position. Pass a symbol (`:left`, `:center`, `:right`) to
    # set alignment intent — resolved at draw time against the window.
    def x=(value)
      return self.x_align = value if value.is_a?(Symbol)
      @x_align = nil unless @_resolving_alignment
      @x = value
    end

    # Set the y position. Pass a symbol (`:top`, `:center`, `:bottom`) to
    # set alignment intent — resolved at draw time against the window.
    def y=(value)
      return self.y_align = value if value.is_a?(Symbol)
      @y_align = nil unless @_resolving_alignment
      @y = value
    end

    # Get the rotation center x coordinate
    def rx
      @_user_rx.nil? ? @x + @width / 2.0 : @_user_rx
    end

    # Get the rotation center y coordinate
    def ry
      @_user_ry.nil? ? @y + @height / 2.0 : @_user_ry
    end

    # Set the rotation center x coordinate
    def rx=(val)
      @_user_rx = val
    end

    # Set the rotation center y coordinate
    def ry=(val)
      @_user_ry = val
    end

    # Create an image
    def initialize(path,
                   width: nil, height: nil, x: 0, y: 0, z: 0,
                   rotate: 0, rx: nil, ry: nil, tint: nil,
                   opacity: nil, add: true, visible: true,
                   padding: nil, padding_top: nil, padding_right: nil,
                   padding_bottom: nil, padding_left: nil,
                   _share_from: nil)
      @width = width
      @height = height

      x, y = _extract_alignment(x, y)
      _apply_padding(padding, padding_top, padding_right, padding_bottom, padding_left)
      @x = x
      @y = y
      @z = z
      @rotate = rotate
      @_user_rx = rx
      @_user_ry = ry
      self.tint = tint || 'white'
      self.tint.opacity = opacity unless opacity.nil?

      if _share_from
        # SpriteSheet uses this to give every Sprite the same backing texture
        # without re-decoding the file or re-uploading to the GPU.
        @path        = _share_from.path
        @ext_image   = _share_from.instance_variable_get(:@ext_image)
        @orig_width  = _share_from.instance_variable_get(:@orig_width)
        @orig_height = _share_from.instance_variable_get(:@orig_height)
        @width     ||= @orig_width
        @height    ||= @orig_height
        @clipped     = false
        @clip_x      = 0.0
        @clip_y      = 0.0
        @clip_width  = @orig_width
        @clip_height = @orig_height
      else
        @path = path.to_s
        raise Error, "Image file `#{@path}` not found" unless File.exist?(@path)

        # Preserve user-provided values before image_create may overwrite them
        provided_width = @width
        provided_height = @height
        provided_rotate = @rotate
        Ext.image_create(self)

        @width = provided_width || @width
        @height = provided_height || @height
        @rotate = provided_rotate
      end

      @visible = visible
      self.add if add
    end

    # Re-rasterize the source at a new pixel size and update `width`/`height`.
    # For SVGs this re-runs the vector rasterizer so the image stays crisp at
    # the new size. For raster images it resamples the source to the new size
    # — useful for trimming GPU memory when displaying a large source small.
    # Called with no arguments, re-rasterizes at the current `width`/`height`
    # — handy after assigning to `width=`/`height=` to commit a fresh raster.
    def resize!(width = @width, height = @height)
      unless width.is_a?(Numeric) && height.is_a?(Numeric) && width.positive? && height.positive?
        raise Error, 'Image#resize! requires positive width and height'
      end

      Ext.image_resize(self, width, height)
      @width = width
      @height = height
      self
    end

    # The image's tint color. The image's own texture colors are multiplied
    # by this — `tint: 'red'` makes the image redder, not solid red.
    def tint
      @color
    end

    def tint=(c)
      @color = Color.new(c)
    end

    # Render the image. Called with overrides for one-shot rendering inside a
    # render block; with no arguments it draws the same frame the scene graph
    # does (delegating to `_render_scene`).
    def render(x: nil, y: nil, width: nil, height: nil, rotate: nil,
               tint: nil, opacity: nil)
      if x.nil? && y.nil? && width.nil? && height.nil? && rotate.nil? &&
         tint.nil? && opacity.nil?
        return _render_scene
      end

      Window.render_ready_check

      saved_x, saved_y = @x, @y
      saved_width, saved_height = @width, @height
      saved_rotate = @rotate
      saved_color = @color

      @x = x if x
      @y = y if y
      @width = width if width
      @height = height if height
      @rotate = rotate if rotate

      if tint || opacity
        @color = tint ? Color.new(tint) : Color.new(saved_color)
        @color.opacity = opacity if opacity
      end

      begin
        Ext.image_draw(self)
      ensure
        @x, @y = saved_x, saved_y
        @width, @height = saved_width, saved_height
        @rotate = saved_rotate
        @color = saved_color
      end
    end

    private

    # Scene-graph draw hook (see Renderable#_render_scene): `render` with no
    # overrides, minus its keyword handling — a zero-arg call into the
    # 7-keyword `render` still pays ~3.4µs of keyword setup on wasm mruby.
    def _render_scene
      _resolve_alignment
      Ext.image_draw(self)
    end
    public :_render_scene
  end
end

# ---------- lib/ruby2d/line.rb ----------

# Ruby2D::Line

module Ruby2D
  # A line between two points.
  class Line
    include Renderable

    attr_accessor :x1, :x2, :y1, :y2, :stroke_width, :rotate, :dash, :gap

    # Create a line. Pass `dash:` (and optionally `gap:`) to draw a dashed line.
    # Specify endpoints via `points:` or via `x1:`/`y1:`/`x2:`/`y2:`. `points:`
    # takes precedence if both are given.
    def initialize(x1: 0, y1: 0, x2: 100, y2: 100,
                   points: nil,
                   z: 0,
                   stroke_width: 1, dash: 0, gap: 5,
                   rotate: 0, rx: nil, ry: nil,
                   color: nil, colour: nil, opacity: nil,
                   add: true, visible: true)
      if points
        Line.send(:validate_points, points)
        x1, y1 = points[0]
        x2, y2 = points[1]
      end
      @x1 = x1
      @y1 = y1
      @x2 = x2
      @y2 = y2
      @z = z
      @stroke_width = stroke_width
      @dash = dash
      @gap = gap
      @rotate = rotate
      @_user_rx = rx
      @_user_ry = ry
      self.color = color || colour || 'white'
      self.opacity = opacity unless opacity.nil?
      @visible = visible
      self.add if add
    end

    # Set the color of the line. Accepts a single color or a `Color::Set` of 2
    # (start, end) for a gradient along the length.
    def color=(color)
      color = Color.set(color)

      if color.is_a?(Color::Set) && color.length != 2
        raise ArgumentError,
              "`#{self.class}` requires 2 colors (start, end) for a gradient. #{color.length} were given."
      end

      @color = color
      @_cc = nil
    end

    # Return the length of the line
    def length
      points_distance(@x1, @y1, @x2, @y2)
    end

    # Bounding-box width and height (extent between the two endpoints)
    def width
      (@x1 - @x2).abs
    end

    def height
      (@y1 - @y2).abs
    end

    # Check if the line contains the given point — within half the stroke width
    # of the drawn segment and between its endpoints, so the hit region matches
    # the rendered (butt-capped) rectangle rather than overhanging its ends.
    # Shares the segment test with `Polyline`.
    def contains?(x, y)
      return false if @stroke_width.negative?
      x, y = _unrotate(x, y) if @rotate != 0
      half = @stroke_width / 2.0
      _point_on_segment?(x, y, @x1, @y1, @x2, @y2, half * half)
    end

    # Get the rotation center x coordinate
    def rx
      @_user_rx.nil? ? (@x1 + @x2) / 2.0 : @_user_rx
    end

    # Get the rotation center y coordinate
    def ry
      @_user_ry.nil? ? (@y1 + @y2) / 2.0 : @_user_ry
    end

    # Set the rotation center x coordinate
    def rx=(val)
      @_user_rx = val
    end

    # Set the rotation center y coordinate
    def ry=(val)
      @_user_ry = val
    end

    # Render a line without creating an instance
    def self.render(x1: 0, y1: 0, x2: 100, y2: 100,
                    points: nil,
                    stroke_width: 1, dash: 0, gap: 5,
                    rotate: 0, rx: nil, ry: nil,
                    color: nil, colour: nil, opacity: nil)
      Window.render_ready_check
      if points
        validate_points(points)
        x1, y1 = points[0]
        x2, y2 = points[1]
      end

      input = color || colour
      c = Color.for_render(input.nil? ? 'white' : input)
      if c.is_a?(Color::Set) && c.length != 2
        raise ArgumentError,
              "`#{self}` requires 2 colors (start, end) for a gradient. #{c.length} were given."
      end

      # Expand to 4 vertex colors: start -> both start corners, end -> both end corners
      c0 = c.vertex(0)
      c1 = c.vertex(1)
      c0a = opacity || c0.a
      c1a = opacity || c1.a

      if rotate != 0
        cx = rx || (x1 + x2) / 2.0
        cy = ry || (y1 + y2) / 2.0
        rad = rotate * Math::PI / 180.0
        sa = Math.sin(rad); ca = Math.cos(rad)
        dx = x1 - cx; dy = y1 - cy
        x1 = dx * ca - dy * sa + cx; y1 = dx * sa + dy * ca + cy
        dx = x2 - cx; dy = y2 - cy
        x2 = dx * ca - dy * sa + cx; y2 = dx * sa + dy * ca + cy
      end

      if dash > 0
        Ext.draw_dashed_line(
          x1, y1, x2, y2, stroke_width, dash, gap,
          c0.r, c0.g, c0.b, c0a,
          c0.r, c0.g, c0.b, c0a,
          c1.r, c1.g, c1.b, c1a,
          c1.r, c1.g, c1.b, c1a
        )
      else
        Ext.draw_line(
          x1, y1, x2, y2, stroke_width,
          c0.r, c0.g, c0.b, c0a,
          c0.r, c0.g, c0.b, c0a,
          c1.r, c1.g, c1.b, c1a,
          c1.r, c1.g, c1.b, c1a
        )
      end
    end

    private

    def self.validate_points(points)
      raise ArgumentError, 'Line requires exactly 2 points' unless points.length == 2
      raise ArgumentError, 'points must be an array of [x, y] pairs' \
        unless points.all? { |p| p.is_a?(Array) && p.length == 2 }
    end
    private_class_method :validate_points

    def render
      ensure_cc

      x1 = @x1; y1 = @y1; x2 = @x2; y2 = @y2

      if @rotate != 0
        cx = rx; cy = ry
        rad = @rotate * Math::PI / 180.0
        sa = Math.sin(rad); ca = Math.cos(rad)
        dx = x1 - cx; dy = y1 - cy
        x1 = dx * ca - dy * sa + cx; y1 = dx * sa + dy * ca + cy
        dx = x2 - cx; dy = y2 - cy
        x2 = dx * ca - dy * sa + cx; y2 = dx * sa + dy * ca + cy
      end

      cc = @_cc
      if @dash && @dash > 0
        Ext.draw_dashed_line(
          x1, y1, x2, y2, @stroke_width, @dash, @gap,
          cc[0],  cc[1],  cc[2],  cc[3],
          cc[4],  cc[5],  cc[6],  cc[7],
          cc[8],  cc[9],  cc[10], cc[11],
          cc[12], cc[13], cc[14], cc[15]
        )
      else
        Ext.draw_line(
          x1, y1, x2, y2, @stroke_width,
          cc[0],  cc[1],  cc[2],  cc[3],
          cc[4],  cc[5],  cc[6],  cc[7],
          cc[8],  cc[9],  cc[10], cc[11],
          cc[12], cc[13], cc[14], cc[15]
        )
      end
    end

    # Scene-graph draw hook (see Renderable#_render_scene). Line's `render` is
    # already zero-arg, so the hook is the same method under the scene name.
    alias_method :_render_scene, :render
    public :_render_scene

    # Calculate the distance between two points
    def points_distance(x1, y1, x2, y2)
      dx = x1 - x2
      dy = y1 - y2
      Math.sqrt(dx * dx + dy * dy)
    end

    # Build/rebuild flat color cache for the native extension. Line is a quad
    # internally, so the 2-color gradient (start, end) expands to 4 vertex
    # entries: start→both start corners, end→both end corners.
    def ensure_cc
      if @_cc.nil? || !cc_matches?
        c0 = @color.vertex(0)
        c1 = @color.vertex(1)
        @_cc = [c0.r, c0.g, c0.b, c0.a,
                c0.r, c0.g, c0.b, c0.a,
                c1.r, c1.g, c1.b, c1.a,
                c1.r, c1.g, c1.b, c1.a]
      end
    end

    # Line's 4-vertex expansion is deterministic, so checking the two source
    # entries (start and end) detects any Color::Set mutation.
    def cc_matches?
      c0 = @color.vertex(0)
      c1 = @color.vertex(1)
      return false if @_cc[0] != c0.r || @_cc[1] != c0.g || @_cc[2]  != c0.b || @_cc[3]  != c0.a
      return false if @_cc[8] != c1.r || @_cc[9] != c1.g || @_cc[10] != c1.b || @_cc[11] != c1.a
      true
    end
  end
end

# ---------- lib/ruby2d/polygon.rb ----------

# Ruby2D::Polygon

module Ruby2D
  # A closed polygon defined by N vertices (N >= 3), filled or stroked.
  class Polygon
    include Renderable

    attr_accessor :rotate, :fill, :stroke_width
    attr_reader :stroke_color
    alias_method :stroke_colour, :stroke_color

    # Create a polygon
    # points is an array of [x, y] pairs with N >= 3 vertices
    def initialize(points:, z: 0, rotate: 0, rx: nil, ry: nil,
                   color: nil, colour: nil, opacity: nil,
                   fill: true, stroke_width: 0, stroke_color: nil, stroke_colour: nil,
                   add: true, visible: true)
      raise ArgumentError, 'Polygon requires at least 3 points' if points.length < 3
      raise ArgumentError, 'points must be an array of [x, y] pairs' \
        unless points.all? { |p| p.is_a?(Array) && p.length == 2 }

      @coordinates = points.flat_map { |x, y| [x.to_f, y.to_f] }
      @z = z
      @rotate = rotate
      @_user_rx = rx
      @_user_ry = ry
      self.color = color || colour || 'white'
      self.opacity = opacity unless opacity.nil?
      @fill = fill
      @stroke_width = stroke_width
      self.stroke_color = stroke_color || stroke_colour || (color || colour)
      self.stroke_color.opacity = opacity unless opacity.nil?
      @visible = visible
      self.add if add
    end

    # Number of vertices
    def vertex_count
      @coordinates.length / 2
    end

    # The vertices as an array of [x, y] pairs
    def points
      @coordinates.each_slice(2).to_a
    end

    # Bounding-box width and height (extent across all vertices)
    def width
      xs = @coordinates.each_slice(2).map(&:first)
      xs.max - xs.min
    end

    def height
      ys = @coordinates.each_slice(2).map(&:last)
      ys.max - ys.min
    end

    # Test whether (x, y) lies inside the polygon, using the even-odd ray-cast
    # rule (shared by every filled polygonal shape — see `_point_in_polygon?`).
    # Matches the rendered fill for non-self-intersecting polygons (convex and
    # concave); self-intersecting input isn't fully supported by the renderer, so
    # the test can diverge from the drawn pixels there.
    def contains?(x, y)
      x, y = _unrotate(x, y)
      _point_in_polygon?(@coordinates, x, y)
    end

    # Centroid x (average of vertex x coordinates)
    def x
      sum = 0.0
      n = vertex_count
      n.times { |i| sum += @coordinates[i * 2] }
      sum / n
    end

    # Centroid y (average of vertex y coordinates)
    def y
      sum = 0.0
      n = vertex_count
      n.times { |i| sum += @coordinates[i * 2 + 1] }
      sum / n
    end

    # Set the centroid x coordinate, translating all vertices
    def x=(new_x)
      _require_numeric_position(:x, new_x)
      dx = new_x - x
      i = 0
      while i < @coordinates.length
        @coordinates[i] += dx
        i += 2
      end
    end

    # Set the centroid y coordinate, translating all vertices
    def y=(new_y)
      _require_numeric_position(:y, new_y)
      dy = new_y - y
      i = 1
      while i < @coordinates.length
        @coordinates[i] += dy
        i += 2
      end
    end

    # Get the rotation center x coordinate
    def rx
      @_user_rx.nil? ? x : @_user_rx
    end

    # Get the rotation center y coordinate
    def ry
      @_user_ry.nil? ? y : @_user_ry
    end

    # Set the rotation center x coordinate
    def rx=(val)
      @_user_rx = val
    end

    # Set the rotation center y coordinate
    def ry=(val)
      @_user_ry = val
    end

    # Set the fill color (single or per-vertex array).
    # Per-vertex array length must match vertex_count.
    def color=(color)
      cs = Color.set(color)
      if cs.is_a?(Color::Set) && cs.length != vertex_count
        raise ArgumentError,
              "`#{self.class}` requires #{vertex_count} colors, one for each vertex. #{cs.length} were given."
      end
      @color = cs
      @_cc = nil
    end

    # Set the stroke color. Accepts a single color or a `Color::Set` of
    # vertex_count colors (one per vertex) interpolated around the perimeter.
    def stroke_color=(c)
      @stroke_color = Renderable.resolve_color_or_default(c, vertex_count, label: self.class)
      @_stroke_cc = nil
    end
    alias_method :stroke_colour=, :stroke_color=

    # Render a polygon without creating an instance
    def self.render(points:, rotate: 0, rx: nil, ry: nil,
                    color: nil, colour: nil, opacity: nil,
                    fill: true, stroke_width: 0, stroke_color: nil, stroke_colour: nil)
      Window.render_ready_check
      raise ArgumentError, 'Polygon requires at least 3 points' if points.length < 3

      n = points.length
      coords = Renderable.flatten_points(points)
      fill_input = color || colour
      pvc = Renderable.flatten_color(fill_input, n, opacity, label: self)

      if rotate != 0
        ccx = 0.0; ccy = 0.0
        n.times do |i|
          ccx += coords[i * 2]
          ccy += coords[i * 2 + 1]
        end
        ccx /= n
        ccy /= n
        coords = rotate_coords(coords, rotate, rx || ccx, ry || ccy)
      end

      Ext.draw_polygon(coords, pvc) if fill
      # Flatten the stroke colors only when actually stroking; an explicitly
      # given stroke color is still validated at stroke_width 0 to match the
      # instance constructor.
      if stroke_width > 0
        pvs = Renderable.flatten_color(stroke_color || stroke_colour || fill_input, n, opacity, label: self)
        Ext.stroke_path(coords, stroke_width, pvs, true)
      elsif stroke_color || stroke_colour
        Renderable.flatten_color(stroke_color || stroke_colour, n, opacity, label: self)
      end
    end

    private

    # Apply rotation to every (x, y) pair in a flat coords array, writing into
    # `out` (allocated fresh when nil) — the input is never mutated. The
    # instance render path passes a reused per-object buffer so a rotated
    # polygon doesn't allocate an N-element array every frame; the native draw
    # copies the values out synchronously, so reuse is safe.
    def self.rotate_coords(coords, angle, cx, cy, out = nil)
      rad = angle * Math::PI / 180.0
      sa = Math.sin(rad)
      ca = Math.cos(rad)
      n = coords.length / 2
      out ||= Array.new(coords.length)
      n.times do |i|
        dx = coords[i * 2]     - cx
        dy = coords[i * 2 + 1] - cy
        out[i * 2]     = dx * ca - dy * sa + cx
        out[i * 2 + 1] = dx * sa + dy * ca + cy
      end
      out
    end
    private_class_method :rotate_coords

    def render
      ensure_cc
      ensure_scc if @stroke_width && @stroke_width > 0

      coords = @coordinates
      if @rotate != 0
        # Resolve the rotation center in a single vertex pass. Calling `rx` and
        # `ry` separately would average the coordinates twice (two N-loops) when
        # no user pivot is set; an explicit pivot skips the loop entirely.
        if !@_user_rx.nil? && !@_user_ry.nil?
          cx = @_user_rx
          cy = @_user_ry
        else
          sum_x = 0.0
          sum_y = 0.0
          n = vertex_count
          n.times do |i|
            sum_x += @coordinates[i * 2]
            sum_y += @coordinates[i * 2 + 1]
          end
          cx = @_user_rx.nil? ? sum_x / n : @_user_rx
          cy = @_user_ry.nil? ? sum_y / n : @_user_ry
        end
        if @_rot_coords.nil? || @_rot_coords.length != @coordinates.length
          @_rot_coords = Array.new(@coordinates.length)
        end
        coords = Polygon.send(:rotate_coords, @coordinates, @rotate, cx, cy, @_rot_coords)
      end

      Ext.draw_polygon(coords, @_cc)              if @fill
      Ext.stroke_path(coords, @stroke_width, @_stroke_cc, true) if @stroke_width && @stroke_width > 0
    end

    # Scene-graph draw hook (see Renderable#_render_scene). Polygon's `render` is
    # already zero-arg, so the hook is the same method under the scene name.
    alias_method :_render_scene, :render
    public :_render_scene

    # Flatten @color into per-vertex RGBA array. If @color is a Color::Set, use
    # each entry; otherwise replicate across all vertices.
    def ensure_cc
      n = vertex_count
      if @_cc.nil? || @_cc.length != n * 4 || !cc_matches?
        @_cc = Array.new(n * 4)
        n.times do |i|
          c = @color.vertex(i)
          @_cc[i * 4]     = c.r
          @_cc[i * 4 + 1] = c.g
          @_cc[i * 4 + 2] = c.b
          @_cc[i * 4 + 3] = c.a
        end
      end
    end

    def cc_matches?
      n = vertex_count
      n.times do |i|
        c = @color.vertex(i)
        return false if @_cc[i * 4]     != c.r
        return false if @_cc[i * 4 + 1] != c.g
        return false if @_cc[i * 4 + 2] != c.b
        return false if @_cc[i * 4 + 3] != c.a
      end
      true
    end

    # Build flat per-vertex stroke color cache (vertex_count × rgba floats)
    def ensure_scc
      n = vertex_count
      if @_stroke_cc.nil? || @_stroke_cc.length != n * 4 || !scc_matches?
        @_stroke_cc = Array.new(n * 4)
        n.times do |i|
          c = @stroke_color.vertex(i)
          @_stroke_cc[i * 4]     = c.r
          @_stroke_cc[i * 4 + 1] = c.g
          @_stroke_cc[i * 4 + 2] = c.b
          @_stroke_cc[i * 4 + 3] = c.a
        end
      end
    end

    def scc_matches?
      n = vertex_count
      n.times do |i|
        c = @stroke_color.vertex(i)
        return false if @_stroke_cc[i * 4]     != c.r
        return false if @_stroke_cc[i * 4 + 1] != c.g
        return false if @_stroke_cc[i * 4 + 2] != c.b
        return false if @_stroke_cc[i * 4 + 3] != c.a
      end
      true
    end
  end
end

# ---------- lib/ruby2d/polyline.rb ----------

# Ruby2D::Polyline

module Ruby2D
  # A connected sequence of line segments. Stroke-only (no fill).
  # Set `closed: true` to connect the last point back to the first.
  class Polyline
    include Renderable

    attr_accessor :rotate, :stroke_width, :closed

    # Miter-join limit, matching `R2D_MITER_LIMIT` in the C extension (the SVG
    # default). A sharp corner's miter is clamped to `MITER_LIMIT * stroke_width / 2`.
    MITER_LIMIT = 4.0

    # Create a polyline
    # points is an array of [x, y] pairs with N >= 2 vertices
    def initialize(points:, z: 0, rotate: 0, rx: nil, ry: nil,
                   color: nil, colour: nil, opacity: nil,
                   stroke_width: 1, closed: false, add: true, visible: true)
      raise ArgumentError, 'Polyline requires at least 2 points' if points.length < 2
      raise ArgumentError, 'points must be an array of [x, y] pairs' \
        unless points.all? { |p| p.is_a?(Array) && p.length == 2 }

      @coordinates = points.flat_map { |x, y| [x.to_f, y.to_f] }
      @z = z
      @rotate = rotate
      @_user_rx = rx
      @_user_ry = ry
      @stroke_width = stroke_width
      @closed = closed
      self.color = color || colour || 'white'
      self.opacity = opacity unless opacity.nil?
      @visible = visible
      self.add if add
    end

    # Number of vertices
    def vertex_count
      @coordinates.length / 2
    end

    # The vertices as an array of [x, y] pairs
    def points
      @coordinates.each_slice(2).to_a
    end

    # Bounding-box width and height (extent across all vertices)
    def width
      xs = @coordinates.each_slice(2).map(&:first)
      xs.max - xs.min
    end

    def height
      ys = @coordinates.each_slice(2).map(&:last)
      ys.max - ys.min
    end

    # Test whether (x, y) lies on the polyline's stroke. Hit-tests against the
    # exact shape the renderer draws — the ribbon between the outer and inner
    # stroke outlines, with mitered joints and butt-capped open ends — so the
    # clickable region matches the visible pixels, corners and all. A closed
    # path joins at every vertex (no open ends).
    def contains?(x, y)
      return false unless @stroke_width.positive?
      x, y = _unrotate(x, y) if @rotate != 0
      n = vertex_count
      outer, inner = compute_stroke_outline
      edges = @closed ? n : n - 1
      edges.times do |i|
        j = (i + 1) % n
        # The renderer fills each edge as the quad outer[i] → inner[i] →
        # inner[j] → outer[j]; the point is on the stroke iff it lies inside any
        # of those quads. The miter outline makes the corners exact.
        oi = outer[i]; ii = inner[i]
        oj = outer[j]; ij = inner[j]
        return true if _point_in_polygon?(
          [oi[0], oi[1], ii[0], ii[1], ij[0], ij[1], oj[0], oj[1]], x, y
        )
      end
      false
    end

    # Centroid x
    def x
      sum = 0.0
      n = vertex_count
      n.times { |i| sum += @coordinates[i * 2] }
      sum / n
    end

    # Centroid y
    def y
      sum = 0.0
      n = vertex_count
      n.times { |i| sum += @coordinates[i * 2 + 1] }
      sum / n
    end

    # Set the centroid x coordinate, translating all vertices
    def x=(new_x)
      _require_numeric_position(:x, new_x)
      dx = new_x - x
      i = 0
      while i < @coordinates.length
        @coordinates[i] += dx
        i += 2
      end
    end

    # Set the centroid y coordinate, translating all vertices
    def y=(new_y)
      _require_numeric_position(:y, new_y)
      dy = new_y - y
      i = 1
      while i < @coordinates.length
        @coordinates[i] += dy
        i += 2
      end
    end

    # Get the rotation center x coordinate
    def rx
      @_user_rx.nil? ? x : @_user_rx
    end

    # Get the rotation center y coordinate
    def ry
      @_user_ry.nil? ? y : @_user_ry
    end

    # Set the rotation center x coordinate
    def rx=(val)
      @_user_rx = val
    end

    # Set the rotation center y coordinate
    def ry=(val)
      @_user_ry = val
    end

    # The stroke color. Accepts a single color or a `Color::Set` of
    # vertex_count colors (one per vertex) interpolated along the path.
    def color=(c)
      @color = Renderable.resolve_color_or_default(c, vertex_count, label: self.class)
      @_stroke_cc = nil
    end

    # Set opacity. Accepts a single value (applied to all vertices) or an
    # array of per-vertex values (length must equal vertex_count).
    def opacity=(value)
      if value.is_a?(Array)
        n = vertex_count
        raise ArgumentError,
              "opacity array must have #{n} values, one for each vertex. #{value.length} were given." \
              unless value.length == n
        # Clamp each entry to 0.0..1.0, matching the scalar path (Color#opacity=).
        # NaN can't be clamped (Float::NAN.clamp raises), so map it to 0.0 first.
        @_per_vertex_opacity = value.map do |v|
          f = v.to_f
          f = 0.0 if f.nan?
          f.clamp(0.0, 1.0)
        end
      else
        @_per_vertex_opacity = nil
        @color.opacity = value
      end
      @_stroke_cc = nil
    end

    # Get opacity. Returns the per-vertex array when set, otherwise the
    # uniform alpha from the first vertex color.
    def opacity
      @_per_vertex_opacity || @color&.opacity
    end

    # Render a polyline without creating an instance
    def self.render(points:, rotate: 0, rx: nil, ry: nil,
                    color: nil, colour: nil, opacity: nil,
                    stroke_width: 1, closed: false)
      Window.render_ready_check
      raise ArgumentError, 'Polyline requires at least 2 points' if points.length < 2

      n = points.length
      coords = Renderable.flatten_points(points)
      pvs = Renderable.flatten_color(color || colour, n, opacity, label: self)

      if rotate != 0
        ccx = 0.0; ccy = 0.0
        n.times do |i|
          ccx += coords[i * 2]
          ccy += coords[i * 2 + 1]
        end
        ccx /= n
        ccy /= n
        coords = rotate_coords(coords, rotate, rx || ccx, ry || ccy)
      end

      Ext.stroke_path(coords, stroke_width, pvs, closed) if stroke_width > 0
    end

    private

    # Build the stroke outline the renderer draws: the outer- and inner-edge
    # point for each vertex, with miter joins clamped to `MITER_LIMIT` and butt
    # caps at the open ends. A faithful port of `R2D_ComputeStrokeOutline`
    # (`ext/ruby2d/shapes.c`) — keep the two in sync. Returns `[outer, inner]`,
    # each an array of `[x, y]`. Used by `contains?` to hit-test the exact drawn
    # shape, including the mitered corner spikes a round-join disk would miss.
    def compute_stroke_outline
      n = vertex_count
      coords = @coordinates
      hw = @stroke_width / 2.0
      max_ml = MITER_LIMIT * hw
      outer = Array.new(n)
      inner = Array.new(n)

      n.times do |i|
        vx = coords[i * 2]
        vy = coords[i * 2 + 1]

        # Open-path endpoints get a butt cap: perpendicular of the lone edge.
        if !@closed && (i == 0 || i == n - 1)
          other = i == 0 ? 1 : n - 2
          dx = vx - coords[other * 2]
          dy = vy - coords[other * 2 + 1]
          if i == 0
            dx = -dx
            dy = -dy
          end
          len = Math.sqrt(dx * dx + dy * dy)
          if len < 0.0001
            outer[i] = [vx, vy]
            inner[i] = [vx, vy]
          else
            nx = -dy / len
            ny = dx / len
            outer[i] = [vx + nx * hw, vy + ny * hw]
            inner[i] = [vx - nx * hw, vy - ny * hw]
          end
          next
        end

        # Interior joint (every vertex when closed): miter.
        prev = (i - 1 + n) % n
        nxt = (i + 1) % n
        d1x = vx - coords[prev * 2]
        d1y = vy - coords[prev * 2 + 1]
        d2x = coords[nxt * 2] - vx
        d2y = coords[nxt * 2 + 1] - vy
        len1 = Math.sqrt(d1x * d1x + d1y * d1y)
        len2 = Math.sqrt(d2x * d2x + d2y * d2y)
        if len1 < 0.0001 || len2 < 0.0001
          outer[i] = [vx, vy]
          inner[i] = [vx, vy]
          next
        end
        d1x /= len1; d1y /= len1
        d2x /= len2; d2y /= len2
        n1x = -d1y; n1y = d1x
        n2x = -d2y; n2y = d2x
        mx = n1x + n2x
        my = n1y + n2y
        mlen = Math.sqrt(mx * mx + my * my)
        if mlen < 0.0001
          # 180° turn — degenerate; use the perpendicular of the first edge.
          outer[i] = [vx + n1x * hw, vy + n1y * hw]
          inner[i] = [vx - n1x * hw, vy - n1y * hw]
          next
        end
        mx /= mlen; my /= mlen
        dot = mx * n1x + my * n1y
        dot = 0.0001 if dot.abs < 0.0001
        ml = hw / dot
        ml = max_ml if ml > max_ml
        ml = -max_ml if ml < -max_ml
        outer[i] = [vx + mx * ml, vy + my * ml]
        inner[i] = [vx - mx * ml, vy - my * ml]
      end

      [outer, inner]
    end

    # Apply rotation to every (x, y) pair in a flat coords array, writing into
    # `out` (allocated fresh when nil) — the input is never mutated. The
    # instance render path passes a reused per-object buffer so a rotated
    # polyline doesn't allocate an N-element array every frame; the native draw
    # copies the values out synchronously, so reuse is safe.
    def self.rotate_coords(coords, angle, cx, cy, out = nil)
      rad = angle * Math::PI / 180.0
      sa = Math.sin(rad)
      ca = Math.cos(rad)
      n = coords.length / 2
      out ||= Array.new(coords.length)
      n.times do |i|
        dx = coords[i * 2]     - cx
        dy = coords[i * 2 + 1] - cy
        out[i * 2]     = dx * ca - dy * sa + cx
        out[i * 2 + 1] = dx * sa + dy * ca + cy
      end
      out
    end
    private_class_method :rotate_coords

    def render
      ensure_scc

      coords = @coordinates
      if @rotate != 0
        # Resolve the rotation center in a single vertex pass. Calling `rx` and
        # `ry` separately would average the coordinates twice (two N-loops) when
        # no user pivot is set; an explicit pivot skips the loop entirely.
        if !@_user_rx.nil? && !@_user_ry.nil?
          cx = @_user_rx
          cy = @_user_ry
        else
          sum_x = 0.0
          sum_y = 0.0
          n = vertex_count
          n.times do |i|
            sum_x += @coordinates[i * 2]
            sum_y += @coordinates[i * 2 + 1]
          end
          cx = @_user_rx.nil? ? sum_x / n : @_user_rx
          cy = @_user_ry.nil? ? sum_y / n : @_user_ry
        end
        if @_rot_coords.nil? || @_rot_coords.length != @coordinates.length
          @_rot_coords = Array.new(@coordinates.length)
        end
        coords = Polyline.send(:rotate_coords, @coordinates, @rotate, cx, cy, @_rot_coords)
      end

      Ext.stroke_path(coords, @stroke_width, @_stroke_cc, @closed) if @stroke_width && @stroke_width > 0
    end

    # Scene-graph draw hook (see Renderable#_render_scene). Polyline's `render`
    # is already zero-arg, so the hook is the same method under the scene name.
    alias_method :_render_scene, :render
    public :_render_scene

    # Build flat per-vertex stroke color cache (vertex_count × rgba floats)
    def ensure_scc
      n = vertex_count
      if @_stroke_cc.nil? || @_stroke_cc.length != n * 4 || !scc_matches?
        @_stroke_cc = Array.new(n * 4)
        n.times do |i|
          c = @color.vertex(i)
          @_stroke_cc[i * 4]     = c.r
          @_stroke_cc[i * 4 + 1] = c.g
          @_stroke_cc[i * 4 + 2] = c.b
          @_stroke_cc[i * 4 + 3] = @_per_vertex_opacity ? @_per_vertex_opacity[i] : c.a
        end
      end
    end

    def scc_matches?
      n = vertex_count
      n.times do |i|
        c = @color.vertex(i)
        a = @_per_vertex_opacity ? @_per_vertex_opacity[i] : c.a
        return false if @_stroke_cc[i * 4]     != c.r
        return false if @_stroke_cc[i * 4 + 1] != c.g
        return false if @_stroke_cc[i * 4 + 2] != c.b
        return false if @_stroke_cc[i * 4 + 3] != a
      end
      true
    end
  end
end

# ---------- lib/ruby2d/quad.rb ----------

# Ruby2D::Quad

module Ruby2D
  # A quadrilateral based on four points in clockwise order starting at the top left.
  class Quad
    include Renderable

    # Coordinates in clockwise order, starting at top left:
    # x1,y1 == top left
    # x2,y2 == top right
    # x3,y3 == bottom right
    # x4,y4 == bottom left
    attr_accessor :x1, :y1,
                  :x2, :y2,
                  :x3, :y3,
                  :x4, :y4,
                  :rotate,
                  :fill, :stroke_width
    attr_reader :stroke_color
    alias_method :stroke_colour, :stroke_color

    # The x coordinate of the centroid (average of the four vertex x's)
    def x
      (@x1 + @x2 + @x3 + @x4) / 4.0
    end

    # The y coordinate of the centroid (average of the four vertex y's)
    def y
      (@y1 + @y2 + @y3 + @y4) / 4.0
    end

    # Set the x coordinate of the centroid, translating all vertices
    def x=(new_x)
      _require_numeric_position(:x, new_x)
      dx = new_x - x
      @x1 += dx
      @x2 += dx
      @x3 += dx
      @x4 += dx
    end

    # Set the y coordinate of the centroid, translating all vertices
    def y=(new_y)
      _require_numeric_position(:y, new_y)
      dy = new_y - y
      @y1 += dy
      @y2 += dy
      @y3 += dy
      @y4 += dy
    end

    # Bounding-box width and height (extent across the four vertices)
    def width
      xs = [@x1, @x2, @x3, @x4]
      xs.max - xs.min
    end

    def height
      ys = [@y1, @y2, @y3, @y4]
      ys.max - ys.min
    end

    # Create a quadrilateral. Specify vertices via `points:` or via
    # `x1:`/`y1:`/... `points:` takes precedence if both are given.
    def initialize(x1: 0, y1: 0, x2: 100, y2: 0, x3: 100, y3: 100, x4: 0, y4: 100,
                   points: nil,
                   z: 0, rotate: 0, rx: nil, ry: nil,
                   color: nil, colour: nil, opacity: nil,
                   fill: true, stroke_width: 0, stroke_color: nil, stroke_colour: nil,
                   add: true, visible: true)
      if points
        Quad.send(:validate_points, points)
        x1, y1 = points[0]
        x2, y2 = points[1]
        x3, y3 = points[2]
        x4, y4 = points[3]
      end
      @x1 = x1
      @y1 = y1
      @x2 = x2
      @y2 = y2
      @x3 = x3
      @y3 = y3
      @x4 = x4
      @y4 = y4
      @z  = z
      @rotate = rotate
      @_user_rx = rx
      @_user_ry = ry
      self.color = color || colour || 'white'
      self.opacity = opacity unless opacity.nil?
      @fill = fill
      @stroke_width = stroke_width
      self.stroke_color = stroke_color || stroke_colour || (color || colour)
      self.stroke_color.opacity = opacity unless opacity.nil?
      @visible = visible
      self.add if add
    end

    # Set the stroke color. Accepts a single color or a `Color::Set` of 4
    # (one per vertex) interpolated around the perimeter. If nil, defaults to
    # the fill color (preserving a per-vertex set when the fill is per-vertex).
    def stroke_color=(c)
      @stroke_color = Renderable.resolve_color_or_default(c, 4, label: self.class)
      # A single stroke Color (not a per-vertex Set) takes the compact
      # `stroke_quad_uniform` fast path.
      @_stroke_color_uniform = !@stroke_color.is_a?(Color::Set)
      @_stroke_cc = nil
    end
    alias_method :stroke_colour=, :stroke_color=

    # Set the color of the quad
    def color=(color)
      # convert to Color or Color::Set
      color = Color.set(color)

      # require 4 colours if multiple colours provided
      if color.is_a?(Color::Set) && color.length != 4
        raise ArgumentError,
              "`#{self.class}` requires 4 colors, one for each vertex. #{color.length} were given."
      end

      @color = color # converted above
      # A single Color (not a per-vertex Set) is uniform across all four
      # vertices, so it takes the compact `draw_quad_uniform` fast path.
      @_color_uniform = !color.is_a?(Color::Set)
      @_cc = nil # invalidate cached color components
    end

    # Check if the quad contains the given point (inside the rendered fill).
    # Ray-cast over the four vertices, so concave quads hit-test against what's
    # actually drawn — unlike the old area method, which only held for convex
    # quads. Self-intersecting (bow-tie) quads aren't fully supported by the fill
    # renderer, so the test can diverge from the drawn pixels there.
    def contains?(x, y)
      x, y = _unrotate(x, y)
      _point_in_polygon?([@x1, @y1, @x2, @y2, @x3, @y3, @x4, @y4], x, y)
    end

    # Get the rotation center x coordinate
    def rx
      @_user_rx.nil? ? (@x1 + @x2 + @x3 + @x4) / 4.0 : @_user_rx
    end

    # Get the rotation center y coordinate
    def ry
      @_user_ry.nil? ? (@y1 + @y2 + @y3 + @y4) / 4.0 : @_user_ry
    end

    # Set the rotation center x coordinate
    def rx=(val)
      @_user_rx = val
    end

    # Set the rotation center y coordinate
    def ry=(val)
      @_user_ry = val
    end

    # Render a quad without creating an instance
    def self.render(x1: 0, y1: 0, x2: 100, y2: 0, x3: 100, y3: 100, x4: 0, y4: 100,
                    points: nil,
                    rotate: 0, rx: nil, ry: nil,
                    color: nil, colour: nil, opacity: nil,
                    fill: true, stroke_width: 0, stroke_color: nil, stroke_colour: nil)
      if points
        validate_points(points)
        x1, y1 = points[0]
        x2, y2 = points[1]
        x3, y3 = points[2]
        x4, y4 = points[3]
      end
      draw_immediate(x1, y1, x2, y2, x3, y3, x4, y4, rotate, rx, ry,
                     color || colour, opacity, fill, stroke_width,
                     stroke_color || stroke_colour)
    end

    # The immediate-mode draw shared by Quad, Rectangle, and Square. Takes
    # positional arguments, and subclasses call it directly instead of
    # forwarding through `super`: keyword dispatch is expensive on mruby
    # (~17µs per hop of this many keywords on the web build), so each public
    # `.render` pays for its own keywords exactly once. `rx`/`ry` may be nil
    # (centroid default); `explicit_stroke` is the user's stroke color or nil.
    def self.draw_immediate(x1, y1, x2, y2, x3, y3, x4, y4, rotate, rx, ry,
                            fill_input, opacity, fill, stroke_width, explicit_stroke)
      Window.render_ready_check
      # Resolve the fill color once. A single Color (not a per-vertex Set) with
      # scalar opacity is uniform across all four vertices and draws via the
      # compact `draw_quad_uniform`; otherwise build the per-vertex color array
      # from the already-resolved color (no second parse). `for_render` returns
      # a shared cached instance for string colors — read-only here.
      # A per-vertex color flattens straight to floats, skipping the
      # `Color::Set` the general path builds — that allocates and parses one
      # `Color` per vertex on every call. `resolved` stays nil in that case
      # and the stroke below resolves for itself if it ends up needing one.
      # The `is_a?(Array)` guard is inline so the common single-color call
      # doesn't pay for a method call that would only decline.
      c = fill_input.is_a?(Array) ? Renderable.flatten_per_vertex(fill_input, 4, opacity) : nil
      if c
        resolved = nil
        uniform = false
      else
        resolved = Color.for_render(fill_input.nil? ? 'white' : fill_input)
        uniform = !resolved.is_a?(Color::Set) && !opacity.is_a?(Array)
        c = uniform ? nil : Renderable.flatten_resolved_color(resolved, 4, opacity, label: self)
      end

      # Rotation is inlined into locals (as in `render` below and Line#render):
      # a helper returning the rotated points would allocate an array per
      # rotated shape per frame — measured 2.9µs vs 1.8µs per quad on wasm.
      if rotate != 0
        cx = rx || (x1 + x2 + x3 + x4) / 4.0
        cy = ry || (y1 + y2 + y3 + y4) / 4.0
        rad = rotate * Math::PI / 180.0
        sa = Math.sin(rad)
        ca = Math.cos(rad)
        dx = x1 - cx; dy = y1 - cy
        x1 = dx * ca - dy * sa + cx; y1 = dx * sa + dy * ca + cy
        dx = x2 - cx; dy = y2 - cy
        x2 = dx * ca - dy * sa + cx; y2 = dx * sa + dy * ca + cy
        dx = x3 - cx; dy = y3 - cy
        x3 = dx * ca - dy * sa + cx; y3 = dx * sa + dy * ca + cy
        dx = x4 - cx; dy = y4 - cy
        x4 = dx * ca - dy * sa + cx; y4 = dx * sa + dy * ca + cy
      end

      if fill
        if uniform
          a = opacity || resolved.a
          Ext.draw_quad_uniform(x1, y1, x2, y2, x3, y3, x4, y4, resolved.r, resolved.g, resolved.b, a)
        else
          c1r, c1g, c1b, c1a, c2r, c2g, c2b, c2a,
            c3r, c3g, c3b, c3a, c4r, c4g, c4b, c4a = c
          Ext.draw_quad(
            x1, y1, c1r, c1g, c1b, c1a,
            x2, y2, c2r, c2g, c2b, c2a,
            x3, y3, c3r, c3g, c3b, c3a,
            x4, y4, c4r, c4g, c4b, c4a
          )
        end
      end

      # Resolve the stroke color only when actually stroking. A single stroke
      # color draws via the compact `stroke_quad_uniform`; a per-vertex Set keeps
      # the splatting path. When no explicit stroke is given the stroke reuses
      # the already-resolved fill color. (An explicit stroke color is still
      # validated at stroke_width 0 below, matching the instance constructor.)
      if stroke_width > 0
        stroke_input = explicit_stroke || fill_input
        sresolved = if !stroke_input.equal?(fill_input)
                      Color.for_render(stroke_input)
                    else
                      resolved || Color.for_render(fill_input.nil? ? 'white' : fill_input)
                    end
        if !sresolved.is_a?(Color::Set) && !opacity.is_a?(Array)
          sa = opacity || sresolved.a
          Ext.stroke_quad_uniform(x1, y1, x2, y2, x3, y3, x4, y4, stroke_width,
                                  sresolved.r, sresolved.g, sresolved.b, sa)
        else
          s1r, s1g, s1b, s1a, s2r, s2g, s2b, s2a,
            s3r, s3g, s3b, s3a, s4r, s4g, s4b, s4a =
            Renderable.flatten_resolved_color(sresolved, 4, opacity, label: self)
          Ext.stroke_quad(
            x1, y1, x2, y2, x3, y3, x4, y4, stroke_width,
            s1r, s1g, s1b, s1a,
            s2r, s2g, s2b, s2a,
            s3r, s3g, s3b, s3a,
            s4r, s4g, s4b, s4a
          )
        end
      elsif explicit_stroke
        Renderable.flatten_color(explicit_stroke, 4, opacity, label: self)
      end
    end
    private_class_method :draw_immediate

    private

    def self.validate_points(points)
      raise ArgumentError, 'Quad requires exactly 4 points' unless points.length == 4
      raise ArgumentError, 'points must be an array of [x, y] pairs' \
        unless points.all? { |p| p.is_a?(Array) && p.length == 2 }
    end
    private_class_method :validate_points

    def render
      # Note: Quad does not support symbolic alignment — its `x`/`y` are the
      # centroid, not a top-left origin, so `_resolve_alignment` (which assumes
      # top-left) cannot position it coherently. Matches Triangle/Polygon.
      ensure_cc
      ensure_scc if @stroke_width && @stroke_width > 0

      x1, y1, x2, y2, x3, y3, x4, y4 = @x1, @y1, @x2, @y2, @x3, @y3, @x4, @y4

      # Rotation inlined into locals — see the `draw_immediate` note.
      if @rotate != 0
        cx = rx; cy = ry
        rad = @rotate * Math::PI / 180.0
        sa = Math.sin(rad)
        ca = Math.cos(rad)
        dx = x1 - cx; dy = y1 - cy
        x1 = dx * ca - dy * sa + cx; y1 = dx * sa + dy * ca + cy
        dx = x2 - cx; dy = y2 - cy
        x2 = dx * ca - dy * sa + cx; y2 = dx * sa + dy * ca + cy
        dx = x3 - cx; dy = y3 - cy
        x3 = dx * ca - dy * sa + cx; y3 = dx * sa + dy * ca + cy
        dx = x4 - cx; dy = y4 - cy
        x4 = dx * ca - dy * sa + cx; y4 = dx * sa + dy * ca + cy
      end

      if @fill
        cc = @_cc
        if @_color_uniform
          Ext.draw_quad_uniform(x1, y1, x2, y2, x3, y3, x4, y4, cc[0], cc[1], cc[2], cc[3])
        else
          Ext.draw_quad(
            x1, y1, cc[0],  cc[1],  cc[2],  cc[3],
            x2, y2, cc[4],  cc[5],  cc[6],  cc[7],
            x3, y3, cc[8],  cc[9],  cc[10], cc[11],
            x4, y4, cc[12], cc[13], cc[14], cc[15]
          )
        end
      end

      if @stroke_width && @stroke_width > 0
        scc = @_stroke_cc
        if @_stroke_color_uniform
          Ext.stroke_quad_uniform(x1, y1, x2, y2, x3, y3, x4, y4, @stroke_width, scc[0], scc[1], scc[2], scc[3])
        else
          Ext.stroke_quad(
            x1, y1, x2, y2, x3, y3, x4, y4, @stroke_width,
            scc[0],  scc[1],  scc[2],  scc[3],
            scc[4],  scc[5],  scc[6],  scc[7],
            scc[8],  scc[9],  scc[10], scc[11],
            scc[12], scc[13], scc[14], scc[15]
          )
        end
      end
    end

    # Scene-graph draw hook (see Renderable#_render_scene). Quad's `render` is
    # already zero-arg, so the hook is the same method under the scene name.
    alias_method :_render_scene, :render
    public :_render_scene

    # Build/rebuild flat per-vertex stroke color cache (4 × rgba = 16 floats)
    def ensure_scc
      if @_stroke_color_uniform
        c = @stroke_color
        if @_stroke_cc.nil? || @_stroke_cc[0] != c.r || @_stroke_cc[1] != c.g || @_stroke_cc[2] != c.b || @_stroke_cc[3] != c.a
          @_stroke_cc = [c.r, c.g, c.b, c.a]
        end
      elsif @_stroke_cc.nil? || !scc_matches?
        @_stroke_cc = Array.new(16)
        4.times do |i|
          c = @stroke_color.vertex(i)
          @_stroke_cc[i * 4]     = c.r
          @_stroke_cc[i * 4 + 1] = c.g
          @_stroke_cc[i * 4 + 2] = c.b
          @_stroke_cc[i * 4 + 3] = c.a
        end
      end
    end

    def scc_matches?
      4.times do |i|
        c = @stroke_color.vertex(i)
        return false if @_stroke_cc[i * 4]     != c.r
        return false if @_stroke_cc[i * 4 + 1] != c.g
        return false if @_stroke_cc[i * 4 + 2] != c.b
        return false if @_stroke_cc[i * 4 + 3] != c.a
      end
      true
    end

    # Build/rebuild flat color cache for the native extension
    def ensure_cc
      # Solid fill: cache 4 floats and validity-check 4 comparisons (the
      # per-frame check still catches in-place `color.opacity=` fades). Mirrors
      # the Circle/Ellipse single-color cache.
      if @_color_uniform
        c = @color
        if @_cc.nil? || @_cc[0] != c.r || @_cc[1] != c.g || @_cc[2] != c.b || @_cc[3] != c.a
          @_cc = [c.r, c.g, c.b, c.a]
        end
      elsif @_cc.nil? || !cc_matches?
        @_cc = Array.new(16)
        4.times do |i|
          c = @color.vertex(i)
          @_cc[i * 4]     = c.r
          @_cc[i * 4 + 1] = c.g
          @_cc[i * 4 + 2] = c.b
          @_cc[i * 4 + 3] = c.a
        end
      end
    end

    def cc_matches?
      4.times do |i|
        c = @color.vertex(i)
        return false if @_cc[i * 4]     != c.r
        return false if @_cc[i * 4 + 1] != c.g
        return false if @_cc[i * 4 + 2] != c.b
        return false if @_cc[i * 4 + 3] != c.a
      end
      true
    end
  end
end

# ---------- lib/ruby2d/rectangle.rb ----------

# Ruby2D::Rectangle

module Ruby2D
  # A rectangle
  class Rectangle < Quad
    # Create a rectangle
    def initialize(x: 0, y: 0, width: 200, height: 100, z: 0, rotate: 0,
                   rx: nil, ry: nil, color: nil, colour: nil, opacity: nil,
                   fill: true, stroke_width: 0, stroke_color: nil, stroke_colour: nil,
                   add: true, visible: true,
                   padding: nil, padding_top: nil, padding_right: nil,
                   padding_bottom: nil, padding_left: nil)
      x, y = _extract_alignment(x, y)
      _apply_padding(padding, padding_top, padding_right, padding_bottom, padding_left)
      _validate_dimensions(width: width, height: height)
      @width = width
      @height = height
      super(x1: @x = x, y1: @y = y,
            x2: x + width, y2: y,
            x3: x + width, y3: y + height,
            x4: x, y4: y + height, z: z, rotate: rotate,
            rx: rx, ry: ry,
            color: color, colour: colour, opacity: opacity,
            fill: fill, stroke_width: stroke_width,
            stroke_color: stroke_color, stroke_colour: stroke_colour,
            add: add, visible: visible)
    end

    # The x position (top-left). Rectangles are anchored at their top-left
    # corner, not the centroid like a general Quad.
    def x
      @x1
    end

    # The y position (top-left).
    def y
      @y1
    end

    # Get the rotation center x coordinate
    def rx
      @_user_rx.nil? ? (@x1 + @width / 2.0) : @_user_rx
    end

    # Get the rotation center y coordinate
    def ry
      @_user_ry.nil? ? (@y1 + @height / 2.0) : @_user_ry
    end

    # Set the x position (top-left), updating all four vertices. Pass a
    # symbol (`:left`, `:center`, `:right`) to set alignment intent.
    def x=(x)
      return self.x_align = x if x.is_a?(Symbol)
      @x_align = nil unless @_resolving_alignment
      @x = @x1 = x
      @x2 = x + @width
      @x3 = x + @width
      @x4 = x
    end

    # Set the y position (top-left), updating all four vertices. Pass a
    # symbol (`:top`, `:center`, `:bottom`) to set alignment intent.
    def y=(y)
      return self.y_align = y if y.is_a?(Symbol)
      @y_align = nil unless @_resolving_alignment
      @y = @y1 = y
      @y2 = y
      @y3 = y + @height
      @y4 = y + @height
    end

    # Set the width
    def width=(width)
      @width = width
      @x2 = @x1 + width
      @x3 = @x1 + width
    end

    # Set the height
    def height=(height)
      @height = height
      @y3 = @y1 + height
      @y4 = @y1 + height
    end

    # Render a rectangle without creating an instance. Calls the positional
    # internal directly rather than `super` — see `Quad.draw_immediate`.
    def self.render(x: 0, y: 0, width: 200, height: 100, rotate: 0,
                    rx: nil, ry: nil, color: nil, colour: nil, opacity: nil,
                    fill: true, stroke_width: 0, stroke_color: nil, stroke_colour: nil)
      draw_immediate(x, y,
                     x + width, y,
                     x + width, y + height,
                     x, y + height,
                     rotate, rx || x + width / 2.0, ry || y + height / 2.0,
                     color || colour, opacity, fill, stroke_width,
                     stroke_color || stroke_colour)
    end

    # Check if the rectangle contains the given point
    def contains?(x, y)
      x, y = _unrotate(x, y)
      x >= @x && x <= (@x + @width) && y >= @y && y <= (@y + @height)
    end

    private

    # Resolve symbolic alignment (e.g. `x: :center`) against the window before
    # drawing, then draw via Quad. Rectangle/Square are top-left-anchored and
    # support alignment; a bare Quad (centroid-anchored) does not, so the call
    # lives here rather than in Quad#render.
    def render
      _resolve_alignment
      super
    end

    # Scene-graph draw hook (see Renderable#_render_scene). Re-aliased here so
    # the hook picks up Rectangle's alignment-resolving `render`, not Quad's.
    alias_method :_render_scene, :render
    public :_render_scene
  end
end

# ---------- lib/ruby2d/square.rb ----------

# Ruby2D::Square

module Ruby2D
  # A square
  class Square < Rectangle
    attr_reader :size

    # Create a square
    def initialize(x: 0, y: 0, size: 100, z: 0, rotate: 0,
                   rx: nil, ry: nil, color: nil, colour: nil, opacity: nil,
                   fill: true, stroke_width: 0, stroke_color: nil, stroke_colour: nil,
                   add: true, visible: true,
                   padding: nil, padding_top: nil, padding_right: nil,
                   padding_bottom: nil, padding_left: nil)
      _validate_dimensions(size: size)
      @size = size
      super(x: x, y: y, width: size, height: size, z: z, rotate: rotate,
            rx: rx, ry: ry,
            color: color, colour: colour, opacity: opacity,
            fill: fill, stroke_width: stroke_width,
            stroke_color: stroke_color, stroke_colour: stroke_colour,
            add: add, visible: visible,
            padding: padding, padding_top: padding_top, padding_right: padding_right,
            padding_bottom: padding_bottom, padding_left: padding_left)
    end

    # Set the size of the square
    def size=(size)
      self.width = self.height = @size = size
    end

    # Render a square without creating an instance
    # Render a square without creating an instance. Calls the positional
    # internal directly rather than `super` — see `Quad.draw_immediate`.
    def self.render(x: 0, y: 0, size: 100, rotate: 0,
                    rx: nil, ry: nil, color: nil, colour: nil, opacity: nil,
                    fill: true, stroke_width: 0, stroke_color: nil, stroke_colour: nil)
      draw_immediate(x, y,
                     x + size, y,
                     x + size, y + size,
                     x, y + size,
                     rotate, rx || x + size / 2.0, ry || y + size / 2.0,
                     color || colour, opacity, fill, stroke_width,
                     stroke_color || stroke_colour)
    end

    # Make the inherited width and height attribute accessors private
    private :width=, :height=
  end
end

# ---------- lib/ruby2d/text.rb ----------

# Ruby2D::Text

module Ruby2D
  # A text string drawn with a specified font and size
  class Text
    include Renderable

    # Font style name → TTF style flag bit (mirrors SDL3_ttf's `TTF_STYLE_*`).
    STYLE_FLAGS = {
      normal: 0, bold: 1, italic: 2, underline: 4, strikethrough: 8
    }.freeze

    # Frozen NUL string for the content scan below. A bare `"\0"` literal would
    # allocate a throwaway string on every `content=` — 360×/frame under a
    # dynamic-text HUD — since the library doesn't enable frozen string literals.
    NUL = "\0".freeze

    attr_reader :content, :size, :font, :style
    attr_accessor :rotate

    # Set the x position. Pass a symbol (`:left`, `:center`, `:right`) to
    # set alignment intent — resolved at draw time against the window.
    def x=(value)
      return self.x_align = value if value.is_a?(Symbol)
      @x_align = nil unless @_resolving_alignment
      @x = value
    end

    # Set the y position. Pass a symbol (`:top`, `:center`, `:bottom`) to
    # set alignment intent — resolved at draw time against the window.
    def y=(value)
      return self.y_align = value if value.is_a?(Symbol)
      @y_align = nil unless @_resolving_alignment
      @y = value
    end

    # Get the rotation center x coordinate
    def rx
      @_user_rx.nil? ? @x + @width / 2.0 : @_user_rx
    end

    # Get the rotation center y coordinate
    def ry
      @_user_ry.nil? ? @y + @height / 2.0 : @_user_ry
    end

    # Set the rotation center x coordinate
    def rx=(val)
      @_user_rx = val
    end

    # Set the rotation center y coordinate
    def ry=(val)
      @_user_ry = val
    end

    # Create a text object
    def initialize(content, size: 20, style: nil, font: Font.default,
                   x: 0, y: 0, z: 0,
                   rotate: 0, rx: nil, ry: nil, color: nil, colour: nil,
                   opacity: nil, add: true, visible: true,
                   padding: nil, padding_top: nil, padding_right: nil,
                   padding_bottom: nil, padding_left: nil)
      x, y = _extract_alignment(x, y)
      _apply_padding(padding, padding_top, padding_right, padding_bottom, padding_left)
      @x = x
      @y = y
      @z = z
      @content = validate_content(content).dup.freeze
      @size = validate_size(size)
      @rotate = rotate
      @_user_rx = rx
      @_user_ry = ry
      @style = style
      @style_flags = compute_style_flags(style)
      @font = normalize_font_path(font)

      self.color = color || colour || 'white'
      self.opacity = opacity unless opacity.nil?
      Ext.text_create(self)

      @visible = visible
      self.add if add
    end

    # Set the text content. A no-op when the content is unchanged — rebuilding
    # the texture is the expensive part, and per-frame assignments of the same
    # string (HUDs, score counters) are common. Validation still runs first so
    # invalid input raises regardless; the frozen copy is only allocated when
    # the content actually changes, so a same-string per-frame assignment costs
    # a coerce and a compare, not a string copy.
    def content=(msg)
      str = validate_content(msg)
      return if str == @content

      @content = str.dup.freeze
      Ext.text_create(self)
    end

    # Set the font size. A no-op when unchanged, like `content=` — rebuilding
    # the texture is the expensive part, and per-frame assignments of the same
    # value are common.
    def size=(size)
      size = validate_size(size)
      return if size == @size

      @size = size
      Ext.text_create(self)
    end

    # Set the font style. Accepts `:normal`, `:bold`, `:italic`, `:underline`,
    # `:strikethrough`, an array combining them (e.g. `[:bold, :italic]`), or
    # `nil` for normal. Re-renders the text; a no-op when the computed style
    # flags are unchanged (`:bold` and `[:bold]` are the same style).
    def style=(style)
      flags = compute_style_flags(style)
      @style = style
      return if flags == @style_flags

      @style_flags = flags
      Ext.text_create(self)
    end

    # Set the font, given a path to a `.ttf` file. Re-renders the text; a
    # no-op when the resolved path is unchanged.
    def font=(font)
      font = normalize_font_path(font)
      return if font == @font

      @font = font
      Ext.text_create(self)
    end

    # Render the text. Called with overrides for one-shot rendering inside a
    # render block; with no arguments it draws the same frame the scene graph
    # does (delegating to `_render_scene`).
    def render(x: nil, y: nil, rotate: nil, color: nil, colour: nil, opacity: nil)
      if x.nil? && y.nil? && rotate.nil? && color.nil? && colour.nil? && opacity.nil?
        return _render_scene
      end

      Window.render_ready_check

      saved_x, saved_y = @x, @y
      saved_rotate = @rotate
      saved_color = @color

      @x = x if x
      @y = y if y
      @rotate = rotate if rotate

      c = color || colour
      if c || opacity
        @color = c ? Color.new(c) : Color.new(saved_color)
        @color.opacity = opacity if opacity
      end

      begin
        Ext.text_draw(self, rx, ry)
      ensure
        @x, @y = saved_x, saved_y
        @rotate = saved_rotate
        @color = saved_color
      end
    end

    private

    # Scene-graph draw hook (see Renderable#_render_scene): `render` with no
    # overrides, minus its keyword handling — a zero-arg call into a
    # keyword-heavy `render` still pays microseconds of keyword setup on wasm
    # mruby.
    def _render_scene
      _resolve_alignment
      Ext.text_draw(self, rx, ry)
    end
    public :_render_scene

    # Coerce a font argument to a usable path: stringify, expand a leading `~`
    # on CRuby, and raise a clear error if the file is missing.
    def normalize_font_path(font)
      font = font.to_s
      font = File.expand_path(font) if RUBY_ENGINE == 'ruby' && font.start_with?('~')
      raise Error, "Font file `#{font}` not found" unless File.exist?(font)

      font
    end

    # Ensure the font size is a positive number, raising a clear error instead
    # of letting an invalid value reach the native font loader (where it would
    # surface as a cryptic `TypeError`/`TTF_OpenFont failed`). Coerce to the same
    # integer the native renderer uses (truncation toward zero) so the `size`
    # reader equals the size actually rendered — e.g. `size: 10.9` renders and
    # reports 10, not 10.9.
    def validate_size(size)
      unless size.is_a?(Numeric) && size > 0
        raise Error, "Text size must be a positive number, got #{size.inspect}"
      end

      size.to_i
    end

    # Coerce content to a string and reject embedded NUL bytes. NUL has no glyph
    # and SDL_ttf cannot render it — passing one to the native rasterizer
    # hangs/over-allocates on U+0000 — while silently truncating at the NUL (the
    # historical behavior) hides the caller's corrupt data. So fail loudly.
    # Returns the coerced string as-is (which may be the caller's own object for
    # a String argument); callers that store it own the `dup.freeze`, so the
    # cheap no-op comparison in `content=` runs before anything is allocated.
    # Freezing at the store site stops in-place mutation (`text.content << 'x'`)
    # from desyncing the native surface, which only rerasterizes via `content=`.
    def validate_content(content)
      str = content.to_s
      raise Error, 'Text content cannot contain NUL (\0) bytes' if str.include?(NUL)

      str
    end

    # Combine a style (nil, a symbol, a string, or an array of them) into the
    # integer TTF style flags the native renderer expects. Raises a clear error
    # on an unknown style name rather than silently ignoring it.
    def compute_style_flags(style)
      return 0 if style.nil?

      Array(style).reduce(0) do |flags, s|
        bit = STYLE_FLAGS[s.to_s.to_sym]
        if bit.nil?
          raise Error,
                "Unknown text style #{s.inspect}; expected one of #{STYLE_FLAGS.keys}"
        end
        flags | bit
      end
    end
  end
end

# ---------- lib/ruby2d/triangle.rb ----------

# Ruby2D::Triangle

module Ruby2D
  # A triangle
  class Triangle
    include Renderable

    attr_accessor :x1, :y1,
                  :x2, :y2,
                  :x3, :y3,
                  :rotate,
                  :fill, :stroke_width
    attr_reader :color, :stroke_color
    alias_method :stroke_colour, :stroke_color

    # The x coordinate of the centroid
    def x
      (@x1 + @x2 + @x3) / 3.0
    end

    # The y coordinate of the centroid
    def y
      (@y1 + @y2 + @y3) / 3.0
    end

    # Set the x coordinate of the centroid, translating all vertices
    def x=(new_x)
      _require_numeric_position(:x, new_x)
      dx = new_x - x
      @x1 += dx
      @x2 += dx
      @x3 += dx
    end

    # Set the y coordinate of the centroid, translating all vertices
    def y=(new_y)
      _require_numeric_position(:y, new_y)
      dy = new_y - y
      @y1 += dy
      @y2 += dy
      @y3 += dy
    end

    # Bounding-box width and height (extent across the three vertices)
    def width
      xs = [@x1, @x2, @x3]
      xs.max - xs.min
    end

    def height
      ys = [@y1, @y2, @y3]
      ys.max - ys.min
    end

    # Create a triangle. Specify vertices via `points:` or via `x1:`/`y1:`/...
    # `points:` takes precedence if both are given.
    def initialize(x1: 50, y1: 0, x2: 100, y2: 100, x3: 0, y3: 100,
                   points: nil,
                   z: 0, rotate: 0, rx: nil, ry: nil,
                   color: nil, colour: nil, opacity: nil,
                   fill: true, stroke_width: 0, stroke_color: nil, stroke_colour: nil,
                   add: true, visible: true)
      if points
        Triangle.send(:validate_points, points)
        x1, y1 = points[0]
        x2, y2 = points[1]
        x3, y3 = points[2]
      end
      @x1 = x1
      @y1 = y1
      @x2 = x2
      @y2 = y2
      @x3 = x3
      @y3 = y3
      @z  = z
      @rotate = rotate
      @_user_rx = rx
      @_user_ry = ry
      self.color = color || colour || 'white'
      self.opacity = opacity unless opacity.nil?
      @fill = fill
      @stroke_width = stroke_width
      self.stroke_color = stroke_color || stroke_colour || (color || colour)
      self.stroke_color.opacity = opacity unless opacity.nil?
      @visible = visible
      self.add if add
    end

    # Set the stroke color. Accepts a single color or a `Color::Set` of 3
    # (one per vertex) interpolated around the perimeter. If nil, defaults to
    # the fill color (preserving a per-vertex set when the fill is per-vertex).
    def stroke_color=(c)
      @stroke_color = Renderable.resolve_color_or_default(c, 3, label: self.class)
      # A single stroke Color (not a per-vertex Set) takes the compact
      # `stroke_triangle_uniform` fast path.
      @_stroke_color_uniform = !@stroke_color.is_a?(Color::Set)
      @_stroke_cc = nil
    end
    alias_method :stroke_colour=, :stroke_color=

    # Set the color of the triangle
    def color=(color)
      # convert to Color or Color::Set
      color = Color.set(color)

      # require 3 colours if multiple colours provided
      if color.is_a?(Color::Set) && color.length != 3
        raise ArgumentError,
              "`#{self.class}` requires 3 colors, one for each vertex. #{color.length} were given."
      end

      @color = color # converted above
      # A single Color (not a per-vertex Set) is uniform across all three
      # vertices, so it takes the compact `draw_triangle_uniform` fast path.
      @_color_uniform = !color.is_a?(Color::Set)
      @_cc = nil # invalidate cached color components
    end

    # Check if the triangle contains the given point (inside the rendered fill)
    def contains?(x, y)
      x, y = _unrotate(x, y)
      _point_in_polygon?([@x1, @y1, @x2, @y2, @x3, @y3], x, y)
    end

    # Get the rotation center x coordinate
    def rx
      @_user_rx.nil? ? x : @_user_rx
    end

    # Get the rotation center y coordinate
    def ry
      @_user_ry.nil? ? y : @_user_ry
    end

    # Set the rotation center x coordinate
    def rx=(val)
      @_user_rx = val
    end

    # Set the rotation center y coordinate
    def ry=(val)
      @_user_ry = val
    end

    # Render a triangle without creating an instance
    def self.render(x1: 50, y1: 0, x2: 100, y2: 100, x3: 0, y3: 100,
                    points: nil,
                    rotate: 0, rx: nil, ry: nil,
                    color: nil, colour: nil, opacity: nil,
                    fill: true, stroke_width: 0, stroke_color: nil, stroke_colour: nil)
      Window.render_ready_check
      if points
        validate_points(points)
        x1, y1 = points[0]
        x2, y2 = points[1]
        x3, y3 = points[2]
      end
      fill_input = color || colour
      # Resolve the fill color once. A single Color (not a per-vertex Set) with
      # scalar opacity is uniform across all three vertices and draws via the
      # compact `draw_triangle_uniform`; otherwise build the per-vertex color
      # array from the already-resolved color (no second parse).
      # A per-vertex color flattens straight to floats, skipping the
      # `Color::Set` the general path builds — that allocates and parses one
      # `Color` per vertex on every call. `resolved` stays nil in that case
      # and the stroke below resolves for itself if it ends up needing one.
      # The `is_a?(Array)` guard is inline so the common single-color call
      # doesn't pay for a method call that would only decline.
      c = fill_input.is_a?(Array) ? Renderable.flatten_per_vertex(fill_input, 3, opacity) : nil
      if c
        resolved = nil
        uniform = false
      else
        resolved = Color.for_render(fill_input.nil? ? 'white' : fill_input)
        uniform = !resolved.is_a?(Color::Set) && !opacity.is_a?(Array)
        c = uniform ? nil : Renderable.flatten_resolved_color(resolved, 3, opacity, label: self)
      end

      # Rotation is inlined into locals (as in `render` below and Line#render):
      # a helper returning the rotated points would allocate an array per
      # rotated shape per frame — measured 2.9µs vs 1.8µs per quad on wasm.
      if rotate != 0
        cx = rx || ((x1 + x2 + x3) / 3.0)
        cy = ry || ((y1 + y2 + y3) / 3.0)
        rad = rotate * Math::PI / 180.0
        sa = Math.sin(rad)
        ca = Math.cos(rad)
        dx = x1 - cx; dy = y1 - cy
        x1 = dx * ca - dy * sa + cx; y1 = dx * sa + dy * ca + cy
        dx = x2 - cx; dy = y2 - cy
        x2 = dx * ca - dy * sa + cx; y2 = dx * sa + dy * ca + cy
        dx = x3 - cx; dy = y3 - cy
        x3 = dx * ca - dy * sa + cx; y3 = dx * sa + dy * ca + cy
      end

      if fill
        if uniform
          a = opacity || resolved.a
          Ext.draw_triangle_uniform(x1, y1, x2, y2, x3, y3, resolved.r, resolved.g, resolved.b, a)
        else
          c1r, c1g, c1b, c1a, c2r, c2g, c2b, c2a, c3r, c3g, c3b, c3a = c
          Ext.draw_triangle(
            x1, y1, c1r, c1g, c1b, c1a,
            x2, y2, c2r, c2g, c2b, c2a,
            x3, y3, c3r, c3g, c3b, c3a
          )
        end
      end

      # Resolve the stroke color only when actually stroking. A single stroke
      # color draws via the compact `stroke_triangle_uniform`; a per-vertex Set
      # keeps the splatting path. When no explicit stroke is given the stroke
      # reuses the already-resolved fill color. (An explicit stroke color is
      # still validated at stroke_width 0 below, matching the instance constructor.)
      if stroke_width > 0
        stroke_input = stroke_color || stroke_colour || fill_input
        sresolved = if !stroke_input.equal?(fill_input)
                      Color.for_render(stroke_input)
                    else
                      resolved || Color.for_render(fill_input.nil? ? 'white' : fill_input)
                    end
        if !sresolved.is_a?(Color::Set) && !opacity.is_a?(Array)
          sa = opacity || sresolved.a
          Ext.stroke_triangle_uniform(x1, y1, x2, y2, x3, y3, stroke_width,
                                      sresolved.r, sresolved.g, sresolved.b, sa)
        else
          s1r, s1g, s1b, s1a, s2r, s2g, s2b, s2a, s3r, s3g, s3b, s3a =
            Renderable.flatten_resolved_color(sresolved, 3, opacity, label: self)
          Ext.stroke_triangle(
            x1, y1, x2, y2, x3, y3, stroke_width,
            s1r, s1g, s1b, s1a,
            s2r, s2g, s2b, s2a,
            s3r, s3g, s3b, s3a
          )
        end
      elsif stroke_color || stroke_colour
        Renderable.flatten_color(stroke_color || stroke_colour, 3, opacity, label: self)
      end
    end

    private

    def self.validate_points(points)
      raise ArgumentError, 'Triangle requires exactly 3 points' unless points.length == 3
      raise ArgumentError, 'points must be an array of [x, y] pairs' \
        unless points.all? { |p| p.is_a?(Array) && p.length == 2 }
    end
    private_class_method :validate_points

    def render
      ensure_cc
      ensure_scc if @stroke_width && @stroke_width > 0

      x1, y1, x2, y2, x3, y3 = @x1, @y1, @x2, @y2, @x3, @y3

      # Rotation inlined into locals — see the `Triangle.render` note.
      if @rotate != 0
        cx = rx; cy = ry
        rad = @rotate * Math::PI / 180.0
        sa = Math.sin(rad)
        ca = Math.cos(rad)
        dx = x1 - cx; dy = y1 - cy
        x1 = dx * ca - dy * sa + cx; y1 = dx * sa + dy * ca + cy
        dx = x2 - cx; dy = y2 - cy
        x2 = dx * ca - dy * sa + cx; y2 = dx * sa + dy * ca + cy
        dx = x3 - cx; dy = y3 - cy
        x3 = dx * ca - dy * sa + cx; y3 = dx * sa + dy * ca + cy
      end

      if @fill
        cc = @_cc
        if @_color_uniform
          Ext.draw_triangle_uniform(x1, y1, x2, y2, x3, y3, cc[0], cc[1], cc[2], cc[3])
        else
          Ext.draw_triangle(
            x1, y1, cc[0], cc[1], cc[2],  cc[3],
            x2, y2, cc[4], cc[5], cc[6],  cc[7],
            x3, y3, cc[8], cc[9], cc[10], cc[11]
          )
        end
      end

      if @stroke_width && @stroke_width > 0
        scc = @_stroke_cc
        if @_stroke_color_uniform
          Ext.stroke_triangle_uniform(x1, y1, x2, y2, x3, y3, @stroke_width, scc[0], scc[1], scc[2], scc[3])
        else
          Ext.stroke_triangle(
            x1, y1, x2, y2, x3, y3, @stroke_width,
            scc[0], scc[1], scc[2],  scc[3],
            scc[4], scc[5], scc[6],  scc[7],
            scc[8], scc[9], scc[10], scc[11]
          )
        end
      end
    end

    # Scene-graph draw hook (see Renderable#_render_scene). Triangle's `render`
    # is already zero-arg, so the hook is the same method under the scene name.
    alias_method :_render_scene, :render
    public :_render_scene

    # Build/rebuild flat per-vertex stroke color cache (3 × rgba = 12 floats)
    def ensure_scc
      if @_stroke_color_uniform
        c = @stroke_color
        if @_stroke_cc.nil? || @_stroke_cc[0] != c.r || @_stroke_cc[1] != c.g || @_stroke_cc[2] != c.b || @_stroke_cc[3] != c.a
          @_stroke_cc = [c.r, c.g, c.b, c.a]
        end
      elsif @_stroke_cc.nil? || !scc_matches?
        @_stroke_cc = Array.new(12)
        3.times do |i|
          c = @stroke_color.vertex(i)
          @_stroke_cc[i * 4]     = c.r
          @_stroke_cc[i * 4 + 1] = c.g
          @_stroke_cc[i * 4 + 2] = c.b
          @_stroke_cc[i * 4 + 3] = c.a
        end
      end
    end

    def scc_matches?
      3.times do |i|
        c = @stroke_color.vertex(i)
        return false if @_stroke_cc[i * 4]     != c.r
        return false if @_stroke_cc[i * 4 + 1] != c.g
        return false if @_stroke_cc[i * 4 + 2] != c.b
        return false if @_stroke_cc[i * 4 + 3] != c.a
      end
      true
    end

    # Build/rebuild flat color cache for the native extension
    def ensure_cc
      # Solid fill: cache 4 floats and validity-check 4 comparisons (the
      # per-frame check still catches in-place `color.opacity=` fades). Mirrors
      # the Circle/Ellipse single-color cache.
      if @_color_uniform
        c = @color
        if @_cc.nil? || @_cc[0] != c.r || @_cc[1] != c.g || @_cc[2] != c.b || @_cc[3] != c.a
          @_cc = [c.r, c.g, c.b, c.a]
        end
      elsif @_cc.nil? || !cc_matches?
        @_cc = Array.new(12)
        3.times do |i|
          c = @color.vertex(i)
          @_cc[i * 4]     = c.r
          @_cc[i * 4 + 1] = c.g
          @_cc[i * 4 + 2] = c.b
          @_cc[i * 4 + 3] = c.a
        end
      end
    end

    def cc_matches?
      3.times do |i|
        c = @color.vertex(i)
        return false if @_cc[i * 4]     != c.r
        return false if @_cc[i * 4 + 1] != c.g
        return false if @_cc[i * 4 + 2] != c.b
        return false if @_cc[i * 4 + 3] != c.a
      end
      true
    end
  end
end

# ---------- lib/ruby2d/vertices.rb ----------

# Ruby2D::Vertices

module Ruby2D
  # Vertex and texture coordinates for tile placements
  class Vertices
    # Texture coordinates for an uncropped quad (full image)
    TEX_UNCROPPED_COORDS = [
      0.0, 0.0, # top left
      1.0, 0.0, # top right
      1.0, 1.0, # bottom right
      0.0, 1.0  # bottom left
    ].freeze

    # Create a vertex set for a tile placement
    def initialize(x, y, width, height, rotate, crop: nil, flip: nil)
      @x = x
      @y = y
      @width = width.to_f
      @height = height.to_f
      @rotate = rotate
      @crop = crop
      apply_flip(flip)
      @rx = @x + (@width / 2.0)
      @ry = @y + (@height / 2.0)
    end

    # Get the quad corner coordinates as a flat array
    def coordinates
      @coordinates ||= @rotate.zero? ? unrotated_coordinates : rotated_coordinates
    end

    # Get the texture UV coordinates as a flat array
    def texture_coordinates
      @texture_coordinates ||= @crop ? cropped_texture_coordinates : TEX_UNCROPPED_COORDS
    end

    private

    def unrotated_coordinates
      [
        @x,          @y,           # top left
        @x + @width, @y,           # top right
        @x + @width, @y + @height, # bottom right
        @x,          @y + @height  # bottom left
      ]
    end

    def rotated_coordinates
      angle = @rotate * Math::PI / 180.0
      sa = Math.sin(angle)
      ca = Math.cos(angle)

      [
        *rotate_point(@x,          @y,           sa, ca), # top left
        *rotate_point(@x + @width, @y,           sa, ca), # top right
        *rotate_point(@x + @width, @y + @height, sa, ca), # bottom right
        *rotate_point(@x,          @y + @height, sa, ca)  # bottom left
      ]
    end

    # Rotate a point around the center of the quad, given the precomputed sine
    # and cosine of the rotation angle
    def rotate_point(x, y, sa, ca)
      dx = x - @rx
      dy = y - @ry

      [dx * ca - dy * sa + @rx,
       dx * sa + dy * ca + @ry]
    end

    def cropped_texture_coordinates
      img_w = @crop[:image_width].to_f
      img_h = @crop[:image_height].to_f

      left   = @crop[:x] / img_w
      top    = @crop[:y] / img_h
      right  = left + (@crop[:width] / img_w)
      bottom = top + (@crop[:height] / img_h)

      [
        left,  top,    # top left
        right, top,    # top right
        right, bottom, # bottom right
        left,  bottom  # bottom left
      ]
    end

    def apply_flip(flip)
      return unless flip

      if flip == :horizontal || flip == :both
        @x += @width
        @width = -@width
      end

      if flip == :vertical || flip == :both
        @y += @height
        @height = -@height
      end
    end
  end
end

# ---------- lib/ruby2d/dsl.rb ----------

module Ruby2D
  # Domain-specific language methods for the top-level Ruby2D interface
  module DSL
    # Get the DSL window instance, constructing a default on first access
    def self.window
      @window ||= Ruby2D::Window.new
    end

    # Set the DSL window instance
    def self.window=(window)
      @window = window
    end

    # Whether a DSL window already exists, without constructing one. Used to
    # enforce the single-window rule (reading `window` would auto-create one).
    def self.window?
      !@window.nil?
    end

    # Get a window attribute by name
    def get(sym)
      DSL.window.get(sym)
    end

    # Set window attributes
    def set(opts)
      DSL.window.set(opts)
    end

    # Take a screenshot, saving to `path` (or a timestamped file if omitted)
    def screenshot(path = nil)
      DSL.window.screenshot(path)
    end

    # Register an event handler
    def on(event = nil, **filters, &proc)
      DSL.window.on(event, **filters, &proc)
    end

    # Remove an event handler
    def off(event_descriptor)
      DSL.window.off(event_descriptor)
    end

    # Set the update callback
    def update(&proc)
      DSL.window.update(&proc)
    end

    # Set the render callback. `z:` positions the block in the scene's
    # z-order — `:foreground` (default), `:background`, or a number.
    def render(z: :foreground, &proc)
      DSL.window.render(z: z, &proc)
    end

    # Monotonic seconds since the engine started (see `Window#elapsed`)
    def elapsed
      DSL.window.elapsed
    end

    # Clear all objects from the window
    def clear
      DSL.window.clear
    end

    # The connected gamepads, in connect order
    def gamepads
      DSL.window.gamepads
    end

    # Load a gamepad mapping from a file path or a single mapping string
    def add_gamepad_mapping(path_or_string)
      DSL.window.add_gamepad_mapping(path_or_string)
    end

    # Show the window
    def show
      DSL.window.show
    end

    # Close the window
    def close
      DSL.window.close
    end

    # Request a render on the next tick (for :on_demand render mode)
    def request_render
      DSL.window.request_render
    end
  end
end
