require "yaml"
require "optparse"
require "highline/import"

module Bosh
  module Cli

    class Runner

      attr_reader   :namespace
      attr_reader   :action
      attr_reader   :cmd_args

      def self.run(args)
        new(args).run
      end

      def initialize(args)
        @args = args
        @options = {
          :director_checks => true,
          :colorize        => true,          
        }
      end

      def set_cmd(*args)
        @namespace, @action, *@cmd_args = args
      end

      def run
        parse_options!
        parse_command!

        Config.colorize   = @options.delete(:colorize)
        Config.output   ||= STDOUT unless @options[:quiet]

        if @namespace && @action
          eval("Bosh::Cli::Command::#{@namespace.to_s.capitalize}").new(@options).send(@action.to_sym, *@cmd_args)
        else
          display_usage
        end

#      rescue ArgumentError => e
#        say("Invalid arguments for '%s'" % [ @namespace, @action ].compact.join(" "))
      rescue Bosh::Cli::AuthError
        say("Director auth error")
      rescue Bosh::Cli::GracefulExit => e
        # Redirected tasks end up generating this exception
      rescue Bosh::Cli::CliExit => e
        say(e.message.red)
      rescue Bosh::Cli::CliError => e
        say("Error #{e.error_code}: #{e.message}")
      ensure
        say("\n")
      end

      def parse_options!
        opts_parser = OptionParser.new do |opts|
          opts.on("-c", "--config FILE")    { |file|  @options[:config] = file }
          opts.on("--cache-dir DIR")        { |dir|   @options[:cache_dir] = dir }
          opts.on("-v", "--verbose")        {         @options[:verbose] = true }
          opts.on("--no-color")             {         @options[:colorize] = false }
          opts.on("--skip-director-checks") {         @options[:director_checks] = false }
          opts.on("--force")                {         @options[:director_checks] = false }
          opts.on("--quiet")                {         @options[:quiet] = true }
          opts.on("--non-interactive")      {         @options[:non_interactive] = true }
          opts.on("--version")              {         set_cmd(:dashboard, :version) }
          opts.on("--help")                 {}
        end

        @args = opts_parser.order!(@args)
      end

      def display_usage
        puts <<-USAGE

usage: bosh [--verbose|-v] [--config|-c <FILE>] [--cache-dir <DIR]
            [--no-color] [--skip-director-checks] [--quiet] [--non-interactive]
            command [<args>]

Currently available bosh commands are:

  target <name>                            Choose target to work with

  deployment <name>                        Choose deployment to work with (it also updates current target)

  user create [<username>] [<password>]    Create user

  login [<username>] [<password>]          Use given username for the subsequent interactions
  logout                                   Forgets currently saved credentials

  purge                                    Purge cached data

  task <id>                                Show task status (monitor if not done)

  release upload /path/to/release.tgz      Upload the release
  release verify /path/to/release.tgz      Verify the release

  package create  <name>|<path>|all        Build a package

  stemcell upload /path/to/stemcell.tgz    Upload the stemcell
  stemcell verify /path/to/stemcell.tgz    Verify the stemcell

  status                                   Show current status (current target, user, deployment info etc.)

  deploy                                   Deploy according to the currently selected deployment

USAGE
      end      

      def parse_command!
        head, *args = @args

        case head
        when "version"
          set_cmd(:dashboard, :version)
        when "target"
          if args.size > 0
            set_cmd(:dashboard, :set_target, *args)
          else
            set_cmd(:dashboard, :show_target)
          end
        when "deploy"
          set_cmd(:deployment, :perform)
        when "deployment"
          if args.size > 0
            set_cmd(:deployment, :set_current, *args)
          else
            set_cmd(:deployment, :show_current)
          end
        when "status", "st"
          set_cmd(:dashboard, :status)
        when "login"
          set_cmd(:dashboard, :login, *args)
        when "logout"
          set_cmd(:dashboard, :logout)
        when "purge"
          set_cmd(:dashboard, :purge_cache)
        when "user"
          op, *params = args
          case op
          when "create": set_cmd(:user, :create, *params)
          end
        when "task"
          set_cmd(:task, :track, *args)
        when "stemcell"
          op, *params = args
          case op
          when "upload": set_cmd(:stemcell, :upload, *params)
          when "verify", "validate": set_cmd(:stemcell, :verify, *params)
          end
        when "package"
          op, name, *params = args
          case op
          when "create", "build": set_cmd(:package, :create, name)
          end
        when "job"
          op, name, *params = args
          case op
          when "create", "build": set_cmd(:job, :create, name)
          end
        when "release"
          op, *params = args
          case op
          when "upload": set_cmd(:release, :upload, *params)
          when "verify", "validate": set_cmd(:release, :verify, *params)
          when "create": set_cmd(:release, :create)
          end
        end
      end
    end
    
  end
end
