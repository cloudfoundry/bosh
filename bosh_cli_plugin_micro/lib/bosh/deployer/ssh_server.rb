require 'net/ssh'

module Bosh::Deployer
  class SshServer
    def initialize(user, key, port, logger)
      @user = user
      @key = key
      @port = port
      @logger = logger
    end

    SSH_EXCEPTIONS = [
      Net::SSH::AuthenticationFailed,
      Net::SSH::ConnectionTimeout,
      Net::SSH::Disconnect,
      Net::SSH::HostKeyError,
    ]

    def readable?(ip)
      socket = TCPSocket.new(ip, port)
      if IO.select([socket], nil, nil, 5)
        logger.debug("tcp socket #{ip}:#{port} is readable")
        true
      else
        false
      end
    rescue SocketError, SystemCallError => e
      logger.debug("tcp socket #{ip}:#{port} #{e.inspect}")
      Kernel.sleep(1)
      false
    ensure
      socket.close if socket
    end

    def start_session(ip)
      logger.info("Starting SSH session for port forwarding to #{user}@#{ip}...")
      session = Net::SSH.start(ip, user, keys: [key], paranoid: false, port: port)
      logger.debug("ssh #{user}@#{ip}: ESTABLISHED")
      session
    rescue *SSH_EXCEPTIONS => e
      logger.debug("ssh start #{user}@#{ip} failed: #{e.inspect}")
      Kernel.sleep(1)
      return nil
    end

    private

    attr_reader :user, :key, :port, :logger
  end
end
