module Bosh::Monitor
  module Plugins
    class Varz < Base
      def run
        logger.info("Varz plugin is running...")
      end

      def process(event)
        @agents ||= {}
        @agents[event.kind] ||= {}
        agent_id = event.attributes["agent_id"] || "unknown"
        @agents[event.kind][agent_id.to_s] = event.to_hash
        Bhm.set_varz("last_agents_" + event.kind.to_s, @agents[event.kind])
      end
    end
  end
end
