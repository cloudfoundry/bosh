module Bosh::Spec
  # HealthMonitor provides information from the operator perspective.
  class HealthMonitor
    def initialize(logs_path, logger)
      @logs_path = logs_path
      @logger = logger
    end

    def read_log
      File.read(File.join(@logs_path, 'health_monitor.log'))
    end
  end
end
