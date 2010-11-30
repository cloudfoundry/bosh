module Bosh
  module Cli

    class Runner

      def self.run(cmd, output, *args)
        new(cmd, output, *args).run
      end

      def initialize(cmd, output, *args)
        @cmd  = cmd
        @args = args
        @out  = output
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
        say("Locked and loaded, sir!")
      end

      def cmd_set_target(name)
        say("Set target to %s" % [ name ])
      end

      def cmd_show_target
        say("Current target is %s" % [ 'dummy' ])
      end

      def cmd_set_deployment(name)
        say("Set deployment to %s" % [ name ])
      end

      def cmd_show_deployment
        say("Current deployment is %s" % [ 'dummy' ])
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
