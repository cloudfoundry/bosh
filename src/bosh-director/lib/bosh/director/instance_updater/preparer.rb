module Bosh::Director
  class InstanceUpdater::Preparer
    def initialize(instance_plan, agent_client, logger)
      @instance_plan = instance_plan
      @agent_client = agent_client
      @logger = logger
    end

    def prepare
      instance = @instance_plan.instance
      # If resource pool has changed or instance will be recreated/detached
      # there is no point in preparing current VM for future since it will be destroyed.
      unless @instance_plan.needs_shutting_down? || instance.state == 'detached'

        apply_spec = DeploymentPlan::InstanceSpec.create_from_instance_plan(@instance_plan).as_apply_spec
        @agent_client.prepare(apply_spec)
      end
    rescue RpcRemoteException => e
      if e.message =~ /unknown message/
        # It's ok if agent does not support prepare optimization
        @logger.warn("Ignoring prepare 'unknown message' error from the agent: #{e.inspect}")
      else
        # Prepare is really an optimization to a deployment process.
        # It should not prevent deploy from continuing on and trying to actually finish an update.
        @logger.warn("Ignoring prepare error from the agent: #{e.inspect}")
      end
    end
  end
end
