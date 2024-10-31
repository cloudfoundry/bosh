module IntegrationSupport
  # HealthMonitor provides information from the operator perspective.
  class HealthMonitor
    def initialize(health_monitor_process, logger)
      @health_monitor_process = health_monitor_process
      @logger = logger
    end

    def read_log
      @health_monitor_process.stdout_contents
    end
  end
end
