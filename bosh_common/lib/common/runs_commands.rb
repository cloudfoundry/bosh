require 'common/exec'

# Mixin to make it easy to inject an alternate command runner into a class that runs commands.
module Bosh
  module RunsCommands
    def sh(command)
      (@command_runner || Bosh::Exec).sh(command)
    end

    attr_accessor :command_runner
  end
end
