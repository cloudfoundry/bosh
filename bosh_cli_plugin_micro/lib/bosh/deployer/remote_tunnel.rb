require 'bosh/deployer/ssh_server'

module Bosh::Deployer
  class RemoteTunnel
    def initialize(ssh_server, wait, logger)
      @ssh_server = ssh_server
      @wait = wait
      @logger = logger
    end

    def create(ip, port)
      return if sessions[port]

      loop until ssh_server.readable?(ip)

      # sshd is up, sleep while host keys are generated
      Kernel.sleep(wait)

      loop do
        session = ssh_server.start_session(ip)

        if session
          sessions[port] = session
          break
        end
      end

      sessions[port].forward.remote(port, '127.0.0.1', port)
      logger.info("SSH forwarding for port #{port} started: OK")

      monitor_session(port)
      cleanup_at_exit
    end

    private

    attr_reader :ssh_server, :wait, :logger

    def monitor_session(port)
      Thread.new do
        while sessions[port]
          begin
            sessions[port].loop { true }
          rescue IOError => e
            logger.debug(
              "SSH session #{sessions[port].inspect} " +
                "forwarding for port #{port} terminated: #{e.inspect}"
            )
            sessions.delete(port)
          end
        end
      end
    end

    def cleanup_at_exit
      Kernel.at_exit do
        status = $!.is_a?(::SystemExit) ? $!.status : nil
        close_ssh_sessions
        exit status if status
      end
    end

    def close_ssh_sessions
      sessions.each_value { |s| s.close }
    end

    def sessions
      @sessions ||= {}
    end
  end
end
