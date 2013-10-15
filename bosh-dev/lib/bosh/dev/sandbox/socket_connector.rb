require 'socket'
require 'bosh/dev'

module Bosh::Dev::Sandbox
  class SocketConnector
    def initialize(host, port, logger)
      @addr = Socket.pack_sockaddr_in(port, host)
      @logger = logger
    end

    def try_to_connect(remaining_attempts = 20)
      remaining_attempts -= 1
      socket = Socket.new(Socket::Constants::AF_INET, Socket::Constants::SOCK_STREAM, 0)
      socket.connect(@addr)
    rescue Errno::ECONNREFUSED, Errno::ETIMEDOUT
      raise if remaining_attempts == 0
      sleep(0.2) # unfortunate fine-tuning required here
      retry
    end
  end
end
