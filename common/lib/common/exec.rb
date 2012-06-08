# Copyright (c) 2012 VMware, Inc.

module Bosh

  # Module to execute shell commands using different ways to invoke processes.
  # Kudos to the multi_json gang for the adaptor framework
  module Exec

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

    # Raised when there was an error executing the command
    class Error < StandardError
    end

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
        @adapetr = load_adapter(new_adapter)
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

      # @param [String] command shell command to execute
      # @param [Hash] options
      # @option options [String] :on_error if set to :raise commands
      #   returning anything but 0 will raise an [Bosh::Exec::Error]
      # @option options [String] :block if set to :on_false it will execute
      #   the block when the command fails, else it will execute the block
      #   when the command succeeds
      # @return [Bosh::Exec::Result]
      # @raise [Bosh::Exec::Error]
      # @example execute block only when command succeeds
      #   sh("command") do
      #     ...
      #   end
      # @example execute block only when command fails
      #   sh("command", :block => :on_false) do
      #     ...
      #   end
      # @example raise error if the command return anything but 0
      #   sh("command", :on_error => :raise) do
      #     ...
      #   end
      def sh(command, options={})

        adapter = current_adapter(options)
        result = adapter.sh(command)

        if result.failed?
          raise Error if options[:on_error] == :raise
          yield if block_given? && options[:block] == :on_false

        else
          yield if block_given?
        end

        result
      rescue Errno::ENOENT => e
        msg = "command not found: #{command}"

        if options[:on_error] == :raise
          raise Error, msg
        end

        result = Result.new(command, nil, msg, -1, true)

        yield result if block_given? && options[:block] == :on_false
        result
      end
    end

  end
end
