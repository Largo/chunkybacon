# The RP2040/RP2350's PIO, as far as the Pico lessons need it
# (docs/HANDOVER.md §6r): PicoRuby's picoruby-pio is vendored unchanged
# (vendor/pio.rb, the assembler, and vendor/pio_state_machine.rb); this is
# the hardware behind its C half (prims.rb, from src/mruby/pio.c and
# ports/rp2040/pio.c of 4.0.3): 32 instruction slots per PIO block, four
# state machines each, a clock divider from clk_sys (150 MHz on a Pico 2,
# 125 MHz on a Pico), the TX FIFO (4 words, 8 joined).
#
# A state machine does not run cycle by cycle here. When it starts, its
# program is run once on two test words (all ones, all zeros) by a small
# interpreter (Pio.waveform), which measures what the program puts on its
# pin for one bit of each: the high time and the period, in clock cycles.
# A program that sends one pulse per bit - WS2812's, from picoruby-pio's
# README and ksbmyk/picoruby-ws2812 - is then known by its timing, and the
# words a program puts into the FIFO become a bit stream on that pin
# (Pio#bits). The parts on the pin (devices/ws2812.rb) decode it as the
# chips would. A program this cannot measure (IN, WAIT, IRQ, PUSH, a
# side-set that never toggles) puts nothing on the pin, and the bench's log
# says so.

