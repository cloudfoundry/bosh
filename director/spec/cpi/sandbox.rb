# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director::Cpi
  class Sandbox
    NATS_PID        = File.join("/tmp", "cpi-nats.pid")
    NATS_PORT       = 4222

    class << self
      def start
        run_with_pid("nats-server -p #{NATS_PORT}", NATS_PID)
        test_config = YAML.load(spec_asset("test-cpi-config.yml"))
        test_config["cloud"]["properties"]["mbus"] = "nats://localhost:#{NATS_PORT}"
        test_config["mbus"] = "nats://localhost:#{NATS_PORT}"
        test_config
      end

      def stop
        kill_process(NATS_PID)
      end

      def start_nats_tunnel(vm_ip)
        pid_file = File.join("/tmp", "cpi-nats-tunnel-#{rand(1000)}.pid")
        cmd = "sshpass -p 'ca$hc0w'  ssh -R #{NATS_PORT}:localhost:#{NATS_PORT} -o \"UserKnownHostsFile /dev/null\" -o StrictHostKeyChecking=no -N root@#{vm_ip}"
        run_with_pid(cmd, pid_file)
        pid_file
      end

      def stop_nats_tunnel(pid_file)
        kill_process(pid_file)
      end

      private
      def run_with_pid(cmd, pidfile, opts = {})
        env = opts[:env] || {}
        output = opts[:output] || "/dev/null"

        unless process_running?(pidfile)
          pid = fork do
            $stdin.reopen("/dev/null")
            [ $stdout, $stderr ].each { |stream| stream.reopen(output, "w") }
            env.each_pair { |k, v| ENV[k] = v }
            exec cmd
          end

          Process.detach(pid)
          File.open(pidfile, "w") { |f| f.write(pid) }

          tries = 0

          while !process_running?(pidfile)
            tries += 1
            raise RuntimeError, "Cannot run '#{cmd}' with #{env.inspect}" if tries > 5
            sleep(1)
          end
        end
      end

      def process_running?(pidfile)
        begin
          File.exists?(pidfile) && Process.kill(0, File.read(pidfile).to_i)
        rescue Errno::ESRCH
          FileUtils.rm pidfile
          false
        end
      end

      def kill_process(pidfile, signal="TERM")
        return unless process_running?(pidfile)
        pid = File.read(pidfile).to_i

        Process.kill(signal, pid)
        sleep(1) while process_running?(pidfile)

      rescue Errno::ESRCH
        puts "Not found process with PID=#{pid} (pidfile #{pidfile})"
      ensure
        FileUtils.rm_rf pidfile
      end
    end
  end
end
