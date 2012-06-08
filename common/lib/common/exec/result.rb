module Bosh::Exec
  class Result
    # command that generated the result
    # @return [String]
    attr_reader :command
    # standard output from the executed command
    # @return [String]
    attr_reader :stdout
    # standard error from the executed command
    # @return [String]
    attr_reader :stderr
    # exit status of the command
    # @return [Integer]
    attr_reader :exit_status

    def initialize(command, stdout, stderr, exit_status, not_found=false)
      @command = command
      @stdout = stdout
      @stderr = stderr
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
