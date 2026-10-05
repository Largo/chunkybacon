# PyCall in the browser. The pycall gem loads libpython into the Ruby
# process - a browser has none. Here Python is Pyodide, CPython compiled to
# WebAssembly (index.html: ensurePython, tools/vendor_pyodide.rb), and this
# file speaks to it through JavaScript - with the gem's API, so the lesson's
# code runs unchanged on a computer with the real gem:
#
#   require "pycall"
#   pd = PyCall.import_module("pandas")
#   df = pd.DataFrame.new({ "a" => [1, 2, 3] })
#   df["a"].sum          # => 6, a Ruby Integer
#
# Python objects stay in Python: a registry there keeps them, Ruby holds a
# PyObject with the registry's number, and every operation is one request
# as JSON - so a Python int comes back as an Integer and a float as a Float
# (JavaScript would make both a number), None as nil, a numpy scalar as a
# plain number, and lists and dicts stay Python until to_a / to_h.
#
# matplotlib draws under the cell (EXPERIMENT, experiments/01-matplotlib-charts):
#
#   plt = PyCall.import_module("matplotlib.pyplot")
#   plt.plot([1, 2, 3], [2, 4, 3])
#   plt.show()             # the chart as SVG below the cell, as in a notebook
#   show_plot              # the same, explicitly; show_plot(fig) for one figure
#
# Python draws with matplotlib's Agg backend into memory (no window, no
# canvas): the bridge's own backend (BACKEND below) keeps what plt.show()
# draws as SVG, the bridge's answer to that request carries it, and the
# figure goes under the cell like a show_image.
require "json"

