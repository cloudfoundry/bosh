# Copyright (c) 2009-2012 VMware, Inc.

require "open4"

module Bosh
  # This module can either be included or extended into other classes,
  # or called directly as Bosh::Exec.sh()
  module Exec

    class Error < StandardError
    end

    # class that hold the result of a command execution
    class Result
      attr_reader :stdout, :stderr, :status
      def initialize(stdout, stderr, status)
        @stdout = stdout
        @stderr = stderr
        @status = status
      end

      # returns true when the command execution succeeded
      def ok?
        @status == 0
      end

      # returns true when the command execution failed
      def failed?
        @status != 0
      end
    end

    # Execute command in a subshell using the open4 gem and return
    # the results. If a block is provided it is only executed if the
    # command fails.
    #
    # @param [String, command] the command to execute
    # @param [boolean, exception_on_error] if a non-zero result should raise
    #   an Bosh::Exec::Error
    # @return [Bosh::Exec::Result] execution results
    def sh(command, exception_on_error=false, &block)
      stdout = nil
      stderr = nil
      status = Open4::popen4(command) do |pid, stdin, out, err|
        stdout = out.read.strip
        stderr = err.read.strip
      end
      @result = Result.new(stdout, stderr, status.exitstatus)
    rescue Errno::ENOENT => e
      @result = Result.new("", "", 1)
    ensure
      if @result.failed? && exception_on_error
        raise Error, "failed to execute '#{command}'"
      end
      yield @result if block_given? && @result.failed?
      @result
    end

    module_function :sh
  end
end
