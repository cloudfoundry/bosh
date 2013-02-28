# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Agent
  class SshdMonitor
    class << self
      def ok_to_stop?
        Config.sshd_monitor_enabled && @start_time && (Time.now - @start_time) > @start_delay
      end

      def platform
        Bosh::Agent::Config.platform
      end

      def start_sshd
        @lock.synchronize do
          platform.start_ssh_and_wait
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

          platform.stop_ssh_and_wait
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
