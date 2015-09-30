module Bosh::Cli
  module Command
    class Base
      extend Bosh::Cli::CommandDiscovery
      include Bosh::Cli::DeploymentHelper

      attr_accessor :options, :out, :args
      attr_reader :work_dir, :exit_code, :runner

      DEFAULT_DIRECTOR_PORT = 25555

      # @param [Bosh::Cli::Runner] runner
      def initialize(runner = nil, director = nil)
        @runner = runner
        @director = director
        @options = {}
        @work_dir = Dir.pwd
        @exit_code = 0
        @out = nil
        @args = []
      end

      # @return [Bosh::Cli::Config] Current configuration
      def config
        @config ||= begin
          # Handle the environment variable being set to the empty string.
          env_bosh_config = ENV['BOSH_CONFIG'].to_s.empty? ? nil : ENV['BOSH_CONFIG']
          config_file = options[:config] || env_bosh_config || Bosh::Cli::DEFAULT_CONFIG_PATH
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
        return @director if @director

        director_client_options = [:no_track, :ca_cert]
        @director = Bosh::Cli::Client::Director.new(
          target,
          credentials,
          @options.select { |k, _| director_client_options.include?(k) }
        )
      end

      def release
        return @release if @release
        check_if_release_dir
        @release = Bosh::Cli::Release.new(release_directory, options[:final])
      end

      def progress_renderer
        interactive? ? Bosh::Cli::InteractiveProgressRenderer.new : Bosh::Cli::NonInteractiveProgressRenderer.new
      end

      def blob_manager
        @blob_manager ||= Bosh::Cli::BlobManager.new(release, config.max_parallel_downloads, progress_renderer)
      end

      def blobstore
        release.blobstore
      end

      def logged_in?
        !!(credentials && credentials.authorization_header)
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

      def confirmed?(question = 'Are you sure?')
        return true if non_interactive?
        ask("#{question} (type 'yes' to continue): ") == 'yes'
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

      def credentials
        return @credentials if @credentials

        if auth_info.uaa?
          token_decoder = Client::Uaa::TokenDecoder.new
          uaa_token_provider = Client::Uaa::TokenProvider.new(auth_info, config, token_decoder, target)
          @credentials = Client::UaaCredentials.new(uaa_token_provider)
        elsif username && password
          @credentials = Client::BasicCredentials.new(username, password)
        end

        @credentials
      end

    def target_name
      options[:target] || config.target_name || target_url
    end

    def cache_dir
      File.join(Dir.home, '.bosh', 'cache')
    end

    def show_current_state(deployment_name=nil)
      user_desc = auth_info.client_auth? ? 'client' : 'user'
      msg = "Acting as #{user_desc} '#{credentials.username.to_s.make_green}'"
      msg += " on deployment '#{deployment_name.make_green}'" if deployment_name
      msg += " on '#{target_name.make_green}'" if target_name
      warn(msg)
    end

    protected

    def auth_info
      @auth_info ||= begin
        ca_cert = config.ca_cert(target)
        director_client = Client::Director.new(target, nil, ca_cert: ca_cert)
        Client::Uaa::AuthInfo.new(director_client, ENV, ca_cert)
      end
    end

    # @return [String] Director username
    def username
      options[:username] || ENV['BOSH_USER'] || config.username(target)
    end

    # @return [String] Director password
    def password
      options[:password] || ENV['BOSH_PASSWORD'] || config.password(target)
    end

    # Prints director task completion report. Note that event log usually
    # contains pretty detailed error report and other UI niceties, so most
    # of the time this could just do nothing
    # @param [Symbol] status Task status
    # @param [#to_s] task_id Task ID
    def task_report(status, task_id, success_msg = nil, error_msg = nil)
      case status
        when :non_trackable
          report = "Can't track director task".make_red
        when :track_timeout
          report = 'Task tracking timeout'.make_red
        when :running
          report = "Task #{task_id.make_yellow} running"
        when :error
          report = error_msg
        when :done
          report = success_msg
        else
          report = "Task exited with status #{status}"
      end

      unless [:running, :done].include?(status)
        @exit_code = 1
      end

      say("\n#{report}") if report
      say("\nFor a more detailed error report, run: bosh task #{task_id} --debug") if status == :error
    end

    def auth_required
      target_required
      err('Please log in first') unless logged_in?
    end

    def target_required
      err('Please choose target first') if target.nil?
    end

    def deployment_required
      err('Please choose deployment first') if deployment.nil?
    end

    def show_deployment
      say("Current deployment is #{deployment.make_green}")
    end

    def no_track_unsupported
      if @options.delete(:no_track)
        say('Ignoring `' + '--no-track'.make_yellow + "' option")
      end
    end

    def switch_to_release_dir
      Dir.chdir(release_directory)
    end

    def check_if_release_dir
      unless in_release_dir?
        err("Sorry, your current directory doesn't look like release directory")
      end
    end

    def raise_dirty_state_error
      say("\n%s\n" % [`git status`])
      err('Your current directory has some local modifications, ' +
          "please discard or commit them first.\n\n" +
          'Use the --force option to skip this check.')
    end

    def release_directory
      return @release_directory if @release_directory

      if options[:dir]
        @release_directory = File.expand_path(options[:dir])
      else
        @release_directory = @work_dir
      end

      @release_directory
    end

    def in_release_dir?
      File.directory?(File.join(release_directory, 'packages')) &&
        File.directory?(File.join(release_directory, 'jobs')) &&
        File.directory?(File.join(release_directory, 'src'))
    end

    def dirty_state?
      git_status = `git status 2>&1`
      case $?.exitstatus
        when 128 # Not in a git repo
          false
        when 127 # git command not found
          false
        else
          !git_status.lines.to_a.last.include?('nothing to commit')
      end
    end

    def valid_index_for(manifest_hash, job, index, options = {})
      index = '0' if job_unique_in_deployment?(manifest_hash, job)
      err('You should specify the job index. There is more than one instance of this job type.') if index.nil?
      index = index.to_i if options[:integer_index]
      index
    end

    def normalize_url(url)
      url = url.gsub(/\/$/, '')
      url = "https://#{url}" unless url.match(/^http:?/)
      uri = URI.parse(url)

      if port = url.match(/:(\d+)$/)
        port_number = port.captures[0].to_i
        if port_number == URI::HTTPS::DEFAULT_PORT
          uri.to_s + ":#{URI::HTTPS::DEFAULT_PORT}"
        else
          uri.port = port_number
          uri.to_s
        end
      else
        uri.port = DEFAULT_DIRECTOR_PORT
        uri.to_s
      end
    end
  end
end
end
