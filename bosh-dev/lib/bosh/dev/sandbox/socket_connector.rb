require 'socket'
require 'timeout'
require 'bosh/dev'

module Bosh::Dev::Sandbox
  class SocketConnector
    def initialize(service_name, host, port, logger)
      @service_name = service_name
      @host = host
      @port = port
      @logger = logger
    end

    def try_to_connect(remaining_attempts = 40)
      @logger.info("Waiting for #{@service_name} to come up on #{@host}:#{@port}")

      begin
        remaining_attempts -= 1
        Timeout.timeout(1) { TCPSocket.new(@host, @port).close }
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
