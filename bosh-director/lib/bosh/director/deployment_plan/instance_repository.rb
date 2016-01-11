module Bosh::Director::DeploymentPlan
  class InstanceRepository
    def initialize(network_reservation_repostory, logger)
      @network_reservation_repository = network_reservation_repostory
      @logger = logger
    end

    def fetch_existing(existing_instance_model, existing_instance_state, job, index, deployment)
      @logger.debug("Fetching existing instance for: #{existing_instance_model.inspect}")
      # if state was not specified in manifest, use saved state
      job_state = job.state_for_instance(existing_instance_model) || existing_instance_model.state
      @logger.debug("Job instance states: #{job.instance_states}, found: #{job.state_for_instance(existing_instance_model)}, state: #{job_state}")

      instance = Instance.create_from_job(job, index, job_state, deployment.model, existing_instance_state, existing_instance_model.availability_zone, @logger)
      instance.bind_existing_instance_model(existing_instance_model)

      existing_network_reservations = @network_reservation_repository.fetch_network_reservations(existing_instance_model, existing_instance_state)
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
