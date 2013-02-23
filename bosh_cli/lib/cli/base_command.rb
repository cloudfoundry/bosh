# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Cli
  module Command
    class Base
      extend Bosh::Cli::CommandDiscovery

      attr_reader :options
      attr_reader :work_dir
      attr_reader :runner

      attr_accessor :out

      # @return [Array] Arguments passed to command handler
      attr_accessor :args

      DEFAULT_DIRECTOR_PORT = 25555

      # @param [Bosh::Cli::Runner] runner
      def initialize(runner = nil)
        @runner = runner
        @options = {}
        @work_dir = Dir.pwd
        @exit_code = 0
        @out = nil
        @args = []
      end

      # @return [Bosh::Cli::Cache] Current CLI cache
      def cache
        Config.cache
      end

      # @return [Bosh::Cli::Config] Current configuration
      def config
        @config ||= begin
          config_file = options[:config] || Bosh::Cli::DEFAULT_CONFIG_PATH
          Bosh::Cli::Config.new(config_file)
        end
      end

      def add_option(name, value)
        @options[name] = value
      end

      def remove_option(name)
        @options.delete(name)
      end

      def director
        @director ||= Bosh::Cli::Director.new(
            target, username, password, @options.select { |k, _| k == :no_track })
      end

      def release
        return @release if @release
        check_if_release_dir
        @release = Bosh::Cli::Release.new(@work_dir)
      end

      def blob_manager
        @blob_manager ||= Bosh::Cli::BlobManager.new(release)
      end

      def blobstore
        release.blobstore
      end

      def logged_in?
        username && password
      end

      def non_interactive?
        options[:non_interactive]
      end

      def interactive?
        !non_interactive?
      end

      def verbose?
        @options[:verbose]
      end

      def redirect(*args)
        Bosh::Cli::Runner.new(args, @options).run
      end

      def confirmed?(question = "Are you sure?")
        return true if non_interactive?
        ask("#{question} (type 'yes' to continue): ") == "yes"
      end

      # @return [String] Target director URL
      def target
        raw_url = options[:target] || config.target
        url = config.resolve_alias(:target, raw_url) || raw_url
        url ? normalize_url(url) : nil
      end
      alias_method :target_url, :target

      # @return [String] Deployment manifest path
      def deployment
        options[:deployment] || config.deployment
      end

      # @return [String] Director username
      def username
        options[:username] || ENV["BOSH_USER"] || config.username(target)
      end

      # @return [String] Director password
      def password
        options[:password] || ENV["BOSH_PASSWORD"] || config.password(target)
      end

      def target_name
        config.target_name || target_url
      end

      # Sets or returns command exit code
      # @param [optional,Integer] code If param is given, sets exit code. If
      #   it's nil, returns previously set exit_code
      def exit_code(code = nil)
        if code
          @exit_code = code
        else
          @exit_code
        end
      end

      # Prints director task completion report. Note that event log usually
      # contains pretty detailed error report and other UI niceties, so most
      # of the time this could just do nothing
      # @param [Symbol] status Task status
      # @param [#to_s] task_id Task ID
      def task_report(status, task_id, success_msg = nil, error_msg = nil)
        case status
          when :non_trackable
            report = "Can't track director task".red
          when :track_timeout
            report = "Task tracking timeout".red
          when :running
            report = "Task #{task_id.yellow} running"
          when :error
            report = error_msg
          when :done
            report = success_msg
          else
            report = nil
        end

        unless [:running, :done].include?(status)
          exit_code(1)
        end

        say("\n#{report}") if report
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
        show_deployment
      end

      def show_deployment
        say("Current deployment is #{deployment.green}")
      end

      def no_track_unsupported
        if @options.delete(:no_track)
          say("Ignoring `" + "--no-track".yellow + "' option")
        end
      end

      def check_if_release_dir
        unless in_release_dir?
          err("Sorry, your current directory doesn't look like release directory")
        end
      end

      def raise_dirty_state_error
        say("\n%s\n" % [`git status`])
        err("Your current directory has some local modifications, " +
                "please discard or commit them first.\n\n" +
                "Use the --force option to skip this check.")
      end

      def in_release_dir?
        File.directory?("packages") &&
            File.directory?("jobs") &&
            File.directory?("src")
      end

      def dirty_state?
        `which git`
        return false unless $? == 0
        File.directory?(".git") && `git status --porcelain | wc -l`.to_i > 0
      end

      def normalize_url(url)
        had_port = url.to_s =~ /:\d+$/
        url = "http://#{url}" unless url.match(/^https?/)
        uri = URI.parse(url)
        uri.port = DEFAULT_DIRECTOR_PORT unless had_port
        uri.to_s.strip.gsub(/\/$/, "")
      end

    end
  end
end
