module Bosh::Common
  module Exec
    # Raised when there was an error executing the command
    class Error < StandardError
      attr_reader :output

      def initialize(status, command, output = nil)
        @status = status
        @command = command
        @output = output
      end

      def message
        if @status
          "command '#{@command}' failed with exit code #{@status}"
        else
          "command not found: #{@command}"
        end
      end

      def to_s
        message
      end
    end
  end
end
