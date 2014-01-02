require 'socket'
require 'timeout'
require 'bosh/dev'

module Bosh::Dev::Sandbox
  class SocketConnector
    def initialize(host, port, logger)
      @host = host
      @port = port
      @logger = logger
    end

    def try_to_connect(remaining_attempts = 40)
      remaining_attempts -= 1
      Timeout.timeout(1) { TCPSocket.new(@host, @port).close }
    rescue Timeout::Error, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ETIMEDOUT => e
      raise if remaining_attempts == 0
      @logger.info("Failed to connect: #{e.inspect} host=#{@host} port=#{@port} remaining_attempts=#{remaining_attempts}")
      sleep(0.2) # unfortunate fine-tuning required here
      retry
    end
  end
end
