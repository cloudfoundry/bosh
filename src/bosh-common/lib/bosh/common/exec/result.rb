module Bosh::Common
  module Exec
    class Result
      # command that generated the result
      # @return [String]
      attr_reader :command
      # output from the executed command
      # @return [String]
      attr_reader :output
      # exit status of the command
      # @return [Integer]
      attr_reader :exit_status

      def initialize(command, output, exit_status, not_found = false)
        @command = command
        @output = output
        @exit_status = exit_status
        @not_found = not_found
      end

      def success?
        @exit_status == 0
      end

      def failed?
        @exit_status != 0 || @not_found
      end

      # true if the command was not found
      def not_found?
        @not_found
      end
    end
  end
end
