module Bosh::Agent
  class SshdMonitor
    extend Bosh::Exec

    class << self
      def ok_to_stop?
        Config.sshd_monitor_enabled && @start_time && (Time.now - @start_time) > @start_delay
      end

      def test_service(status)
        success = false
        3.times do |_|
          result = sh("service ssh start 2>&1")
          success = result.ok? && result.stdout =~ /#{status}/
          break if success
          sleep 1
        end
        success
      end

      def start_sshd
        @lock.synchronize do
          result = sh("service ssh start 2>&1")
          if result.failed? && !test_service("running")
            raise "Failed to start sshd #{result.stdout}"
          end

          @start_time = Time.now
          @logger.info("started sshd #{@start_time}")
        end
      end

      def stop_sshd
        @lock.synchronize do
          return if !ok_to_stop?
          # No need to check for logged in users as existing ssh connections are not
          # affected by stopping ssh
          @logger.info("stopping sshd")

          result = sh("service ssh stop 2>&1")
          raise "Failed to stop sshd" if result.failed? && !test_service("stop")
          @start_time = nil
        end
      end

      def enable(interval, start_delay)
        @logger = Config.logger
        @lock = Mutex.new
        @start_time = nil
        @start_delay = start_delay

        EventMachine.add_periodic_timer(interval) do
          EventMachine.defer { stop_sshd } if SshdMonitor.ok_to_stop?
        end
      end
    end
  end
end
