module Bosh::Monitor

  class AgentManager
    attr_reader :heartbeats_received
    attr_reader :alerts_received
    attr_reader :alerts_processed

    attr_accessor :processor

    def initialize(event_processor)
      # hash of agent id to agent structure (see add_agent())
      @agents = { }

      # hash of deployment name to set of agent ids
      @deployments = { }

      @logger = Bhm.logger
      @heartbeats_received = 0
      @alerts_received = 0
      @alerts_processed = 0

      @processor = event_processor
    end

    # Get a hash of agent id -> agent object for all agents associated with the deployment
    def get_agents_for_deployment(deployment_name)
      agent_ids = @deployments[deployment_name]
      @agents.select { |key, value| agent_ids.include?(key) }
    end

    def lookup_plugin(name, options = {})
      plugin_class = nil
      begin
        class_name = name.to_s.split("_").map(&:capitalize).join
        plugin_class = Bosh::Monitor::Plugins.const_get(class_name)
      rescue NameError => e
        raise PluginError, "Cannot find `#{name}' plugin"
      end

      plugin_class.new(options)
    end

    def setup_events
      @processor.enable_pruning(Bhm.intervals.prune_events)
      Bhm.plugins.each do |plugin|
        @processor.add_plugin(lookup_plugin(plugin["name"], plugin["options"]), plugin["events"])
      end

      EM.schedule do
        Bhm.nats.subscribe("hm.agent.heartbeat.*") do |message, reply, subject|
          process_event(:heartbeat, subject, message)
        end

        Bhm.nats.subscribe("hm.agent.alert.*") do |message, reply, subject|
          process_event(:alert, subject, message)
        end

        Bhm.nats.subscribe("hm.agent.shutdown.*") do |message, reply, subject|
          process_event(:shutdown, subject, message)
        end
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
      @logger.info("Removing agent #{agent_id} from all deployments...")
      @agents.delete(agent_id)
      @deployments.each_pair do |deployment, agents|
        agents.delete(agent_id)
      end
    end

    # Processes VM data from BOSH Director,
    # extracts relevant agent data, wraps it into Agent object
    # and adds it to a list of managed agents.
    def add_agent(deployment_name, vm_data)
      unless vm_data.kind_of?(Hash)
        @logger.error("Invalid format for VM data: expected Hash, got #{vm_data.class}: #{vm_data}")
        return false
      end

      @logger.info("Adding agent #{vm_data["agent_id"]} (#{vm_data["job"]}/#{vm_data["index"]}) to #{deployment_name}...")

      agent_id = vm_data["agent_id"]
      agent_cid = vm_data["cid"]

      if agent_id.nil?
        @logger.warn("No agent id for VM: #{vm_data}")
        return false
      end

      # Idle VMs, we don't care about them, but we still want to track them
      if vm_data["job"].nil?
        @logger.debug("VM with no job found: #{agent_id}")
      end

      agent = @agents[agent_id]

      if agent.nil?
        @logger.debug("Discovered agent #{agent_id}")
        agent = Agent.new(agent_id)
        @agents[agent_id] = agent
      end

      agent.deployment = deployment_name
      agent.job = vm_data["job"]
      agent.index = vm_data["index"]
      agent.cid = vm_data["cid"]

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
      ts = Time.now.to_i

      if agent.nil?
        @logger.error("Can't analyze agent #{agent_id} as it is missing from agents index, skipping...")
        return false
      end

      if agent.timed_out? && agent.rogue?
        # Agent has timed out but it was never
        # actually a proper member of the deployment,
        # so we don't really care about it
        remove_agent(agent.id)
        return
      end

      if agent.timed_out?
        @processor.process(:alert,
          severity: 2,
          source: agent.name,
          title: "#{agent.id} has timed out",
          created_at: ts,
          deployment: agent.deployment,
          job: agent.job,
          index: agent.index)
      end

      if agent.rogue?
        @processor.process(:alert,
          :severity => 2,
          :source => agent.name,
          :title => "#{agent.id} is not a part of any deployment",
          :created_at => ts)
      end

      true
    end

    def process_event(kind, subject, payload = {})
      kind = kind.to_s
      agent_id = subject.split('.', 4).last
      agent = @agents[agent_id]

      if agent.nil?
        # There might be more than a single shutdown event,
        # we are only interested in processing it if agent
        # is still managed
        return if kind == "shutdown"

        @logger.warn("Received #{kind} from unmanaged agent: #{agent_id}")
        agent = Agent.new(agent_id)
        @agents[agent_id] = agent
      else
        @logger.debug("Received #{kind} from #{agent_id}: #{payload}")
      end

      case payload
      when String
        message = Yajl::Parser.parse(payload)
      when Hash
        message = payload
      end

      case kind.to_s
      when "alert"
        on_alert(agent, message)
      when "heartbeat"
        on_heartbeat(agent, message)
      when "shutdown"
        on_shutdown(agent, message)
      else
        @logger.warn("No handler found for `#{kind}' event")
      end

    rescue Yajl::ParseError => e
      @logger.error("Cannot parse incoming event: #{e}")
    rescue Bhm::InvalidEvent => e
      @logger.error("Invalid event: #{e}")
    end

    def on_alert(agent, message)
      if message.is_a?(Hash) && !message.has_key?("source")
        message["source"] = agent.name
      end

      @processor.process(:alert, message)
      @alerts_processed += 1
    end

    def on_heartbeat(agent, message)
      agent.updated_at = Time.now

      if message.is_a?(Hash)
        message["timestamp"] = Time.now.to_i if message["timestamp"].nil?
        message["agent_id"] = agent.id
        message["deployment"] = agent.deployment
      end

      @processor.process(:heartbeat, message)
      @heartbeats_received += 1
    end

    def on_shutdown(agent, message)
      @logger.info("Agent `#{agent.id}' shutting down...")
      remove_agent(agent.id)
    end

  end
end
