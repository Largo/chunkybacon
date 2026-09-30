# ShoesDom: a Lacci display service that draws a Shoes app into this page.
#
# Scarpe splits a Shoes app in two. Lacci (the `lacci` gem) owns the DSL and
# the drawable tree and knows nothing about pixels; a *display service*
# subscribes to that tree's events and paints it with some real toolkit --
# Webview, libui, and here the browser's own DOM. That split is the whole
# point of the Scarpe lesson, so the notebook renders Shoes apps the same way
# Scarpe's own backends do, rather than faking it.
#
# Loaded lazily by main.rb, because it can only be defined once Shoes is.
module ShoesDom
  # Shoes::Log needs an implementation plugged in; Scarpe ships one that
  # prints, which would land in the cell's output. Here logging goes nowhere.
  module NullLog
    module Logger
      def self.debug(*) = nil
      def self.info(*) = nil
      def self.warn(*) = nil
      def self.error(*) = nil
      def self.fatal(*) = nil
    end

    def self.logger_for_component(_component) = Logger
    def self.configure_logger(_config) = nil
  end

  # Para carries the kind of text it is as a `size` style rather than as a
  # class of its own, so this is what turns `title "x"` into an <h1>.
  TEXT_TAGS = {
    banner: "h1", title: "h1", subtitle: "h2", tagline: "h3",
    caption: "p", para: "p", inscription: "p"
  }.freeze

  INLINE_TAGS = {
    "Strong" => "strong", "Em" => "em", "Code" => "code", "Del" => "del",
    "Ins" => "ins", "Sub" => "sub", "Sup" => "sup", "Span" => "span"
  }.freeze

  # What one show_shoes call produced: the element to put on the page, the
  # Shoes class names it created (for lesson checks), and a way to take it
  # down again.
  Mounted = Struct.new(:element, :types, :drawables) do
    # Lacci's own App#destroy cannot be used for this: it broadcasts
    # `destroy` with no target, and every live app subscribes to that, so it
    # would take down the apps in every other cell too. Unsubscribing this
    # app's display drawables stops them reacting; the DOM goes with the cell.
    def dispose
      drawables.each(&:unsub_all_shoes_events)
      drawables.clear
    end
  end

  class << self
    attr_accessor :service, :container, :current

    def document = JSG.d

    # Runs +block+ as a Shoes app and returns a {Mounted}.
    #
    # One display service serves the whole page, and every app stays alive
    # until its cell re-runs or the lesson changes. Resetting Lacci between
    # apps would be wrong: its event handlers are process-wide, so a reset
    # for cell 5 would silently disconnect the buttons of the app in cell 3.
    def mount(width:, height:, &block)
      setup!
      root = document.createElement("div")
      root.className = "shoes-app"
      root.style.width = "#{width}px"
      # sized to its content unless the app asks for a height, as a window would
      root.style.minHeight = "#{height}px" if height
      self.container = root
      self.current = Mounted.new(root, [], [])

      Shoes.app(title: "Shoes", width: width, height: height || 420, &block)
      current
    ensure
      self.container = nil
    end

    # Drops every app at once - the one case where a global reset is right.
    def reset!
      return unless @setup

      Shoes::DisplayService.full_reset!
      Shoes.APPS.clear
      service&.forget_all
    end

    private

    def setup!
      return if @setup

      Shoes::Log.instance = NullLog unless Shoes::Log.instance
      # A notebook hosts one app per cell, all live at once. Lacci refuses a
      # second Shoes::App unless the display service declares this.
      Shoes::FEATURES << :multi_app unless Shoes::FEATURES.include?(:multi_app)
      Shoes::DisplayService.set_display_service_class(DisplayService)
      @setup = true
    end
  end

  # One display drawable per Shoes drawable, holding the DOM node that shows
  # it. Lacci talks to it only through events.
  class Drawable < Shoes::Linkable
    attr_reader :el, :shoes_type

    def initialize(id, props, shoes_type)
      @id = id
      @props = props
      @shoes_type = shoes_type
      super(linkable_id: id)

      @el = build_element
      @el.dataset.shoes = shoes_type if @el

      bind_shoes_event(event_name: "prop_change", target: id) do |changes|
        changes.each { |k, v| @props[k.to_s] = v }
        refresh
      end
      bind_shoes_event(event_name: "destroy", target: id) do
        @el&.remove
      end
    end

    def append_to(parent)
      return unless @el && parent&.el

      parent.el.appendChild(@el)
    end

    private

    def prop(name) = @props[name.to_s]

    def build_element
      case @shoes_type
      when "DocumentRoot" then element("div", "shoes-root")
      when "Stack" then slot("shoes-stack")
      when "Flow" then slot("shoes-flow")
      when "Para" then text_element
      when "Button" then button_element
      when "EditLine" then edit_line_element
      when "EditBox" then edit_box_element
      when "Link" then link_element
      when "Image" then image_element
      when "Border", "Background" then nil
      else
        INLINE_TAGS.key?(@shoes_type) ? text_element(INLINE_TAGS[@shoes_type]) : element("div", "shoes-other")
      end
    end

    def element(tag, css_class = nil)
      node = ShoesDom.document.createElement(tag)
      node.className = css_class if css_class
      node
    end

    def slot(css_class)
      node = element("div", css_class)
      apply_box(node)
      node
    end

    def text_element(tag = nil)
      tag ||= TEXT_TAGS.fetch((prop(:size) || :para).to_sym, "p")
      node = element(tag, "shoes-text")
      write_text(node)
      node
    end

    def button_element
      node = element("button", "shoes-button")
      node.textContent = prop(:text).to_s
      node.addEventListener("click") { send_shoes_event(event_name: "click", target: @id) }
      node
    end

    def edit_line_element
      node = element("input", "shoes-editline")
      node.type = "text"
      node.value = prop(:text).to_s
      node.addEventListener("input") { |event| send_shoes_event(event.target.value, event_name: "change", target: @id) }
      node
    end

    def edit_box_element
      node = element("textarea", "shoes-editbox")
      node.value = prop(:text).to_s
      node.addEventListener("input") { |event| send_shoes_event(event.target.value, event_name: "change", target: @id) }
      node
    end

    def link_element
      node = element("a", "shoes-link")
      node.href = "#"
      write_text(node)
      node.addEventListener("click") do |event|
        event.preventDefault
        send_shoes_event(event_name: "click", target: @id)
      end
      node
    end

    def image_element
      node = element("img", "shoes-image")
      node.src = prop(:filename).to_s
      node.alt = ""
      node
    end

    # text_items mixes plain strings with the linkable ids of nested text
    # drawables -- `para "Chunky ", strong("Bacon")` arrives as ["Chunky ", 5].
    def write_text(node)
      node.innerHTML = ""
      Array(prop(:text_items)).each do |item|
        if item.is_a?(String)
          node.appendChild(ShoesDom.document.createTextNode(item))
        else
          nested = ShoesDom.service&.drawable_for(item)
          node.appendChild(nested.el) if nested&.el
        end
      end
      apply_text_style(node)
    end

    def apply_text_style(node)
      style = node.style
      style.color = css_color(prop(:stroke)) if prop(:stroke)
      style.textAlign = prop(:align).to_s if prop(:align)
      style.fontFamily = prop(:family).to_s if prop(:family)
      size = prop(:size)
      style.fontSize = "#{size}px" if size.is_a?(Numeric)
    end

    def apply_box(node)
      style = node.style
      style.width = css_length(prop(:width)) if prop(:width)
      style.height = css_length(prop(:height)) if prop(:height)
      style.margin = "#{prop(:margin).to_i}px" if prop(:margin).is_a?(Numeric)
      style.background = css_color(prop(:background_color)) if prop(:background_color)
    end

    # Shoes sizes are pixels, or a fraction of the parent between 0 and 1.
    def css_length(value)
      return value.to_s unless value.is_a?(Numeric)
      return "#{(value * 100).round}%" if value.is_a?(Float) && value <= 1.0

      "#{value.to_i}px"
    end

    # Shoes colours arrive as [r, g, b] or [r, g, b, a], or as a name.
    def css_color(value)
      return value.to_s unless value.is_a?(Array)

      r, g, b, a = value
      a.nil? || a >= 255 ? "rgb(#{r},#{g},#{b})" : "rgba(#{r},#{g},#{b},#{(a / 255.0).round(3)})"
    end

    def refresh
      case @shoes_type
      when "Para", *INLINE_TAGS.keys, "Link" then write_text(@el)
      when "Button" then @el.textContent = prop(:text).to_s
      when "EditLine", "EditBox" then @el.value = prop(:text).to_s
      when "Stack", "Flow" then apply_box(@el)
      end
    end
  end

  # The app drawable. Telling Lacci the event loop is "return" is what keeps
  # Shoes.app from blocking: the browser already has an event loop, and
  # blocking here would freeze the page.
  class AppDrawable < Drawable
    def initialize(id, props)
      super(id, props, "App")
      # `run` is untargeted, so this hears every later app's start too; only
      # the first answer is for this app, and answering again is harmless.
      bind_shoes_event(event_name: "run") do
        send_shoes_event("return", event_name: "custom_event_loop")
      end
      bind_shoes_event(event_name: "init") { nil }
      bind_shoes_event(event_name: "destroy") { nil }
    end

    private

    def build_element = nil
  end

  class DisplayService < Shoes::DisplayService
    def initialize
      super
      @drawables = {}
      ShoesDom.service = self
    end

    def drawable_for(id) = @drawables[id]

    def forget_all
      @drawables.clear
      @display_drawable_for = {}
    end

    def create_display_drawable_for(class_name, id, properties, parent_id:, is_widget:)
      drawable = if class_name == "App"
                   AppDrawable.new(id, properties)
                 else
                   Drawable.new(id, properties, class_name)
                 end
      @drawables[id] = drawable
      set_drawable_pairing(id, drawable)
      if (mounted = ShoesDom.current)
        mounted.drawables << drawable
        mounted.types << class_name unless class_name == "App"
      end

      if class_name == "DocumentRoot"
        ShoesDom.container&.appendChild(drawable.el)
      elsif parent_id
        drawable.append_to(@drawables[parent_id])
      end
      drawable
    end

    def destroy = nil
  end
end
