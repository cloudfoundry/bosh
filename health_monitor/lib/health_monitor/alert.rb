module Bosh::HealthMonitor

  class Alert
    attr_accessor :component, :severity, :timestamp, :details
  end

end
