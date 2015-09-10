module Bosh::Cli
  class ParseTreeNode < Hash
    attr_accessor :command
  end

  class Runner

    # @return [Array]
    attr_reader :args

    # @return [Hash]
    attr_reader :options

    # @param [Array] args
    def self.run(args)
      new(args).run
    end

    # @param [Array] args
    def initialize(args, options = {})
      @args = args
      @options = options.dup

      banner = "Usage: bosh [<options>] <command> [<args>]"
      @option_parser = OptionParser.new(banner)

      Config.colorize = nil
      Config.output ||= STDOUT

      parse_global_options
    end

    # Find and run CLI command
    # @return [void]
    def run
      Config.interactive = !@options[:non_interactive]
      Config.poll_interval = @options[:poll_interval]

      load_plugins
      build_parse_tree
      add_shortcuts

      @args = %w(help) if @args.empty?

      command = search_parse_tree(@parse_tree)
      if command.nil? && Config.interactive
        command = try_alias
      end

      if command.nil?
        err("Unknown command: #{@args.join(" ")}")
      end

      command.runner = self
      begin
        exit_code = command.run(@args, @options)
        exit(exit_code)
      rescue OptionParser::ParseError => e
        say_err(e.message)
        nl
        say_err("Usage: bosh #{command.usage_with_params.columnize(60, 7)}")
        nl
        if command.has_options?
          say(command.options_summary.indent(7))
        end
        exit(1)
      end

    rescue OptionParser::ParseError => e
      say_err(e.message)
      say_err(@option_parser.to_s)
      exit(1)

    rescue Bosh::Cli::CliError => e
      say_err(e.message)
      nl
      exit(e.exit_code)
    end

    # Finds command completions in the parse tree
    # @param [Array] words Completion prefix
    # @param [Bosh::Cli::ParseTreeNode] node Current parse tree node
    def find_completions(words, node = @parse_tree, index = 0)
      word = words[index]

      # exact match and not on the last word
      if node[word] && words.length != index
        find_completions(words, node[word], index + 1)

        # exact match at the last word
      elsif node[word]
        node[word].values

        # find all partial matches
      else
        node.keys.grep(/^#{word}/)
      end
    end

    def parse_global_options
      # -v is reserved for verbose but having 'bosh -v' is handy,
      # hence the little hack
      if @args.size == 1 && (@args[0] == "-v" || @args[0] == "--version")
        @args = %w(version)
        return
      end

      opts = @option_parser
      config_desc = "Override configuration file. Also can be overridden " +
                    "by BOSH_CONFIG environment variable. Defaults to " +
                    "$HOME/.bosh_config. Override precedence is command-" +
                    "line option, then environment variable, then home directory."
      opts.on("-c", "--config FILE", config_desc) do |file|
        @options[:config] = file
      end

      opts.on("--parallel MAX", "Sets the max number of parallel downloads") do |max|
        Config.max_parallel_downloads = Integer(max)
      end

      opts.on("--[no-]color", "Toggle colorized output") do |v|
        Config.colorize = v
      end

      opts.on("-v", "--verbose", "Show additional output") do
        @options[:verbose] = true
      end
      opts.on("-q", "--quiet", "Suppress all output") do
        Config.output = nil
      end
      opts.on("-n", "--non-interactive", "Don't ask for user input") do
        @options[:non_interactive] = true
      end
      opts.on("-N", "--no-track", "Return Task ID and don't track") do
        @options[:no_track] = true
      end
      opts.on("-P", "--poll INTERVAL", "Director task polling interval") do |interval|
        @options[:poll_interval] = Integer(interval)
      end
      opts.on("-t", "--target URL", "Override target") do |target|
        @options[:target] = target
      end
      opts.on("-u", "--user USER", "Override username") do |user|
        @options[:username] = user
      end
      opts.on("-p", "--password PASSWORD", "Override password") do |pass|
        @options[:password] = pass
      end
      opts.on("-d", "--deployment FILE", "Override deployment") do |file|
        @options[:deployment] = file
      end
      opts.on("-h", "--help", "here you go") do
        @args << 'help'
      end

      @args = @option_parser.order!(@args)
    end

    def plugins_glob; "bosh/cli/commands/*.rb"; end

    # Discover and load CLI plugins from all available gems
    # @return [void]
    def load_plugins
      load_local_plugins
      load_gem_plugins
    end

    def load_local_plugins
      Dir.glob(File.join("lib", plugins_glob)).each do |file|
        say("WARNING: loading local plugin: #{file}")
        require_plugin(file)
      end
    end

    def load_gem_plugins
      get_gem_plugins.each do |plugin_path|
        original_commands = Config.commands.size

        begin
          next unless require_plugin plugin_path
        rescue Exception => e
          err("Failed to load plugin #{plugin_path}: #{e.message}".make_red)
        end

        if Config.commands =~ original_commands
          say(("File #{plugin_path} has been loaded as plugin but it didn't " +
              "contain any commands.\nMake sure this plugin is updated to be " +
              "compatible with BOSH CLI 1.0.").columnize(80).make_yellow)
        end
      end
    end

    def get_gem_plugins
      Gem::Specification.latest_specs(true).map { |spec|
        spec.matches_for_glob(plugins_glob)
      }.flatten.uniq
    rescue
      err("Cannot load plugins, ".make_yellow +
              "please run `gem update --system' to ".make_yellow +
              "update your RubyGems".make_yellow)
    end

    def require_plugin(file)
      require File.absolute_path(file)
    end

    def build_parse_tree
      @parse_tree = ParseTreeNode.new

      Config.commands.each_value do |command|
        p = @parse_tree
        n_kw = command.keywords.size

        command.keywords.each_with_index do |kw, i|
          p[kw] ||= ParseTreeNode.new
          p = p[kw]
          p.command = command if i == n_kw - 1
        end
      end
    end

    def add_shortcuts
      {
        "st" => "status",
        "props" => "properties",
        "cck" => "cloudcheck"
      }.each do |short, long|
        @parse_tree[short] = @parse_tree[long]
      end
    end

    def usage
      @option_parser.to_s
    end

    def search_parse_tree(node)
      return nil if node.nil?
      arg = @args.shift

      longer_command = search_parse_tree(node[arg])

      if longer_command.nil?
        @args.unshift(arg) if arg # backtrack if needed
        node.command
      else
        longer_command
      end
    end

    def try_alias
      # Tries to find best match among aliases (possibly multiple words),
      # then unwinds it onto the remaining args and searches parse tree again.
      # Not the most effective algorithm but does the job.
      config = Bosh::Cli::Config.new(@options[:config])
      candidate = []
      best_match = nil
      save_args = @args.dup

      while (arg = @args.shift)
        candidate << arg
        resolved = config.resolve_alias(:cli, candidate.join(" "))
        if best_match && resolved.nil?
          @args.unshift(arg)
          break
        end
        best_match = resolved
      end

      if best_match.nil?
        @args = save_args
        return
      end

      best_match.split(/\s+/).reverse.each do |keyword|
        @args.unshift(keyword)
      end

      search_parse_tree(@parse_tree)
    end

    private

    def say_err(message)
      $stderr << message.make_red
    end
  end

end
