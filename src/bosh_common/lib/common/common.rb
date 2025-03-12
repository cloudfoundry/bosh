require 'common/retryable'

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

    # Retries execution of given block until block returns true
    #
    # The block is called with two parameters: the number of tries and the most recent
    # exception. If the block returns true retrying is stopped.
    # Examples:
    #   Bosh::Common.retryable do |retries, exception|
    #     puts "try #{retries} failed with exception: #{exception}" if retries > 0
    #     pick_up_soap
    #   end
    #
    #   # Wait for EC2 instance to be terminated
    #   Bosh::Common.retryable(on: AWS::EC2::Errors::RequestLimitExceeded) do |retries, exception|
    #     @ec2.instance['i-a3x5g5'].status == :terminated
    #   end
    #
    #
    # @param [Hash] options
    # @options opts [Proc] :ensure
    #   Default: `Proc.new {}`
    #   Ensure that a block of code is executed, regardless of whether an exception
    #   was raised. It doesn't matter if the block exits normally, if it retries
    #   to execute block of code, or if it is terminated by an uncaught exception
    #   -- the ensure block will get run.
    #   Example:
    #   f = File.open("testfile")
    #
    #   ensure_cb = Proc.new do |retries|
    #     puts "total retry attempts: #{retries}"
    #
    #     f.close
    #  end
    #
    #  Bosh::Common.retryable(ensure: ensure_cb) do
    #    # process file
    #  end
    #
    # @options opts [Regexp] :matching
    #   Default: `/.*/`
    #   Retry based on the exception message
    #   Example:
    #   Bosh::Common.retryable(matching: /IO timeout/) do |retries, exception|
    #     raise "yo, IO timeout!" if retries == 0
    #   end
    #
    # @options opts [Array<ExceptionClass>] :on
    #   Default: `[]`
    #   The array of exception classes to retry on.
    #   Example:
    #   Bosh::Common.retryable(on: [StandardError, ArgumentError]) do
    #     # do something and retry if StandardError or ArgumentError is raised
    #   end
    #
    # @options opts [Proc, Fixnum] :sleep
    #   Defaults: `lambda { |tries, _| [2**(tries-1), 10].min }`,  1, 2, 4, 8, 10, 10..10 seconds
    #   If a Fixnum is given, sleep that many seconds between retries.
    #   If a Proc is given, call it with the expectation that a Fixnum is returned
    #   and sleep that many seconds. The Proc will be called with the number of tries
    #   and the raised exception (or nil)
    #   Example:
    #   Bosh::Common.retryable(sleep: lambda { |n,e| logger.info(e.message) if e; 4**n }) { }
    #
    # @options opts [Fixnum] :tries
    #   Default: 2
    #   Number of times to try
    #   Example:
    #   Bosh::Common.retryable(tries: 3, on: OpenURI::HTTPError) do
    #     xml = open("http://example.com/test.xml").read
    #   end
    #
    def retryable(options = {}, &block)
      Bosh::Retryable.new(options).retryer(&block)
    end

    module_function :retryable
  end
end
