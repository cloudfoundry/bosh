# Copyright (c) 2012 VMware, Inc.

module Bosh

  # Module for common methods used throughout the BOSH code.
  module Common

    # Converts all keys of a [Hash] to symbols. Performs deep conversion.
    #
    # @param [Hash] hash to convert
    # @return [Hash] a copy of the original hash
    def symbolize_keys(hash)
      hash.inject({}) do |h, (key, value)|
        h[key.to_sym] = value.is_a?(Hash) ? symbolize_keys(value) : value
        h
      end
    end

    module_function :symbolize_keys

    # @overload which(program, path)
    #   Looks for program in the executables search path (PATH).
    #   The file must be executable to be found.
    #   @param [String] program
    #   @param [String] path search path
    #   @return [String] full path of the executable,
    #     or nil if not found
    # @overload which(programs, path)
    #   Looks for one of the programs in the executables search path (PATH).
    #   The file must be executable to be found.
    #   @param [Array] programs
    #   @param [String] path search path
    #   @return [String] full path of the executable,
    #     or nil if not found
    def which(programs, path=ENV["PATH"])
      path.split(File::PATH_SEPARATOR).each do |dir|
        Array(programs).each do |bin|
          exe = File.join(dir, bin)
          return exe if File.executable?(exe)
        end
      end
      nil
    end

    module_function :which

    def retryable(options = {}, &block)
      opts = {:tries => 2, :sleep => 1, :on => StandardError, :matching  => /.*/, :ensure => Proc.new {}}
      invalid_options = opts.merge(options).keys - opts.keys

      raise ArgumentError.new("Invalid options: #{invalid_options.join(", ")}") unless invalid_options.empty?
      opts.merge!(options)

      return if opts[:tries] == 0

      on_exception, tries = [ opts[:on] ].flatten, opts[:tries]
      retries = 0
      retry_exception = nil

      begin
        return yield retries, retry_exception
      rescue *on_exception => exception
        raise unless exception.message =~ opts[:matching]
        raise if retries+1 >= tries

        # Interrupt Exception could be raised while sleeping
        begin
          sleep opts[:sleep].respond_to?(:call) ? opts[:sleep].call(retries) : opts[:sleep]
        rescue *on_exception
        end

        retries += 1
        retry_exception = exception
        retry
      ensure
        opts[:ensure].call(retries)
      end
    end

    module_function :retryable
  end
end
