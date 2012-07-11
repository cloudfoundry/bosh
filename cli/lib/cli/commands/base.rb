# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Cli
  module Command
    class Base
      BLOBS_DIR = "blobs"
      BLOBS_INDEX_FILE = "blob_index.yml"

      attr_reader :cache, :config, :options, :work_dir
      attr_accessor :out, :usage

      def initialize(options = {})
        @options = options.dup
        @work_dir = Dir.pwd
        config_file = @options[:config] || Bosh::Cli::DEFAULT_CONFIG_PATH
        @config = Config.new(config_file)
        @cache = Config.cache
        @exit_code = 0
      end

      class << self
        attr_reader :commands

        def command(name, &block)
          @commands ||= {}
          @commands[name] = block
        end
      end

      def director
        @director ||= Bosh::Cli::Director.new(target, username, password)
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
        say("Usage: #{@usage}") if @usage
      end

      def run(namespace, action, *args)
        eval(namespace.to_s.capitalize).new(options).send(action.to_sym, *args)
      end

      def redirect(*args)
        run(*args)
        raise Bosh::Cli::GracefulExit, "redirected to %s" % [args.join(" ")]
      end

      def confirmed?(question = "Are you sure?")
        non_interactive? ||
            ask("#{question} (type 'yes' to continue): ") == "yes"
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
        # TODO refactor this method
        ret = (target_name.blank? || target_name == target_url ?
            target_name : "%s (%s)" % [target_name, target_url])
        ret + " %s" % target_version if ret
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
      def task_report(status, success_msg = nil, error_msg = nil)
        case status
          when :non_trackable
            report = "Can't track director task".red
          when :track_timeout
            report = "Task tracking timeout".red
          when :error
            report = "#{error_msg}".red
          when :failed
            report = "#{error_msg}".red
          when :notfound
            report = "#{error_msg}".red
          when :done
            report = success_msg
          else
            report = nil
        end

        if status != :done
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
      end

      def check_if_release_dir
        unless in_release_dir?
          err("Sorry, your current directory doesn't look " +
              "like release directory")
        end
      end

      def check_if_dirty_state
        if dirty_state?
          say("\n%s\n" % [`git status`])
          err("Your current directory has some local modifications, " +
              "please discard or commit them first")
        end
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
        url = "http://#{url}" unless url.match(/^https?/)
        URI.parse(url).to_s
      end

    end
  end
end
