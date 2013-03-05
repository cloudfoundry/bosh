# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Cli::Command
  class Complete < Base

    # bosh complete: Bash-compatible command line completion
    usage "complete"
    desc "Command completion options"
    def complete(*args)
      unless ENV.has_key?("COMP_LINE")
        err("COMP_LINE must be set when calling bosh complete")
      end
      line = ENV["COMP_LINE"].gsub(/^\S*bosh\s*/, "")
      say(completions(line).join("\n"))
    end

    private

    # @param [String] line
    def completions(line)
      if runner.nil?
        err("Command runner is not instantiated")
      end

      runner.find_completions(line.split(/\s+/))
    end

  end
end