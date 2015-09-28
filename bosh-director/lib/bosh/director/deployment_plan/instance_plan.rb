module Bosh
  module Director
    module DeploymentPlan
      class InstancePlan

        # FIXME: This is pretty sad. But it should go away when we move away from using
        # Instance and just become part of making an InstancePlan
        def self.create_from_deployment_plan_instance(instance, logger)
          # no one currently cares if this DesiredInstance is real, we just want to have one for now
          # so our InstancePlan doesn't think it's obsolete
          desired_instance = DeploymentPlan::DesiredInstance.new(nil, {}, nil)

          network_plans = NetworkPlanner.new(logger)
                            .plan_ips(instance.desired_network_reservations, instance.existing_network_reservations)

          instance_plan = new(
            existing_instance: instance.model,
            instance: instance,
            desired_instance: desired_instance
          )
          instance_plan.network_plans = network_plans
          instance_plan
        end

        def initialize(attrs)
          @existing_instance = attrs.fetch(:existing_instance)
          @desired_instance = attrs.fetch(:desired_instance)
          @instance = attrs.fetch(:instance)
          @network_plans = []
          @logger = Config.logger
        end

        attr_reader :desired_instance, :existing_instance, :instance

        attr_accessor :network_plans

        ##
        # @return [Boolean] returns true if the any of the expected specifications
        #   differ from the ones provided by the VM
        def changed?
          !changes.empty?
        end

        ##
        # @return [Set<Symbol>] returns a set of all of the specification differences
        def changes
          return @changes if @changes

          @changes = Set.new
          @changes << :restart if needs_restart?
          @changes << :recreate if needs_recreate?
          @changes << :cloud_properties if instance.cloud_properties_changed?
          @changes << :resource_pool if instance.resource_pool_changed?
          @changes << :network if networks_changed?
          @changes << :packages if instance.packages_changed?
          @changes << :persistent_disk if instance.persistent_disk_changed?
          @changes << :configuration if instance.configuration_changed?
          @changes << :job if instance.job_changed?
          @changes << :state if state_changed?
          @changes << :dns if instance.dns_changed?
          @changes << :trusted_certs if instance.trusted_certs_changed?
          @changes
        end

        def needs_restart?
          @desired_instance.virtual_state == 'restart'
        end

        def needs_recreate?
          @desired_instance.virtual_state == 'recreate'
        end

        def networks_changed?
          desired_plans = network_plans.select(&:desired?)
          obsolete_plans = network_plans.select(&:obsolete?)
          obsolete_plans.any? || desired_plans.any?
        end

        def state_changed?
          if desired_instance.state == 'detached' &&
              existing_instance.state != desired_instance.state
            @logger.debug("Instance '#{instance}' needs to be detached")
            return true
          end

          if instance.state == 'stopped' && instance.current_job_state == 'running' ||
              instance.state == 'started' && instance.current_job_state != 'running'
            @logger.debug("Instance state is '#{instance.state}' and agent reports '#{instance.current_job_state}'")
            return true
          end

          false
        end

        def mark_desired_network_plans_as_existing
          network_plans.select(&:desired?).each { |network_plan| network_plan.existing = true }
        end

        def release_obsolete_ips
          network_plans
            .select(&:obsolete?)
            .each do |network_plan|
            reservation = network_plan.reservation
            @instance.job.deployment.ip_provider.release(reservation)
          end
          network_plans.delete_if(&:obsolete?)
        end

        def release_all_ips
          network_plans.each do |network_plan|
            reservation = network_plan.reservation
            @instance.job.deployment.ip_provider.release(reservation) if reservation.reserved?
          end
          network_plans.clear
        end

        def obsolete?
          desired_instance.nil?
        end

        def new?
          existing_instance.nil?
        end

        def network_settings
          if @instance.respond_to?(:job)
            DeploymentPlan::NetworkSettings.new(
              @instance.job.name,
              @instance.job.can_run_as_errand?,
              @instance.job.deployment.name,
              @instance.job.default_network,
              @instance.desired_network_reservations,
              @instance.current_state,
              @instance.availability_zone,
              @instance.index).to_hash
          else
            @instance.apply_spec['networks']
          end
        end
      end
    end
  end
end
