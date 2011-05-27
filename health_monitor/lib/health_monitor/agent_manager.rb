module Bosh::HealthMonitor

  class AgentManager
    # TODO: make threadsafe? Not supposed to be deferred though...

    attr_reader :heartbeats_received, :alerts_received, :alerts_processed

    def initialize
      @agents = { }
      @agents_by_deployment = { }

      @logger = Bhm.logger
      @heartbeats_received = 0
      @alerts_received     = 0
      @alerts_processed    = 0

      @alert_processor = AlertProcessor.new
    end

    def lookup_delivery_agent(options)
      plugin = options["plugin"].to_s

      case plugin
      when "email"
        EmailDeliveryAgent.new(options)
      when "logger"
        LoggingDeliveryAgent.new(options)
      when "pagerduty"
        PagerdutyDeliveryAgent.new(options)
      else
        raise DeliveryAgentError, "Cannot find delivery agent plugin `#{plugin}'"
      end
    end

    def setup_events
      Bhm.alert_delivery_agents.each do |agent_options|
        @alert_processor.add_delivery_agent(lookup_delivery_agent(agent_options))
      end

      Bhm.nats.subscribe("hm.agent.heartbeat.*") do |heartbeat_json, reply, subject|
        @heartbeats_received += 1
        agent_id = subject.split('.', 4).last
        @logger.debug("Received heartbeat from #{agent_id}")
        process_heartbeat(agent_id, heartbeat_json)
      end

      Bhm.nats.subscribe("hm.agent.alert.*") do |message, reply, subject|
        @alerts_received += 1
        agent_id = subject.split('.', 4).last
        @logger.info("Received alert from `#{agent_id}': #{message}")
        process_alert(agent_id, message)
      end

      Bhm.nats.subscribe("hm.agent.shutdown.*") do |message, reply, subject|
        agent_id = subject.split('.', 4).last
        process_shutdown(agent_id, message)
      end
    end

    def agents_count
      @agents.size
    end

    # Processes VM data from Bosh Director,
    # extracts relevant agent data, wraps it into Agent object
    # and adds it to a list of managed agents.
    def add_agent(deployment_name, vm_data)
      unless vm_data.kind_of?(Hash)
        @logger.error("Invalid format for VM data: expected Hash, got #{vm_data.class}: #{vm_data}")
        return false
      end

      agent_id = vm_data["agent_id"]

      if agent_id.nil? # TODO: alert?
        @logger.warn("No agent id for VM: #{vm_data}")
        return false
      end

      agent = @agents[agent_id]

      if agent.nil?
        @logger.debug("Discovered agent #{agent_id}")
        @agents[agent_id] = Agent.new(agent_id, deployment_name, vm_data["job"], vm_data["index"])
      else
        agent.deployment = deployment_name
        agent.job        = vm_data["job"]
        agent.index      = vm_data["index"]
      end

      @agents_by_deployment[deployment_name] ||= Set.new
      @agents_by_deployment[deployment_name] << agent_id
      true
    end

    def analyze_agents
      @logger.info "Analyzing agents..."
      started = Time.now

      processed = Set.new
      count = 0

      # Agents from managed deployments
      @agents_by_deployment.each_pair do |deployment_name, agent_ids|
        agent_ids.each do |agent_id|
          analyze_agent(agent_id)
          processed << agent_id
          count += 1
        end
      end

      # Rogue agents (hey there Solid Snake)
      (@agents.keys.to_set - processed).each do |agent_id|
        @logger.warn("Agent #{agent_id} is not a part of any deployment")
        analyze_agent(agent_id)
        count += 1
      end

      @logger.info("Analyzed %s, took %s seconds" % [ pluralize(count, "agent"), Time.now - started ])
      count
    end

    def analyze_agent(agent_id)
      agent = @agents[agent_id]
      ts    = Time.now.to_i

      if agent.nil?
        @logger.error("Agent #{agent_id} is missing from agents index, skipping...")
        return false
      end

      if agent.timed_out?
        alert = {
          :id         => "timeout-#{agent.id}-#{ts}",
          :severity   => 2,
          :source     => agent.name,
          :title      => "#{agent.id} has timed out",
          :created_at => ts
        }

        register_alert(alert)
      end

      if agent.rogue?
        alert = {
          :id         => "rogue-#{agent.id}-#{ts}",
          :severity   => 2,
          :source     => agent.name,
          :title      => "#{agent.id} is not a part of any deployment",
          :created_at => ts
        }

        register_alert(alert)
      end

      true
    end

    def register_alert(alert)
      @alert_processor.register_alert(alert)
    end

    # Subscription callbacks
    def process_alert(agent_id, alert_json)
      agent = @agents[agent_id]

      if agent.nil?
        @logger.warn("Received an alert from an unmanaged agent: #{agent_id}")
        agent = Agent.new(agent_id)
        @agents[agent_id] = agent
      end

      alert = Yajl::Parser.parse(alert_json)

      if alert.is_a?(Hash) && !alert.has_key?("source")
        alert["source"] = agent.name
      end

      if register_alert(alert)
        @alerts_processed += 1
      end

    rescue Yajl::ParseError => e
      @logger.error("Cannot parse incoming alert: #{e}")
    rescue Bhm::InvalidAlert => e
      @logger.error(e)
    end


    def process_shutdown(agent_id, shutdown_payload = nil)
      agent = @agents[agent_id]
      # Agent sends shutdown message several times, so we
      # earlier if we know this agent is no longer managed
      # to avoid flooding logs with the same message
      return if agent.nil?
      @logger.info("Agent `#{agent_id}' shutting down...")

      @agents.delete(agent_id)
      @agents_by_deployment.each_pair do |deployment, agents|
        agents.delete(agent_id)
      end
    end

    def process_heartbeat(agent_id, heartbeat_payload)
      agent = @agents[agent_id]

      if agent.nil?
        @logger.warn("Received a heartbeat from an unmanaged agent: #{agent_id}")
        agent = Agent.new(agent_id)
        @agents[agent_id] = agent
      end

      agent.process_heartbeat(heartbeat_payload)
    end

  end
end
