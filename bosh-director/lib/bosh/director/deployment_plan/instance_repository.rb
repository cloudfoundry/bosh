module Bosh::Director::DeploymentPlan
  class InstanceRepository
    def initialize(logger)
      @logger = logger
    end

    def fetch_existing(desired_instance, existing_instance_model, existing_instance_state)
      @logger.debug("Fetching existing instance for: #{existing_instance_model.inspect}")
      # if state was not specified in manifest, use saved state
      job_state = desired_instance.state || existing_instance_model.state
      instance = Instance.new(desired_instance.job, desired_instance.index, job_state, desired_instance.deployment, existing_instance_state, desired_instance.az, desired_instance.bootstrap?, @logger)
      instance.bind_existing_instance_model(existing_instance_model)
      instance.bind_existing_reservations(existing_instance_state)
      instance
    end

    def create(desired_instance, index)
      job_state = desired_instance.state || 'started'
      instance = Instance.new(desired_instance.job, index, job_state, desired_instance.deployment, nil, desired_instance.az, desired_instance.bootstrap?, @logger)
      instance.bind_new_instance_model
      instance
    end
  end
end
