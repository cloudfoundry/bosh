# Copyright (c) 2009-2012 VMware, Inc.

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

      Config.colorize = true
      Config.output ||= STDOUT
    end

    # Find and run CLI command
    # @return [void]
    def run
      parse_global_options

      Config.interactive = !@options[:non_interactive]
      Config.cache = Bosh::Cli::Cache.new(@options[:cache_dir])

      load_plugins
      build_parse_tree
      add_shortcuts

      if @args.empty?
        say(usage)
        exit(0)
      end

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
        say(e.message.red)
        say("Usage: bosh #{command.usage_with_params.columnize(60, 7)}")
        if command.has_options?
          say(command.options_summary.indent(7))
        end
      end

    rescue OptionParser::ParseError => e
      say(e.message.red)
      say(@option_parser.to_s)
      exit(1)
    rescue Bosh::Cli::CliError => e
      say(e.message.red)
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
      opts.on("-c", "--config FILE", "Override configuration file") do |file|
        @options[:config] = file
      end
      opts.on("-C", "--cache-dir DIR", "Override cache directory") do |dir|
        @options[:cache_dir] = dir
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
        Config.colorize = false
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

      @args = @option_parser.order!(@args)
    end

    # Discover and load CLI plugins from all available gems
    # @return [void]
    def load_plugins
      plugins_glob = "bosh/cli/commands/*.rb"

      unless Gem::Specification.respond_to?(:latest_specs) &&
             Gem::Specification.instance_methods.include?(:matches_for_glob)
        say("Cannot load plugins, ".yellow +
            "please run `gem update --system' to ".yellow +
            "update your RubyGems".yellow)
        return
      end

      plugins = Gem::Specification.latest_specs(true).map { |spec|
        spec.matches_for_glob(plugins_glob)
      }.flatten

      plugins.each do |plugin|
        n_commands = Config.commands.size
        gem_dir = Pathname.new(Gem.dir)
        plugin_name = Pathname.new(plugin).relative_path_from(gem_dir)
        begin
          require plugin
        rescue Exception => e
          say("Failed to load plugin #{plugin_name}: #{e.message}".red)
        end
        if Config.commands.size == n_commands
          say(("File #{plugin_name} has been loaded as plugin but it didn't " +
              "contain any commands.\nMake sure this plugin is updated to be " +
              "compatible with BOSH CLI 1.0.").columnize(80).yellow)
        end
      end
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
  end
end