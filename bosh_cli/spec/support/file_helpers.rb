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
      end
    end

    def list_tar_files(tarball_path)
      `tar -ztf #{tarball_path}`.chomp.split(/\n/).reject {|f| f =~ /\/$/ }
    end

    class ReleaseDirectory
      attr_reader :path, :artifacts_dir

      def initialize
        @path = Dir.mktmpdir('bosh-release-path')
        @artifacts_dir = Dir.mktmpdir('bosh-release-artifacts-path')
      end

      def cleanup
        FileUtils.remove_entry path if File.exists?(path)
        FileUtils.remove_entry artifacts_dir if File.exists?(artifacts_dir)
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
