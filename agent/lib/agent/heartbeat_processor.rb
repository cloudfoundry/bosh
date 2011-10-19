module Bosh::Agent
  class HeartbeatProcessor

    def enable(interval)
      unless EM.reactor_running?
        raise Bosh::Agent::HeartbeatError, "Event loop must be running in order to enable heartbeats"
      end

      if @timer
        Config.logger.warn("Heartbeat timer already running, canceling")
        disable
      end

      @pending = 0

      @timer = EM.add_periodic_timer(interval) do
        beat
      end
    end

    def disable
      Config.logger.info("Disabled heartbeats")
      @timer.cancel if @timer
      @timer = nil
    end

    def beat
      raise "outstanding heartbeats" if @pending > 0

      Heartbeat.new.send_via_mbus do
        @pending -= 1
      end
      @pending += 1
    rescue => e
      Config.logger.warn("Error sending heartbeat: #{e}")
      Config.logger.warn(e.backtrace.join("\n"))
    end

  end
end
