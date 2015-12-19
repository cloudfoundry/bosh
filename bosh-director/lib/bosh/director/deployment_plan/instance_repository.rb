module Bosh::Director::DeploymentPlan
  class InstanceRepository
    def initialize(logger)
      @logger = logger
    end

    def fetch_existing(desired_instance, existing_instance_model, existing_instance_state)
      @logger.debug("Fetching existing instance for: #{existing_instance_model.inspect}")
      # if state was not specified in manifest, use saved state
      job_state = desired_instance.job.state_for_instance(existing_instance_model) || existing_instance_model.state
      @logger.debug("Job instance states: #{desired_instance.job.instance_states}, found: #{desired_instance.job.state_for_instance(existing_instance_model)}, state: #{job_state}")

      instance = Instance.create_from_job(desired_instance.job, desired_instance.index, job_state, desired_instance.deployment.model, existing_instance_state, existing_instance_model.availability_zone, @logger)
      instance.bind_existing_instance_model(existing_instance_model)

      if existing_instance_model.ip_addresses.any?
        existing_network_reservations = InstanceNetworkReservations.create_from_db(instance, desired_instance.deployment, @logger)
      elsif existing_instance_state
        # This is for backwards compatibility when we did not store
        # network reservations in DB and constructed them from instance state
        existing_network_reservations = InstanceNetworkReservations.create_from_state(instance, existing_instance_state, desired_instance.deployment, @logger)
      else
        existing_network_reservations = InstanceNetworkReservations.new(@logger)
      end
      instance.bind_existing_reservations(existing_network_reservations)
      instance
    end

    def create(desired_instance, index)
      @logger.debug("Creating new desired instance for: #{desired_instance.inspect}")
      instance = Instance.create_from_job(desired_instance.job, index, 'started', desired_instance.deployment.model, nil, desired_instance.az, @logger)
      instance.bind_new_instance_model
      instance
    end
  end
end
