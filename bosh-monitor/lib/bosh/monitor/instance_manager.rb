module Bosh::Monitor

  class InstanceManager
    attr_reader :heartbeats_received
    attr_reader :alerts_received
    attr_reader :alerts_processed
    attr_reader :instance_id_to_instance

    attr_accessor :processor

    def initialize(event_processor)
      @agent_id_to_agent = { }
      @instance_id_to_instance = { }

      @deployment_name_to_agent_ids = { }
      @deployment_name_to_instance_ids = { }

      @logger = Bhm.logger
      @heartbeats_received = 0
      @alerts_received = 0
      @alerts_processed = 0

      @processor = event_processor
    end

    # Get a hash of agent id -> agent object for all agents associated with the deployment
    def get_agents_for_deployment(deployment_name)
      agent_ids = @deployment_name_to_agent_ids[deployment_name]
      @agent_id_to_agent.select { |key, _| agent_ids.include?(key) }
    end

    def lookup_plugin(name, options = {})
      plugin_class = nil
      begin
        class_name = name.to_s.split("_").map(&:capitalize).join
        plugin_class = Bosh::Monitor::Plugins.const_get(class_name)
      rescue NameError => e
        raise PluginError, "Cannot find '#{name}' plugin"
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
      @agent_id_to_agent.size
    end

    def deployments_count
      @deployment_name_to_agent_ids.size
    end

    # Syncs deployments list received from director
    # with HM deployments.
    # @param deployments Array list of deployments returned by director
    def sync_deployments(deployments)
      managed = Set.new(deployments.map { |d| d["name"] })
      all     = Set.new(@deployment_name_to_agent_ids.keys)

      (all - managed).each do |stale_deployment|
        @logger.warn("Found stale deployment #{stale_deployment}, removing...")
        remove_deployment(stale_deployment)
      end
    end

    def sync_deployment_state(deployment_name, instances_data)
      sync_instances(deployment_name, instances_data)
      sync_agents(deployment_name, get_instances_for_deployment(deployment_name))
    end

    def sync_instances(deployment, instances_data)
      managed_instance_ids = @deployment_name_to_instance_ids[deployment] || Set.new
      instances_with_vms = Set.new

      instances_data.each do |instance_data|
        if add_instance(deployment, instance_data)
          instances_with_vms << instance_data['id']
        end
      end

      (managed_instance_ids - instances_with_vms).each do |instance_id|
        remove_instance(instance_id)
      end
    end

    def sync_agents(deployment, instances)
      managed_agent_ids = @deployment_name_to_agent_ids[deployment] || Set.new
      active_agent_ids  = Set.new

      instances.each do |instance|
        if add_agent(deployment, instance)
          active_agent_ids << instance.agent_id
        end
      end

      (managed_agent_ids - active_agent_ids).each do |agent_id|
        remove_agent(agent_id)
      end
    end

    def remove_deployment(name)
      agent_ids = @deployment_name_to_agent_ids[name]
      instance_ids = @deployment_name_to_instance_ids[name]

      agent_ids.each { |agent_id| @agent_id_to_agent.delete(agent_id) }

      instance_ids.each { |instance_id| @instance_id_to_instance.delete(instance_id) }

      @deployment_name_to_agent_ids.delete(name)
    end

    def remove_agent(agent_id)
      @logger.info("Removing agent #{agent_id} from all deployments...")
      @agent_id_to_agent.delete(agent_id)
      @deployment_name_to_agent_ids.each_pair do |deployment, agents|
        agents.delete(agent_id)
      end
    end

    def remove_instance(instance_id)
      @logger.info("Removing instance #{instance_id} from all deployments...")
      @instance_id_to_instance.delete(instance_id)
      @deployment_name_to_instance_ids.each_pair do |deployment, instances|
        instances.delete(instance_id)
      end
    end

    def add_instance(deployment_name, instance_data)
      instance = Bhm::Instance.create(instance_data)

      unless instance
        return false
      end

      unless instance.expects_vm
        @logger.debug("Instance with no VM expected found: #{instance.id}")
        return false
      end

      instance.deployment = deployment_name
      if @instance_id_to_instance[instance.id].nil?
        @logger.debug("Discovered instance #{instance_data['id']}")
        @instance_id_to_instance[instance.id] = instance
      end

      @deployment_name_to_instance_ids[deployment_name] ||= Set.new
      @deployment_name_to_instance_ids[deployment_name] << instance.id
      true
    end

    def get_instances_for_deployment(deployment_name)
      instance_ids_for_deployment = @deployment_name_to_instance_ids[deployment_name]
      selected_instance_ids_to_instances = @instance_id_to_instance.select do |key, _|
        instance_ids_for_deployment.include?(key)
      end

      selected_instance_ids_to_instances.values
    end

    # Processes VM data from BOSH Director,
    # extracts relevant agent data, wraps it into Agent object
    # and adds it to a list of managed agents.
    def add_agent(deployment_name, instance)

      @logger.info("Adding agent #{instance.agent_id} (#{instance.job}/#{instance.id}) to #{deployment_name}...")

      agent_id = instance.agent_id

      if agent_id.nil?
        @logger.warn("No agent id for Instance: #{instance.inspect}")
        return false
      end

      # Idle VMs, we don't care about them, but we still want to track them
      if instance.job.nil?
        @logger.debug("VM with no job found: #{agent_id}")
      end

      agent = @agent_id_to_agent[agent_id]

      if agent.nil?
        @logger.debug("Discovered agent #{agent_id}")
        agent = Agent.new(agent_id)
        @agent_id_to_agent[agent_id] = agent
      end

      agent.deployment = deployment_name
      agent.job = instance.job
      agent.index = instance.index
      agent.cid = instance.cid
      agent.instance_id = instance.id

      @deployment_name_to_agent_ids[deployment_name] ||= Set.new
      @deployment_name_to_agent_ids[deployment_name] << agent_id
      true
    end

    def analyze_agents
      @logger.info "Analyzing agents..."
      started = Time.now

      processed = Set.new
      count = 0

      # Agents from managed deployments
      @deployment_name_to_agent_ids.each_pair do |deployment_name, agent_ids|
        agent_ids.each do |agent_id|
          analyze_agent(agent_id)
          processed << agent_id
          count += 1
        end
      end

      # Rogue agents (hey there Solid Snake)
      (@agent_id_to_agent.keys.to_set - processed).each do |agent_id|
        @logger.warn("Agent #{agent_id} is not a part of any deployment")
        analyze_agent(agent_id)
        count += 1
      end

      @logger.info("Analyzed %s, took %s seconds" % [ pluralize(count, "agent"), Time.now - started ])
      count
    end

    def analyze_agent(agent_id)
      agent = @agent_id_to_agent[agent_id]
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
          instance_id: agent.instance_id)
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

    def analyze_instances
      @logger.info "Analyzing instances..."
      started = Time.now
      count = 0

      @deployment_name_to_instance_ids.each_pair do |_, instance_ids|
        instance_ids.each do |instance_id|
          analyze_instance(instance_id)
          count += 1
        end
      end

      @logger.info("Analyzed %s, took %s seconds" % [ pluralize(count, "instance"), Time.now - started ])
      count
    end

    def analyze_instance(instance_id)
      instance = @instance_id_to_instance[instance_id]
      unless instance
        @logger.error("Can't analyze instance #{instance_id} as it is missing from instances index, skipping...")
        return false
      end

      unless instance.has_vm?
        ts = Time.now.to_i
        @processor.process(:alert,
          severity: 2,
          source: instance.name,
          title: "#{instance.id} has no VM",
          created_at: ts,
          deployment: instance.deployment,
          job: instance.job,
          instance_id: instance.id)
      end

      true
    end

    def process_event(kind, subject, payload = {})
      kind = kind.to_s
      agent_id = subject.split('.', 4).last
      agent = @agent_id_to_agent[agent_id]

      if agent.nil?
        # There might be more than a single shutdown event,
        # we are only interested in processing it if agent
        # is still managed
        return if kind == "shutdown"

        @logger.warn("Received #{kind} from unmanaged agent: #{agent_id}")
        agent = Agent.new(agent_id)
        @agent_id_to_agent[agent_id] = agent
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
        @logger.warn("No handler found for '#{kind}' event")
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
      @logger.info("Agent '#{agent.id}' shutting down...")
      remove_agent(agent.id)
    end

  end
end
