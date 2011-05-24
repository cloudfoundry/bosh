module Bosh::HealthMonitor

  class AgentManager
    # TODO: make threadsafe? Not supposed to be deferred though...

    attr_reader :heartbeats_received, :alerts_received, :alerts_processed

    def initialize
      @agents = { }
      @agent_ids = Set.new
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
        @logger.debug("Received heartbeat from #{agent_id}: #{heartbeat_json}")
        process_heartbeat(agent_id, heartbeat_json)
      end

      Bhm.nats.subscribe("hm.agent.alert.*") do |message, reply, subject|
        @alerts_received += 1
        agent_id = subject.split('.', 4).last
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
      end

      @agent_ids << agent_id
      @agents_by_deployment[deployment_name] ||= Set.new
      @agents_by_deployment[deployment_name] << agent_id
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
      (@agent_ids - processed).each do |agent_id|
        @logger.warn("Agent #{agent_id} is not a part of any deployment")
        # TODO: alert?
        analyze_agent(agent_id)
        count += 1
      end

      @logger.info("Analyzed %s, took %s seconds" % [ pluralize(count, "agent"), Time.now - started ])
    end

    def analyze_agent(agent_id)
      agent = @agents[agent_id]
      ts    = Time.now.to_i

      if agent.nil?
        @logger.error("Agent #{agent_id} is missing from agents index, skipping...")
        return
      end

      if agent.timed_out?
        alert = {
          :id         => "timeout-#{agent_id}-#{ts}",
          :severity   => 2,
          :title      => "Agent timed out: #{agent_id}",
          :created_at => ts
        }

        @alert_processor.register_alert(alert)
      end
    end

    # Subscription callbacks
    def process_alert(alert_json)
      alert = Alert.create!(Yajl::Parser.parse(alert_json))
      @alert_processor.register_alert(alert)
      @alerts_processed += 1

    rescue Yajl::ParseError => e
      @logger.error("Cannot parse incoming alert: #{e}")
    rescue Bhm::InvalidAlert => e
      @logger.error(e)
    end

    def process_heartbeat(agent_id, heartbeat_payload)
      agent = @agents[agent_id]

      if agent.nil?
        # TODO: alert?
        @logger.warn("Received a heartbeat from an unmanaged agent #{agent_id}")
        agent = Agent.new(agent_id)
        agent.process_heartbeat(heartbeat_payload)
        @agents[agent_id] = agent
      else
        agent.process_heartbeat(heartbeat_payload)
      end
    end

  end
end
