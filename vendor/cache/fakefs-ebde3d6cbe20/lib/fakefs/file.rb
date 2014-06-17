require 'stringio'

module FakeFS
  class File < StringIO
    MODES = [
      READ_ONLY           = "r",
      READ_WRITE          = "r+",
      WRITE_ONLY          = "w",
      READ_WRITE_TRUNCATE = "w+",
      APPEND_WRITE_ONLY   = "a",
      APPEND_READ_WRITE   = "a+"
    ]

    FILE_CREATION_MODES = MODES - [READ_ONLY, READ_WRITE]

    MODE_BITMASK = RealFile::RDONLY   |
                   RealFile::WRONLY   |
                   RealFile::RDWR     |
                   RealFile::APPEND   |
                   RealFile::CREAT    |
                   RealFile::EXCL     |
                   RealFile::NONBLOCK |
                   RealFile::TRUNC    |
                   (RealFile.const_defined?(:NOCTTY) ? RealFile::NOCTTY : 0)   |
                   (RealFile.const_defined?(:SYNC) ? RealFile::SYNC : 0)

    FILE_CREATION_BITMASK = RealFile::CREAT

    def self.extname(path)
      RealFile.extname(path)
    end

    def self.join(*parts)
      RealFile.join(parts)
    end

    def self.exist?(path)
      if(File.symlink?(path)) then
        referent = File.expand_path(File.readlink(path), File.dirname(path))
        exist?(referent)
      else
        !!FileSystem.find(path)
      end
    end

    class << self
      alias_method :exists?, :exist?

      # Assuming that everyone can read and write files
      alias_method :readable?, :exist?
      alias_method :writable?, :exist?
    end

    def self.mtime(path)
      if exists?(path)
        FileSystem.find(path).mtime
      else
        raise Errno::ENOENT
      end
    end

    def self.ctime(path)
      if exists?(path)
        FileSystem.find(path).ctime
      else
        raise Errno::ENOENT
      end
    end

    def self.atime(path)
      if exists?(path)
        FileSystem.find(path).atime
      else
        raise Errno::ENOENT
      end
    end

    def self.utime(atime, mtime, *paths)
      paths.each do |path|
        if exists?(path)
          FileSystem.find(path).atime = atime
          FileSystem.find(path).mtime = mtime
        else
          raise Errno::ENOENT
        end
      end

      paths.size
    end

    def self.size(path)
      read(path).bytesize
    end

    def self.size?(path)
      if exists?(path) && !size(path).zero?
        size(path)
      else
        nil
      end
    end

    def self.zero?(path)
      exists?(path) && size(path) == 0
    end

    def self.const_missing(name)
      RealFile.const_get(name)
    end

    def self.directory?(path)
      if path.respond_to? :entry
        path.entry.is_a? FakeDir
      else
        result = FileSystem.find(path)
        result ? result.entry.is_a?(FakeDir) : false
      end
    end

    def self.symlink?(path)
      if path.respond_to? :entry
        path.is_a? FakeSymlink
      else
        FileSystem.find(path).is_a? FakeSymlink
      end
    end

    def self.file?(path)
      if path.respond_to? :entry
        path.entry.is_a? FakeFile
      else
        result = FileSystem.find(path)
        result ? result.entry.is_a?(FakeFile) : false
      end
    end

    def self.expand_path(file_name, dir_string=FileSystem.current_dir.to_s)
      dir_string = FileSystem.find(dir_string).to_s
      RealFile.expand_path(file_name, dir_string)
    end

    def self.basename(*args)
      RealFile.basename(*args)
    end

    def self.dirname(path)
      RealFile.dirname(path)
    end

    def self.readlink(path)
      symlink = FileSystem.find(path)
      symlink.target
    end

    def self.read(path, *args)
      file = new(path)

      raise Errno::ENOENT if !file.exists?
      raise Errno::EISDIR, path if directory?(path)

      FileSystem.find(path).atime = Time.now
      file.read
    end

    def self.readlines(path)
      file = new(path)
      if file.exists?
        FileSystem.find(path).atime = Time.now
        file.readlines
      else
        raise Errno::ENOENT
      end
    end

    def self.rename(source, dest)
      if directory?(source) && file?(dest)
        raise Errno::ENOTDIR, "#{source} or #{dest}"
      elsif file?(source) && directory?(dest)
        raise Errno::EISDIR, "#{source} or #{dest}"
      end

      if target = FileSystem.find(source)
        FileSystem.add(dest, target.entry.clone)
        FileSystem.delete(source)
      else
        raise Errno::ENOENT, "#{source} or #{dest}"
      end

      0
    end

    def self.link(source, dest)
      if directory?(source)
        raise Errno::EPERM, "#{source} or #{dest}"
      end

      if !exists?(source)
        raise Errno::ENOENT, "#{source} or #{dest}"
      end

      if exists?(dest)
        raise Errno::EEXIST, "#{source} or #{dest}"
      end

      source = FileSystem.find(source)
      dest = FileSystem.add(dest, source.entry.clone)
      source.link(dest)

      0
    end

    def self.delete(file_name, *additional_file_names)
      if !exists?(file_name)
        raise Errno::ENOENT, file_name
      end

      FileUtils.rm(file_name)

      additional_file_names.each do |file_name|
        FileUtils.rm(file_name)
      end

      additional_file_names.size + 1
    end

    class << self
      alias_method :unlink, :delete
    end

    def self.symlink(source, dest)
      FileUtils.ln_s(source, dest)
    end

    def self.stat(file)
      File::Stat.new(file)
    end

    def self.lstat(file)
      File::Stat.new(file, true)
    end

    def self.split(path)
      return RealFile.split(path)
    end

    def self.chmod(mode_int, filename)
      FileSystem.find(filename).mode = 0100000 + mode_int
    end

    # Not exactly right, returns true if the file is chmod +x for owner. In the
    # context of when you would use fakefs, this is usually what you want.
    def self.executable?(filename)
      file = FileSystem.find(filename)
      return false unless file
      (file.mode - 0100000) & 0100 != 0
    end

    def self.chown(owner_int, group_int, filename)
      file = FileSystem.find(filename)
      if owner_int && owner_int != -1
        owner_int.is_a?(Fixnum) or raise TypeError, "can't convert String into Integer"
        file.uid = owner_int
      end
      if group_int && group_int != -1
        group_int.is_a?(Fixnum) or raise TypeError, "can't convert String into Integer"
        file.gid = group_int
      end
    end

    def self.umask(*args)
      RealFile.umask(*args)
    end

    def self.binread(file, length = nil, offset = 0)
      contents = File.read(file)

      if length
        contents.slice(offset, length)
      else
        contents
      end
    end

    class Stat
      attr_reader :ctime, :mtime, :atime, :mode, :uid, :gid

      def initialize(file, __lstat = false)
        if !File.exists?(file)
          raise Errno::ENOENT, file
        end

        @file      = file
        @fake_file = FileSystem.find(@file)
        @__lstat   = __lstat
        @ctime     = @fake_file.ctime
        @mtime     = @fake_file.mtime
        @atime     = @fake_file.atime
        @mode      = @fake_file.mode
        @uid       = @fake_file.uid
        @gid       = @fake_file.gid
      end

      def symlink?
        File.symlink?(@file)
      end

      def directory?
        File.directory?(@file)
      end

      def file?
        File.file?(@file)
      end

      def ftype
        return 'link' if symlink?
        return 'directory' if directory?
        return 'file'
      end

      # assumes, like above, that all files are readable and writable
      def readable?
        true
      end

      def writable?
        true
      end

      def nlink
        @fake_file.links.size
      end

      def size
        if @__lstat && symlink?
          @fake_file.target.size
        else
          File.size(@file)
        end
      end

      def zero?
        size == 0
      end

      include Comparable

      def <=>(other)
        @mtime <=> other.mtime
      end
    end

    attr_reader :path

    def initialize(path, mode = READ_ONLY, perm = nil)
      @path = path
      @mode = mode.is_a?(Hash) ? (mode[:mode] || READ_ONLY) : mode
      @file = FileSystem.find(path)
      @autoclose = true

      check_modes!

      file_creation_mode? ? create_missing_file : check_file_existence!

      super(@file.content, @mode)
    end

    def exists?
      true
    end

    def write(str)
      val = super(str)
      @file.mtime = Time.now
      val
    end

    alias_method :tell=,    :pos=
    alias_method :sysread,  :read
    alias_method :syswrite, :write

    undef_method :closed_read?
    undef_method :closed_write?
    undef_method :length
    undef_method :size
    undef_method :string
    undef_method :string=
    if RUBY_PLATFORM == 'java'
      undef_method :to_channel
      undef_method :to_outputstream
      undef_method :to_inputstream
    end

    def is_a?(klass)
      RealFile.allocate.is_a?(klass)
    end

    def ioctl(integer_cmd, arg)
      raise NotImplementedError
    end

    def read_nonblock(maxlen, outbuf = nil)
      raise NotImplementedError
    end

    def stat
      self.class.stat(@path)
    end

    def lstat
      self.class.lstat(@path)
    end

    def sysseek(position, whence = SEEK_SET)
      seek(position, whence)
      pos
    end

    alias_method :to_i, :fileno

    def to_io
      self
    end

    def write_nonblock(string)
      raise NotImplementedError
    end

    def readpartial(maxlen, outbuf = nil)
      raise NotImplementedError
    end

    def atime
      self.class.atime(@path)
    end

    def ctime
      self.class.ctime(@path)
    end

    def flock(locking_constant)
      raise NotImplementedError
    end

    def mtime
      self.class.mtime(@path)
    end

    def chmod(mode_int)
      @file.mode = 0100000 + mode_int
    end

    def chown(owner_int, group_int)
      if owner_int && owner_int != -1
        owner_int.is_a?(Fixnum) or raise TypeError, "can't convert String into Integer"
        @file.uid = owner_int
      end
      if group_int && group_int != -1
        group_int.is_a?(Fixnum) or raise TypeError, "can't convert String into Integer"
        @file.gid = group_int
      end
    end

    if RUBY_VERSION >= "1.9"
      def self.realpath(*args)
        RealFile.realpath(*args)
      end

      def binmode?
        raise NotImplementedError
      end

      def close_on_exec=(bool)
        raise NotImplementedError
      end

      def close_on_exec?
        raise NotImplementedError
      end

      def to_path
        @path
      end
    end

    if RUBY_VERSION >= "1.9.2"
      attr_writer :autoclose

      def autoclose?
        @autoclose
      end

      def autoclose?
        @autoclose ? true : false
      end

      def autoclose=(autoclose)
        @autoclose = autoclose
      end

      alias_method :fdatasync, :flush

      def size
        File.size(@path)
      end
    end

    if RUBY_VERSION >= "1.9.3"
      def advise(advice, offset=0, len=0)
      end

      def self.write(filename, contents, offset = nil)
        if offset
          open(filename, 'a') do |f|
            f.seek(offset)
            f.write(contents)
          end
        else
          open(filename, 'w') do |f|
            f << contents
          end
        end

        contents.length
      end
    end

    def read(length = nil, buf = "")
      read_buf = super(length, buf)
      if read_buf.respond_to?(:force_encoding) && binary_mode? #change to binary only for ruby 1.9.3
        read_buf = read_buf.force_encoding('ASCII-8BIT')
      end
      read_buf
    end

  private

    def check_modes!
      StringIO.new("", @mode)
    end

    def binary_mode?
      @mode.is_a?(String) && (@mode.include?('b') || @mode.include?('binary')) && !@mode.include?('bom')
    end

    def check_file_existence!
      raise Errno::ENOENT, @path unless @file
    end

    def file_creation_mode?
      mode_in?(FILE_CREATION_MODES) || mode_in_bitmask?(FILE_CREATION_BITMASK)
    end

    def mode_in?(list)
      list.any? { |element| @mode.include?(element) } if @mode.respond_to?(:include?)
    end

    def mode_in_bitmask?(mask)
      (@mode & mask) != 0 if @mode.is_a?(Integer)
    end

    # Create a missing file if the path is valid.
    #
    def create_missing_file
      raise Errno::EISDIR, path if File.directory?(@path)

      if !File.exists?(@path) # Unnecessary check, probably.
        dirname = RealFile.dirname @path

        unless dirname == "."
          dir = FileSystem.find dirname

          unless dir.kind_of? FakeDir
            raise Errno::ENOENT, path
          end
        end

        @file = FileSystem.add(path, FakeFile.new)
      end
    end
  end
end
