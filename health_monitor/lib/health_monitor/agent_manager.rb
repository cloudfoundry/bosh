module Bosh::HealthMonitor

  class AgentManager

    attr_reader :heartbeats_received

    def initialize
      alert_plugin  = Bhm.alert_plugin || :email
      alert_options = Bhm.alert_options

      @agents = { }
      @agents_by_deployment = { }

      @logger = Bhm.logger
      @heartbeats_received = 0

      @alert_processor = AlertProcessor.find(alert_plugin, alert_options)
    end

    def setup_subscriptions
      # TODO: handle errors
      # TODO: handle missing agent

      Bhm.nats.subscribe("hm.agent.heartbeat.*") do |message, reply, subject|
        @heartbeats_received += 1
        agent_id = subject.split('.').last
        @logger.info("Received heartbeat from #{agent_id}: #{message}")
        @agents[agent_id] ||= { "id" => agent_id }
        @agents[agent_id]["state"] = message
      end

      Bhm.nats.subscribe("hm.agent.alert.*") do |message, reply, subject|
        agent_id = subject.split('.').last
        @logger.info("Received alert from `#{agent_id}': #{message}")
        process_alert(message)
      end
    end

    def agents_count
      @agents.size
    end

    def process_alert(raw_alert)
      @alert_processor.process(raw_alert)
    end

    def update_agent(deployment_name, agent_id)
      @agents[agent_id] = { "id" => agent_id } # TODO: make agent a first class object

      @agents_by_deployment[deployment_name] ||= [ ]
      @agents_by_deployment[deployment_name] << agent_id
    end

    def each_agent(&blk)
      @agents_by_deployment.each_pair do |deployment_name, agent_ids|
        agent_ids.each do |agent_id|
          yield @agents[agent_id]
        end
      end
    end
  end

end
