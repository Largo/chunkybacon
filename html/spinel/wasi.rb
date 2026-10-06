# WASI preview 1 for the Spinel lesson (lesson 42), in Ruby on PicoRuby.wasm
# in a worker (spinel/boot.js): it runs spinel.wasm, the compiler, and the
# programs it builds, each on a filesystem in memory. Only what those two
# ask of a host is here - files and directories under one preopened "/",
# stdin/stdout/stderr, clocks, random numbers, exit; everything else answers
# ENOSYS, as an unsupported call does on a POSIX system.
#
#   fs = SpinelWasi::MemFS.new
#   fs.write_text("/work/main.rb", source)
#   result = SpinelWasi.run(wasm_module, args: [...], fs: fs)   # {code, stdout, stderr}
#
# The bytes stay JavaScript's (Uint8Arrays; a Ruby String would end at the
# first NUL on its way to JavaScript): Ruby keeps the references and the
# bookkeeping. The imports are Ruby callbacks, registered once per worker;
# the module calls them synchronously, inside the Ruby call that started it.
# PicoRuby's limits (docs/PICORUBY_SHELL.md §5) hold here as in html/shell/:
# test/shell/portability_test.rb scans this directory too.
require 'js'

module SpinelWasi
  SUCCESS = 0
  EBADF = 8
  EEXIST = 20
  EINVAL = 28
  EIO = 29
  EISDIR = 31
  ENOENT = 44
  ENOSYS = 52
  ENOTDIR = 54
  ENOTEMPTY = 55
  ESPIPE = 70
  CHARACTER_DEVICE = 2
  DIRECTORY = 3
  REGULAR_FILE = 4
  O_CREAT = 1
  O_DIRECTORY = 2
  O_EXCL = 4
  O_TRUNC = 8
  FD_APPEND = 1
  TWO32 = 4_294_967_296.0

  # a regular file: its bytes (a Uint8Array) and how many of them count;
  # shared while it is the archive's or a clone's, copied on the first write
  class MemFile
    attr_accessor :data, :size, :shared

    def initialize(data, size, shared = false)
      @data = data
      @size = size
      @shared = shared
    end

    def dir? = false
  end

  class MemDir
    attr_reader :entries

    def initialize
      @entries = {}
    end

    def dir? = true
  end

  class MemFS
    attr_accessor :root

    def initialize
      @root = MemDir.new
    end

    def self.parts(path)
      path.split("/").reject { |part| part.empty? || part == "." }
    end

    def lookup(path, from = @root)
      node = from
      stack = []
      MemFS.parts(path).each do |part|
        return nil unless node.dir?

        if part == ".."
          node = stack.pop || @root
          next
        end
        stack << node
        node = node.entries[part]
        return nil if node.nil?
      end
      node
    end

    # the directory a path is in, and its last part
    def parent(path, from = @root, create = false)
      parts = MemFS.parts(path)
      name = parts.pop
      node = from
      parts.each do |part|
        child = part == ".." ? @root : node.entries[part]
        if child.nil? && create
          child = MemDir.new
          node.entries[part] = child
        end
        return [nil, name] if child.nil? || !child.dir?

        node = child
      end
      [node, name]
    end

    def write_file(path, bytes, shared = false)
      dir, name = parent(path, @root, true)
      dir.entries[name] = MemFile.new(bytes, bytes[:length], shared)
    end

    def write_text(path, text)
      write_file(path, JS.global[:TextEncoder].new.encode(text))
    end

    def mkdir(path)
      dir, name = parent(path, @root, true)
      dir.entries[name] = MemDir.new unless dir.entries[name]
    end

    # the bytes of a file (a Uint8Array), or nil
    def read_file(path)
      node = lookup(path)
      node && !node.dir? ? node.data.subarray(0, node.size) : nil
    end

    def read_text(path)
      bytes = read_file(path)
      bytes ? JS.global[:TextDecoder].new.decode(bytes) : nil
    end

    # the files of a tar archive (ustar, as tools/build_spinel.rb writes
    # it: no long names) under +prefix+, shared with the archive's bytes
    def add_tar(bytes, prefix = "/")
      decoder = JS.global[:TextDecoder].new
      total = bytes[:length]
      at = 0
      while at + 512 <= total && bytes[at] != 0
        name = MemFS.c_string(decoder, bytes, at, 100)
        pre = MemFS.c_string(decoder, bytes, at + 345, 155)
        name = "#{pre}/#{name}" unless pre.empty?
        size = MemFS.c_string(decoder, bytes, at + 124, 12).strip.to_i(8)
        if bytes[at + 156] == 53 # "5": a directory
          mkdir(prefix + name)
        else
          write_file(prefix + name, bytes.subarray(at + 512, at + 512 + size), true)
        end
        at += 512 + ((size + 511) / 512) * 512
      end
      self
    end

    # a field of a tar header: up to its first NUL
    def self.c_string(decoder, bytes, at, length)
      finish = at
      finish += 1 while finish < at + length && bytes[finish] != 0
      decoder.decode(bytes.subarray(at, finish))
    end

    # a copy whose files can be written without touching this one's
    def clone
      copy = MemFS.new
      copy.root = MemFS.copy_node(@root)
      copy
    end

    def self.copy_node(node)
      return MemFile.new(node.data, node.size, true) unless node.dir?

      dir = MemDir.new
      node.entries.each { |name, child| dir.entries[name] = MemFS.copy_node(child) }
      dir
    end

    # the tree as YoWASP's runtime takes it: {dir: {file: Uint8Array}}
    def self.js_tree(node)
      tree = JS.global[:Object].new
      node.entries.each do |name, child|
        tree[name] = child.dir? ? MemFS.js_tree(child) : child.data.subarray(0, child.size)
      end
      tree
    end
  end

  # An open file: a node and where it is read or written, or a terminal
  class Handle
    attr_accessor :node, :at, :append, :tty

    def initialize(node: nil, tty: nil, append: false)
      @node = node
      @at = 0
      @append = append
      @tty = tty
    end

    def dir = @node && @node.dir? ? @node : nil
  end

  # The host for one run of one module; SpinelWasi.run makes it and the
  # callbacks find it as SpinelWasi.current.
  class Host
    attr_reader :code, :fs

    def initialize(fs, args, stdin, out, err)
      @fs = fs
      @args = args.map { |arg| Host.c_bytes(arg) }
      @stdin = stdin   # a Uint8Array
      @stdin_at = 0
      @out = out
      @err = err
      @handles = { 0 => Handle.new(tty: 0), 1 => Handle.new(tty: 1), 2 => Handle.new(tty: 2),
                   3 => Handle.new(node: fs.root) }
      @next_fd = 4
      @code = 0
      @exited = false
      @memory = nil
    end

    # a C string's bytes, NUL included (a NUL in a Ruby String would end the
    # string on its way to JavaScript, so the terminator is a zeroed byte)
    def self.c_bytes(text)
      bytes = JS.global[:TextEncoder].new.encode(text.to_s)
      with_nul = JS.global[:Uint8Array].new(bytes[:length] + 1)
      with_nul.set(bytes)
      with_nul
    end

    def attach(memory)
      @memory = memory
    end

    def exited? = @exited

    # views of the memory now (it may have grown since the last call)
    def dv = JS.global[:DataView].new(@memory[:buffer])
    def u8 = JS.global[:Uint8Array].new(@memory[:buffer])

    def text_at(ptr, len)
      JS.global[:TextDecoder].new.decode(u8.subarray(ptr, ptr + len))
    end

    def put32(ptr, value)
      dv.setUint32(ptr, value, true)
    end

    # a 64-bit value as two halves: no BigInt, and no Integer past 32 bits
    def put64(ptr, value)
      high = (value / TWO32).floor
      view = dv
      view.setUint32(ptr, value - high * TWO32, true)
      view.setUint32(ptr + 4, high, true)
    end

    def iovecs(ptr, count)
      view = dv
      list = []
      i = 0
      while i < count
        list << [view.getUint32(ptr + i * 8, true), view.getUint32(ptr + i * 8 + 4, true)]
        i += 1
      end
      list
    end

    # the node a path names, relative to a directory handle: [node, path, from]
    def resolve(dirfd, ptr, len)
      base = @handles[dirfd]
      return [nil, nil, nil] unless base && base.dir

      path = text_at(ptr, len)
      [@fs.lookup(path, base.dir), path, base.dir]
    end

    def writable(file)
      return unless file.shared

      file.data = file.data.slice(0, file.size)
      file.shared = false
    end

    def grow(file, size)
      writable(file)
      capacity = file.data[:length]
      return if size <= capacity

      capacity *= 2
      capacity = size if capacity < size
      capacity = 256 if capacity < 256
      bigger = JS.global[:Uint8Array].new(capacity)
      bigger.set(file.data.subarray(0, file.size))
      file.data = bigger
    end

    def write_at(file, at, bytes)
      length = bytes[:length]
      grow(file, at + length)
      file.data.set(bytes, at)
      file.size = at + length if at + length > file.size
    end

    def read_stdin(max)
      left = @stdin[:length] - @stdin_at
      max = left if max > left
      chunk = @stdin.subarray(@stdin_at, @stdin_at + max)
      @stdin_at += max
      chunk
    end

    def file_stat(ptr, node, tty)
      view = dv
      i = 0
      while i < 64
        view.setUint32(ptr + i, 0, true)
        i += 4
      end
      type = if tty then CHARACTER_DEVICE
             elsif node.dir? then DIRECTORY
             else REGULAR_FILE
             end
      view.setUint8(ptr + 16, type)
      put64(ptr + 24, 1)
      put64(ptr + 32, node && !node.dir? ? node.size : 0)
      SUCCESS
    end

    def put_list(list, ptrs, buf)
      mem = u8
      list.each do |bytes|
        put32(ptrs, buf)
        ptrs += 4
        mem.set(bytes, buf)
        buf += bytes[:length]
      end
      SUCCESS
    end

    def sizes(list, count_ptr, size_ptr)
      put32(count_ptr, list.length)
      total = 0
      list.each { |bytes| total += bytes[:length] }
      put32(size_ptr, total)
      SUCCESS
    end

    # ---------- the calls (wasi_snapshot_preview1) ----------

    def args_get(ptrs, buf) = put_list(@args, ptrs, buf)
    def args_sizes_get(count, size) = sizes(@args, count, size)
    def environ_get(_ptrs, _buf) = SUCCESS

    def environ_sizes_get(count, size)
      put32(count, 0)
      put32(size, 0)
      SUCCESS
    end

    def clock_res_get(_id, ptr)
      put64(ptr, 1000)
      SUCCESS
    end

    def clock_time_get(id, _precision, ptr)
      ns = id == 0 ? JS.global[:Date].now * 1_000_000.0 : JS.global[:performance].now * 1_000_000.0
      put64(ptr, ns.floor)
      SUCCESS
    end

    def random_get(ptr, len)
      at = 0
      while at < len
        upto = at + 65_536
        upto = len if upto > len
        JS.global[:crypto].getRandomValues(u8.subarray(ptr + at, ptr + upto))
        at = upto
      end
      SUCCESS
    end

    # the module traps right after it (wasi-libc's _Exit: unreachable), and
    # SpinelWasi.run takes the trap for the end of the program
    def proc_exit(code)
      @code = code
      @exited = true
      SUCCESS
    end

    def sched_yield = SUCCESS

    # sleep: every clock subscription is done at once (a virtual sleep)
    def poll_oneoff(in_ptr, out_ptr, count, count_ptr)
      view = dv
      i = 0
      while i < count
        sub = in_ptr + i * 48
        event = out_ptr + i * 32
        view.setUint32(event, view.getUint32(sub, true), true)
        view.setUint32(event + 4, view.getUint32(sub + 4, true), true)
        view.setUint16(event + 8, 0, true)
        view.setUint8(event + 10, view.getUint8(sub + 8))
        i += 1
      end
      put32(count_ptr, count)
      SUCCESS
    end

    def fd_write(fd, iovs, count, n_ptr)
      handle = @handles[fd]
      return EBADF unless handle

      written = 0
      iovecs(iovs, count).each do |ptr, size|
        bytes = u8.subarray(ptr, ptr + size)
        if handle.tty
          (handle.tty == 1 ? @out : @err).call(bytes.slice(0, size))
        elsif handle.node && !handle.node.dir?
          handle.at = handle.node.size if handle.append
          write_at(handle.node, handle.at, bytes)
          handle.at += size
        else
          return EBADF
        end
        written += size
      end
      put32(n_ptr, written)
      SUCCESS
    end

    def fd_pwrite(fd, iovs, count, offset, n_ptr)
      handle = @handles[fd]
      return EBADF unless handle && handle.node && !handle.node.dir?

      at = SpinelWasi.int(offset)
      written = 0
      iovecs(iovs, count).each do |ptr, size|
        write_at(handle.node, at, u8.subarray(ptr, ptr + size))
        at += size
        written += size
      end
      put32(n_ptr, written)
      SUCCESS
    end

    def fd_read(fd, iovs, count, n_ptr)
      handle = @handles[fd]
      return EBADF unless handle
      return EISDIR if handle.node && handle.node.dir?

      read = 0
      iovecs(iovs, count).each do |ptr, size|
        if handle.tty == 0
          chunk = read_stdin(size)
        elsif handle.node
          upto = handle.at + size
          upto = handle.node.size if upto > handle.node.size
          from = handle.at
          from = upto if from > upto
          chunk = handle.node.data.subarray(from, upto)
          handle.at = upto
        else
          return EBADF
        end
        got = chunk[:length]
        u8.set(chunk, ptr)
        read += got
        break if got < size
      end
      put32(n_ptr, read)
      SUCCESS
    end

    def fd_pread(fd, iovs, count, offset, n_ptr)
      handle = @handles[fd]
      return EBADF unless handle && handle.node && !handle.node.dir?

      at = SpinelWasi.int(offset)
      read = 0
      iovecs(iovs, count).each do |ptr, size|
        upto = at + size
        upto = handle.node.size if upto > handle.node.size
        upto = at if upto < at
        chunk = handle.node.data.subarray(at, upto)
        u8.set(chunk, ptr)
        got = upto - at
        at = upto
        read += got
        break if got < size
      end
      put32(n_ptr, read)
      SUCCESS
    end

    def fd_seek(fd, offset, whence, ptr)
      handle = @handles[fd]
      return EBADF unless handle
      return ESPIPE unless handle.node

      base = if whence == 0 then 0
             elsif whence == 1 then handle.at
             else handle.node.dir? ? 0 : handle.node.size
             end
      at = base + SpinelWasi.int(offset)
      return EINVAL if at < 0

      handle.at = at
      put64(ptr, at)
      SUCCESS
    end

    def fd_tell(fd, ptr)
      handle = @handles[fd]
      return EBADF unless handle && handle.node

      put64(ptr, handle.at)
      SUCCESS
    end

    def fd_close(fd)
      @handles.delete(fd) ? SUCCESS : EBADF
    end

    def fd_sync(*) = SUCCESS

    def fd_fdstat_get(fd, ptr)
      handle = @handles[fd]
      return EBADF unless handle

      type = if handle.tty then CHARACTER_DEVICE
             elsif handle.node.dir? then DIRECTORY
             else REGULAR_FILE
             end
      view = dv
      view.setUint8(ptr, type)
      view.setUint16(ptr + 2, handle.append ? FD_APPEND : 0, true)
      # every right, base and inheriting
      view.setUint32(ptr + 8, 0xffffffff, true)
      view.setUint32(ptr + 12, 0, true)
      view.setUint32(ptr + 16, 0xffffffff, true)
      view.setUint32(ptr + 20, 0, true)
      SUCCESS
    end

    def fd_fdstat_set_flags(fd, flags)
      handle = @handles[fd]
      return EBADF unless handle

      handle.append = (flags & FD_APPEND) != 0
      SUCCESS
    end

    def fd_filestat_get(fd, ptr)
      handle = @handles[fd]
      return EBADF unless handle

      file_stat(ptr, handle.node, handle.tty)
    end

    def fd_filestat_set_size(fd, size)
      handle = @handles[fd]
      return EBADF unless handle && handle.node && !handle.node.dir?

      size = SpinelWasi.int(size)
      file = handle.node
      grow(file, size)
      file.data.fill(0, size, file.size) if size < file.size
      file.size = size
      SUCCESS
    end

    def fd_prestat_get(fd, ptr)
      return EBADF unless fd == 3

      put32(ptr, 0)
      put32(ptr + 4, 1)
      SUCCESS
    end

    def fd_prestat_dir_name(fd, ptr, _len)
      return EBADF unless fd == 3

      dv.setUint8(ptr, 47) # "/"
      SUCCESS
    end

    def fd_readdir(fd, buf, len, cookie, n_ptr)
      handle = @handles[fd]
      dir = handle && handle.dir
      return EBADF unless dir

      names = dir.entries.keys
      encoder = JS.global[:TextEncoder].new
      at = buf
      i = SpinelWasi.int(cookie)
      while i < names.length
        name = encoder.encode(names[i])
        entry = JS.global[:Uint8Array].new(24 + name[:length])
        view = JS.global[:DataView].new(entry[:buffer])
        view.setUint32(0, i + 1, true)
        view.setUint32(8, i + 1, true)
        view.setUint32(16, name[:length], true)
        view.setUint8(20, dir.entries[names[i]].dir? ? DIRECTORY : REGULAR_FILE)
        entry.set(name, 24)
        room = buf + len - at
        take = entry[:length]
        take = room if take > room
        u8.set(entry.subarray(0, take), at)
        at += take
        break if room < entry[:length]

        i += 1
      end
      put32(n_ptr, at - buf)
      SUCCESS
    end

    def fd_renumber(from, to)
      handle = @handles[from]
      return EBADF unless handle

      @handles[to] = handle
      @handles.delete(from)
      SUCCESS
    end

    def path_open(dirfd, _lookup, ptr, len, oflags, _base, _inherit, fdflags, fd_ptr)
      node, path, from = resolve(dirfd, ptr, len)
      return EBADF unless from
      return EEXIST if node && (oflags & O_EXCL) != 0 && (oflags & O_CREAT) != 0

      if node.nil?
        return ENOENT if (oflags & O_CREAT) == 0

        dir, name = @fs.parent(path, from)
        return ENOENT unless dir

        node = MemFile.new(JS.global[:Uint8Array].new(0), 0)
        dir.entries[name] = node
      end
      return ENOTDIR if (oflags & O_DIRECTORY) != 0 && !node.dir?

      if (oflags & O_TRUNC) != 0 && !node.dir?
        writable(node)
        node.size = 0
      end
      fd = @next_fd
      @next_fd += 1
      @handles[fd] = Handle.new(node: node, append: (fdflags & FD_APPEND) != 0)
      put32(fd_ptr, fd)
      SUCCESS
    end

    def path_filestat_get(dirfd, _flags, ptr, len, stat_ptr)
      node, _path, from = resolve(dirfd, ptr, len)
      return EBADF unless from
      return ENOENT unless node

      file_stat(stat_ptr, node, nil)
    end

    def path_create_directory(dirfd, ptr, len)
      node, path, from = resolve(dirfd, ptr, len)
      return EBADF unless from
      return EEXIST if node

      dir, name = @fs.parent(path, from)
      return ENOENT unless dir

      dir.entries[name] = MemDir.new
      SUCCESS
    end

    def path_unlink_file(dirfd, ptr, len)
      node, path, from = resolve(dirfd, ptr, len)
      return EBADF unless from
      return ENOENT unless node
      return EISDIR if node.dir?

      dir, name = @fs.parent(path, from)
      dir.entries.delete(name)
      SUCCESS
    end

    def path_remove_directory(dirfd, ptr, len)
      node, path, from = resolve(dirfd, ptr, len)
      return EBADF unless from
      return ENOENT unless node
      return ENOTDIR unless node.dir?
      return ENOTEMPTY unless node.entries.empty?

      dir, name = @fs.parent(path, from)
      dir.entries.delete(name)
      SUCCESS
    end

    def path_rename(from_fd, from_ptr, from_len, to_fd, to_ptr, to_len)
      node, path, from = resolve(from_fd, from_ptr, from_len)
      _other, to_path, to = resolve(to_fd, to_ptr, to_len)
      return EBADF unless from && to
      return ENOENT unless node

      to_dir, to_name = @fs.parent(to_path, to)
      return ENOENT unless to_dir

      from_dir, from_name = @fs.parent(path, from)
      from_dir.entries.delete(from_name)
      to_dir.entries[to_name] = node
      SUCCESS
    end

    # no links: readlink("/proc/self/exe") fails, and the compiler takes argv[0]
    def path_readlink(*) = EINVAL
  end

  # the calls the module may make, and their number of arguments
  CALLS = {
    "args_get" => 2, "args_sizes_get" => 2, "environ_get" => 2, "environ_sizes_get" => 2,
    "clock_res_get" => 2, "clock_time_get" => 3, "random_get" => 2, "proc_exit" => 1,
    "sched_yield" => 0, "poll_oneoff" => 4, "fd_write" => 4, "fd_pwrite" => 5, "fd_read" => 4,
    "fd_pread" => 5, "fd_seek" => 4, "fd_tell" => 2, "fd_close" => 1, "fd_sync" => 1,
    "fd_datasync" => 1, "fd_advise" => 4, "fd_allocate" => 3, "fd_fdstat_get" => 2,
    "fd_fdstat_set_flags" => 2, "fd_fdstat_set_rights" => 3, "fd_filestat_get" => 2,
    "fd_filestat_set_size" => 2, "fd_filestat_set_times" => 4, "fd_prestat_get" => 2,
    "fd_prestat_dir_name" => 3, "fd_readdir" => 5, "fd_renumber" => 2, "path_open" => 9,
    "path_filestat_get" => 5, "path_filestat_set_times" => 6, "path_create_directory" => 3,
    "path_unlink_file" => 3, "path_remove_directory" => 3, "path_rename" => 6,
    "path_readlink" => 6, "path_symlink" => 5, "path_link" => 7, "proc_raise" => 1,
    "sock_accept" => 3, "sock_recv" => 6, "sock_send" => 5, "sock_shutdown" => 2
  }.freeze
  # answered without a Host method: success, or not supported
  ALWAYS = {
    "fd_datasync" => SUCCESS, "fd_advise" => SUCCESS, "fd_allocate" => SUCCESS,
    "fd_fdstat_set_rights" => SUCCESS, "fd_filestat_set_times" => SUCCESS,
    "path_filestat_set_times" => SUCCESS, "path_symlink" => ENOSYS, "path_link" => ENOSYS,
    "proc_raise" => ENOSYS, "sock_accept" => ENOSYS, "sock_recv" => ENOSYS,
    "sock_send" => ENOSYS, "sock_shutdown" => ENOSYS
  }.freeze

  @current = nil
  @imports = nil

  class << self
    attr_reader :current
  end

  # a 64-bit argument arrives as a BigInt
  def self.int(value)
    value.is_a?(JS::Object) ? JS.global.Number(value) : value
  end

  # a call of the module: the current host answers it; a Ruby error in it
  # is EIO for the module and a line on the console, not a hang
  def self.dispatch(name, args)
    host = @current
    return ENOSYS unless host

    fixed = ALWAYS[name]
    return fixed unless fixed.nil?

    host.send(name, *args)
  rescue StandardError => e
    JS.global[:console].error("wasi #{name}: #{e.class}: #{e.message}")
    EIO
  end

  # the import object, made once: a callback for every call
  def self.imports
    return @imports if @imports

    wasi = JS.global[:Object].new
    CALLS.each do |name, arity|
      key = "spinelWasi_#{name}"
      SpinelWasi.register(key, name, arity)
      wasi[name] = JS.generic_callbacks[key]
    end
    @imports = JS.global[:Object].new
    @imports[:wasi_snapshot_preview1] = wasi
    @imports
  end

  # one callback per arity: a block's parameters are fixed
  def self.register(key, name, arity)
    case arity
    when 0 then JS::Object.register_callback(key) { SpinelWasi.dispatch(name, []) }
    when 1 then JS::Object.register_callback(key) { |a| SpinelWasi.dispatch(name, [a]) }
    when 2 then JS::Object.register_callback(key) { |a, b| SpinelWasi.dispatch(name, [a, b]) }
    when 3 then JS::Object.register_callback(key) { |a, b, c| SpinelWasi.dispatch(name, [a, b, c]) }
    when 4 then JS::Object.register_callback(key) { |a, b, c, d| SpinelWasi.dispatch(name, [a, b, c, d]) }
    when 5 then JS::Object.register_callback(key) { |a, b, c, d, e| SpinelWasi.dispatch(name, [a, b, c, d, e]) }
    when 6 then JS::Object.register_callback(key) { |a, b, c, d, e, f| SpinelWasi.dispatch(name, [a, b, c, d, e, f]) }
    when 7 then JS::Object.register_callback(key) { |a, b, c, d, e, f, g| SpinelWasi.dispatch(name, [a, b, c, d, e, f, g]) }
    else
      JS::Object.register_callback(key) { |a, b, c, d, e, f, g, h, i| SpinelWasi.dispatch(name, [a, b, c, d, e, f, g, h, i]) }
    end
  end

  # Runs a WASI command module (a WebAssembly.Module) to its end.
  # out/err get each write's bytes (a Uint8Array); without them the output
  # is collected and returned as text. {"code", "stdout", "stderr"}
  def self.run(wasm_module, args: [], fs: MemFS.new, stdin: nil, out: nil, err: nil)
    stdin ||= JS.global[:Uint8Array].new(0)
    collected = { 1 => [], 2 => [] }
    out ||= ->(bytes) { collected[1] << bytes }
    err ||= ->(bytes) { collected[2] << bytes }
    host = Host.new(fs, args, stdin, out, err)
    instance = JS.global[:WebAssembly][:Instance].new(wasm_module, imports)
    host.attach(instance[:exports][:memory])
    @current = host
    begin
      instance[:exports]._start
    rescue StandardError => e
      # proc_exit, then the trap after it: the end. Anything else is a crash.
      raise e unless host.exited?
    ensure
      @current = nil
    end
    { "code" => host.code, "stdout" => SpinelWasi.text(collected[1]), "stderr" => SpinelWasi.text(collected[2]) }
  end

  def self.text(chunks)
    decoder = JS.global[:TextDecoder].new
    parts = []
    chunks.each { |bytes| parts << decoder.decode(bytes) }
    parts.join
  end
end
