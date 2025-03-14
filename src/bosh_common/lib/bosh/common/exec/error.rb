module Bosh::Common
  module Exec
    # Raised when there was an error executing the command
    class Error < StandardError
      attr_reader :output

      def initialize(status, command, output = nil)
        @output = output

        message =
          if status
            "command '#{command}' failed with exit code #{status}"
          else
            "command not found: #{command}"
          end

        super(message)
      end
    end
  end
end
