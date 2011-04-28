module Bosh::HealthMonitor

  class DeploymentManager

    def initialize
      @deployments = { }
    end

    def deployments_count
      @deployments.size
    end

    def update_deployment(name, data)
      @deployments[name] = data
    end

  end

end
