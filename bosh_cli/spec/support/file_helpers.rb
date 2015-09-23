require 'spec_helper'

module Support
  module FileHelpers
    def directory_listing(dir, include_dirs = false)
      Dir.chdir(dir) do
        all_files_and_dirs = Dir.glob('**/*', File::FNM_DOTMATCH).reject do |f|
          f =~ /(\/|^)\.\.?$/ # Kill . and .. directories (recursively)
        end

        if include_dirs
          all_files_and_dirs
        else
          all_files_and_dirs.reject! { |f| File.directory?(f) }
        end

        all_files_and_dirs
      end
    end

    def extract_tar_files(tarball_path)
      `tar -zxf #{tarball_path} 2>&1`
    end

    def list_tar_files(tarball_path)
      `tar -ztf #{tarball_path}`.chomp.split(/\n/).reject {|f| f =~ /\/$/ }
    end

    def file_mode(file)
      File.stat(file).mode.to_s(8)[-4..-1]
    end

    class ReleaseTarball
      attr_reader :directory

      def initialize(name)
        @name = name
        @files = []
        @directory = Dir.mktmpdir(name)
      end

      def add_file(name, content)
        @files << File.write(File.join(directory, name), content)
      end

      def build
        Dir.chdir(directory) do
          `tar zcf #{@name} *` unless @files.empty?
        end

        self
      end

      def cleanup
        file.close
        FileUtils.remove_entry directory if File.exists?(directory)
      end

      def has_file?(path)
        list.include?(path)
      end

      def file
        @file ||= begin
          if @files.empty?
            Tempfile.new(@name, directory)
          else
            File.open(File.join(directory, "#{@name}"))
          end
        end
      end

      def path
        file.path
      end

      private

      def list
        `tar -ztf #{file.path}`.chomp.split(/\n/).reject {|f| f =~ /\/$/ }
      end
    end


    class ReleaseDirectory
      attr_reader :path, :artifacts_dir, :tarballs

      def initialize
        @path = Dir.mktmpdir('bosh-release-path')
        @artifacts_dir = Dir.mktmpdir('bosh-release-artifacts-path')
        @tarballs = []
      end

      def cleanup
        FileUtils.remove_entry path if File.exists?(path)
        FileUtils.remove_entry artifacts_dir if File.exists?(artifacts_dir)
        tarballs.each do |tarball|
          tarball.cleanup
        end
      end

      def git_init
        Dir.chdir(@path) do
          `git init`
          `git add -A`
          `git commit -m 'initial commit'`
        end
      end

      def add_tarball(name, &block)
        tarball = ReleaseTarball.new(name)
        yield tarball if block_given?
        tarballs << tarball.build
        tarball
      end

      def add_dir(subdir)
        FileUtils.mkdir_p(File.join(path, subdir))
      end

      def add_file(subdir, filepath, contents = nil)
        full_path = File.join([path, subdir, filepath].compact)
        FileUtils.mkdir_p(File.dirname(full_path))

        if contents
          File.open(full_path, 'w') { |f| f.write(contents) }
        else
          FileUtils.touch(full_path)
        end

        full_path
      end

      def add_files(subdir, filepaths)
        filepaths.each { |filepath| add_file(subdir, filepath) }
      end

      def add_version(key, index_dir, payload, build)
        index_storage_path  = self.join(index_dir)
        version_index = Bosh::Cli::Versions::VersionsIndex.new(index_storage_path)
        artifacts_store = Bosh::Cli::Versions::LocalArtifactStorage.new(artifacts_dir)
        src_path = get_tmp_file_path(payload)

        build['sha1'] = Digest::SHA1.file(src_path).hexdigest
        version_index.add_version(key, build)
        artifacts_store.put_file(build['sha1'], src_path)

        build
      end

      def has_index_file?(filepath)
        File.exists?(join(filepath))
      end

      def has_artifact?(name)
        File.exists?(artifact_path(name))
      end

      def artifact_path(name)
        File.join(artifacts_dir, name)
      end

      def join(*args)
        File.join(*([path] + args))
      end

      def remove_dir(subdir)
        FileUtils.rm_rf(File.join(path, subdir))
      end

      def remove_file(subdir, filepath)
        FileUtils.rm(File.join(path, [subdir, filepath].compact))
      end

      def remove_files(subdir, filepaths)
        filepaths.each { |filepath| remove_file(subdir, filepath) }
      end
    end
  end
end

RSpec.configure do |config|
  config.include(Support::FileHelpers)
end
