require 'spec_helper'

module Support
  module FileHelpers
    class << self
      def included(base)
        base.let(:spec_package) { SpecPackage.new }
      end
    end

    class SpecPackage < String
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

      def add_version(index, storage, key, build, src_file_path)
        index.add_version(key, build)
        file_path = storage.put_file(key, src_file_path)
        build['sha1'] = Digest::SHA1.file(file_path).hexdigest
        index.update_version(key, build)
      end

      def remove_dir(path)
        FileUtils.rm_rf(File.join(self.to_s, path))
      end

      def remove_file(dir, path)
        FileUtils.rm(File.join(self.to_s, dir, path))
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
