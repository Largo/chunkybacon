# SQLite in the browser. The sqlite3 gem is a C extension around libsqlite3,
# which ruby.wasm does not have; sql.js is SQLite compiled to WebAssembly
# (index.html: window.chunkySqlite, tools/vendor_sqljs.rb), and this file is
# the gem's API on top of it - enough for Sequel's own SQLite adapter, so
#
#   require "sequel"
#   DB = Sequel.sqlite
#
# runs unchanged, as on a computer with the real gem. main.rb registers it
# as the "sqlite3" shim, so require "sqlite3" and install_gem "sqlite3" work.
#
# Every database lives in memory (sql.js has no files): a path is accepted
# and ignored, and each Database.new is a fresh, empty one. Values cross as
# JSON - an INTEGER as text, so it stays exact; a REAL as a number - and
# each result column carries its declared type (from PRAGMA table_info, as
# sql.js does not export sqlite3_column_decltype), which Sequel uses to
# turn 1 into true and "2026-10-04" into a Date.
require "json"

module SQLite3
  # the API level of the gem this stands in for; Sequel reads it
  VERSION = "2.0.0"

  class Exception < ::StandardError
    # SQLite's extended result code; sql.js gives only the message, and
    # Sequel then recognises constraint errors by their text
    def code = nil
  end
  class SQLException < Exception; end
  class ConstraintException < Exception; end
  class BusyException < Exception; end
  class MisuseException < Exception; end

  # sql.js is still loading, or could not be loaded
  class NotReady < Exception; end

  module Bridge
    module_function

    def sqlite
      state = JS.global[:chunkySqlite]
      return state if state[:ready].to_s == "true"

      failed = state[:error].typeof == "string" ? state[:error].to_s : nil
      JS.global.call(:ensureSqlite)
      raise NotReady, failed ? "SQLite (sql.js) could not be loaded: #{failed}" : ChunkyApp.instance.ui["sqliteLoading"].to_s
    end

    # one call; the answer as Ruby data, or the SQLite error as an exception
    def call(name, *args)
      answer = JSON.parse(sqlite.call(name, *args).to_s)
      raise error_for(answer["error"]) if answer.key?("error")

      answer["ok"]
    end

    def error_for(message)
      klass = message.match?(/constraint failed|not unique|may not be NULL/i) ? ConstraintException : SQLException
      klass.new(message)
    end

    # a Ruby value for binding: small integers as numbers, others as text
    # (exact), binary strings as base64
    def encode(value)
      case value
      when nil, Float, true, false then value == true ? 1 : (value == false ? 0 : value)
      when Integer then value.between?(-2**31, 2**31 - 1) ? value : { "i" => value.to_s }
      when String
        if value.encoding == Encoding::BINARY && !value.dup.force_encoding(Encoding::UTF_8).valid_encoding? ||
           value.class.name == "Sequel::SQL::Blob" || value.class.name == "SQLite3::Blob"
          { "b" => [value].pack("m0") }
        else
          value.encode(Encoding::UTF_8)
        end
      else value.to_s
      end
    end

    # bind variables as the gem takes them: none, a list, a splat or a hash
    def bindings(vars)
      vars = vars.first if vars.size == 1 && (vars.first.is_a?(Hash) || vars.first.is_a?(Array))
      vars.is_a?(Hash) ? vars.to_h { |k, v| [k.to_s, encode(v)] } : Array(vars).map { |v| encode(v) }
    end

    def decode(value)
      case value
      when Hash
        return Integer(value["i"]) if value.key?("i")
        return value["f"].to_f if value.key?("f")
        return value["b"].unpack1("m0") if value.key?("b")

        value
      when String then value.dup.force_encoding(Encoding::UTF_8)
      else value
      end
    end
  end

  # a binary value, as the gem has it
  class Blob < String; end

  # The rows of one statement; the gem hands this to query and
  # Statement#execute blocks. Sequel reads columns, types and each.
  class ResultSet
    include Enumerable

    attr_reader :columns, :types

    def initialize(db, answer)
      @db = db
      @columns = answer["columns"]
      @types = answer["types"]
      @rows = answer["rows"].map { |row| row.map { |v| Bridge.decode(v) } }
      @at = 0
    end

    def each
      return to_enum(:each) unless block_given?

      while (row = self.next)
        yield row
      end
    end

    def next
      row = @rows[@at] or return nil
      @at += 1
      @db.results_as_hash ? @columns.zip(row).to_h : row
    end

    def reset(*) = @at = 0
    def eof? = @at >= @rows.size
    def close = @rows = []
    def closed? = false
  end

  # A statement: its SQL, run afresh on each execute (sql.js statements live
  # in JavaScript; keeping them across calls would gain little in memory)
  class Statement
    attr_reader :sql, :columns, :types

    def initialize(db, sql)
      @db = db
      @sql = sql.to_s
      @bound = []
      @closed = false
    end

    def bind_params(*vars)
      @bound = vars
      self
    end

    def execute(*vars)
      raise MisuseException, "cannot use a closed statement" if @closed

      result = @db.run_query(@sql, vars.empty? ? @bound : vars)
      @columns = result.columns
      @types = result.types
      return result unless block_given?

      yield result
    end

    def execute!(*vars, &block)
      rows = execute(*vars).to_a
      block ? rows.each(&block) : rows
    end

    def clear_bindings!
      @bound = []
      self
    end

    def reset! = self
    def close = @closed = true
    def closed? = @closed
  end

  class Database
    attr_accessor :results_as_hash

    def self.quote(string) = string.to_s.gsub("'", "''")

    # path is accepted and ignored: sql.js keeps every database in memory
    def initialize(_path = ":memory:", options = {})
      @results_as_hash = options.is_a?(Hash) && options[:results_as_hash]
      @id = Bridge.sqlite.call(:open).to_i
      @closed = false
      return unless block_given?

      begin
        yield self
      ensure
        close
      end
    end

    # rows as arrays (hashes with results_as_hash), or each one to the block
    def execute(sql, *vars, &block)
      rows = run_query(sql, vars).to_a
      block ? rows.each(&block) : rows
    end

    # several statements; with bind variables only the one statement
    def execute_batch(sql, *vars)
      Bridge.call(:batch, @id, sql.to_s, JSON.generate(Bridge.bindings(vars)))
      nil
    end
    alias execute_batch2 execute_batch

    def query(sql, *vars)
      result = run_query(sql, vars)
      return result unless block_given?

      yield result
    end

    def prepare(sql)
      statement = Statement.new(self, sql)
      return statement unless block_given?

      begin
        yield statement
      ensure
        statement.close
      end
    end

    def get_first_row(sql, *vars) = execute(sql, *vars).first
    def get_first_value(sql, *vars) = Array(get_first_row(sql, *vars)).then { |row| row.is_a?(Hash) ? row.values.first : row.first }

    def last_insert_row_id = Integer(Bridge.sqlite.call(:lastInsertRowId, @id).to_s)
    def changes = Bridge.sqlite.call(:changes, @id).to_i

    def transaction(mode = :deferred)
      execute("BEGIN #{mode.to_s.upcase} TRANSACTION")
      return true unless block_given?

      begin
        result = yield self
        commit
        result
      rescue ::Exception
        rollback
        raise
      end
    end

    def commit = execute("COMMIT")
    def rollback = execute("ROLLBACK")

    def close
      Bridge.sqlite.call(:close, @id) unless @closed
      @closed = true
      self
    end

    def closed? = @closed

    # things the C library does that make no sense in a browser tab
    def busy_timeout(_ms) = self
    def busy_timeout=(_ms); end
    def extended_result_codes=(_on); end

    def create_function(name, *)
      raise NotImplementedError, "SQL functions written in Ruby (#{name}) are not available in the browser"
    end

    # used by Statement and execute: one statement and its rows
    def run_query(sql, vars)
      raise MisuseException, "cannot use a closed database" if @closed

      ResultSet.new(self, Bridge.call(:query, @id, sql.to_s, JSON.generate(Bridge.bindings(vars))))
    end
  end
end
