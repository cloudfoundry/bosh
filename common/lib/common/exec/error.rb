# Copyright (c) 2012 VMware, Inc.

module Bosh::Exec
# Raised when there was an error executing the command
  class Error < StandardError
    def initialize(status, command)
      @status = status
      @command = command
    end

    def message
      if @status
        "command '#{@command}' failed with exit code #{@status}"
      else
        "command not found: #{@command}"
      end
    end
  end
end