module PyCall
  # a Python exception, as "KeyError: 'preis'"
  class PyError < StandardError
    attr_reader :type

    def initialize(type, message)
      @type = type
      super("#{type}: #{message}")
    end
  end

  # Python is still loading, or could not be loaded
  class NotReady < StandardError; end

  # several keys at once: df["a", "b"] is df[("a", "b")] in Python
  Tuple = Data.define(:items)

  # the Python side, defined once in Pyodide
  BRIDGE = <<~'PYTHON'
    import importlib, json, operator, sys

    class _ChunkyRubyBridge:
        def __init__(self):
            self.objects = {}
            self.last = 0
            self.globals = {"__name__": "__main__"}

        def keep(self, obj):
            self.last += 1
            self.objects[self.last] = obj
            return self.last

        def scalar(self, obj):
            numpy = sys.modules.get("numpy")
            return obj.item() if numpy is not None and isinstance(obj, numpy.generic) else obj

        def encode(self, obj):
            obj = self.scalar(obj)
            if obj is None: return {"t": "none"}
            if isinstance(obj, bool): return {"t": "bool", "v": obj}
            if isinstance(obj, int): return {"t": "int", "v": str(obj)}
            if isinstance(obj, float): return {"t": "float", "v": repr(obj)}
            if isinstance(obj, str): return {"t": "str", "v": obj}
            return {"t": "obj", "id": self.keep(obj)}

        def decode(self, value):
            if isinstance(value, dict):
                if "__py__" in value: return self.objects[value["__py__"]]
                if "__tuple__" in value: return tuple(self.decode(v) for v in value["__tuple__"])
                return {k: self.decode(v) for k, v in value.items()}
            if isinstance(value, list): return [self.decode(v) for v in value]
            return value

        # Ruby data: a Series or numpy array as a list, a DataFrame as a dict,
        # a sympy integer or float as a number (a fraction stays its text)
        def plain(self, obj):
            obj = self.scalar(obj)
            sympy = sys.modules.get("sympy")
            if sympy is not None and isinstance(obj, sympy.Basic):
                if obj.is_Integer: return int(obj)
                if obj.is_Float: return float(obj)
            if hasattr(obj, "tolist") and not isinstance(obj, (str, bytes)): obj = obj.tolist()
            elif hasattr(obj, "to_dict") and not isinstance(obj, dict): obj = obj.to_dict()
            if isinstance(obj, dict): return {str(k): self.plain(v) for k, v in obj.items()}
            if isinstance(obj, (list, tuple, set, frozenset)): return [self.plain(v) for v in obj]
            if obj is None or isinstance(obj, (bool, int, float, str)): return obj
            return str(obj)

        # PyCall's obj.name(...): a callable attribute is called, a class is
        # returned (.new makes an instance), anything else is the value
        def op_send(self, obj, name, args, kwargs):
            attr = getattr(obj, name)
            if callable(attr) and not isinstance(attr, type):
                return attr(*args, **kwargs)
            if args or kwargs:
                raise TypeError(f"{name} is not callable")
            return attr

        def op_import(self, name): return importlib.import_module(name)
        def op_eval(self, code): return eval(code, self.globals)
        def op_exec(self, code): exec(code, self.globals)
        def op_call(self, obj, args, kwargs): return obj(*args, **kwargs)
        def op_setattr(self, obj, name, value): setattr(obj, name, value)
        def op_hasattr(self, obj, name): return hasattr(obj, name)
        def op_getitem(self, obj, key): return obj[key]
        def op_setitem(self, obj, key, value): obj[key] = value
        def op_binary(self, name, a, b): return getattr(operator, name)(a, b)
        def op_unary(self, name, a): return getattr(operator, name)(a)
        def op_str(self, obj): return str(obj)
        def op_repr(self, obj): return repr(obj)
        def op_len(self, obj): return len(obj)
        def op_isclass(self, obj): return isinstance(obj, type)
        def op_html(self, obj):
            html = getattr(obj, "_repr_html_", None)
            return html() if callable(html) and not isinstance(obj, type) else None

        # show_plot: one figure (None: the current one) as SVG; it is closed,
        # so a later plt.show() does not draw it again
        def op_figure(self, figure):
            import chunky_backend
            pyplot = importlib.import_module("matplotlib.pyplot")
            figure = pyplot.gcf() if figure is None else figure
            image = chunky_backend.render(figure)
            pyplot.close(figure)
            return image

        # matplotlib's backend for the browser: Agg, whose show() keeps the
        # figures for Ruby (BACKEND in pycall.rb). Written as a module file,
        # as matplotlib imports a backend by name; MPLBACKEND picks it before
        # anything imports matplotlib, and only a script that imports
        # matplotlib pays for it.
        def install_backend(self, source):
            import os
            folder = "/home/pyodide/.chunky"
            os.makedirs(folder, exist_ok=True)
            with open(folder + "/chunky_backend.py", "w") as f:
                f.write(source)
            if folder not in sys.path:
                sys.path.append(folder)
            # Pyodide's matplotlib would pick webagg, whose show() wants a server
            os.environ["MPLBACKEND"] = "module://chunky_backend"
            if "matplotlib.pyplot" in sys.modules:   # imported before the bridge
                sys.modules["matplotlib.pyplot"].switch_backend("module://chunky_backend")

        def run(self, request):
            req = json.loads(request)
            try:
                args = [self.decode(a) for a in req["args"]]
                if req["op"] == "plain":
                    answer = {"data": self.plain(args[0])}
                elif req["op"] == "box":   # a Ruby value as a Python object, for coerce
                    answer = {"ok": {"t": "obj", "id": self.keep(args[0])}}
                else:
                    answer = {"ok": self.encode(getattr(self, "op_" + req["op"])(*args))}
            except Exception as e:
                answer = {"error": type(e).__name__, "message": str(e)}
            # what plt.show() drew and plt.savefig() wrote during this
            # request goes along
            backend = sys.modules.get("chunky_backend")
            if backend is not None:
                for key in ("figures", "files"):
                    if getattr(backend, key):
                        answer[key] = getattr(backend, key)[:]
                        del getattr(backend, key)[:]
            return json.dumps(answer, allow_nan=True)

    _chunky_rb_bridge = _ChunkyRubyBridge()
  PYTHON

  # matplotlib's backend in the browser, a module file in Pyodide (written
  # by install_backend): Agg draws into memory, show() renders every open
  # figure as SVG for the cell and closes it - what matplotlib-inline does in
  # Jupyter. Text stays text in the SVG (svg.fonttype "none"): smaller, and
  # the browser's fonts draw Japanese, which matplotlib's DejaVu Sans lacks.
  BACKEND = <<~'PYTHON'
    import base64, io, warnings
    import matplotlib
    from matplotlib._pylab_helpers import Gcf
    from matplotlib.backends.backend_agg import FigureCanvasAgg

    FigureCanvas = FigureCanvasAgg
    # this Pyodide build warns from Agg's compiled text drawing on every PNG
    # ("x parameter as float"; backend_agg.py passes round()ed values, the
    # cause is not traced) - noise in a learner's cell
    warnings.filterwarnings("ignore", message="The [xy] parameter as float was deprecated",
                            category=matplotlib.MatplotlibDeprecationWarning)
    figures = []   # SVG text, taken by the bridge after each request

    def render(figure, fmt="svg"):
        buffer = io.BytesIO()
        with matplotlib.rc_context({"svg.fonttype": "none", "svg.hashsalt": "chunky"}), warnings.catch_warnings():
            # DejaVu Sans has no Japanese; matplotlib only measures the text
            # with it here, and the browser draws it (a PNG would show boxes)
            warnings.filterwarnings("ignore", message="Glyph .* missing from font")
            figure.savefig(buffer, format=fmt, bbox_inches="tight", dpi=100)
        data = buffer.getvalue()
        return data.decode("utf-8") if fmt == "svg" else base64.b64encode(data).decode("ascii")

    def show(*args, **kwargs):
        for manager in Gcf.get_all_fig_managers():
            figures.append(render(manager.canvas.figure))
        Gcf.destroy_all()

    # plt.savefig("chart.png") writes into Pyodide's file system, which Ruby
    # does not see: a relative name also goes to Ruby's files (SandboxFS),
    # so it is offered below the cell and kept in the workshop like any
    # file a cell writes - the same code saves a real file on a computer
    import os
    from matplotlib.figure import Figure
    files = []   # [name, base64], taken by the bridge after each request
    _savefig = Figure.savefig

    def _savefig_for_ruby(self, fname, *args, **kwargs):
        result = _savefig(self, fname, *args, **kwargs)
        if isinstance(fname, (str, os.PathLike)) and not os.path.isabs(fname):
            name = os.fspath(fname)
            if not os.path.splitext(name)[1]:
                name += "." + kwargs.get("format", matplotlib.rcParams["savefig.format"])
            with open(name, "rb") as f:
                files.append([name, base64.b64encode(f.read()).decode("ascii")])
        return result

    Figure.savefig = _savefig_for_ruby
  PYTHON

  SPECIAL_FLOATS = { "nan" => Float::NAN, "inf" => Float::INFINITY, "-inf" => -Float::INFINITY }.freeze

  class << self
    # a module of a package that is vendored but not loaded yet (the
    # workshop; a lesson asks for its own when it opens): load it, and the
    # cell is run again
    def import_module(name)
      request("import", name.to_s)
    rescue PyError => e
      top = name.to_s.split(".").first
      raise unless e.type == "ModuleNotFoundError" && JS.global[:chunkyPython][:imports][top].typeof == "string"

      JS.global.call(:ensurePython, %(import_module("#{top}")))
      raise NotReady, ChunkyApp.instance.ui["pythonLoading"].to_s
    end
    def eval(code) = request("eval", code.to_s)
    def exec(code) = request("exec", code.to_s)
    def builtins = import_module("builtins")

    # one operation in Python; the answer as a Ruby value or a PyObject
    def request(op, *args)
      json = JSON.generate({ "op" => op, "args" => args.map { |a| encode(a) } }, allow_nan: true)
      answer = JSON.parse(bridge.call(:run, json).to_s, allow_nan: true)
      flush_output
      answer["figures"]&.each { |svg| show_figure(svg) }
      answer["files"]&.each { |name, data| SandboxFS.write(name, data.unpack1("m0")) }
      raise PyError.new(answer["error"], answer["message"]) if answer["error"]
      return answer["data"] if answer.key?("data")

      decode(answer["ok"])
    end

    # a matplotlib figure (SVG text) below the cell, as show_image puts a
    # picture there; app.css gives an SVG its own size
    def show_figure(svg)
      ChunkyApp.instance.add_image("data:image/svg+xml;base64,#{[svg.b].pack('m0')}")
    end

    private

    def decode(value)
      case value["t"]
      when "none" then nil
      when "bool" then value["v"]
      when "int" then Integer(value["v"])
      when "float" then SPECIAL_FLOATS.fetch(value["v"]) { Float(value["v"]) }
      when "str" then value["v"]
      else PyObject.new(value["id"])
      end
    end

    def encode(value)
      case value
      when PyObject then { "__py__" => value.__pyid__ }
      when Tuple then { "__tuple__" => value.items.map { |v| encode(v) } }
      when Hash then value.to_h { |k, v| [k.to_s, encode(v)] }
      when Array then value.map { |v| encode(v) }
      when Range then value.to_a
      when Symbol then value.to_s
      when nil, true, false, Integer, Float, String then value
      else value.to_s
      end
    end

    # Pyodide, once index.html has loaded it; until then a word for the cell
    # (shell/bridge.js holds runs until Python is there, so this is rare)
    def python
      state = JS.global[:chunkyPython]
      return state if state[:ready].to_s == "true"

      failed = state[:error].typeof == "string" ? state[:error].to_s : nil
      ui = ChunkyApp.instance.ui
      raise NotReady, ui["pythonOffline"].to_s if failed == "offline"

      JS.global.call(:ensurePython)
      raise NotReady, failed ? "Python (Pyodide) could not be loaded: #{failed}" : ui["pythonLoading"].to_s
    end

    def bridge
      @bridge ||= begin
        pyodide = python[:pyodide]
        pyodide.call(:runPython, BRIDGE)
        pyodide[:globals].call(:get, "_chunky_rb_bridge").tap { |b| b.call(:install_backend, BACKEND) }
      end
    end

    # what Python printed goes into the cell's output
    def flush_output
      text = JS.global[:chunkyPython].call(:takeOutput).to_s
      $stdout.write(text) unless text.empty?
    end
  end

  # A Python object, kept in Python's registry. PyCall's ways apply: a
  # method call calls the attribute (a class comes back as it is, .new makes
  # an instance), [] and []= index, operators are Python's, and keyword
  # arguments are Python's keyword arguments.
  class PyObject
    BINARY = { :+ => "add", :- => "sub", :* => "mul", :/ => "truediv", :% => "mod", :** => "pow",
               :> => "gt", :< => "lt", :>= => "ge", :<= => "le", :& => "and_", :| => "or_", :^ => "xor" }.freeze

    def initialize(id)
      @id = id
    end

    def __pyid__ = @id

    def method_missing(name, *args, **kwargs, &block)
      key = name.to_s
      return PyCall.request("setattr", self, key.chomp("="), args.first) if key.end_with?("=") && args.size == 1 && kwargs.empty?

      PyCall.request("send", self, key, args, kwargs)
    end

    # Ruby asks before converting (to_ary, to_str ...): only the conversions
    # below exist; anything else is Python's to say
    def respond_to_missing?(name, include_private = false)
      key = name.to_s
      return false if key.start_with?("to_")

      PyCall.request("hasattr", self, key.chomp("="))
    end

    def new(*args, **kwargs) = PyCall.request("call", self, args, kwargs)
    def call(*args, **kwargs) = PyCall.request("call", self, args, kwargs)
    def [](*keys) = PyCall.request("getitem", self, keys.size == 1 ? keys.first : Tuple.new(keys))

    def []=(key, value)
      PyCall.request("setitem", self, key, value)
    end

    BINARY.each { |op, name| define_method(op) { |other| PyCall.request("binary", name, self, other) } }
    # 2 * x: Ruby asks the right-hand side, which makes the 2 a Python
    # object, and the operation runs in Python (the gem does the same)
    def coerce(other) = [PyCall.request("box", other), self]
    # Python's ==, as with the gem: two handles to equal objects are equal
    # (the registry gives every result its own number)
    def ==(other) = PyCall.request("binary", "eq", self, other)
    def -@ = PyCall.request("unary", "neg", self)
    def ~ = PyCall.request("unary", "invert", self)

    def to_s = PyCall.request("str", self)
    def inspect = PyCall.request("repr", self)
    def length = PyCall.request("len", self)
    alias size length
    # a list, tuple, dict, numpy array, Series or DataFrame as Ruby data
    def to_ruby = PyCall.request("plain", self)
    def to_a = Array(to_ruby)
    def to_h = to_ruby.to_h
    # what a notebook shows for it, when Python has that (a DataFrame: a table)
    def __html__ = PyCall.request("html", self)
  end
end

# helpers available inside notebook cells
module Kernel
  # A matplotlib figure below the cell, as SVG - what plt.show() does with
  # every open figure:
  #   show_plot          # the current figure
  #   show_plot fig      # one figure (plt.figure, fig.add_subplot ...)
  # A file is plt.savefig("chart.png"): offered below the cell, as on a
  # computer. (The companion gem could make show_plot savefig + open.)
  def show_plot(figure = nil)
    PyCall.show_figure(PyCall.request("figure", figure))
    nil
  end
end
