# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Agent

  # A good chunk of this code is lifted from the implementation of POSIX::Spawn::Child
  class Monit
    BUFSIZE = (32 * 1024)
    NUM_RETRY_MONIT_INCARNATION = 60
    NUM_RETRY_MONIT_WAIT_INCARNATION = 15

    class << self
      attr_accessor :enabled

      # enable supposed to be called in the very beginning as it creates
      # sync primitives. Ideally this class should be refactored to minimize
      # the number of singleton methods having to keep track of the state.
      def enable
        @enabled     = true
      end

      def start
        new.run
      end

      def base_dir
        Bosh::Agent::Config.base_dir
      end

      def logger
        Bosh::Agent::Config.logger
      end

      def monit_dir
        File.join(base_dir, 'monit')
      end

      def monit_events_dir
        File.join(monit_dir, 'events')
      end

      def monit_user_file
        File.join(monit_dir, 'monit.user')
      end

      def monit_alerts_file
        File.join(monit_dir, 'alerts.monitrc')
      end

      def smtp_port
        Bosh::Agent::Config.smtp_port
      end

      def monit_credentials
        entry = File.read(monit_user_file).lines.find { |line| line.match(/\A#{BOSH_APP_GROUP}/) }
        user, cred = entry.split(/:/)
        [user, cred.strip]
      end

      def monit_api_client
        # Primarily for CI - normally done during configure
        unless Bosh::Agent::Config.configure
          setup_monit_user
        end

        user, cred = monit_credentials
        MonitApi::Client.new("http://#{user}:#{cred}@localhost:2822", :logger => logger)
      end

      def random_credential
        OpenSSL::Random.random_bytes(8).unpack("H*")[0]
      end

      def setup_monit_dir
        FileUtils.mkdir_p(monit_dir)
        FileUtils.chmod(0700, monit_dir)
      end

      def setup_monit_user
        unless File.exist?(monit_user_file)
          setup_monit_dir
          File.open(monit_user_file, 'w') do |f|
            f.puts("vcap:#{random_credential}")
          end
        end
      end

      # This and other methods could probably be refactored into a separate management class to avoid keeping
      # all this state in a metaclass (as it's weird to test)
      def setup_alerts
        return unless Config.process_alerts

        alerts_config = <<-CONFIG
        set alert bosh@localhost
        set mailserver 127.0.0.1 port #{Config.smtp_port}
            username "#{Config.smtp_user}" password "#{Config.smtp_password}"

        set eventqueue
            basedir #{monit_events_dir}
            slots 5000

        set mail-format {
          from: monit@localhost
          subject: Monit Alert
          message: Service: $SERVICE
          Event: $EVENT
          Action: $ACTION
          Date: $DATE
          Description: $DESCRIPTION
        }
        CONFIG

        setup_monit_dir
        FileUtils.mkdir_p(monit_events_dir)

        File.open(monit_alerts_file, 'w') do |f|
          f.puts(alerts_config)
        end
      end

      def monit_bin
        File.join(base_dir, 'bosh', 'bin', 'monit')
      end

      def monitrc
        File.join(base_dir, 'bosh', 'etc', 'monitrc')
      end

      def reload
        old_incarnation = incarnation
        logger.info("Monit: old incarnation #{old_incarnation}")

        monit_reload_cmd
        logger.info("Monit: reload")

        monit_reload_incarnation_retry.times do |n|
          check_incarnation = incarnation
          if old_incarnation < check_incarnation
            logger.info("Monit: updated incarnation #{check_incarnation}")
            return
          end

          # Backoff a bit on the retry
          sleep n * monit_reload_incarnation_base_sleep
        end

        # If we ever get here we have failed to get the new incarnation
        raise StateError, "Failed to get updated incarnation from Monit"
      end

      def monit_reload_cmd
        # Exit code and output has no usable output
        `#{monit_bin} reload`
      end

      def monit_reload_incarnation_retry
        NUM_RETRY_MONIT_WAIT_INCARNATION
      end

      def monit_reload_incarnation_base_sleep
        0.1
      end

      def unmonitor_services(attempts=10)
        retry_monit_request(attempts) do |client|
          client.unmonitor(:group => BOSH_APP_GROUP)
        end
      end

      def monitor_services(attempts=10)
        retry_monit_request(attempts) do |client|
          client.monitor(:group => BOSH_APP_GROUP)
        end
      end

      def start_services(attempts=20)
        retry_monit_request(attempts) do |client|
          client.start(:group => BOSH_APP_GROUP)
        end
      end

      def stop_services(attempts=20)
        retry_monit_request(attempts) do |client|
          client.stop(:group => BOSH_APP_GROUP)
        end
      end

      def retry_monit_request(attempts=10)
        # HACK: Monit becomes unresponsive after reload
        begin
          yield monit_api_client if block_given?
        rescue Errno::ECONNREFUSED, TimeoutError
          sleep 1
          logger.info("Monit Service Connection Refused: retrying")
          retry if (attempts -= 1) > 0
        rescue => e
          messages = [
            "Connection reset by peer",
            "Service Unavailable"
          ]
          if messages.include?(e.message)
            logger.info("Monit Service Unavailable (#{e.message}): retrying")
            sleep 1
            retry if (attempts -= 1) > 0
          end
          raise e
        end
      end

      def incarnation
        NUM_RETRY_MONIT_INCARNATION.times do
          info = monit_info
          if info && info[:incarnation]
            return info[:incarnation].to_i
          end
          sleep 1
        end

        # If we ever get here we have failed to get incarnation
        raise StateError, "Failed to get incarnation from Monit"
      end

      def monit_info
        retry_monit_request { |client| client.monit_info }
      end

      def get_status(num_retries=10)
        return {} unless @enabled
        retry_monit_request(num_retries) do |client|
          client.status(:group => BOSH_APP_GROUP)
        end
      end

      def get_system_status(num_retries=10)
        return {} unless @enabled
        retry_monit_request(num_retries) do |client|
          system_status = client.status(:type => :system)
          return {} unless system_status.is_a?(Hash)
          system_status.values.first
        end
      end

      def get_vitals(num_retries=10)
        return {} unless @enabled
        status = get_system_status(num_retries)
        return {} unless status.is_a?(Hash)

        raw_data = status[:raw] || {}
        sys_data = raw_data["system"] || {}
        loadavg = sys_data["load"] || {}
        cpu = sys_data["cpu"] || {}
        mem = sys_data["memory"] || {}
        swap = sys_data["swap"] || {}

        {
          "load" => [ loadavg["avg01"], loadavg["avg05"], loadavg["avg15"] ],
          "cpu" => { "user" => cpu["user"], "sys" => cpu["system"], "wait" => cpu["wait"] },
          "mem" => { "percent" => mem["percent"], "kb" => mem["kilobyte"] },
          "swap" => { "percent" => swap["percent"], "kb" => swap["kilobyte"] }
        }
      end

      def service_group_state(num_retries=10)
        # FIXME: state should be unknown if monit is disabled
        # However right now that would break director interaction
        # (at least in integration tests)
        return "running" unless @enabled
        status = get_status(num_retries)

        not_running = status.reject do |name, data|
          # break early if any service is initializing
          return "starting" if data[:monitor] == :init
          # at least with monit_api a stopped services is still running
          (data[:monitor] == :yes && data[:status][:message] == "running")
        end

        not_running.empty? ? "running" : "failing"
      rescue => e
        logger.info("Unable to determine job state: #{e}")
        "unknown"
      end

    end

    def initialize
      @logger = Bosh::Agent::Config.logger
    end

    def run
      Thread.new { exec_monit }
    end

    def exec_monit
      status = nil

      pid, stdin, stdout, stderr = POSIX::Spawn.popen4(Monit.monit_bin, '-I', '-c', Monit.monitrc)
      stdin.close

      at_exit {
        Process.kill('TERM', pid) rescue nil
        Process.waitpid(pid)      rescue nil
      }

      log_monit_output(stdout, stderr)

      status = Process.waitpid(pid) rescue nil
    rescue => e
      # TODO: send alert to HM
      @logger.error("Failed to run Monit: #{e.inspect} #{e.backtrace}")

      [stdin, stdout, stderr].each { |fd| fd.close rescue nil }

      if status.nil?
        Process.kill('TERM', pid) rescue nil
        Process.waitpid(pid)      rescue nil
      end

      raise
    ensure
      [stdin, stdout, stderr].each { |fd| fd.close rescue nil }
    end

    def log_monit_output(stdout, stderr)
      timeout = nil
      out, err = '', ''
      readers = [stdout, stderr]
      writers = []

      while readers.any?
        ready = IO.select(readers, writers, readers + writers, timeout)
        ready[0].each do |fd|
          buf = (fd == stdout) ? out : err
          begin
            buf << fd.readpartial(BUFSIZE)
          rescue Errno::EAGAIN, Errno::EINTR
          rescue EOFError
            readers.delete(fd)
            fd.close
          end
          buf.gsub!(/\n\Z/,'')
          @logger.info("Monit: #{buf}")
        end
        out, err = '', ''
      end

    end

  end
end

