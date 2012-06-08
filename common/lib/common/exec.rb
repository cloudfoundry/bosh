# Copyright (c) 2012 VMware, Inc.

require "common/exec/result"
require "common/exec/error"

module Bosh

  # Module to execute shell commands using different ways to invoke processes.
  # Kudos to the multi_json gang for the adaptor framework
  module Exec

    REQUIREMENT_MAP = [
      ["posix/spawn", :posix_spawn],
      ["open4", :open4]
    ]

    class << self

      def default_adapter
        return :posix_spawn if defined?(::POSIX::Spawn)
        return :open4 if defined?(::Open4)
        REQUIREMENT_MAP.each do |library, adapter|
          begin
            require library
            return adapter
          rescue LoadError
            next
          end
        end
      end

      def adapter
        return @adapter if @adapter
        self.use(self.default_adapter)
      end

      def use(new_adapter)
        @adapter = load_adapter(new_adapter)
      end

      def load_adapter(new_adapter)
        case new_adapter
        when String, Symbol
          require "common/exec/adapters/#{new_adapter}"
          const = new_adapter.to_s.split('_').map{|s| s.capitalize}.join('')
          Bosh::Exec::Adapters.const_get("#{const}")
        when Class
          new_adapter
        else
          raise "unknown adapter: #{new_adapter}"
        end
      end

      def current_adapter(options={})
        if new_adapter = options.delete(:adapter)
          load_adapter(new_adapter)
        else
          adapter
        end
      end

      # Execute commands in a way that forces you to deal with failures and helps you
      # to simplify testing.
      #
      # A sample way to mock the execution of "ls /":
      #   it "should be possible to mock the result of a command execution" do
      #     cmd = "ls /"
      #     result = Bosh::Exec::Result.new(cmd, "bin etc var", "", 0)
      #     Bosh::Exec.should_receive(:sh).with(cmd).and_return(result)
      #     result = Bosh::Exec.sh(cmd)
      #     result.success?.should be_true
      #   end
      #
      # @note when testing do this ...
      # @param [String] command shell command to execute
      # @param [Hash] options
      # @option options [String] :on_error if set to :return failing commands
      #   return [Bosh::Exec::Result] instead of raising [Bosh::Exec::Error]
      # @option options [String] :yield if set to :on_false it will execute
      #   the block when the command fails, else it will execute the block
      #   only when the command succeeds. Implies :on_error = :return
      # @yield [Bosh::Exec::Result] command result
      # @return [Bosh::Exec::Result] command result
      # @raise [Bosh::Exec::Error] raised when the command isn't found or
      #   the command exits with a non zero status
      # @example by default execute block only when command succeeds and raise error on failure
      #   sh("command") do |result|
      #     ...
      #   end
      # @example don't raise error if the command fails
      #   result = sh("command", :on_error => :return) do |result|
      #     ...
      #   end
      # @example execute block only when command fails (which implies :on_error => :return)
      #   sh("command", :yield => :on_false) do |result|
      #     ...
      #   end
      def sh(command, options={})
        puts "options: #{options.inspect}"
        opts = options.dup
        # can only yield if we don't raise errors
        opts[:on_error] = :return if opts[:yield] == :on_false

        adapter = current_adapter(opts)
        result = adapter.sh(command)

        if result.failed?
          raise Error.new(result.exit_status, command) unless opts[:on_error] == :return
          yield result if block_given? && opts[:yield] == :on_false

        else
          yield result if block_given?
        end

        result
      rescue Errno::ENOENT => e
        msg = "command not found: #{command}"

        raise Error.new(nil, command) unless opts[:on_error] == :return

        result = Result.new(command, nil, msg, -1, true)

        yield result if block_given? && opts[:yield] == :on_false
        result
      end
    end

  end
end
