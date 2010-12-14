require "yaml"

module Bosh
  module Cli

    class Runner

      DEFAULT_CONFIG_PATH = File.expand_path("~/.bosh_config")

      def self.run(cmd, *args)
        new(cmd, *args).run
      end

      def initialize(cmd, options, *args)
        @options = options || {}

        @cmd         = cmd
        @args        = args
        @work_dir    = Dir.pwd
        @config_path = @options[:config] || DEFAULT_CONFIG_PATH
        @cache       = Cache.new(@options[:cache_dir])
      end

      def run
        method   = find_cmd_implementation
        expected = method.arity

        if expected >= 0 && @args.size != expected
          raise ArgumentError, "wrong number of arguments for #{self.class.name}##{method.name} (#{@args.size} for #{expected})"
        end

        method.call(*@args)
      rescue AuthError
        bosh_say("Director auth error")
      rescue CliError => e
        bosh_say("Error #{e.error_code}: #{e.message}")
      end

      def cmd_status
        say("Target:     %s" % [ config['target'] || "not set" ])
        say("User:       %s" % [ logged_in? && saved_credentials["username"] || "not set" ])
        say("Deployment: %s" % [ config['deployment'] || "not set" ])
      end

      def cmd_set_target(name)
        client = api_client(name)

        if @options[:director_checks] && !client.can_access_director?
          say("Cannot talk to director at '#{name}', please set correct target")
          return
        end

        config["target"] = name

        if config['deployment']
          deployment = Deployment.new(@work_dir, config['deployment'])
          if !deployment.manifest_exists? || deployment.target != name
            say("WARNING! Your deployment has been unset")
            config['deployment'] = nil
          end
        end
        
        save_config
        say("Target set to '%s'" % [ name ])
      end

      def cmd_show_target
        if config['target']
          say("Current target is '%s'" % [ config['target'] ] )
        else
          say("Target not set")
        end
      end

      def cmd_show_task(task_id)
        task = DirectorTask.new(api_client, task_id)
        say("Task state: #{task.state}")

        say("Task log:")
        begin
          state, output = task.state, task.output
          bosh_say(output) if output
          sleep(1)
        end while ["queued", "processing"].include?(state)
        bosh_say(task.flush_output)
      end

      def cmd_set_deployment(name)
        deployment = Deployment.new(@work_dir, name)

        if deployment.manifest_exists?

          if deployment.target.nil? || deployment.target =~ /^\s*$/
            say("Deployment manifest for '#{name}' has no target, please add target to manifest before proceeding")
            return
          end

          config['deployment'] = name

          if deployment.target != config['target']
            config['target'] = deployment.target
            say("WARNING! Your target has been changed to '%s'" % [ deployment.target ])
          end

          say("Deployment set to '%s'" % [ name ])
          config['deployment'] = name
          save_config          
        else
          say("Cannot find deployment '%s'" % [ deployment.path ])
          cmd_list_deployments
        end        
      end

      def cmd_list_deployments
        deployments = Deployment.all(@work_dir)

        if deployments.size > 0
          say("Available deployments are:")

          for deployment in Deployment.all(@work_dir)
            say("  %s" % [ deployment.name ])
          end
        else
          say("No deployments available")
        end        
      end

      def cmd_show_deployment
        if config['deployment']
          say("Current deployment is '%s'" % [ config['deployment'] ] )
        else
          say("Deployment not set")
        end
      end

      def cmd_login(username, password)
        if config["target"].nil?
          say("Please choose target first")
          return
        end

        if @options[:director_checks]
          if !api_client(config['target'], username, password).authenticated?
            say("Cannot log in as '#{username}', please try again")
            return :retry
          else
            say("Logged in as '#{username}'")
          end
        end

        all_configs["auth"] ||= {}
        all_configs["auth"][config["target"]] = { "username" => username, "password" => password }
        save_config
      end

      def cmd_purge
        if @cache.cache_dir != Cache::DEFAULT_CACHE_DIR
          say("Cache directory '#{@cache.cache_dir}' differs from default, please remove manually")
        else
          FileUtils.rm_rf(@cache.cache_dir)
          say("Purged cache")          
        end
      end

      def cmd_logout
        if config["target"].nil?
          say("Please choose target first")
          return
        end

        all_configs["auth"] ||= {}
        all_configs["auth"][config["target"]] = nil
        save_config
        say("You are no longer logged in to '#{config['target']}'")
      end

      def cmd_create_user(username, password)
        if !logged_in?
          say("Please log in first")
          return
        end

        created = User.create(api_client, username, password)
        if created
          bosh_say "User #{username} has been created"
        else
          bosh_say "Error creating user"
        end
      end

      def cmd_verify_stemcell(tarball_path)
        stemcell = Stemcell.new(tarball_path, @cache)

        say("\nVerifying stemcell...")
        stemcell.validate
        say("\n")

        if stemcell.valid?
          say("'%s' is a valid stemcell" % [ tarball_path] )
        else
          say("'%s' is not a valid stemcell:" % [ tarball_path] )
          for error in stemcell.errors
            say("- %s" % [ error ])
          end
        end        
      end

      def cmd_upload_stemcell(tarball_path)
        if !logged_in?
          bosh_say("Please log in first")
          return
        end

        stemcell = Stemcell.new(tarball_path, @cache)

        say("\nVerifying stemcell...")
        stemcell.validate
        say("\n")

        say("\nUploading stemcell...\n")

        status, message = stemcell.upload(api_client)

        responses = {
          :done          => "Stemcell uploaded and created",
          :non_trackable => "Uploaded stemcell but director at #{config['target']} doesn't support creation tracking",
          :track_timeout => "Uploaded stemcell but timed out out while tracking status",
          :error         => "Uploaded stemcell but received an error while tracking status",
          :invalid       => "Stemcell is invalid, please fix, verify and upload again"
        }

        say responses[status] || "Cannot upload stemcell: #{message}"
      end

      def cmd_verify_release(tarball_path)
        release = Release.new(tarball_path)

        say("\nVerifying release...")
        release.validate
        say("\n")

        if release.valid?
          say("'%s' is a valid release" % [ tarball_path] )
        else
          say("'%s' is not a valid release:" % [ tarball_path] )
          for error in release.errors
            say("- %s" % [ error ])
          end
        end
      end

      def cmd_upload_release(tarball_path)
        if !logged_in?
          bosh_say("Please log in first")
          return
        end
        
        release = Release.new(tarball_path)

        say("\nVerifying release...")
        release.validate
        say("\n")

        say("\nUploading release...\n")

        status, message = release.upload(api_client)

        responses = {
          :done          => "Release uploaded and updated",
          :non_trackable => "Uploaded release but director at #{config['target']} doesn't support update tracking",
          :track_timeout => "Uploaded release but timed out out while tracking status",
          :error         => "Uploaded release but received an error while tracking status",
          :invalid       => "Release is invalid, please fix, verify and upload again"
        }

        say responses[status] || "Cannot upload release: #{message}"
      end

      def cmd_deploy
        if config["deployment"].nil?
          say("Please choose deployment first")
          cmd_list_deployments
          return
        end

        if !logged_in?
          say("You should be logged in")
          return
        end
        
        deployment = Deployment.new(@work_dir, config["deployment"])

        if !deployment.manifest_exists?
          say("Missing manifest for %s" % [ config["deployment"] ])
          return
        end

        if !deployment.valid?
          say("Invalid manifest for '%s': name, release and target are all required" % [ config["deployment"] ])
        end
        
        desc = "to '%s' using '%s' deployment manifest" %
          [
           deployment.target,
           config["deployment"]
          ]
        
        say("Deploying #{desc}...")
        say("\n")
        status, body = deployment.perform(api_client) do |poll_number, job_status|
          if poll_number % 10 == 0
            ts = Time.now.strftime("%H:%M:%S")
            say("[#{ts}] Deployment job status is '#{job_status}' (#{poll_number} polls)...")
          end          
        end

        responses = {
          :done          => "Deployed #{desc}",
          :non_trackable => "Started deployment but director at '#{deployment.target}' doesn't support deployment tracking",
          :track_timeout => "Started deployment but timed out out while tracking status",
          :error         => "Started deployment but received an error while tracking status",
          :invalid       => "Deployment is invalid, please fix it and deploy again"
        }

        say responses[status] || "Cannot deploy: #{body}"
      end

      private

      def say(message)
        bosh_say(message)
      end

      def config
        @config ||= all_configs[@work_dir] || {}
      end

      def save_config
        all_configs[@work_dir] = config
        
        File.open(@config_path, "w") do |f|
          YAML.dump(all_configs, f)
        end
        
      rescue SystemCallError => e
        raise ConfigError, e.message
      end

      def all_configs
        return @_all_configs unless @_all_configs.nil?
        
        unless File.exists?(@config_path)
          File.open(@config_path, "w") { |f| YAML.dump({}, f) }
          File.chmod(0600, @config_path)
        end

        configs = YAML.load_file(@config_path)

        unless configs.is_a?(Hash)
          raise ConfigError, "Malformed config file: %s" % [ @config_path ]
        end

        @_all_configs = configs
      rescue SystemCallError => e
        raise ConfigError, "Cannot read config file: %s" % [ e.message ]        
      end

      def saved_credentials
        if config["target"].nil? || all_configs["auth"].nil? || all_configs["auth"][config["target"]].nil?
          nil
        else
          all_configs["auth"][config["target"]]
        end
      end

      def logged_in?
        !saved_credentials.nil?
      end

      def api_client(target = nil, username = nil, password = nil)
        if logged_in?
          username ||= saved_credentials["username"]
          password ||= saved_credentials["password"]
        end
        
        ApiClient.new(target || config["target"], username, password)
      end

      def find_cmd_implementation
        begin
          self.method("cmd_%s" % [ @cmd ])
        rescue NameError
          raise UnknownCommand, "unknown command '%s'" % [ @cmd ]
        end
      end
      
    end
    
  end
end
