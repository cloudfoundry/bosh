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

        Config.interactive = !@options[:non_interactive]
        Config.colorize    = @options.delete(:colorize)
        Config.output    ||= STDOUT unless @options[:quiet]

        if @namespace && @action
          ns_class_name = @namespace.to_s.gsub(/(?:^|_)(.)/) { $1.upcase }
          klass = eval("Bosh::Cli::Command::#{ns_class_name}")
          command = klass.new(@options)
          command.usage = @usage
          command.send(@action.to_sym, *@args)
        else
          display_usage
        end

        @normal_exit = true

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
      rescue => e
        if @options[:debug] || ENV["DEBUG"]
          raise e
        else
          say("BOSH CLI Error: #{e.message}".red)
          begin
            errfile = File.expand_path("~/.bosh_error")
            File.open(errfile, "w") do |f|
              f.write(e.message)
              f.write("\n")
              f.write(e.backtrace.join("\n"))
            end
            say("Error information saved in #{errfile}")
          rescue => e
            say("Error information couldn't be saved: #{e.message}")
          end
        end
      ensure
        say("\n")
        exit(@normal_exit ? 0 : 1)
      end

      def parse_options!
        opts_parser = OptionParser.new do |opts|
          opts.on("-c", "--config FILE")    { |file|  @options[:config] = file }
          opts.on("--cache-dir DIR")        { |dir|   @options[:cache_dir] = dir }
          opts.on("--verbose")              {         @options[:verbose] = true }
          opts.on("--no-color")             {         @options[:colorize] = false }
          opts.on("--skip-director-checks") {         @options[:director_checks] = false }
          opts.on("--force")                {         @options[:director_checks] = false }
          opts.on("--quiet")                {         @options[:quiet] = true }
          opts.on("--non-interactive")      {         @options[:non_interactive] = true }
          opts.on("--debug")                {         @options[:debug] = true }
          opts.on("-v", "--version")        {         set_cmd(:misc, :version); stop_parsing; }
          opts.on("--help")                 {}
        end

        @args = opts_parser.order!(@args)
      end

      def stop_parsing
        @stopped_parsing = true
      end

      def basic_usage
        <<-OUT
usage: bosh [--verbose] [--config|-c <FILE>] [--cache-dir <DIR] [--force]
            [--no-color] [--skip-director-checks] [--quiet] [--non-interactive]
            command [<args>]
        OUT
      end

      def display_usage
        if @usage
          say @usage_error if @usage_error
          say "Usage: #{@usage}"
          return
        elsif @verb_usage
          say @verb_usage
          return
        end

        say <<-USAGE

#{basic_usage}

Currently available bosh commands are:

  Deployment
    deployment <name>                         Choose deployment to work with (it also updates current target)
    delete deployment <name>                  Delete deployment
                                              --force        ignore all errors while deleting parts of the deployment
    deployments                               Show the list of available deployments
    deploy [--recreate]                       Deploy according to the currently selected deployment

  Releases
    create release                            Attempt to create release (assumes current directory to contain release).
                                              Release creation options:
                                               --force        bypass git dirty state check
                                               --final        create production-ready release
                                                              (stores artefacts in blobstore, bumps final version)
                                               --with-tarball create full release tarball
                                                              (by default only manifest is created)

    delete release <name>                     Delete release <name>
    delete release <name> <version>           Delete version <version> of release <name>
                                              Release deletion options:
                                               --force        ignore all errors while deleting parts of the release

    create package <name>|<path>              Build a single package
    verify release /path/to/release.tgz       Verify release tarball
    upload release /path/to/release.{tgz,yml} Upload release in tarball or by yml file
    releases                                  Show the list of uploaded releases
    reset release                             Reset release development environment (deletes all dev artifacts)

    generate package <name>                   Generate package template
    generate job <name>                       Generate job template

  Stemcells
    verify stemcell /path/to/stemcell.tgz     Verify the stemcell
    upload stemcell /path/to/stemcell.tgz     Upload the stemcell
    stemcells                                 Show the list of uploaded stemcells
    delete stemcell <name> <version>          Delete the stemcell

  User management
    create user [<username>] [<password>]     Create user

  Job management
    start <job> [<index>]                     Start job/instance
    stop  <job> [<index>] [--hard|--soft]     Stop job/instance (--soft stops processes, --hard also deletes the VM)
    restart <job> [<index>]                   Restart job/instance (soft stop + start)
    recreate <job> [<index>]                  Recreate job/instance (hard stop + start)
                                              Job management options:
                                              --force     allow job management even when local
                                                          deployment manifest contains other changes

  Log management
    logs <job> <index> [--agent|--job]        Fetch job (default) or agent (if --agent option is given) logs
                                              from an instance
                                              Log management options:
                                              --only <filter1>[,<filter2>,...] only fetch logs that satisfy
                                                                               given filters (defined in job spec),
                                                                               i.e. "bosh logs router 0 --only nginx"
                                              --all                            fetch all files in the job or
                                                                               agent log directory

  Task management
    tasks [running]                           Show the list of running tasks
    tasks recent [<number>]                   Show <number> recent tasks
    task [<id>|last] <options>                Show task status and start tracking its output
                                              Tracking options:
                                              --no-cache               don't cache task output locally
                                              --event|--debug|--soap   choose between different log types to track
                                              --raw                    show raw log contents (relevant for event log)
    cancel task <id>                          Cancel task once it reaches the next cancel checkpoint

  Maintenance
    cleanup                                   Remove all but several recent stemcells and releases from current
                                              director (stemcells and releases that are in use are not deleted).

  Misc
    status                                    Show current status (current target, user, deployment info etc.)
    target [<name>] [<alias>]                 Choose director to talk to (optionally creating an alias)
    login [<username>] [<password>]           Use given credentials for the subsequent interactions with director
    logout                                    Forgets currently saved credentials
    purge                                     Purge local manifest cache

