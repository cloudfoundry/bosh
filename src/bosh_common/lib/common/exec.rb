module Bosh; end

require 'common/exec/result'
require 'common/exec/error'

module Bosh

  # Module to execute shell commands using different ways to invoke processes.
  module Exec

    # Execute commands in a way that forces you to deal with failures and
    # helps you to simplify testing. The module can be included which will
    # add sh both as an instance and a class method.
    #
    # A sample way to mock the execution of "ls /":
    #   it "should be possible to mock the result of a command execution" do
    #     cmd = "ls /"
    #     result = Bosh::Exec::Result.new(cmd, "bin etc var", "", 0)
    #     Bosh::Exec.should_receive(:sh).with(cmd).and_return(result)
    #     result = Bosh::Exec.sh(cmd)
    #     result.success?.should be(true)
    #   end
    #
    # @note As commands are executed using %x{...} you need to append 2>&1 to
    #   redirect stderr or it will be output to the stderr of the process
    #   invoking the sh method
    # @param [String] command shell command to execute
    # @param [Hash] options
    # @option options [Symbol] :on_error if set to :return failing commands
    #   return [Bosh::Exec::Result] instead of raising [Bosh::Exec::Error]
    # @option options [Symbol] :yield if set to :on_false it will execute
    #   the block when the command fails, else it will execute the block
    #   only when the command succeeds. Implies :on_error = :return
    # @yield [Bosh::Exec::Result] command result
    # @return [Bosh::Exec::Result] command result
    # @raise [Bosh::Exec::Error] raised when the command isn't found or
    #   the command exits with a non zero status
    # @example by default execute block only when command succeeds and raise
    #   error on failure
    #   sh("command") do |result|
    #     ...
    #   end
    # @example don't raise error if the command fails
    #   result = sh("command", :on_error => :return)
    # @example execute block only when command fails (which implies
    #   :on_error => :return)
    #   sh("command", :yield => :on_false) do |result|
    #     ...
    #   end
    def sh(command, options={})
      opts = options.dup
      # can only yield if we don't raise errors
      opts[:on_error] = :return if opts[:yield] == :on_false

      output = %x{#{command}}
      result = Result.new(command, output, $?.exitstatus)

      if result.failed?
        unless opts[:on_error] == :return
          raise Error.new(result.exit_status, command, output)
        end
        yield result if block_given? && opts[:yield] == :on_false

      else
        yield result if block_given?
      end

      result
    rescue Errno::ENOENT => e
      msg = "command not found: #{command}"

      raise Error.new(nil, command) unless opts[:on_error] == :return

      result = Result.new(command, msg, -1, true)

      yield result if block_given? && opts[:yield] == :on_false
      result
    end

    # Helper method to add sh as a class method when it is included
    def self.included(base)
      base.extend(Bosh::Exec)
    end

    module_function :sh
  end
end
