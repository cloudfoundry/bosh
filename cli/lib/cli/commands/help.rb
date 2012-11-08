# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Cli::Command
  class Help < Base

    # bosh help: shows either a high level help message or drills down to a
    # specific area (release, deployment etc)
    usage "help"
    desc "Show help message"
    option "--all", "Show help for all BOSH commands"
    # @param [Array] keywords What specific kind of help is requested
    def help(*keywords)
      if runner.nil?
        err("Cannot show help message, command runner is not instantiated")
      end

      keywords = "all" if keywords.empty? && options[:all]

      if keywords.empty?
        generic_help
      else
        keyword_help(keywords)
      end
    end

    private

    def generic_help
      message = <<-HELP.gsub(/^\s*\|/, "")
        |BOSH CLI helps you manage your BOSH deployments and releases.
        |
        |#{runner.usage}
        |
        |The most commonly used BOSH commands are:
        |  target                        Point CLI to BOSH Director
        |  deployment                    Set deployment
        |  status                        Current status
        |  create release                Create new release
        |  upload release                Upload release
        |  upload stemcell               Upload stemcell image
        |  deploy                        Perform deployment
        |  task <task_id>                Track task / show task log
        |  tasks                         List running tasks
        |  tasks recent                  List recent tasks
        |  cloudcheck                    Find and resolve deployment problems
        |  deployments                   List deployments
        |  releases                      List releases
        |  start,restart,recreate,stop   Job management
        |  add blob                      Add large binary file to release
        |
        |You can run 'bosh help <keywords...>' to see different commands,
        |i.e. 'bosh help release', 'bosh help cloudcheck'.
        |Or run 'bosh help --all' to see all available BOSH commands
      HELP

      say message
    end

    # @param [Array] keywords
    def keyword_help(keywords)
      matches = Bosh::Cli::Config.commands.values

      if keywords == "all"
        good_matches = matches.sort { |a, b| a.usage <=> b.usage }
      else
        good_matches = []
        matches.each do |command|
          common_keywords = command.keywords & keywords
          if common_keywords.size > 0
            good_matches << command
          end

          good_matches.sort! do |a, b|
            cmp = (b.keywords & keywords).size <=> (a.keywords & keywords).size
            cmp = (a.usage <=> b.usage) if cmp == 0
            cmp
          end
        end
      end

      self.class.list_commands(good_matches)
    end

    def self.list_commands(commands)
      help_column_width = terminal_width - 5
      help_indent = 4

      commands.each_with_index do |command, i|
        nl if i > 0
        margin = command.usage.size + 1
        say("#{command.usage_with_params.columnize(70, margin).green}")
        say(command.desc.columnize(help_column_width).indent(help_indent))
        if command.has_options?
          say(command.options_summary.indent(help_indent))
        end
      end
    end

  end
end
