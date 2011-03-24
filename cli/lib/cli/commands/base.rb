require "yaml"
require "terminal-table/import"

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
      end

      def director
        @director ||= Bosh::Cli::Director.new(target, username, password)
      end

      def logged_in?
        username && password
      end

      def non_interactive?
        !interactive?
      end

      def interactive?
        !options[:non_interactive]
      end

      def verbose?
        options[:verbose]
      end

      # TODO: implement it
      def dry_run?
        options[:dry_run]
      end

      def run(namespace, action, *args)
        eval(namespace.to_s.capitalize).new(options).send(action.to_sym, *args)
      end

      def redirect(*args)
        run(*args)
        raise Bosh::Cli::GracefulExit, "redirected to %s" % [ args.join(" ") ]
      end

      [:username, :password, :target, :deployment].each do |attr_name|
        define_method attr_name do
          config.send(attr_name)
        end
      end

      alias_method :target_url, :target

      def target_name
        config.target_name || target_url
      end

      def full_target_name
        target_name.blank? || target_name == target_url ? target_name : "%s (%s)" % [ target_name, target_url ]
      end

      protected

      def auth_required
        target_required
        err("Please log in first") unless logged_in?
      end

      def target_required
        err("Please choose target first") if target.nil?
      end

      def check_if_release_dir
        if !in_release_dir?
          err "Sorry, your current directory doesn't look like release directory"
        end
      end

      def check_if_dirty_state
        if dirty_state?
          say "\n%s\n" % [ `git status` ]
          err "Your current directory has some local modifications, please discard or commit them first"
        end
      end

      def in_release_dir?
        File.directory?("packages") && File.directory?("jobs") && File.directory?("src")
      end

      def dirty_state?
        `which git`
        return false unless $? == 0
        File.directory?(".git") && `git status --porcelain | wc -l`.to_i > 0
      end

      def init_blobstore(options)
        bs_options = {
          :access_key_id     => options["access_key_id"].to_s,
          :secret_access_key => options["secret_access_key"].to_s,
          :encryption_key    => options["encryption_key"].to_s,
          :bucket_name       => options["bucket_name"].to_s
        }

        Bosh::Blobstore::Client.create("s3", bs_options)
      rescue Bosh::Blobstore::BlobstoreError => e
        err "Cannot init blobstore: #{e}"
      end

      def normalize_url(url)
        url = "http://#{url}" unless url.match(/^https?/)
        URI.parse(url).to_s
      end

    end
  end
end
