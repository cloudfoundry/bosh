require 'spec_helper'

module Support
  module FileHelpers
    class << self
      def included(base)
        base.send(:extend, ClassMethods)
        base.send(:include, InstanceMethods)
      end
    end

    module ClassMethods

    end

    # NOTE: Implies existence of `@release_dir`, which at the moment is created
    # in the `before` blocks within relevant specs. This instance is not being
    # cleaned up, and the whole thing should move to some sort of wrapper.
    module InstanceMethods
      def add_file(dir, path, contents = nil)
        full_path = File.join([@release_dir, dir, path].compact)
        FileUtils.mkdir_p(File.dirname(full_path))

        if contents
          File.open(full_path, 'w') { |f| f.write(contents) }
        else
          FileUtils.touch(full_path)
        end
      end

      def add_files(dir, names)
        names.each { |name| add_file(dir, name) }
      end

      # NOTE: Does this imply a different name for this set of helpers?
      def add_version(index, storage, key, build, src_file_path)
        index.add_version(key, build)
        file_path = storage.put_file(key, src_file_path)
        build['sha1'] = Digest::SHA1.file(file_path).hexdigest
        index.update_version(key, build)
      end

      def remove_file(dir, path)
        FileUtils.rm(File.join(@release_dir, dir, path))
      end

      def remove_files(dir, names)
        names.each { |name| remove_file(dir, name) }
      end
    end
  end
end

RSpec.configure do |config|
  config.include(Support::FileHelpers)
end
