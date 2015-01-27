require 'spec_helper'

module Support
  module FileHelpers
    def directory_listing(dir, include_dirs = false)
      Dir.chdir(dir) do
        all_files_and_dirs = Dir['**/*']

        if include_dirs
          all_files_and_dirs
        else
          all_files_and_dirs.reject! { |f| File.directory?(f) }
        end
      end
    end

    class ReleaseDirectory
      attr_reader :path

      def initialize
        @path = Dir.mktmpdir
      end

      def cleanup
        FileUtils.remove_entry path if File.exists?(path)
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

      def add_version(key, storage_dir, payload, build)
        storage_path  = self.join(storage_dir)
        version_index = Bosh::Cli::Versions::VersionsIndex.new(storage_path)
        version_store = Bosh::Cli::Versions::LocalVersionStorage.new(storage_path)
        src_path = get_tmp_file_path(payload)

        version_index.add_version(key, build)
        file = version_store.put_file(key, src_path)

        build['sha1'] = Digest::SHA1.file(file).hexdigest
        version_index.update_version(key, build)
      end

      def has_file?(filepath)
        File.exists?(join(filepath))
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
