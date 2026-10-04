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
# sql.js keeps a database in memory. Without a path (or ":memory:") that is
# all; with one - Sequel.sqlite("timelog.db") - it is a SQLite file: opening
# reads its bytes, and at the end of each run (main.rb: Database.save_all)
# the database is written back as the bytes of a real SQLite file, if the
# run changed it. A relative path is one of the run's own files (SandboxFS:
# the lesson's virtual files, offered as a download; the workshop's project,
# kept in the browser or the connected folder), an absolute one a file on
# the wasm filesystem. Not after every statement: sql.js exports by closing
# and reopening, which ends a transaction and forgets last_insert_rowid.
#
# Values cross as JSON - an INTEGER as text, so it stays exact; a REAL as a
# number - and each result column carries its declared type (from PRAGMA
# table_info, as sql.js does not export sqlite3_column_decltype), which
# Sequel uses to turn 1 into true and "2026-10-04" into a Date.
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

    # A database file's bytes, or nil when there is none yet. A relative
    # path is the run's virtual file first (what the lesson or the workshop
    # project has), an absolute one a file on the wasm filesystem.
    def read_file(path)
      if defined?(SandboxFS) && SandboxFS.virtual?(path)
        return SandboxFS.read(path).b if SandboxFS.exist?(path)
      end
      File.file?(path) ? File.binread(path) : nil
    end

    def write_file(path, bytes)
      if defined?(SandboxFS) && SandboxFS.virtual?(path)
        SandboxFS.write(path, bytes)
      else
        File.binwrite(path, bytes)
      end
    end

    # SQL that only reads: a live run may send it to any database
    READS = /\A\s*(SELECT|EXPLAIN|VALUES)\b|\A\s*PRAGMA\s+[\w.]+\s*(\(|;|\z)/i

    def writes?(sql)
      text = sql.to_s
      return false if text.match?(READS)
      return text.match?(/\b(INSERT|UPDATE|DELETE|REPLACE)\b/i) if text.match?(/\A\s*WITH\b/i)

      true
    end

    # a live run (autorun.rb), which keeps nothing it changes
    def live_run?
      defined?(ChunkyApp) && ChunkyApp.instance.auto_run?
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

    attr_reader :filename

    @databases = []
    @generation = 0

    class << self
      # every open database; the number of the run going on now
      attr_reader :databases, :generation

      def quote(string) = string.to_s.gsub("'", "''")

      # as the gem: SQLite3::Database.open("x.db") is new
      def open(*args, &block) = new(*args, &block)

      # main.rb, at the end of every run (a live run too) and before it looks
      # at the files the run wrote: each file database the run used goes back
      # to its file. close: true (the workshop, where each run is a program
      # of its own) closes them all, so sql.js does not keep them in memory.
      def save_all(close: false)
        databases.dup.each do |db|
          begin
            close ? db.close : db.save
          rescue StandardError
            nil # a database that cannot be exported keeps its last saved file
          end
        end
      ensure
        @generation += 1
      end
    end

    # ":memory:", "" or nil: a database only in memory; any other path: a
    # SQLite file, read now and written back at the end of the run
    def initialize(path = ":memory:", options = {})
      options = {} unless options.is_a?(Hash)
      @results_as_hash = options[:results_as_hash]
      @filename = memory?(path) ? nil : path.to_s
      @readonly = options[:readonly]
      @generation = Database.generation
      @saved = @filename && Bridge.read_file(@filename)
      @id = Integer(Bridge.call(:open, @saved ? [@saved].pack("m0") : ""))
      @closed = false
      @used = false
      @in_transaction = false
      Database.databases << self
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
      before(sql)
      Bridge.call(:batch, @id, sql.to_s, JSON.generate(Bridge.bindings(vars)))
      after(sql)
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
      return self if @closed

      save
      Bridge.sqlite.call(:close, @id)
      Database.databases.delete(self)
      @closed = true
      self
    end

    def closed? = @closed

    # A file database back to its file, if it was used since the last save
    # and its bytes changed. Not inside a transaction: exporting would end it.
    def save
      return unless @filename && @used && !@closed && !@readonly && !@in_transaction

      @used = false
      bytes = Bridge.call(:exportDb, @id).unpack1("m0")
      return if bytes == @saved

      Bridge.write_file(@filename, bytes)
      @saved = bytes
    end

    # things the C library does that make no sense in a browser tab
    def busy_timeout(_ms) = self
    def busy_timeout=(_ms); end
    def extended_result_codes=(_on); end

    def create_function(name, *)
      raise NotImplementedError, "SQL functions written in Ruby (#{name}) are not available in the browser"
    end

    # used by Statement and execute: one statement and its rows
    def run_query(sql, vars)
      before(sql)
      result = ResultSet.new(self, Bridge.call(:query, @id, sql.to_s, JSON.generate(Bridge.bindings(vars))))
      after(sql)
      result
    end

    private

    def memory?(path)
      text = path.to_s
      text.empty? || text == ":memory:" || text.start_with?("file::memory:")
    end

    # A live run changes no database it did not open itself - those it opened
    # are thrown away with it; for the others, the cell asks for ▶ Run.
    def before(sql)
      raise MisuseException, "cannot use a closed database" if @closed
      raise AutoRun::NeedsRun if Bridge.live_run? && @generation != Database.generation && Bridge.writes?(sql)

      @used = true
    end

    # whether a transaction is open, so save waits for its end
    def after(sql)
      case sql.to_s
      when /\A\s*BEGIN\b/i then @in_transaction = true
      when /\A\s*(COMMIT|END)\b/i, /\A\s*ROLLBACK\s*(TRANSACTION\s*)?;?\s*\z/i then @in_transaction = false
      end
    end
  end
end
