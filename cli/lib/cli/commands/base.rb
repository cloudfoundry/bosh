module Bosh::Cli
  module Command
    class Base
      attr_reader   :cache, :config, :options, :work_dir
      attr_accessor :out, :usage

      def initialize(options = {})
        @options     = options.dup
        @work_dir    = Dir.pwd
        @config      = Config.new(@options[:config] || Bosh::Cli::DEFAULT_CONFIG_PATH)
        @cache       = Cache.new(@options[:cache_dir] || Bosh::Cli::DEFAULT_CACHE_DIR)
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

      def show_usage
        say "Usage: #{@usage}" if @usage
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

      def target_version
        config.target_version ? "Ver: " + config.target_version : ""
      end

      def full_target_name
        ret = (target_name.blank? || target_name == target_url ? target_name : "%s (%s)" % [ target_name, target_url])
        ret + " %s" % target_version if ret
      end

      protected

      def auth_required
        target_required
        err("Please log in first") unless logged_in?
      end

      def target_required
        err("Please choose target first") if target.nil?
      end

      def deployment_required
        err("Please choose deployment first") if deployment.nil?
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

      def operation_confirmed?(prompt = "Are you sure? (type 'yes' to continue): ")
        non_interactive? || (ask(prompt) == "yes")
      end

      def init_blobstore(options)
        if options.nil?
          err "Failed to initialize blobstore. Try updating the release config file"
        end
        bs_options = {}
        provider = options["provider"]
        case provider
        when "s3"
          provider_options = options["s3_options"]
          bs_options = {
            :access_key_id     => provider_options["access_key_id"].to_s,
            :secret_access_key => provider_options["secret_access_key"].to_s,
            :encryption_key    => provider_options["encryption_key"].to_s,
            :bucket_name       => provider_options["bucket_name"].to_s
          }
        when "atmos"
          provider_options = options["atmos_options"]
          bs_options = {
            :url    => provider_options["url"].to_s,
            :uid    => provider_options["uid"].to_s,
            :secret => provider_options["secret"].to_s,
            :tag    => provider_options["tag"].to_s
          }
        else
          raise "Unknown provider #{provider}"
        end

        Bosh::Blobstore::Client.create(provider, bs_options)
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
