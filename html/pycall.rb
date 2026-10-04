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

        # Ruby data: a Series or numpy array as a list, a DataFrame as a dict
        def plain(self, obj):
            obj = self.scalar(obj)
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

        def run(self, request):
            req = json.loads(request)
            try:
                args = [self.decode(a) for a in req["args"]]
                if req["op"] == "plain":
                    return json.dumps({"data": self.plain(args[0])}, allow_nan=True)
                return json.dumps({"ok": self.encode(getattr(self, "op_" + req["op"])(*args))})
            except Exception as e:
                return json.dumps({"error": type(e).__name__, "message": str(e)})

    _chunky_rb_bridge = _ChunkyRubyBridge()
  PYTHON

  SPECIAL_FLOATS = { "nan" => Float::NAN, "inf" => Float::INFINITY, "-inf" => -Float::INFINITY }.freeze

  class << self
    def import_module(name) = request("import", name.to_s)
    def eval(code) = request("eval", code.to_s)
    def exec(code) = request("exec", code.to_s)
    def builtins = import_module("builtins")

    # one operation in Python; the answer as a Ruby value or a PyObject
    def request(op, *args)
      json = JSON.generate({ "op" => op, "args" => args.map { |a| encode(a) } }, allow_nan: true)
      answer = JSON.parse(bridge.call(:run, json).to_s, allow_nan: true)
      flush_output
      raise PyError.new(answer["error"], answer["message"]) if answer["error"]
      return answer["data"] if answer.key?("data")

      decode(answer["ok"])
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
      JS.global.call(:ensurePython)
      raise NotReady, failed ? "Python (Pyodide) could not be loaded: #{failed}" : ChunkyApp.instance.ui["pythonLoading"].to_s
    end

    def bridge
      @bridge ||= begin
        pyodide = python[:pyodide]
        pyodide.call(:runPython, BRIDGE)
        pyodide[:globals].call(:get, "_chunky_rb_bridge")
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
    def ==(other) = other.is_a?(PyObject) ? @id == other.__pyid__ : PyCall.request("binary", "eq", self, other)
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
