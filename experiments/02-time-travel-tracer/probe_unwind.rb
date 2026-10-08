# Probe: during a :b_return / :return caused by an exception, is $! set?
# And does a rescued exception leave $! set at a later normal b_return?
code = "begin\n  [1].each { |x| x + nil }\nrescue\nend\n[2].each { |y| y }\ndef f = raise('x')\nf rescue 1\n"
tp = TracePoint.new(:b_return, :return, :raise) { |t| p [t.event, t.lineno, $!&.class] }
c = TracePoint.new(:script_compiled) { |t| tp.enable(target: t.instruction_sequence) if t.eval_script == code }
c.enable
eval(code, binding, "cell.rb")
c.disable
tp.disable
