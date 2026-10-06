# The plain-Ruby half of the Spinel lesson's compiler worker
# (html/spinel/toolchain.rb, SpinelBuild): what --print-build says, the
# clang command line made of it, Spinel's messages, IRB's verdict.
#   ruby test/spinel_build_test.rb
# (The rest runs on PicoRuby in a worker: test/spinel_test.mjs, in a browser.)
require "minitest/autorun"
require_relative "../html/spinel/toolchain"

class SpinelBuildTest < Minitest::Test
  PRINT_BUILD = <<~TEXT
    cflag -ffp-contract=off
    include /spinel/bin/../lib
    include /spinel/bin/../lib/regexp
    define -D_WASI_EMULATED_SIGNAL
    cflag -mllvm
    cflag -wasm-enable-sjlj
    source /work/main.c
    link /spinel/bin/../packages/json/sp_json_wasi.o
    runtime /spinel/bin/../lib/wasm32-wasi/libspinel_rt.a
    lib -lm
    lib -lsetjmp
    define -DSP_INT_OVERFLOW_MODE_RAISE
  TEXT

  def test_normalize
    assert_equal "/spinel/lib", SpinelBuild.normalize("/spinel/bin/../lib")
    assert_equal "/a/c", SpinelBuild.normalize("/a/b/../c")
    assert_equal "/a/d", SpinelBuild.normalize("/a/b/c/../../d")
    assert_equal "/a", SpinelBuild.normalize("/a/b/..")
    assert_equal "/x/y", SpinelBuild.normalize("/x/y")
  end

  def test_parse_build
    build = SpinelBuild.parse_build(PRINT_BUILD)
    assert_equal ["-ffp-contract=off", "-mllvm", "-wasm-enable-sjlj"], build["cflag"]
    assert_equal ["/spinel/lib", "/spinel/lib/regexp"], build["include"]
    assert_equal ["-D_WASI_EMULATED_SIGNAL", "-DSP_INT_OVERFLOW_MODE_RAISE"], build["define"]
    assert_equal "/work/main.c", build["source"]
    assert_equal "/spinel/lib/wasm32-wasi/libspinel_rt.a", build["runtime"]
    assert_equal ["/spinel/packages/json/sp_json_wasi.o"], build["link"]
    assert_equal ["-lm", "-lsetjmp"], build["lib"]
  end

  def test_clang_args_keep_the_link_order
    args = SpinelBuild.clang_args(SpinelBuild.parse_build(PRINT_BUILD), "/work/main.wasm")
    assert_equal "clang", args.first
    assert_equal ["-o", "/work/main.wasm"], args.last(2)
    source, package, runtime, libm = %w[/work/main.c /spinel/packages/json/sp_json_wasi.o
                                        /spinel/lib/wasm32-wasi/libspinel_rt.a -lm].map { |a| args.index(a) }
    assert_operator source, :<, package
    assert_operator package, :<, runtime, "a package's object before the archive it needs"
    assert_operator runtime, :<, libm
    assert_includes args, "-I/spinel/lib"
    assert_includes args, "-Wl,--fatal-warnings"
    assert_equal "/spinel/lib/wasi/sp_page.h", args[args.index("-include") + 1]
  end

  def test_tidy
    assert_equal "main.rb:2: unsupported eval", SpinelBuild.tidy("spinel: /work/main.rb:2: unsupported eval\n")
    assert_equal "", SpinelBuild.tidy(nil)
  end

  # what spinel --dump-ast says (measured with the pinned Spinel)
  def test_verdict
    assert_equal "ok", SpinelBuild.verdict(0, "")
    more = "Parse errors in '/work/main.rb':\n  /work/main.rb:1:14: unexpected end-of-input, assuming it is closing the parent top level context\n"
    assert_equal "more", SpinelBuild.verdict(1, more)
    assert_equal "more", SpinelBuild.verdict(1, "Parse errors in '/work/main.rb':\n  /work/main.rb:1:6: unterminated string meets end of file\n")
    wrong = "Parse errors in '/work/main.rb':\n  /work/main.rb:1:6: unexpected integer; expected an expression after the operator\n" \
            "  /work/main.rb:1:6: unexpected integer, expecting end-of-input\nspinel: parse failed for '/work/main.rb'\n"
    assert_equal "error (irb):1:6: unexpected integer; expected an expression after the operator", SpinelBuild.verdict(1, wrong)
  end
end
