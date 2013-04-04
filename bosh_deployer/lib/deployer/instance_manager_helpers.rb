# Copyright (c) 2009-2012 VMware, Inc.

require 'net/ssh'

module Bosh::Deployer

  module InstanceManagerHelpers

    def process_exists?(pid)
      begin
        Process.kill(0, pid)
      rescue Errno::ESRCH
        false
      end
    end

    def socket_readable?(ip, port)
      socket = TCPSocket.new(ip, port)
      if IO.select([socket], nil, nil, 5)
        logger.debug("tcp socket #{ip}:#{port} is readable")
        yield
        true
      else
        false
      end
    rescue SocketError => e
      logger.debug("tcp socket #{ip}:#{port} SocketError: #{e.inspect}")
      sleep 1
      false
    rescue SystemCallError => e
      logger.debug("tcp socket #{ip}:#{port} SystemCallError: #{e.inspect}")
      sleep 1
      false
    ensure
      socket.close if socket
    end

    def remote_tunnel(port)
      tunnel(port, :remote)
    end

    def local_tunnel(port)
      tunnel(port, :local)
    end

    private

    def tunnel(port, direction)
      @sessions ||= {}
      return if @sessions[port]

      ip = discover_bosh_ip

      loop until socket_readable?(ip, @ssh_port) do
        #sshd is up, sleep while host keys are generated
        sleep @ssh_wait
      end

      if @sessions[port].nil?
        logger.info("Starting SSH session for port forwarding to #{@ssh_user}@#{ip}...")
        loop do
          begin
            @sessions[port] = Net::SSH.start(ip, @ssh_user, :keys => [@ssh_key],
                                      :paranoid => false)
            logger.debug("ssh #{@ssh_user}@#{ip}: ESTABLISHED")
            break
          rescue => e
            logger.debug("ssh start #{@ssh_user}@#{ip} failed: #{e.inspect}")
            sleep 1
          end
        end
      end

      lo = "127.0.0.1"
      case direction
      when :remote
        @sessions[port].forward.remote(port, lo, port)
      when :local
        @sessions[port].forward.local(port, lo, port)
      else
        raise ArgumentError, "Invalid direction for ssh tunnel: #{direction}"
      end

      logger.info("SSH #{direction} forwarding for port #{port} started: OK")

      Thread.new do
        while @sessions[port]
          begin
            @sessions[port].loop { true }
          rescue IOError => e
            logger.debug("SSH session #{@sessions[port].inspect} forwarding for port #{port} terminated: #{e.inspect}")
            @sessions.delete(port)
          end
        end
      end
    end
  end
end
