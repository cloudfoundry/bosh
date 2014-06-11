module FakeFS
  module FileUtils
    extend self

    def mkdir_p(list, options = {})
      list = [ list ] unless list.is_a?(Array)
      list.each do |path|
        FileSystem.add(path, FakeDir.new)
      end
    end
    alias_method :mkpath, :mkdir_p
    alias_method :makedirs, :mkdir_p

    def mkdir(list, ignored_options={})
      list = [ list ] unless list.is_a?(Array)
      list.each do |path|
        parent = path.split('/')
        parent.pop
        raise Errno::ENOENT, path unless parent.join == "" || parent.join == "." || FileSystem.find(parent.join('/'))
        raise Errno::EEXIST, path if FileSystem.find(path)
        FileSystem.add(path, FakeDir.new)
      end
    end

    def rmdir(list, options = {})
      list = [ list ] unless list.is_a?(Array)
      list.each do |l|
        parent = l.split('/')
        parent.pop
        raise Errno::ENOENT, l unless parent.join == "" || FileSystem.find(parent.join('/'))
        raise Errno::ENOENT, l unless FileSystem.find(l)
        raise Errno::ENOTEMPTY, l unless FileSystem.find(l).empty?
        rm(l)
      end
    end

    def rm(list, options = {})
      Array(list).each do |path|
        FileSystem.delete(path) or (!options[:force] && raise(Errno::ENOENT.new(path)))
      end
    end

    alias_method :rm_rf, :rm
    alias_method :rm_r, :rm
    alias_method :rm_f, :rm
    alias_method :remove, :rm
    alias_method :rmtree, :rm_rf
    alias_method :safe_unlink, :rm_f
    alias_method :remove_entry_secure, :rm_rf

    def ln_s(target, path, options = {})
      options = { :force => false }.merge(options)
      (FileSystem.find(path) && !options[:force]) ?
        raise(Errno::EEXIST, path) :
        FileSystem.delete(path)

      if !options[:force] && !Dir.exists?(File.dirname(path))
        raise Errno::ENOENT, path
      end

      FileSystem.add(path, FakeSymlink.new(target))
    end

    def ln_sf(target, path)
      ln_s(target, path, { :force => true })
    end

    alias_method :symlink, :ln_s

    def cp(src, dest, options={})
      if src.is_a?(Array) && !File.directory?(dest)
        raise Errno::ENOTDIR, dest
      end

      # handle `verbose' flag
      RealFileUtils.cp src, dest, options.merge(:noop => true)

      # handle `noop' flag
      return if options[:noop]

      Array(src).each do |src|
        dst_file = FileSystem.find(dest)
        src_file = FileSystem.find(src)

        if !src_file
          raise Errno::ENOENT, src
        end

        if File.directory? src_file
          raise Errno::EISDIR, src
        end

        if dst_file && File.directory?(dst_file)
          FileSystem.add(File.join(dest, File.basename(src)), src_file.entry.clone(dst_file))
        else
          FileSystem.delete(dest)
          FileSystem.add(dest, src_file.entry.clone)
        end
      end

      return nil
    end

    alias_method :copy, :cp

    def copy_file(src, dest, preserve = false, dereference = true)
      # Not a perfect match, but similar to what regular FileUtils does.
      cp(src, dest)
    end

    def cp_r(src, dest, options={})
      # handle `verbose' flag
      RealFileUtils.cp_r src, dest, options.merge(:noop => true)

      # handle `noop' flag
      return if options[:noop]

      Array(src).each do |src|
        # This error sucks, but it conforms to the original Ruby
        # method.
        raise "unknown file type: #{src}" unless dir = FileSystem.find(src)

        new_dir = FileSystem.find(dest)

        if new_dir && !File.directory?(dest)
          raise Errno::EEXIST, dest
        end

        if !new_dir && !FileSystem.find(dest+'/../')
          raise Errno::ENOENT, dest
        end

        # This last bit is a total abuse and should be thought hard
        # about and cleaned up.
        if new_dir
          if src[-2..-1] == '/.'
            dir.entries.each{|f| new_dir[f.name] = f.clone(new_dir) }
          else
            new_dir[dir.name] = dir.entry.clone(new_dir)
          end
        else
          FileSystem.add(dest, dir.entry.clone)
        end
      end

      return nil
    end

    def mv(src, dest, options={})
      # handle `verbose' flag
      RealFileUtils.mv src, dest, options.merge(:noop => true)

      # handle `noop' flag
      return if options[:noop]

      Array(src).each do |path|
        if target = FileSystem.find(path)
          dest_path = File.directory?(dest) ? File.join(dest, File.basename(path)) : dest
          if File.directory?(dest_path)
            raise Errno::EEXIST, dest_path unless options[:force]
          elsif File.directory?(File.dirname(dest_path))
            FileSystem.delete(dest_path)
            FileSystem.add(dest_path, target.entry.clone)
            FileSystem.delete(path)
          else
            raise Errno::ENOENT, dest_path unless options[:force]
          end
        else
          raise Errno::ENOENT, path
        end
      end

      return nil
    end

    alias_method :move, :mv

    def chown(user, group, list, options={})
      list = Array(list)
      list.each do |f|
        if File.exists?(f)
          uid = if user
                  user.to_s.match(/[0-9]+/) ? user.to_i : Etc.getpwnam(user).uid
                else
                  nil
                end
          gid = if group
                  group.to_s.match(/[0-9]+/) ? group.to_i : Etc.getgrnam(group).gid
                else
                  nil
                end
          File.chown(uid, gid, f)
        else
          raise Errno::ENOENT, f
        end
      end
      list
    end

    def chown_R(user, group, list, options={})
      list = Array(list)
      list.each do |file|
        chown(user, group, file)
        [FileSystem.find("#{file}/**/**")].flatten.each do |f|
          chown(user, group, f.to_s)
        end
      end
      list
    end

    def chmod(mode, list, options={})
      list = Array(list)
      list.each do |f|
        if File.exists?(f)
          File.chmod(mode, f)
        else
          raise Errno::ENOENT, f
        end
      end
      list
    end

    def chmod_R(mode, list, options={})
      list = Array(list)
      list.each do |file|
        chmod(mode, file)
        [FileSystem.find("#{file}/**/**")].flatten.each do |f|
          chmod(mode, f.to_s)
        end
      end
      list
    end

    def touch(list, options={})
      Array(list).each do |f|
        if fs = FileSystem.find(f)
          now = Time.now
          fs.mtime = options[:mtime] || now
          fs.atime = now
        else
          file = File.open(f, 'w')
          file.close

          if mtime = options[:mtime]
            fs = FileSystem.find(f)
            fs.mtime = mtime
          end
        end
      end
    end

    def cd(dir, &block)
      FileSystem.chdir(dir, &block)
    end
    alias_method :chdir, :cd

    def compare_file(file1, file2)
      # we do a strict comparison of both files content
      File.readlines(file1) == File.readlines(file2)
    end
    alias_method :cmp, :compare_file
    alias_method :identical?, :compare_file
  end
end
