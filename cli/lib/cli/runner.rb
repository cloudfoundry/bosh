require "yaml"
require "optparse"
require "highline/import"

module Bosh
  module Cli

    class Runner

      attr_reader   :namespace
      attr_reader   :action
      attr_reader   :args
      attr_reader   :options

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

      def set_cmd(namespace, action, args_range = 0)
        unless args_range == "*" || args_range.is_a?(Range)
          args_range = (args_range.to_i..args_range.to_i)
        end
        
        if args_range == "*" || args_range.include?(@args.size)
          @namespace = namespace
          @action    = action
        elsif @args.size > args_range.last
          usage_error("Too many arguments: %s" % [ @args[args_range.last..-1].map{|a| "'#{a}'"}.join(', ') ])
        else
          usage_error("Not enough arguments")
        end
      end

      def unknown_operation(op)
        if op.blank?
          usage_error("No operation given")
        else
          usage_error("Unknown operation: '#{op}'")
        end
      end

      def run
        parse_options!
        parse_command!

        Config.colorize  = @options.delete(:colorize)
        Config.output   ||= STDOUT unless @options[:quiet]

        if @namespace && @action
          eval("Bosh::Cli::Command::#{@namespace.to_s.capitalize}").new(@options).send(@action.to_sym, *@args)
        else
          display_usage
        end

      rescue OptionParser::InvalidOption => e
        puts(e.message.red)
        puts("\n")
        puts(basic_usage)
      rescue Bosh::Cli::AuthError
        say("Director auth error")
      rescue Bosh::Cli::GracefulExit => e
        # Redirected bosh commands end up generating this exception (kind of goto)
      rescue Bosh::Cli::CliExit => e
        say(e.message.red)
      rescue Bosh::Cli::CliError => e
        say("Error #{e.error_code}: #{e.message}".red)
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

      def basic_usage
        <<-OUT
usage: bosh [--verbose|-v] [--config|-c <FILE>] [--cache-dir <DIR] [--force]
            [--no-color] [--skip-director-checks] [--quiet] [--non-interactive]
            command [<args>]
        OUT
      end

      def display_usage
        if @usage
          say @usage_error if @usage_error
          say "Usage: #{@usage}"
          return
        end

        say <<-USAGE

#{basic_usage}

Currently available bosh commands are:

  target <name>                            Choose target to work with

  deployment <name>                        Choose deployment to work with (it also updates current target)
  deployment delete <name>                 Delete deployment

  deployments                              Show the list of deployments
  releases                                 Show the list of releases
  stemcells                                Show the list of stemcells
  tasks [running]                          Show the list of running tasks
  tasks recent [<number>]                  Show <number> recent tasks

  user create [<username>] [<password>]    Create user

  login [<username>] [<password>]          Use given username for the subsequent interactions
  logout                                   Forgets currently saved credentials

  purge                                    Purge cached data

  task <id>                                Show task status (monitor if not done)

  release upload /path/to/release.tgz      Upload the release
  release verify /path/to/release.tgz      Verify the release

  package create  <name>|<path>|all        Build a package
  release create                           Attempt to create release (assumes current directory to contain release)

  stemcell upload /path/to/stemcell.tgz    Upload the stemcell
  stemcell verify /path/to/stemcell.tgz    Verify the stemcell

  status                                   Show current status (current target, user, deployment info etc.)

  deploy                                   Deploy according to the currently selected deployment

USAGE
      end      

      def parse_command!
        head = @args.shift

        case head
        when "version"
          usage("bosh version")
          set_cmd(:dashboard, :version)
        when "target"
          usage("bosh target [<name>]")
          if @args.size == 1
            set_cmd(:dashboard, :set_target, 1)
          else
            set_cmd(:dashboard, :show_target)
          end
        when "deploy"
          usage("bosh deploy")
          set_cmd(:deployment, :perform)
        when "deployment"
          op = @args.shift
          if op == "delete"
            usage("bosh deployment delete <name>")
            set_cmd(:deployment, :delete, 1)
          else
            @args.unshift(op) if op
            usage("bosh deployment [<name>]")
            if @args.size == 1
              set_cmd(:deployment, :set_current, 1)
            else
              set_cmd(:deployment, :show_current)
            end
          end
        when "status", "st"
          usage("bosh status")
          set_cmd(:dashboard, :status)
        when "login"
          usage("bosh login [<name>] [<password>]")
          set_cmd(:dashboard, :login, 0..2)
        when "logout"
          usage("bosh logout")
          set_cmd(:dashboard, :logout)
        when "purge"
          usage("bosh purge")
          set_cmd(:dashboard, :purge_cache)
        when "user"
          usage("bosh user create [<name>] [<password>]")
          op = @args.shift
          case op
          when "create": set_cmd(:user, :create, 0..2)
          else unknown_operation(op)
          end
        when "task"
          usage("bosh task <task_id>")
          set_cmd(:task, :track, 1)
        when "stemcell"
          op = @args.shift
          case op
          when "upload"
            usage("bosh stemcell upload <path>")
            set_cmd(:stemcell, :upload, 1)
          when "verify", "validate"
            usage("bosh stemcell verify <path>")
            set_cmd(:stemcell, :verify, 1)
          when "delete"
            usage("bosh stemcell verify <name> <version>")
            set_cmd(:stemcell, :delete, 2)
          else unknown_operation(op)            
          end
        when "package"
          usage("bosh package create <name>|<path>")
          op = @args.shift
          case op
          when "create", "build": set_cmd(:package, :create, 1)
          else unknown_operation(op)
          end
        when "release"
          usage("bosh release (upload|verify <path>)|create ")
          op = @args.shift
          case op
          when "upload"
            usage("bosh release upload <path>")
            set_cmd(:release, :upload, 1)
          when "verify", "validate":
            usage("bosh release verify <path>")            
            set_cmd(:release, :verify, 1)
          when "create"
            usage("bosh release create")
            set_cmd(:release, :create)
          else
            unknown_operation(op)
          end
        when "stemcells"
          usage("bosh stemcells")
          set_cmd(:stemcell, :list, 0)
        when "releases"
          usage("bosh releases")
          set_cmd(:release, :list, 0)
        when "deployments"
          usage("bosh deployments")
          set_cmd(:deployment, :list, 0)
        when "tasks"
          args.unshift("running") if args.size == 0
          kind = args.shift
          case kind
          when "running"
            usage("bosh tasks [running]")
            set_cmd(:task, :list_running, 0)
          when "recent"
            usage("bosh tasks recent [<number>]")
            set_cmd(:task, :list_recent, 0..1)
          else
            unknown_operation(kind)
          end
        end
      end

      def usage(msg = nil)
        if msg
          @usage = msg
        else
          @usage
        end
      end

      def usage_error(msg = nil)
        if msg
          @usage_error = msg
        else
          @usage_error
        end
      end
      
    end
    
  end
end
