module Bosh::HealthMonitor

  class AgentManager
    # TODO: make threadsafe? Not supposed to be deferred though...

    attr_reader :heartbeats_received, :alerts_received, :alerts_processed

    def initialize
      @agents = { }
      @deployments = { }

      @logger = Bhm.logger
      @heartbeats_received = 0
      @alerts_received     = 0
      @alerts_processed    = 0

      @alert_processor = AlertProcessor.new
      @event_publisher = EventPublisher.new
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
      when "nats"
        NatsDeliveryAgent.new(options)
      else
        raise DeliveryAgentError, "Cannot find delivery agent plugin `#{plugin}'"
      end
    end

    def setup_events
      @event_publisher.connect_to_mbus

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

    def deployments_count
      @deployments.size
    end

    # Syncs deployments list received from director
    # with HM deployments.
    # @param deployments Array list of deployments returned by director
    def sync_deployments(deployments)
      managed = Set.new(deployments.map { |d| d["name"] })
      all     = Set.new(@deployments.keys)

      (all - managed).each do |stale_deployment|
        @logger.warn("Found stale deployment #{stale_deployment}, removing...")
        remove_deployment(stale_deployment)
      end
    end

    def sync_agents(deployment, vms)
      managed_agent_ids = @deployments[deployment] || Set.new
      active_agent_ids  = Set.new

      vms.each do |vm|
        if add_agent(deployment, vm)
          active_agent_ids << vm["agent_id"]
        end
      end

      (managed_agent_ids - active_agent_ids).each do |agent_id|
        remove_agent(agent_id)
      end
    end

    def remove_deployment(name)
      agent_ids = @deployments[name]

      agent_ids.to_a.each do |agent_id|
        @agents.delete(agent_id)
      end

      @deployments.delete(name)
    end

    def remove_agent(agent_id)
      @agents.delete(agent_id)
      @deployments.each_pair do |deployment, agents|
        agents.delete(agent_id)
      end
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
      agent_cid = vm_data["cid"]

      if agent_id.nil? # TODO: alert?
        @logger.warn("No agent id for VM: #{vm_data}")
        return false
      end

      if vm_data["job"].nil? # Idle VMs, we don't care about them
        @logger.debug("VM with no job found: #{agent_id}")
        return false
      end

      agent = @agents[agent_id]

      if agent.nil?
        @logger.debug("Discovered agent #{agent_id}")
        agent = Agent.new(agent_id)
        @agents[agent_id] = agent
      end

      agent.deployment = deployment_name
      agent.job        = vm_data["job"]
      agent.index      = vm_data["index"]
      agent.cid        = vm_data["cid"]

      @deployments[deployment_name] ||= Set.new
      @deployments[deployment_name] << agent_id
      true
    end

    def analyze_agents
      @logger.info "Analyzing agents..."
      started = Time.now

      processed = Set.new
      count = 0

      # Agents from managed deployments
      @deployments.each_pair do |deployment_name, agent_ids|
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
        # TODO: consider alerting about missing agent?
        @logger.error("Can't analyze agent #{agent_id} as it is missing from agents index, skipping...")
        return false
      end

      if agent.timed_out? && agent.rogue?
        remove_agent(agent.id)
      elsif agent.timed_out?
        alert = {
          :id         => "timeout-#{agent.id}-#{ts}",
          :severity   => 2,
          :source     => agent.name,
          :title      => "#{agent.id} has timed out",
          :created_at => ts
        }

        register_alert(alert)
      elsif agent.rogue?
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
      remove_agent(agent_id)
    end

    def process_heartbeat(agent_id, hb_payload)
      agent = @agents[agent_id]

      if agent.nil?
        @logger.warn("Received a heartbeat from an unmanaged agent: #{agent_id}")
        agent = Agent.new(agent_id)
        @agents[agent_id] = agent
      end

      heartbeat = parse_heartbeat(hb_payload)

      publish_heartbeat_event(agent, heartbeat)
      agent.process_heartbeat(heartbeat)
    end

    def publish_heartbeat_event(agent, heartbeat)
      unless heartbeat.kind_of?(Hash)
        @logger.error("Invalid heartbeat payload format, expected Hash, got #{heartbeat.class}: #{heartbeat}")
        return false
      end

      event_data = {
        :summary   => "Heartbeat received",
        :timestamp => Time.now.to_i,
        :data      => heartbeat.merge(:agent_id => agent.id, :deployment => agent.deployment, :job => agent.job, :index => agent.index)
      }

      begin
        @event_publisher.publish_event!(event_data)
      rescue => e
        @logger.error("Unable to publish event #{event_data}: #{e}")
      end
    end

    def parse_heartbeat(hb_payload)
      Yajl::Parser.parse(hb_payload)
    rescue Yajl::ParseError => e
      @logger.error("Unable to parse heartbeat payload: #{e}")
      nil
    end

  end
end
