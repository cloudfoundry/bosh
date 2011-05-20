module Bosh::HealthMonitor

  class AlertProcessor

    def self.agent_available?(agent)
      [ "email", "logger" ].include?(agent.to_s)
    end

    def self.find_agent(agent, options = { })
      agent_plugin = \
      case agent.to_s
      when "email"
        Bosh::HealthMonitor::EmailDeliveryAgent
      else
        Bosh::HealthMonitor::LoggingDeliveryAgent
      end

      agent = agent_plugin.new(options)

      if agent.respond_to?(:validate_options) && !agent.validate_options
        raise DeliveryAgentError, "Invalid options for `#{agent.class}'"
      end

      agent
    end

  end

end
