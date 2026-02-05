module Bosh::Director::DeploymentPlan
  class InstanceRepository
    def initialize(logger, variables_interpolator)
      @logger = logger
      @variables_interpolator = variables_interpolator
    end

    def build_instance_from_model(instance_model, existing_state, desired_state, deployment_plan)
      @logger.debug("Building instance from instance model: #{instance_model.inspect}")

      stemcell = Stemcell.parse(instance_model.spec['stemcell'])
      stemcell.bind_model(instance_model.deployment)

      availability_zone = AvailabilityZone.new(
        instance_model.availability_zone,
        instance_model.cloud_properties_hash,
      )

      instance_spec = instance_model.spec.merge(existing_state)

      instance = Instance.new(
        instance_model.job,
        instance_model.index,
        desired_state,
        instance_model.cloud_properties_hash,
        stemcell,
        Env.new(instance_model.vm_env),
        false,
        instance_model.deployment,
        instance_spec,
        availability_zone,
        @logger,
        @variables_interpolator,
      )
      instance.bind_existing_instance_model(instance_model)

      existing_network_reservations = InstanceNetworkReservations.create_from_db(
        instance_model,
        deployment_plan,
        @logger,
      )
      instance.bind_existing_reservations(existing_network_reservations)

      instance
    end

    def fetch_existing(existing_instance_model, existing_instance_state, desired_instance)
      @logger.debug("Fetching existing instance for: #{existing_instance_model.inspect}")

      instance_group = desired_instance.instance_group

      # if state was not specified in manifest, use saved state
      job_state = instance_group.state_for_instance(existing_instance_model) ||
                  existing_instance_model.state
      @logger.debug(
        "Job instance states: #{instance_group.instance_states}, " \
        "found: #{instance_group.state_for_instance(existing_instance_model)}, state: #{job_state}",
      )

      availability_zone = AvailabilityZone.new(existing_instance_model.availability_zone, {})
      instance = Instance.create_from_instance_group(
        instance_group,
        desired_instance.index,
        job_state,
        desired_instance.deployment.model,
        existing_instance_state,
        availability_zone,
        @logger,
        @variables_interpolator,
      )
      instance.bind_existing_instance_model(existing_instance_model)

      existing_network_reservations = InstanceNetworkReservations.create_from_db(
        existing_instance_model,
        desired_instance.deployment,
        @logger,
      )
      instance.bind_existing_reservations(existing_network_reservations)
      instance
    end

    def fetch_obsolete_existing(existing_instance_model, existing_instance_state, deployment)
      @logger.debug("Fetching obsolete existing instance for: #{existing_instance_model.inspect}")

      vm_type_spec = existing_instance_model.spec_p('vm_type')
      vm_type = !vm_type_spec.nil? && !vm_type_spec.empty? ? Bosh::Director::DeploymentPlan::VmType.new(vm_type_spec) : nil

      stemcell_spec = existing_instance_model.spec_p('stemcell')
      stemcell = nil
      if !existing_instance_model.vms.empty? && !stemcell_spec.nil? && !stemcell_spec.empty?
        stemcell = Bosh::Director::DeploymentPlan::Stemcell.parse(stemcell_spec)
        stemcell.add_stemcell_models
        stemcell.deployment_model = existing_instance_model.deployment
      end

      availability_zone = AvailabilityZone.new(existing_instance_model.availability_zone, {})
      merged_cloud_properties = MergedCloudProperties.new(availability_zone, vm_type, nil).get
      instance = Instance.new(
        existing_instance_model.job,
        existing_instance_model.index,
        existing_instance_model.state,
        merged_cloud_properties,
        stemcell,
        Bosh::Director::DeploymentPlan::Env.new(existing_instance_model.vm_env),
        existing_instance_model.compilation,
        existing_instance_model.deployment,
        existing_instance_state,
        availability_zone,
        @logger,
        @variables_interpolator,
      )
      instance.bind_existing_instance_model(existing_instance_model)
      existing_network_reservations = InstanceNetworkReservations.create_from_db(existing_instance_model, deployment, @logger)
      instance.bind_existing_reservations(existing_network_reservations)
      instance
    end

    def create(desired_instance, index)
      @logger.debug("Creating new desired instance for: #{desired_instance.inspect}")
      instance = Instance.create_from_instance_group(
        desired_instance.instance_group,
        index,
        Bosh::Director::INSTANCE_STATE_STARTED,
        desired_instance.deployment.model,
        nil,
        desired_instance.az,
        @logger,
        @variables_interpolator,
      )
      instance.bind_new_instance_model
      instance
    end
  end
end
