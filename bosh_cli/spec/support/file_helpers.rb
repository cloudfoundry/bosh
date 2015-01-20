require 'spec_helper'

module Support
  module FileHelpers
    class << self
      def included(base)
        base.let(:release_dir) { ReleaseDirectory.new }
      end
    end

    class ReleaseDirectory < String
      def initialize(s = nil)
        super File.join([Dir.mktmpdir, s].compact)
      end

      def add_dir(path)
        FileUtils.mkdir_p(File.join(self.to_s, path))
      end

      def add_file(dir, path, contents = nil)
        full_path = File.join([self.to_s, dir, path].compact)
        FileUtils.mkdir_p(File.dirname(full_path))

        if contents
          File.open(full_path, 'w') { |f| f.write(contents) }
        else
          FileUtils.touch(full_path)
        end
      end

      def add_files(dir, paths)
        paths.each { |path| add_file(dir, path) }
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

      def join(*args)
        File.join(*([self.to_s] + args))
      end

      def remove_dir(path)
        FileUtils.rm_rf(File.join(self.to_s, path))
      end

      def remove_file(dir, path)
        FileUtils.rm(File.join(self.to_s, [dir, path].compact))
      end

      def remove_files(dir, paths)
        paths.each { |path| remove_file(dir, path) }
      end
    end
  end
end

RSpec.configure do |config|
  config.include(Support::FileHelpers)
end
