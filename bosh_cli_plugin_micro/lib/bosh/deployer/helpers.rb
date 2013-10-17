require 'net/ssh'

module Bosh::Deployer
  module Helpers
    DEPLOYMENTS_FILE = 'bosh-deployments.yml'

    def is_tgz?(path)
      File.extname(path) == '.tgz'
    end

    def cloud_plugin(config)
      err 'No cloud properties defined' if config['cloud'].nil?
      err 'No cloud plugin defined' if config['cloud']['plugin'].nil?

      config['cloud']['plugin']
    end

    def dig_hash(hash, *path)
      path.inject(hash) do |location, key|
        location.respond_to?(:keys) ? location[key] : nil
      end
    end

    def process_exists?(pid)
      Process.kill(0, pid)
    rescue Errno::ESRCH
      false
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

    # rubocop:disable MethodLength
    def remote_tunnel(port)
      @sessions ||= {}
      return if @sessions[port]

      ip = Config.bosh_ip

      # sshd is up, sleep while host keys are generated
      loop until socket_readable?(ip, @ssh_port) { sleep(@ssh_wait) }

      if @sessions[port].nil?
        logger.info("Starting SSH session for port forwarding to #{@ssh_user}@#{ip}...")
        loop do
          begin
            @sessions[port] = Net::SSH.start(ip, @ssh_user, keys: [@ssh_key], paranoid: false)
            logger.debug("ssh #{@ssh_user}@#{ip}: ESTABLISHED")
            break
          rescue => e
            logger.debug("ssh start #{@ssh_user}@#{ip} failed: #{e.inspect}")
            sleep 1
          end
        end
      end

      lo = '127.0.0.1'
      @sessions[port].forward.remote(port, lo, port)

      logger.info("SSH forwarding for port #{port} started: OK")

      Thread.new do
        while @sessions[port]
          begin
            @sessions[port].loop { true }
          rescue IOError => e
            logger.debug(
              "SSH session #{@sessions[port].inspect} " +
              "forwarding for port #{port} terminated: #{e.inspect}"
            )
            @sessions.delete(port)
          end
        end
      end

      at_exit do
        status = $!.is_a?(::SystemExit) ? $!.status : nil
        close_ssh_sessions
        exit status if status
      end
    end
    # rubocop:enable MethodLength

    def close_ssh_sessions
      @sessions.each_value { |s| s.close }
    end

    def strip_relative_path(path)
      path[/#{Regexp.escape File.join(Dir.pwd, '')}(.*)/, 1] || path
    end
  end
end
