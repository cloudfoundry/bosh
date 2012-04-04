# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Agent
  class FileAggregator

    class Error < StandardError; end
    class DirectoryNotFound < Error; end
    class PackagingError < Error; end

    attr_accessor :matcher

    def initialize
      @used_dirs = []
    end

    # Generates a tarball including all the requested entries
    # @return tarball path
    def generate_tarball
      # TODO: check if space left?
      tmpdir = Dir.mktmpdir
      out_dir = Dir.mktmpdir
      @used_dirs << out_dir

      copy_files(tmpdir)
      tarball_path = File.join(out_dir, "files.tgz")

      Dir.chdir(tmpdir) do
        tar_out = `tar -czf #{tarball_path} . 2>&1`
        raise PackagingError, "Cannot create tarball: #{tar_out}" unless $?.exitstatus == 0
      end

      tarball_path
    ensure
      FileUtils.rm_rf(tmpdir) if tmpdir && File.directory?(tmpdir)
    end

    def cleanup
      @used_dirs.each do |dir|
        FileUtils.rm_rf(dir) if File.directory?(dir)
      end
    end

    def copy_files(dst_directory)
      raise Error, "no matcher provided" unless @matcher

      unless File.directory?(@matcher.base_dir)
        raise DirectoryNotFound, "Base directory #{@matcher.base_dir} not found"
      end

      copied = 0
      base_dir = realpath(@matcher.base_dir)

      Dir.chdir(base_dir) do
        @matcher.globs.each do |glob|
          Dir[glob].each do |file|
            path = File.expand_path(file)

            next unless File.file?(file)
            next unless path[0..base_dir.length-1] == base_dir

            dst_filename = File.join(dst_directory, path[base_dir.length..-1])
            FileUtils.mkdir_p(File.dirname(dst_filename))
            FileUtils.cp(realpath(path), dst_filename, :preserve => true)
            copied += 1
          end
        end
      end

      copied
    end

    private

    def realpath(path)
      Pathname.new(path).realpath.to_s
    end

  end
end
