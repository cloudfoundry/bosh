require 'net/http'
require 'timeout'

module IntegrationSupport
  class HTTPEndpointConnector
    class MissingContent < StandardError; end

    def initialize(service_name, host, port, endpoint, expected_content, log_location, logger)
      @service_name = service_name
      @host = host
      @port = port
      @endpoint = endpoint
      @expected_content = expected_content
      @logger = logger
      @log_location = log_location
    end

    def try_to_connect(remaining_attempts = 80)
      @logger.info("Waiting for #{@service_name} to come up on #{@host}:#{@port} (logs at #{@log_location}*)")
      uri = URI("http://#{@host}:#{@port}#{@endpoint}")

      begin
        remaining_attempts -= 1
        result = Timeout.timeout(2) { Net::HTTP.get(uri) }
        if !@expected_content.empty? && !result.to_s.include?(@expected_content)
          raise MissingContent.new("Expected to find '#{@expected_content}' in '#{result}'")
        end
        @logger.info("Connected to #{@service_name} at http://#{@host}:#{@port}#{@endpoint} (logs at #{@log_location}*)")
      rescue Timeout::Error, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::EADDRNOTAVAIL, Errno::ETIMEDOUT, MissingContent => e
        if remaining_attempts == 0
          @logger.error("Failed to connect to #{@service_name}: #{e.inspect} host=#{@host} port=#{@port}")
          raise
        end

        sleep(0.2) # unfortunate fine-tuning required here

        retry
      end
    end
  end
end
