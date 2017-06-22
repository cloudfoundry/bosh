require 'common/deep_copy'

module Bosh
  module Director
    module DeploymentPlan
      class InstancePlan
        def initialize(existing_instance:, desired_instance:, instance:, network_plans: [], skip_drain: false, recreate_deployment: false, logger: Config.logger, tags: {})
          @existing_instance = existing_instance
          @desired_instance = desired_instance
          @instance = instance
          @network_plans = network_plans
          @skip_drain = skip_drain
          @recreate_deployment = recreate_deployment
          @logger = logger
          @tags = tags
          @powerdns_manager = PowerDnsManagerProvider.create
        end

        attr_reader :desired_instance, :existing_instance, :instance, :skip_drain, :recreate_deployment, :tags

        attr_accessor :network_plans

        # An instance of Bosh::Director::Core::Templates::RenderedJobInstance
        attr_accessor :rendered_templates

        ##
        # @return [Boolean] returns true if the any of the expected specifications
        #   differ from the ones provided by the VM
        def changed?
          !changes.empty?
        end

        def needs_to_fix?
          return false if @instance.nil?
          @instance.current_job_state == 'unresponsive'
        end

        ##
        # @return [Set<Symbol>] returns a set of all of the specification differences
        def changes
          return @changes if @changes

          @changes = Set.new
          @changes << :dirty if @instance.dirty?
          @changes << :restart if needs_restart?
          @changes << :recreate if needs_recreate?
          @changes << :cloud_properties if instance.cloud_properties_changed?
          @changes << :stemcell if stemcell_changed?
          @changes << :env if env_changed?
          @changes << :network if networks_changed?
          @changes << :packages if packages_changed?
          @changes << :persistent_disk if persistent_disk_changed?
          @changes << :configuration if configuration_changed?
          @changes << :job if job_changed?
          @changes << :state if state_changed?
          @changes << :dns if dns_changed?
          @changes << :trusted_certs if instance.trusted_certs_changed?
          @changes
        end

        def persistent_disk_changed?
          if @existing_instance && obsolete?
            return @existing_instance.active_persistent_disks.any?
          end

          existing_disk_collection = instance_model.active_persistent_disks
          desired_disks_collection = @desired_instance.instance_group.persistent_disk_collection

          changed_disk_pairs = PersistentDiskCollection.changed_disk_pairs(
            existing_disk_collection,
            instance_model.variable_set,
            desired_disks_collection,
            instance_model.deployment.current_variable_set
          )

          changed_disk_pairs.each do |disk_pair|
            log_changes(__method__, disk_pair[:old], disk_pair[:new], instance)
          end
          !changed_disk_pairs.empty?
        end

        def instance_model
          new? ? instance.model : existing_instance
        end

        def should_be_ignored?
          !instance_model.nil? && instance_model.ignore
        end

        def needs_restart?
          @instance.virtual_state == 'restart'
        end

        def needs_recreate?
          if @recreate_deployment
            @logger.debug("#{__method__} job deployment is configured with \"recreate\" state")
            true
          elsif needs_to_fix?
            @logger.debug("#{__method__} instance should be recreated because of unresponsive agent")
            true
          else
            @instance.virtual_state == 'recreate'
          end
        end

        def networks_changed?
          desired_network_plans = network_plans.select(&:desired?)
          obsolete_network_plans = network_plans.select(&:obsolete?)

          old_network_settings = new? ? {} : @existing_instance.spec_p('networks')
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

          return true if needs_to_fix?

          if instance.state == 'stopped' && instance.current_job_state == 'running' ||
            instance.state == 'started' && instance.current_job_state != 'running'
            @logger.debug("Instance state is '#{instance.state}' and agent reports '#{instance.current_job_state}'")
            return true
          end

          false
        end

        def dns_changed?
          power_dns_changed = false

          if @powerdns_manager.dns_enabled?
            power_dns_changed = network_settings.dns_record_info.any? do |name, ip|
              not_found = @powerdns_manager.find_dns_record(name, ip).nil?
              @logger.debug("#{__method__} The requested dns record with name '#{name}' and ip '#{ip}' was not found in the db.") if not_found
              not_found
            end
          end

          diff = LocalDnsRepo.new(@logger, Config.root_domain).diff(instance_model)
          if diff.changes?
            log_changes(:local_dns_changed?, diff.obsolete + diff.unaffected, diff.unaffected + diff.missing, instance)
          end
          power_dns_changed || diff.changes?
        end

        def configuration_changed?
          changed = instance.configuration_hash != instance_model.spec_p('configuration_hash')
          log_changes(__method__, instance_model.spec_p('configuration_hash'), instance.configuration_hash, instance) if changed
          changed
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
            @desired_instance.instance_group.default_network,
            desired_reservations,
            @instance.current_networks,
            @instance.availability_zone,
            @instance.index,
            @instance.uuid,
            @powerdns_manager.root_domain,
          )
        end

        def network_settings_hash
          network_settings.to_hash
        end

        def network_address(network_name)
          network_settings.network_address(network_name)
        end

        def network_addresses
          network_settings.network_addresses
        end

        def needs_shutting_down?
          return true if obsolete?

          instance.cloud_properties_changed? ||
            stemcell_changed? ||
            env_changed? ||
            needs_recreate? ||
            networks_changed?
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
          @desired_instance.instance_group.jobs
        end

        def job_changed?
          job = @desired_instance.instance_group
          return true if @instance.current_job_spec.nil?

          # The agent job spec could be in legacy form.  job_spec cannot be,
          # though, because we got it from the spec function in job.rb which
          # automatically makes it non-legacy.
          converted_current = InstanceGroup.convert_from_legacy_spec(@instance.current_job_spec)
          changed = job.spec != converted_current
          log_changes(__method__, converted_current, job.spec, @instance) if changed
          changed
        end

        def packages_changed?
          job = @desired_instance.instance_group

          changed = job.package_spec != @instance.current_packages
          log_changes(__method__, @instance.current_packages, job.package_spec, @instance) if changed
          changed
        end

        def already_detached?
          return false if new?

          @existing_instance.state == 'detached'
        end

        def needs_disk?
          job = @desired_instance.instance_group

          job.persistent_disk_collection.needs_disk?
        end

        def persist_current_spec
          instance_model.update(spec: spec.full_spec)
        end

        private

        def network_settings_changed?(old_network_settings, new_network_settings)
          return false if old_network_settings == {}
          remove_dns_record_name_from_network_settings(old_network_settings) != new_network_settings
        end

        def remove_dns_record_name_from_network_settings(network_settings)
          return network_settings if network_settings.nil?

          modified_network_settings = Bosh::Common::DeepCopy.copy(network_settings)

          modified_network_settings.each do |name, network_setting|
            network_setting.delete_if { |key, value| key == "dns_record_name" }
          end
          modified_network_settings
        end

        def env_changed?
          job = @desired_instance.instance_group

          if @existing_instance && @existing_instance.vm_env && job.env.spec != @existing_instance.vm_env
            log_changes(__method__, @existing_instance.vm_env, job.env.spec, @existing_instance)
            return true
          end
          false
        end

        def stemcell_changed?
          if @existing_instance && @instance.stemcell.name != @existing_instance.spec_p('stemcell.name')
            log_changes(__method__, @existing_instance.spec_p('stemcell.name'), @instance.stemcell.name, @existing_instance)
            return true
          end

          if @existing_instance && @instance.stemcell.version != @existing_instance.spec_p('stemcell.version')
            log_changes(__method__, "version: #{@existing_instance.spec_p('stemcell.version')}", "version: #{@instance.stemcell.version}", @existing_instance)
            return true
          end

          false
        end

        def log_changes(method_sym, old_state, new_state, instance)
          @logger.debug("#{method_sym} changed FROM: #{old_state} TO: #{new_state} on instance #{instance}")
        end
      end

      class ResurrectionInstancePlan < InstancePlan
        def network_settings_hash
          @existing_instance.spec_p('networks')
        end

        def spec
          InstanceSpec.create_from_database(@existing_instance.spec, @instance)
        end

        def needs_disk?
          @existing_instance.managed_persistent_disk_cid
        end

        def templates
          @existing_instance.templates.map do |template_model|
            template = Job.new(nil, template_model.name, @instance.model.deployment.name)
            template.bind_existing_model(template_model)
            template
          end
        end
      end
    end
  end
end
