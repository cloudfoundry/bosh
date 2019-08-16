module Bosh::Monitor
  class Deployment

    attr_reader :name
    attr_reader :agent_id_to_agent
    attr_reader :instance_id_to_agent
    attr_reader :teams
    attr_writer :locked

    def initialize(deployment_data)
      @logger = Bhm.logger
      @name = deployment_data['name']
      @teams = deployment_data['teams']
      @locked = deployment_data['locked']
      @instance_id_to_instance = {}
      @agent_id_to_agent = {}
      @instance_id_to_agent = {}
    end

    def self.create(deployment_data)
      unless deployment_data.kind_of?(Hash)
        Bhm.logger.error("Invalid format for Deployment data: expected Hash, got #{deployment_data.class}: #{deployment_data}")
        return nil
      end

      unless deployment_data['name']
        Bhm.logger.error("Deployment data has no name: got #{deployment_data}")
        return nil
      end

      Deployment.new(deployment_data)
    end

    def add_instance(instance)
      unless instance
        return false
      end

      instance.deployment = name
      @logger.debug("Discovered new instance #{instance.id}") if @instance_id_to_instance[instance.id].nil?
      @instance_id_to_instance[instance.id] = instance
      true
    end

    def remove_instance(instance_id)
      @instance_id_to_agent.delete(instance_id)
      @instance_id_to_instance.delete(instance_id)
    end

    def instance(instance_id)
      @instance_id_to_instance[instance_id]
    end

    def instances
      @instance_id_to_instance.values
    end

    def instance_ids
      @instance_id_to_instance.keys.to_set
    end

    # Processes VM data from BOSH Director,
    # extracts relevant agent data, wraps it into Agent object
    # and adds it to a list of managed agents.
    def upsert_agent(instance)
      @logger.info("Adding agent #{instance.agent_id} (#{instance.job}/#{instance.id}) to #{name}...")

      agent_id = instance.agent_id

      if agent_id.nil?
        @logger.warn("No agent id for instance #{instance.job}/#{instance.id} in deployment #{name}")
        #count agents for instances with deleted vm, which expect to have vm
        if instance.expects_vm? && !instance.has_vm?
          agent = Agent.new("agent_with_no_vm", deployment: name)
          @instance_id_to_agent[instance.id] = agent
          agent.update_instance(instance)
        end
        return false
      end

      # Idle VMs, we don't care about them, but we still want to track them
      if instance.job.nil?
        @logger.debug("VM with no job found: #{agent_id}")
      end

      agent = @agent_id_to_agent[agent_id]

      if agent.nil?
        @logger.debug("Discovered agent #{agent_id}")
        agent = Agent.new(agent_id, deployment: name)
        @agent_id_to_agent[agent_id] = agent
        @instance_id_to_agent.delete(instance.id) if @instance_id_to_agent[instance.id]
      end

      agent.update_instance(instance)

      true
    end

    def remove_agent(agent_id)
      @agent_id_to_agent.delete(agent_id)
    end

    def agent(agent_id)
      @agent_id_to_agent[agent_id]
    end

    def agents
      @agent_id_to_agent.values
    end

    def agent_ids
      @agent_id_to_agent.keys.to_set
    end

    def update_teams(new_teams)
      @teams = new_teams
    end

    def locked?
      @locked
    end
  end
end
