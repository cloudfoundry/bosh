# Copyright (c) 2012 VMware, Inc.
require 'common/errors'

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

    # this method will loop until the block returns a true value
    def retryable(options = {}, &block)
      opts = {:tries => 2, :sleep => exponential_sleeper, :on => StandardError, :matching  => /.*/, :ensure => Proc.new {}}
      invalid_options = opts.merge(options).keys - opts.keys

      raise ArgumentError.new("Invalid options: #{invalid_options.join(", ")}") unless invalid_options.empty?
      opts.merge!(options)

      return if opts[:tries] == 0

      on_exception = [ opts[:on] ].flatten
      tries = opts[:tries]
      retries = 0
      retry_exception = nil

      begin
        loop do
          y = yield retries, retry_exception
          return y if y
          raise RetryCountExceeded if retries+1 >= tries
          wait(opts[:sleep], retries, on_exception)
          retries += 1
        end
      rescue *on_exception => exception
        raise unless exception.message =~ opts[:matching]
        raise if retries+1 >= tries

        wait(opts[:sleep], retries, on_exception, exception)

        retries += 1
        retry_exception = exception
        retry
      ensure
        opts[:ensure].call(retries)
      end
    end

    def wait(sleeper, retries, exceptions, exception=nil)
      sleep sleeper.respond_to?(:call) ? sleeper.call(retries, exception) : sleeper
    rescue *exceptions
      # SignalException could be raised while sleeping, so if you want to catch it,
      # it need to be passed in the list of exceptions to ignore
    end

    def exponential_sleeper
      lambda { |tries, _| [2**(tries-1), 10].min } # 1, 2, 4, 8, 10, 10..10 seconds
    end

    module_function :retryable, :wait, :exponential_sleeper
  end
end
