module Bosh
  module Director
    module DeploymentPlan
      class InstancePlan
        def initialize(attrs)
          @existing_instance = attrs.fetch(:existing_instance)
          @desired_instance = attrs.fetch(:desired_instance)
          @instance = attrs.fetch(:instance)
          @network_plans = attrs.fetch(:network_plans, [])
          @skip_drain = attrs.fetch(:skip_drain, false)
          @recreate_deployment = attrs.fetch(:recreate_deployment, false)
          @logger = attrs.fetch(:logger, Config.logger)
          @dns_manager = DnsManagerProvider.create
        end

        attr_reader :desired_instance, :existing_instance, :instance, :skip_drain, :recreate_deployment

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
          @changes << :stemcell if stemcell_changed?
          @changes << :env if env_changed?
          @changes << :network if networks_changed?
          @changes << :packages if packages_changed?
          @changes << :persistent_disk if persistent_disk_changed?
          @changes << :configuration if instance.configuration_changed?
          @changes << :job if job_changed?
          @changes << :state if state_changed?
          @changes << :dns if dns_changed?
          @changes << :trusted_certs if instance.trusted_certs_changed?
          @changes
        end

        def persistent_disk_changed?
          if @existing_instance && obsolete?
            return !@existing_instance.persistent_disk.nil?
          end

          job = @desired_instance.job
          new_disk_size = job.persistent_disk_type ? job.persistent_disk_type.disk_size : 0
          new_disk_cloud_properties = job.persistent_disk_type ? job.persistent_disk_type.cloud_properties : {}
          changed = new_disk_size != disk_size
          log_changes(__method__, "disk size: #{disk_size}", "disk size: #{new_disk_size}", @existing_instance) if changed
          return true if changed

          changed = new_disk_size != 0 && new_disk_cloud_properties != disk_cloud_properties
          log_changes(__method__, disk_cloud_properties, new_disk_cloud_properties, @existing_instance) if changed
          changed
        end

        def instance_model
          new? ? instance.model : existing_instance
        end

        def needs_restart?
          @instance.virtual_state == 'restart'
        end

        def needs_recreate?
          if @recreate_deployment
            @logger.debug("#{__method__} job deployment is configured with \"recreate\" state")
            true
          else
            @instance.virtual_state == 'recreate'
          end
        end

        def networks_changed?
          desired_network_plans = network_plans.select(&:desired?)
          obsolete_network_plans = network_plans.select(&:obsolete?)

          old_network_settings = new? ? {} : @existing_instance.spec['networks']
          new_network_settings = network_settings.to_hash

          changed = false
          if obsolete_network_plans.any?
            @logger.debug("#{__method__} obsolete reservations: [#{obsolete_network_plans.map(&:reservation).map(&:to_s).join(", ")}]")
            changed = true
          end

          if desired_network_plans.any?
            @logger.debug("#{__method__} desired reservations: [#{desired_network_plans.map(&:reservation).map(&:to_s).join(", ")}]")
            changed = true
          end

          if network_settings_changed?(old_network_settings, new_network_settings)
            @logger.debug("#{__method__} network settings changed FROM: #{old_network_settings} TO: #{new_network_settings} on instance #{@existing_instance}")
            changed = true
          end

          changed
        end

        def state_changed?
          if instance.state == 'detached' &&
            existing_instance.state != instance.state
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

        def release_obsolete_network_plans
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

        def existing?
          !new? && !obsolete?
        end

        def network_settings
          desired_reservations = network_plans
                                   .reject(&:obsolete?)
                                   .map { |network_plan| network_plan.reservation }

          DeploymentPlan::NetworkSettings.new(
            @instance.job_name,
            @instance.model.deployment.name,
            @desired_instance.job.default_network,
            desired_reservations,
            @instance.current_state,
            @instance.availability_zone,
            @instance.index,
            @instance.uuid,
            @dns_manager
          )
        end

        def network_settings_hash
          network_settings.to_hash
        end

        def network_addresses
          network_settings.network_addresses
        end

        def needs_shutting_down?
          return true if obsolete?

          instance.cloud_properties_changed? ||
            stemcell_changed? ||
            env_changed? ||
            needs_recreate?
        end

        def find_existing_reservation_for_network(network)
          @instance.existing_network_reservations.find_for_network(network)
        end

        def desired_az_name
          @desired_instance.az ? @desired_instance.az.name : nil
        end

        def network_plan_for_network(network)
          @network_plans.find { |plan| plan.reservation.network == network }
        end

        def spec
          return InstanceSpec.create_empty if obsolete?

          InstanceSpec.create_from_instance_plan(self)
        end

        def templates
          @desired_instance.job.templates
        end

        def job_changed?
          job = @desired_instance.job
          return true if @instance.current_job_spec.nil?

          # The agent job spec could be in legacy form.  job_spec cannot be,
          # though, because we got it from the spec function in job.rb which
          # automatically makes it non-legacy.
          converted_current = Job.convert_from_legacy_spec(@instance.current_job_spec)
          changed = job.spec != converted_current
          log_changes(__method__, converted_current, job.spec, @instance) if changed
          changed
        end

        def packages_changed?
          job = @desired_instance.job

          changed = job.package_spec != @instance.current_packages
          log_changes(__method__, @instance.current_packages, job.package_spec, @instance) if changed
          changed
        end

        def currently_detached?
          return false if new?

          @existing_instance.state == 'detached'
        end

        def needs_disk?
          job = @desired_instance.job

          job && job.persistent_disk_type && job.persistent_disk_type.disk_size > 0
        end

        def persist_current_spec
          instance_model.update(spec: spec.full_spec)
        end

        private

        def network_settings_changed?(old_network_settings, new_network_settings)
          return false if old_network_settings == {}
          old_network_settings != new_network_settings
        end

        def env_changed?
          job = @desired_instance.job

          if @existing_instance && @existing_instance.vm_env && job.env.spec != @existing_instance.vm_env
            log_changes(__method__, @existing_instance.vm_env, job.env.spec, @existing_instance)
            return true
          end
          false
        end

        def stemcell_changed?
          if @existing_instance && @instance.stemcell.name != @existing_instance.spec['stemcell']['name']
            log_changes(__method__, @existing_instance.spec['stemcell']['name'], @instance.stemcell.name, @existing_instance)
            return true
          end

          if @existing_instance && @instance.stemcell.version != @existing_instance.spec['stemcell']['version']
            log_changes(__method__, "version: #{@existing_instance.spec['stemcell']['version']}", "version: #{@instance.stemcell.version}", @existing_instance)
            return true
          end

          false
        end

        def log_changes(method_sym, old_state, new_state, instance)
          @logger.debug("#{method_sym} changed FROM: #{old_state} TO: #{new_state} on instance #{instance}")
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

      class ResurrectionInstancePlan < InstancePlan
        def network_settings_hash
          @existing_instance.spec['networks']
        end

        def spec
          InstanceSpec.create_from_database(@existing_instance.spec, @instance)
        end

        def needs_disk?
          @existing_instance.persistent_disk_cid
        end

        def templates
          @existing_instance.templates.map do |template_model|
            template = Template.new(nil, template_model.name)
            template.bind_existing_model(template_model)
            template
          end
        end
      end
    end
  end
end
