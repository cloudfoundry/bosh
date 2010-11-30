require "yaml"

module Bosh
  module Cli

    class Runner

      CONFIG_PATH = File.expand_path("~/.bosh_config")

      def self.run(cmd, output, *args)
        new(cmd, output, *args).run
      end

      def initialize(cmd, output, *args)
        @cmd         = cmd
        @args        = args
        @out         = output
        @work_dir    = Dir.pwd
      end

      def run
        method   = find_cmd_implementation
        expected = method.arity

        if expected >= 0 && @args.size != expected
          raise ArgumentError, "wrong number of arguments for #{self.class.name}##{method.name} (#{@args.size} for #{expected})"
        end

        method.call(*@args)
      end

      def cmd_status
        say("Target: %s" % [ config['target'] || "not set" ])
        say("Deployment: %s" % [ config['deployment'] || "not set" ])
        say("User: %s" % [ config['user'] || "not set" ])
      end

      def cmd_set_target(name)
        config['target'] = name
        save_config
        say("Target set to '%s'" % [ name ])
      end

      def cmd_show_target
        if config['target']
          say("Current target is %s" % [ config['target'] ] )
        else
          say("Target not set")
        end
      end

      def cmd_set_deployment(name)
        config['deployment'] = name
        save_config
        say("Deployment set to '%s'" % [ name ])
      end

      def cmd_show_deployment
        if config['deployment']
          say("Current target is %s" % [ config['deployment'] ] )
        else
          say("Deployment not set")
        end
      end

      def cmd_login(username, password)
        say("Logged in as %s:%s" % [ username, password ])
      end

      def cmd_create_user(username, password)
        say("Created user %s:%s" % [ username, password ])
      end

      def verify_stemcell(tarball_path)
      end

      def upload_stemcell(tarball_path)
      end

      def verify_release(tarball_path)
      end

      def upload_release(tarball_path)
      end

      def cmd_deploy
        say("Deploying...")
        sleep(0.5)
        say("Deploy OK.")
      end

      private

      def say(message)
        @out.puts(message)
      end

      def config
        @config ||= all_configs[@work_dir] || {}
      end

      def save_config
        File.open(CONFIG_PATH, "w") do |f|
          YAML.dump(all_configs, f)
        end
      rescue SystemCallError => e
        raise ConfigError, "Cannot save config: %s" % [ e.message ]
      end

      def all_configs
        return @_all_configs unless @_all_configs.nil?
        
        unless File.exists?(CONFIG_PATH)
          File.open(CONFIG_PATH, "w") { |f| YAML.dump({}, f) }
          File.chmod(0600, CONFIG_PATH)
        end

        configs = YAML.load_file(CONFIG_PATH)

        unless configs.is_a?(Hash)
          raise ConfigError, "Malformed config file: %s" % [ CONFIG_PATH ]
        end

        @_all_configs = configs

      rescue SystemCallError => e
        raise ConfigError, "Cannot read config file: %s" % [ e.message ]        
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
