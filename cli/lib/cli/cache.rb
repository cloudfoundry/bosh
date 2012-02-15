# Copyright (c) 2009-2012 VMware, Inc.

module Bosh
  module Cli

    class Cache

      attr_reader :cache_dir

      def initialize(cache_dir = nil)
        @cache_dir = cache_dir || Bosh::Cli::DEFAULT_CACHE_DIR

        if File.exists?(@cache_dir) && !File.directory?(@cache_dir)
          raise CacheDirectoryError, "Bosh cache directory error: '#{@cache_dir}' is a file, not directory"
        end

        unless File.exists?(@cache_dir)
          FileUtils.mkdir_p(@cache_dir)
          File.chmod(0700, @cache_dir)
        end
      end

      def read(key)
        cached_file = path(key)
        return nil unless File.exists?(cached_file)
        File.read(cached_file)
      end

      def write(key, value)
        File.open(path(key), "w") do |f|
          f.write(value)
        end
      end

      private

      def path(key)
        File.expand_path(hash_for(key), @cache_dir)
      end

      def hash_for(key)
        Digest::SHA1.hexdigest(key)
      end

    end

  end
end