USAGE
      end

      def parse_command!
        return if @stopped_parsing
        head = @args.shift

        case head

        when "version"
          usage("bosh version")
          set_cmd(:misc, :version)

        when "target"
          usage("bosh target [<name>] [<alias>]")
          if @args.size >= 1
            set_cmd(:misc, :set_target, 1..2)
          else
            set_cmd(:misc, :show_target)
          end

        when "deploy"
          usage("bosh deploy [--recreate]")
          set_cmd(:deployment, :perform, 0..1)

        when "deployment"
          usage("bosh deployment [<name>]")
          if @args.size >= 1
            if @args[0] == "delete"
              @args.unshift(head)
              @args[0], @args[1] = @args[1], @args[0]
              return parse_command!
            end
            set_cmd(:deployment, :set_current, 1)
          else
            set_cmd(:deployment, :show_current)
          end

        when "status", "st"
          usage("bosh status")
          set_cmd(:misc, :status)

        when "login"
          usage("bosh login [<name>] [<password>]")
          set_cmd(:misc, :login, 0..2)

        when "logout"
          usage("bosh logout")
          set_cmd(:misc, :logout)

        when "purge"
          usage("bosh purge")
          set_cmd(:misc, :purge_cache)

        when "create", "build"
          verb_usage("create")
          what = @args.shift
          case what
          when "release"
            usage("bosh create release [--force] [--final] [--with-tarball] [--dry-run]")
            set_cmd(:release, :create, 0..4)
          when "user"
            usage("bosh create user [<name>] [<password>]")
            set_cmd(:user, :create, 0..2)
          when "package"
            usage("bosh create package <name>|<path>")
            set_cmd(:package, :create, 1)
          end

        when "start"
          usage("bosh start <job> [<index>] [--force]")
          set_cmd(:job_management, :start_job, 1..3)

        when "stop"
          usage("bosh stop <job> [<index>] [--soft | --hard] [--force]")
          set_cmd(:job_management, :stop_job, 1..4)

        when "restart"
          usage("bosh restart <job> [<index>] [--force]")
          set_cmd(:job_management, :restart_job, 1..3)

        when "recreate"
          usage("bosh recreate <job> [<index>] [--force]")
          set_cmd(:job_management, :recreate_job, 1..3)

        when "logs"
          usage("bosh logs <job> <index> [--agent]")
          set_cmd(:log_management, :fetch_logs, "*")

        when "generate", "gen"
          verb_usage("generate")
          what = @args.shift
          case what
          when "package"
            usage("bosh generate package <name>")
            set_cmd(:package, :generate, 1)
          when "job"
            usage("bosh generate job <name>")
            set_cmd(:job, :generate, 1)
          end

        when "upload"
          verb_usage("upload")
          what = @args.shift
          case what
          when "stemcell"
            usage("bosh upload stemcell <path>")
            set_cmd(:stemcell, :upload, 1)
          when "release"
            usage("bosh upload release <path>")
            set_cmd(:release, :upload, 0..1)
          end

        when "verify", "validate"
          verb_usage("verify")
          what = @args.shift
          case what
          when "stemcell"
            usage("bosh verify stemcell <path>")
            set_cmd(:stemcell, :verify, 1)
          when "release"
            usage("bosh verify release <path>")
            set_cmd(:release, :verify, 1)
          end

        when "delete"
          verb_usage("delete")
          what = @args.shift
          case what
          when "deployment"
            usage("bosh delete deployment <name> [--force]")
            set_cmd(:deployment, :delete, 1..2)
          when "stemcell"
            usage("bosh delete stemcell <name> <version>")
            set_cmd(:stemcell, :delete, 2)
          when "release"
            usage("bosh delete release <name> [<version>] [--force]")
            set_cmd(:release, :delete, 1..3)
          end

        when "reset"
          what = @args.shift
          case what
          when "release"
            usage("bosh reset release")
            set_cmd(:release, :reset, 0)
          end

        when "cancel"
          what = @args.shift
          case what
          when "task"
            usage("bosh cancel task <task-id>")
            set_cmd(:task, :cancel, 1)
          end

        when "task"
          usage("bosh task [<task_id>|last] [--no-cache] [--event|--soap|--debug] [--raw]")
          set_cmd(:task, :track, 0..4)

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

        when "cleanup"
          usage("bosh cleanup")
          set_cmd(:maintenance, :cleanup)

        else
          # Try alternate verb noun order before giving up
          verbs = ["upload", "build", "verify", "validate", "create", "delete"]
          if @args.size >= 1 && !verbs.include?(head) && verbs.include?(@args[0])
            @args.unshift(head)
            @args[0], @args[1] = @args[1], @args[0]
            return parse_command!
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

      def verb_usage(verb)
        options = {
          "create"   => "user [<name>] [<password>]\npackage <path>\nrelease",
          "upload"   => "release <path>\nstemcell <path>",
          "verify"   => "release <path>\nstemcell <path>",
          "delete"   => "deployment <name>\nstemcell <name> <version>\nrelease <name> [<version>] [--force]",
          "generate" => "package <name>\njob <name>"
        }

        @verb_usage = ("What do you want to #{verb}? The options are:\n\n%s" % [ options[verb] ])
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