module PicoSim
  module Pio
    SLOTS = 32
    LOW_GAP_NS = 50_000     # WS2812's reset: the line low this long latches

    def self.clk_sys(board)
      board == "pico" || board == "picow" ? 125_000_000 : 150_000_000
    end

    # [high cycles of a 1, period of a 1, high cycles of a 0, period of a 0]
    # for one bit, or nil when the program does not send one pulse per bit
    def self.waveform(sm)
      ones = Interp.new(sm).run(0xFFFFFFFF)
      zeros = Interp.new(sm).run(0)
      return nil if ones.nil? || zeros.nil?
      one = steady(ones, sm.threshold)
      zero = steady(zeros, sm.threshold)
      return nil if one.nil? || zero.nil?
      [one[0], one[1], zero[0], zero[1]]
    end

    # every bit of the word the same pulse: [high, period], else nil (the
    # last bit's period ends where the program stalls for the next word)
    def self.steady(pulses, bits)
      return nil if pulses.size != bits
      first = pulses[0]
      return nil if first[1].nil?
      i = 1
      while i < bits
        return nil if pulses[i][0] != first[0]
        return nil if i < bits - 1 && pulses[i][1] != first[1]
        i += 1
      end
      first
    end

    # A PIO state machine's program on one pin (the side-set's first pin,
    # or the first OUT or SET pin), run on one word: the pulses it makes,
    # [[high cycles, period cycles], ...] - nil for an instruction this
    # does not model or a program that loops without using the word.
    class Interp
      def initialize(sm)
        @sm = sm
        @prog = sm.instructions
        @x = 0
        @y = 0
        @osr = 0
        @count = 32           # an empty OSR (pio_sm_init)
        @pc = 0
        @level = 0
        @cycle = 0
        @last_rise = nil
        @pulses = []
        @word = nil
      end

      def run(word)
        @word = word
        @fed = false
        steps = 0
        while steps < 2000
          r = step
          if r == :stall
            # the word is used up: the line stays as it is (low, a reset)
            @pulses.last[1] = @cycle - @last_rise if @pulses.size > 0 && @pulses.last[1].nil?
            return @fed ? @pulses : nil
          end
          return nil unless r
          steps += 1
          return nil if @pulses.size > 40
        end
        nil
      end

      def side_bits
        @sm.side_set_count + (@sm.side_set_optional ? 1 : 0)
      end

      # the pin's level from this cycle on: a rise ends the period of the
      # pulse before, a fall ends a pulse's high time
      def set_line(level)
        return if level == @level
        if level == 1
          @pulses.last[1] = @cycle - @last_rise if @pulses.size > 0 && @pulses.last[1].nil?
          @last_rise = @cycle
        elsif @last_rise
          @pulses << [@cycle - @last_rise, nil]
        end
        @level = level
      end

      def pull
        return false if @word.nil?   # an empty FIFO: the state machine stalls
        @osr = @word & 0xFFFFFFFF
        @word = nil
        @fed = true
        @count = 0
        true
      end

      def shift_out(n)
        n = 32 if n == 0
        if @sm.out_shift_right
          value = n == 32 ? @osr : @osr & ((1 << n) - 1)
          @osr = n == 32 ? 0 : @osr >> n
        else
          value = (@osr >> (32 - n)) & ((1 << n) - 1)
          @osr = n == 32 ? 0 : (@osr << n) & 0xFFFFFFFF
        end
        @count += n
        value
      end

      # one instruction: false for one this does not model
      def step
        instr = @prog[@pc]
        return false if instr.nil?
        op = instr >> 13
        field = (instr >> 8) & 0x1F
        sb = side_bits
        delay_bits = 5 - sb
        delay = field & ((1 << delay_bits) - 1)
        if @sm.side_set_count > 0 && @sm.sideset_pin == @sm.pin
          side = field >> delay_bits
          enabled = true
          if @sm.side_set_optional
            enabled = (side >> @sm.side_set_count) & 1 == 1
            side &= (1 << @sm.side_set_count) - 1
          end
          set_line(side & 1) if enabled
        end
        nxt = @pc + 1
        case op
        when 0b000                                     # JMP
          cond = (instr >> 5) & 7
          addr = instr & 0x1F
          take = case cond
                 when 0 then true
                 when 1 then @x == 0
                 when 2 then (t = @x != 0; @x = (@x - 1) & 0xFFFFFFFF; t)
                 when 3 then @y == 0
                 when 4 then (t = @y != 0; @y = (@y - 1) & 0xFFFFFFFF; t)
                 when 5 then @x != @y
                 when 6 then false
                 else @count < @sm.threshold
                 end
          nxt = addr if take
        when 0b011                                     # OUT
          if @sm.autopull && @count >= @sm.threshold
            return :stall unless pull
          end
          dest = (instr >> 5) & 7
          value = shift_out(instr & 0x1F)
          case dest
          when 0 then set_line(value & 1) if @sm.out_pin == @sm.pin
          when 1 then @x = value
          when 2 then @y = value
          when 3, 4 then nil
          when 5 then nxt = value & 0x1F
          else return false
          end
        when 0b100                                     # PULL (PUSH is not modelled)
          return false if (instr >> 7) & 1 == 0
          ifempty = (instr >> 6) & 1 == 1
          unless ifempty && @count < @sm.threshold
            return :stall unless pull
          end
        when 0b101                                     # MOV
          dest = (instr >> 5) & 7
          opn = (instr >> 3) & 3
          src = instr & 7
          v = case src
              when 1 then @x
              when 2 then @y
              when 3 then 0
              when 7 then @osr
              else 0
              end
          v = (~v) & 0xFFFFFFFF if opn == 1
          case dest
          when 1 then @x = v
          when 2 then @y = v
          when 7 then (@osr = v; @count = 0)
          when 0 then set_line(v & 1) if @sm.out_pin == @sm.pin
          when 5 then nxt = v & 0x1F
          end
        when 0b111                                     # SET
          dest = (instr >> 5) & 7
          v = instr & 0x1F
          case dest
          when 0 then set_line(v & 1) if @sm.set_pin == @sm.pin
          when 1 then @x = v
          when 2 then @y = v
          end
        else
          return false                                 # WAIT, IN, PUSH, IRQ
        end
        @cycle += 1 + delay
        nxt = @sm.wrap_target if @pc == @sm.wrap && nxt == @pc + 1
        @pc = nxt
        true
      end
    end
  end

  # one state machine of the simulated chip (PIO::StateMachine's C side)
  class PioSm
    attr_reader :pio, :sm, :instructions, :side_set_count, :side_set_optional, :wrap_target, :wrap,
                :out_shift_right, :autopull, :threshold, :fifo_depth, :pin, :sideset_pin, :out_pin, :set_pin
    attr_accessor :freq, :enabled, :timing, :busy_until, :backlog

    def initialize(c)
      @pio = c[0]
      @sm = c[1]
      @instructions = c[2]
      @side_set_count = c[4]
      @side_set_optional = c[5] != 0
      @wrap_target = c[6]
      @wrap = c[7]
      @freq = c[8]
      @out_pin = c[9]
      @set_pin = c[11]
      @sideset_pin = c[14]
      @out_shift_right = c[16] != 0
      @autopull = c[17] != 0
      @threshold = c[18] == 0 ? 32 : c[18]
      @fifo_depth = c[22] == 1 ? 8 : 4
      # the pin the program drives: its side-set's first pin, else its OUT
      # or SET pin
      @pin = @side_set_count > 0 && @sideset_pin >= 0 ? @sideset_pin : (@out_pin >= 0 ? @out_pin : @set_pin)
      @enabled = false
      @timing = nil
      @busy_until = 0.0
      @backlog = []
    end

    # the state machine's clock: clk_sys / the divider (at least 1)
    def clock(board)
      sys = Pio.clk_sys(board)
      @freq > sys ? sys.to_f : @freq.to_f
    end

    # ns of [T1H, T1 period, T0H, T0 period], or nil (Pio.waveform)
    def timing_ns(board)
      @timing = (Pio.waveform(self) || []) if @timing.nil?
      return nil if @timing.empty?
      ns = 1_000_000_000.0 / clock(board)
      @timing.map { |c| c * ns }
    end

    # the bits of the words as they leave the OSR: +threshold+ bits per word,
    # the highest first when shifting left
    def bits(words)
      out = []
      words.each do |w|
        w &= 0xFFFFFFFF
        i = 0
        while i < @threshold
          out << (@out_shift_right ? (w >> i) & 1 : (w >> (31 - i)) & 1)
          i += 1
        end
      end
      out
    end

    # how long the words keep the line busy, ms
    def words_ms(count, board)
      t = timing_ns(board)
      period = t ? (t[1] > t[3] ? t[1] : t[3]) : 1250.0
      count * @threshold * period / 1_000_000.0
    end
  end
end
