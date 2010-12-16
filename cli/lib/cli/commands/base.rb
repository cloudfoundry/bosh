module Bosh::Cli
  module Command
    class Base

      DEFAULT_CONFIG_PATH = File.expand_path("~/.bosh_config")
      DEFAULT_CACHE_DIR   = File.expand_path("~/.bosh_cache")

      attr_reader   :cache, :config, :options, :work_dir
      attr_accessor :out

      def initialize(options = {})
        @options     = options.dup
        @work_dir    = Dir.pwd
        @config      = Config.new(@options[:config] || DEFAULT_CONFIG_PATH)
        @cache       = Cache.new(@options[:cache_dir] || DEFAULT_CACHE_DIR)
        @out         = out
      end

      def director
        @director ||= Bosh::Cli::Director.new(target, username, password)
      end

      def logged_in?
        username && password
      end

      def verbose?
        options[:verbose]
      end

      # TODO: implement it
      def dry_run?
        options[:dry_run]
      end

      private

      [:username, :password, :target, :deployment].each do |attr_name|
        define_method attr_name do
          config.send(attr_name)
        end
      end

    end
  end
end
