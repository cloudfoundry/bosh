module Bosh::Director::DeploymentPlan
  class InstanceRepository
    def initialize(network_reservation_repository, logger)
      @network_reservation_repository = network_reservation_repository
      @logger = logger
    end

    def fetch_existing(existing_instance_model, existing_instance_state, instance_group, index, deployment)
      @logger.debug("Fetching existing instance for: #{existing_instance_model.inspect}")
      # if state was not specified in manifest, use saved state
      job_state = instance_group.state_for_instance(existing_instance_model) || existing_instance_model.state
      @logger.debug(
        "Job instance states: #{instance_group.instance_states}, " \
        "found: #{instance_group.state_for_instance(existing_instance_model)}, state: #{job_state}",
      )

      availability_zone = AvailabilityZone.new(existing_instance_model.availability_zone, {})
      instance = Instance.create_from_instance_group(
        instance_group,
        index,
        job_state,
        deployment.model,
        existing_instance_state,
        availability_zone,
        @logger,
      )
      instance.bind_existing_instance_model(existing_instance_model)

      existing_network_reservations = @network_reservation_repository.fetch_network_reservations(
        existing_instance_model,
        existing_instance_state,
      )
      instance.bind_existing_reservations(existing_network_reservations)
      instance
    end

    def fetch_obsolete_existing(existing_instance_model, existing_instance_state)
      @logger.debug("Fetching obsolete existing instance for: #{existing_instance_model.inspect}")

      vm_type_spec = existing_instance_model.spec_p('vm_type')
      vm_type = !vm_type_spec.nil? && !vm_type_spec.empty? ? Bosh::Director::DeploymentPlan::VmType.new(vm_type_spec) : nil
      env = Bosh::Director::DeploymentPlan::Env.new(existing_instance_model.vm_env)
      stemcell_spec = existing_instance_model.spec_p('stemcell')
      if !existing_instance_model.vms.empty? && !stemcell_spec.nil? && !stemcell_spec.empty?
        stemcell = Bosh::Director::DeploymentPlan::Stemcell.parse(stemcell_spec)
        stemcell.add_stemcell_models
        stemcell.deployment_model = existing_instance_model.deployment
      else
        stemcell = nil
      end
      availability_zone = AvailabilityZone.new(existing_instance_model.availability_zone, {})
      merged_cloud_properties = MergedCloudProperties.new(availability_zone, vm_type, nil).get
      instance = Instance.new(
        existing_instance_model.job,
        existing_instance_model.index,
        existing_instance_model.state,
        merged_cloud_properties,
        stemcell,
        env,
        existing_instance_model.compilation,
        existing_instance_model.deployment,
        existing_instance_state,
        availability_zone,
        @logger,
      )
      instance.bind_existing_instance_model(existing_instance_model)

      existing_network_reservations = @network_reservation_repository.fetch_network_reservations(
        existing_instance_model,
        existing_instance_state,
      )
      instance.bind_existing_reservations(existing_network_reservations)
      instance
    end

    def create(desired_instance, index)
      @logger.debug("Creating new desired instance for: #{desired_instance.inspect}")
      instance = Instance.create_from_instance_group(
        desired_instance.instance_group,
        index,
        'started',
        desired_instance.deployment.model,
        nil,
        desired_instance.az,
        @logger,
      )
      instance.bind_new_instance_model
      instance
    end
  end
end
