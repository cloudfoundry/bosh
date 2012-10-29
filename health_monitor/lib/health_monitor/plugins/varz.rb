module Bosh::HealthMonitor
  module Plugins
    class Varz < Base
      def initialize(options = {})
        @agents = {}
        super
      end

      def run
        logger.info("Varz plugin is running...")
      end

      def process(event)
        @agents[event.kind] ||= {}
        @agents[event.kind][event.attributes["agent_id"].to_s] = event.to_hash
        Bhm.set_varz("last_agents_" + event.kind.to_s, @agents[event.kind])
      end
    end
  end
end