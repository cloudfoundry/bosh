require 'net/http'
require 'timeout'
require 'bosh/dev'

module Bosh::Dev::Sandbox
  class HTTPEndpointConnector
    def initialize(service_name, host, port, endpoint, log_location, logger)
      @service_name = service_name
      @host = host
      @port = port
      @endpoint = endpoint
      @logger = logger
      @log_location = log_location
    end

    def try_to_connect(remaining_attempts = 80)
      @logger.info("Waiting for #{@service_name} to come up on #{@host}:#{@port} (logs at #{@log_location}*)")

      uri = URI("http://#{@host}:#{@port}#{@endpoint}")
      begin
        remaining_attempts -= 1
        Timeout.timeout(1) { Net::HTTP.get(uri) }
        @logger.info("Connected to #{@service_name} at http://#{@host}:#{@port}#{@endpoint} (logs at #{@log_location}*)")
      rescue Timeout::Error, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ETIMEDOUT => e
        if remaining_attempts == 0
          @logger.error(
            "Failed to connect to #{@service_name}: #{e.inspect} " +
              "host=#{@host} port=#{@port}")
          raise
        end

        sleep(0.2) # unfortunate fine-tuning required here

        retry
      end
    end
  end
end
