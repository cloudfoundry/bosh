module Bosh::HealthMonitor

  class AgentManager

    attr_reader :heartbeats_received

    def initialize
      alert_plugin  = Bhm.alert_plugin || :email
      alert_options = Bhm.alert_options

      @agents = { }
      @agent_ids = Set.new
      @agents_by_deployment = { }

      @logger = Bhm.logger
      @heartbeats_received = 0

      @alert_processor = AlertProcessor.new
      @alert_processor.add_delivery_agent(EmailDeliveryAgent.new(alert_options))
      @alert_processor.add_delivery_agent(LoggingDeliveryAgent.new)
    end

    def setup_subscriptions
      Bhm.nats.subscribe("hm.agent.heartbeat.*") do |heartbeat_json, reply, subject|
        @heartbeats_received += 1
        # TODO if there are more than 4 parts it's a bogus heartbeat, should ignore it
        agent_id = subject.split('.').last
        @logger.debug("Received heartbeat from #{agent_id}: #{heartbeat_json}")
        process_heartbeat(agent_id, heartbeat_json)
      end

      Bhm.nats.subscribe("hm.agent.alert.*") do |message, reply, subject|
        # TODO if there are more than 4 parts it's a bogus alert, should ignore it
        agent_id = subject.split('.').last
        @logger.info("Received alert from `#{agent_id}': #{message}")
        process_alert(message)
      end
    end

    def agents_count
      @agents.size
    end

    def add_agent(deployment_name, agent_id)
      agent = @agents[agent_id]

      if agent.nil?
        @logger.debug("Discovered agent #{agent_id}")
        @agents[agent_id] = Agent.new(agent_id)
      else
        agent.updated_at = Time.now
      end

      @agent_ids << agent_id
      @agents_by_deployment[deployment_name] ||= Set.new
      @agents_by_deployment[deployment_name] << agent_id
    end

    def analyze_agents
      @logger.info "Analyzing agents..."
      started = Time.now

      processed = Set.new

      # Agents from managed deployments
      @agents_by_deployment.each_pair do |deployment_name, agent_ids|
        agent_ids.each do |agent_id|
          analyze_agent(agent_id)
          processed << agent_id
        end
      end

      # Rogue agents (hey there Solid Snake)
      (@agent_ids - processed).each do |agent_id|
        @logger.warn("Agent #{agent_id} is not a part of any deployment")
        # TODO: alert?
        analyze_agent(agent_id)
      end

      @logger.info("Finished analyzing agents, took %s seconds" % [ Time.now - started ])
    end

    def analyze_agent(agent_id)
      agent = @agents[agent_id]
      if agent.nil?
        @logger.error("Agent #{agent_id} is missing from agents index, skipping...")
      else
        agent.analyze
      end
    end

    # Subscription callbacks
    def process_alert(raw_alert)
      @alert_processor.process(raw_alert)
    end

    def process_heartbeat(agent_id, heartbeat_json)
      agent = @agents[agent_id]
      if agent.nil?
        # TODO: alert?
        @logger.warn("Received a heartbeat from an unmanaged agent #{agent_id}")
        agent = Agent.new(agent_id)
        agent.process_heartbeat(heartbeat_json)
        @agents[agent_id] = agent
      else
        agent.process_heartbeat(heartbeat_json)
      end
    end

  end
end
