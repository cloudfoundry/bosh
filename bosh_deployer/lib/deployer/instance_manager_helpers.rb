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

    def incoming_tunnel(port)
      tunnel(port, :incoming)
    end

    def outgoing_tunnel(port)
      tunnel(port, :outgoing)
    end

    private

    def tunnel(port, direction)
      @established_sessions ||= {}
      return if @session && @established_sessions[port]

      ip = discover_bosh_ip

      loop until socket_readable?(ip, @ssh_port) do
        #sshd is up, sleep while host keys are generated
        sleep @ssh_wait
      end

      lo = "127.0.0.1"
      cmd = "ssh -R #{port}:#{lo}:#{port} #{@ssh_user}@#{ip}"

      logger.info("Preparing for ssh tunnel: #{cmd}")
      loop do
        begin
          @session = Net::SSH.start(ip, @ssh_user, :keys => [@ssh_key],
                                    :paranoid => false)
          logger.debug("ssh #{@ssh_user}@#{ip}: ESTABLISHED")
          break
        rescue => e
          logger.debug("ssh start #{@ssh_user}@#{ip} failed: #{e.inspect}")
          sleep 1
        end
      end unless @session

      if direction == :incoming
        @session.forward.remote(port, lo, port)
      elsif direction == :outgoing
        @session.forward.local(port, lo, port)
      end

      @established_sessions[port] = true

      logger.info("`#{cmd}` started: OK")

      Thread.new do
        begin
          @session.loop { true }
        rescue IOError => e
          logger.debug("`#{cmd}` terminated: #{e.inspect}")
          @session = nil
        end
      end
    end

  end
end
