module Bosh
  module Director
    module DeploymentPlan
      class InstancePlan
        def initialize(attrs)
          @existing_instance = attrs.fetch(:existing_instance)
          @desired_instance = attrs.fetch(:desired_instance)
          @instance = attrs.fetch(:instance)
          @network_plans = attrs.fetch(:network_plans, [])
          @logger = Config.logger
          @dns_manager = DnsManager.create
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
          @changes << :recreate_deployment if recreate_deployment?
          @changes << :cloud_properties if instance.cloud_properties_changed?
          @changes << :vm_type if vm_type_changed?
          @changes << :stemcell if stemcell_changed?
          @changes << :env if env_changed?
          @changes << :network if networks_changed?
          @changes << :packages if instance.packages_changed?
          @changes << :persistent_disk if persistent_disk_changed?
          @changes << :configuration if instance.configuration_changed?
          @changes << :job if instance.job_changed?
          @changes << :state if state_changed?
          @changes << :dns if dns_changed?
          @changes << :bootstrap if bootstrap_changed?
          @changes << :trusted_certs if instance.trusted_certs_changed?
          @changes
        end

        def recreate_deployment?
          return false if obsolete?

          job = @instance.job
          if job.deployment.recreate
            @logger.debug("#{__method__} job deployment is configured with \"recreate\" state")
            return true
          end
          false
        end

        def env_changed?
          job = @instance.job

          if @existing_instance && @existing_instance.env && job.env.spec != @existing_instance.env
            log_changes(__method__, @existing_instance.vm.env, job.env.spec)
            return true
          end
          false
        end

        def persistent_disk_changed?
          if @existing_instance && obsolete?
            return !@existing_instance.persistent_disk.nil?
          end

          job = @instance.job
          new_disk_size = job.persistent_disk_type ? job.persistent_disk_type.disk_size : 0
          new_disk_cloud_properties = job.persistent_disk_type ? job.persistent_disk_type.cloud_properties : {}
          changed = new_disk_size != disk_size
          log_changes(__method__, "disk size: #{disk_size}", "disk size: #{new_disk_size}") if changed
          return true if changed

          changed = new_disk_size != 0 && new_disk_cloud_properties != disk_cloud_properties
          log_changes(__method__, disk_cloud_properties, new_disk_cloud_properties) if changed
          changed
        end


        def needs_restart?
          @desired_instance.virtual_state == 'restart'
        end

        def needs_recreate?
          return false if obsolete?

          @desired_instance.virtual_state == 'recreate'
        end

        def bootstrap_changed?
          existing_instance.nil? || desired_instance.bootstrap? != existing_instance.bootstrap
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

        def vm_type_changed?
          return true if obsolete?

          if @existing_instance && @instance.vm_type.spec != @existing_instance.apply_spec['vm_type']
            log_changes(__method__, @existing_instance.apply_spec['vm_type'], @instance.job.vm_type.spec)
            return true
          end
          false
        end

        def stemcell_changed?
          return true if obsolete?

          if @existing_instance && @instance.stemcell.name != @existing_instance.apply_spec['stemcell']['name']
            log_changes(__method__, @existing_instance.apply_spec['stemcell']['name'], @instance.stemcell.name)
            return true
          end

          if @existing_instance && @instance.stemcell.version != @existing_instance.apply_spec['stemcell']['version']
            log_changes(__method__, "version: #{@existing_instance.apply_spec['stemcell']['version']}", "version: #{@instance.stemcell.version}")
            return true
          end

          false
        end

        def dns_changed?
          return false unless @dns_manager.dns_enabled?

          network_settings.dns_record_info.any? do |name, ip|
            not_found = @dns_manager.find_dns_record(name, ip).nil?
            @logger.debug("#{__method__} The requested dns record with name '#{name}' and ip '#{ip}' was not found in the db.") if not_found
            not_found
          end
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

        def release_all_network_plans
          network_plans.clear
        end

        def obsolete?
          desired_instance.nil?
        end

        def new?
          existing_instance.nil?
        end

        def network_settings
          desired_reservations = network_plans
                                   .reject(&:obsolete?)
                                   .map{ |network_plan| network_plan.reservation }

          if @instance.respond_to?(:job)
            DeploymentPlan::NetworkSettings.new(
              @instance.job.name,
              @instance.job.can_run_as_errand?,
              @instance.model.deployment.name,
              @instance.job.default_network,
              desired_reservations,
              @instance.current_state,
              @instance.availability_zone,
              @instance.index,
              @instance.uuid,
              @dns_manager
            )
          else
            # CAUTION: This is a safety guard in case @instance is an InstanceFromDatabase.
            # This should be removed when InstanceFromDatabase is removed.

            DeploymentPlan::NetworkSettings.new(
              @instance.job_name,
              false,
              @instance.deployment_model.name,
              {},
              [],
              {},
              AvailabilityZone.new(@instance.availability_zone_name, @instance.cloud_properties),
              @instance.index,
              @instance.uuid,
              @dns_manager
            )
          end
        end

        def network_settings_hash
          if obsolete? || network_settings.to_hash.empty?
            @existing_instance.apply_spec['networks']
          else
            network_settings.to_hash
          end
        end

        def network_addresses
          network_settings.network_addresses
        end

        private

        def log_changes(method_sym, old_state, new_state)
          @logger.debug("#{method_sym} changed FROM: #{old_state} TO: #{new_state}")
        end

        def disk_size
          if @instance.model.nil?
            raise DirectorError, "Instance `#{@instance}' model is not bound"
          end

          if @instance.model.persistent_disk
            @instance.model.persistent_disk.size
          else
            0
          end
        end

        def disk_cloud_properties
          if @instance.model.nil?
            raise DirectorError, "Instance `#{@instance}' model is not bound"
          end

          if @instance.model.persistent_disk
            @instance.model.persistent_disk.cloud_properties
          else
            {}
          end
        end
      end
    end
  end
end
