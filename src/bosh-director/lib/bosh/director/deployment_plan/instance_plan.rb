require 'common/deep_copy'

module Bosh
  module Director
    module DeploymentPlan
      class InstancePlan
        # existing_instance: Model::Instance
        # desired_instance: DeploymentPlan::DesiredInstance
        # instance: DeploymentPlan::Instance

        def initialize(existing_instance:,
                       desired_instance:,
                       instance:,
                       network_plans: [],
                       skip_drain: false,
                       recreate_deployment: false,
                       recreate_persistent_disks: false,
                       use_dns_addresses: false,
                       use_short_dns_addresses: false,
                       use_link_dns_addresses: false,
                       link_provider_intents: [],
                       logger: Config.logger,
                       tags: {},
                       variables_interpolator:)
          @existing_instance = existing_instance
          @desired_instance = desired_instance
          @instance = instance
          @network_plans = network_plans
          @skip_drain = skip_drain
          @recreate_deployment = recreate_deployment
          @recreate_persistent_disks = recreate_persistent_disks
          @use_dns_addresses = use_dns_addresses
          @use_short_dns_addresses = use_short_dns_addresses
          @use_link_dns_addresses = use_link_dns_addresses
          @link_provider_intents = link_provider_intents
          @logger = logger
          @tags = tags
          @powerdns_manager = PowerDnsManagerProvider.create
          @variables_interpolator = variables_interpolator
        end

        attr_reader :desired_instance, :existing_instance, :instance, :skip_drain, :recreate_deployment, :tags

        attr_accessor :network_plans

        attr_reader :variables_interpolator

        # An instance of Bosh::Director::Core::Templates::RenderedJobInstance
        attr_accessor :rendered_templates

        ##
        # @return [Boolean] returns true if the any of the expected specifications
        #   differ from the ones provided by the VM
        def changed?
          !changes.empty?
        end

        def should_create_swap_delete?
          @desired_instance.instance_group&.should_create_swap_delete?
        end

        def unresponsive_agent?
          return false if @instance.nil?

          @instance.current_job_state == 'unresponsive'
        end

        ##
        # @return [Set<Symbol>] returns a set of all of the specification differences
        def changes
          return @changes if @changes

          @changes = Set.new
          @changes << :dirty if @instance.dirty?
          @changes << :restart if restart_requested?
          @changes << :recreate if recreation_requested?
          @changes << :recreate_persistent_disks if recreate_persistent_disks_requested?
          @changes << :cloud_properties if instance.cloud_properties_changed?
          @changes << :stemcell if stemcell_changed?
          @changes << :env if env_changed?
          @changes << :network if networks_changed? || network_settings_changed?
          @changes << :packages if packages_changed?
          @changes << :persistent_disk if persistent_disk_changed?
          @changes << :configuration if configuration_changed?
          @changes << :job if job_changed?
          @changes << :state if state_changed?
          @changes << :dns if dns_changed?
          @changes << :trusted_certs if instance.trusted_certs_changed?
          @changes << :blobstore_config if instance.blobstore_config_changed?
          @changes << :nats_config if instance.nats_config_changed?
          @changes << :tags if tags_changed?
          @changes << :variables if variables_changed?
          @changes
        end

        def persistent_disk_changed?
          return true if recreate_persistent_disks_requested?
          return @existing_instance.active_persistent_disks.any? if @existing_instance && obsolete?

          existing_disk_collection = instance_model.active_persistent_disks
          desired_disks_collection = @desired_instance.instance_group.persistent_disk_collection

          changed_disk_pairs = PersistentDiskCollection.changed_disk_pairs(
            existing_disk_collection,
            instance.previous_variable_set,
            desired_disks_collection,
            instance.desired_variable_set,
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

        def restart_requested?
          @instance.virtual_state == 'restart'
        end

        def recreation_requested?
          if @recreate_deployment
            @logger.debug("#{__method__} job deployment is configured with \"recreate\" state")
            true
          elsif unresponsive_agent?
            @logger.debug("#{__method__} instance should be recreated because of unresponsive agent")
            true
          else
            @instance.virtual_state == 'recreate'
          end
        end

        def recreate_persistent_disks_requested?
          if @recreate_persistent_disks
            @logger.debug("#{__method__} job deployment is configured with \"recreate_persistent_disks\" state")
          end
          @recreate_persistent_disks
        end

        def networks_changed?
          desired_network_plans = network_plans.select(&:desired?)
          obsolete_network_plans = network_plans.select(&:obsolete?)

          changed = false
          if obsolete_network_plans.any?
            @logger.debug(
              "#{__method__} obsolete reservations: [#{obsolete_network_plans.map(&:reservation).map(&:to_s).join(', ')}]",
            )
            changed = true
          end

          if desired_network_plans.any?
            @logger.debug(
              "#{__method__} desired reservations: [#{desired_network_plans.map(&:reservation).map(&:to_s).join(', ')}]",
            )
            changed = true
          end

          changed
        end

        def variables_changed?
          previous_variables = instance.previous_variable_set.variables.each_with_object({}) do |variable, hash|
            hash[variable[:variable_name]] = variable
          end
          desired_variables = instance.desired_variable_set.variables.each_with_object({}) do |variable, hash|
            hash[variable[:variable_name]] = variable
          end
          changed = false
          previous_variables.each do |key, value|
            if desired_variables.has_key?(key)
              if desired_variables[key].variable_id != previous_variables[key].variable_id
                @logger.debug(
                  "#{__method__} variable changed NAME: #{key} FROM: #{previous_variables[key][:variable_id]} " \
                  "TO: #{desired_variables[key][:variable_id]} on instance #{@existing_instance}",
                )
                changed = true
              end
            end
          end
          changed
        end

        def network_settings_changed?
          old_network_settings = new? ? {} : @existing_instance.spec_p('networks')
          return false if old_network_settings == {}

          new_network_settings = network_settings_hash

          old_network_settings = remove_dns_record_name_from_network_settings(old_network_settings)
          new_network_settings = remove_dns_record_name_from_network_settings(new_network_settings)

          changed = @variables_interpolator.interpolated_versioned_variables_changed?(old_network_settings, new_network_settings,
                                                                                      @instance.previous_variable_set,
                                                                                      @instance.desired_variable_set)

          if changed
            @logger.debug(
              "#{__method__} network settings changed FROM: #{old_network_settings} " \
              "TO: #{new_network_settings} on instance #{@existing_instance}",
            )
          end

          changed
        end

        def state_changed?
          if instance.state == 'detached' &&
             existing_instance.state != instance.state
            @logger.debug("Instance '#{instance}' needs to be detached")
            return true
          end

          return true if unresponsive_agent?

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

              if not_found
                @logger.debug(
                  "#{__method__} The requested dns record with name '#{name}' " \
                  "and ip '#{ip}' was not found in the db.",
                )
              end

              not_found
            end
          end

          diff = LocalDnsRecordsRepo.new(@logger, Config.root_domain).diff(self)
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

        def remove_obsolete_network_plans_for_ips(ips)
          network_plans.delete_if { |plan| ips.include?(plan.reservation.ip.to_s) }
        end

        def release_obsolete_network_plans(ip_provider)
          network_plans.select(&:obsolete?).each do |network_plan|
            reservation = network_plan.reservation
            ip_provider.release(reservation)
          end
          network_plans.delete_if(&:obsolete?)
        end

        def release_all_network_plans
          network_plans.clear
        end

        def instance_group_properties
          agent_id = instance.model.active_vm&.agent_id

          properties = {
            instance_id: instance.model.id,
            az: instance.model.availability_zone,
            deployment: instance.model.deployment.name,
            agent_id: agent_id,
            instance_group: instance.model.job,
          }

          links = @link_provider_intents.select do |lpi|
            lpi.link_provider.instance_group == properties[:instance_group]
          end.map do |lpi|
            { name: lpi.group_name }
          end.sort_by { |entry| entry[:name] }

          properties.merge(links: links)
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
                                 .map(&:reservation)

          DeploymentPlan::NetworkSettings.new(
            @instance.instance_group_name,
            @instance.model.deployment.name,
            @desired_instance.instance_group.default_network,
            desired_reservations,
            @instance.current_networks,
            @instance.availability_zone,
            @instance.index,
            @instance.uuid,
            root_domain,
            @use_short_dns_addresses,
            @use_link_dns_addresses,
          )
        end

        def network_settings_hash
          network_settings.to_hash
        end

        def network_address
          network_settings.network_address(@use_dns_addresses)
        end

        # @param [Boolean] prefer_dns_entry Flag for using DNS entry when available.
        # @return [Hash] A hash mapping network names to their associated address
        def network_addresses(prefer_dns_entry)
          network_settings.network_addresses(prefer_dns_entry)
        end

        def link_network_address(link_def)
          network_settings.link_network_address(link_def, @use_dns_addresses)
        end

        def link_network_addresses(link_def, prefer_dns_entry)
          network_settings.link_network_addresses(link_def, prefer_dns_entry)
        end

        def root_domain
          @powerdns_manager.root_domain
        end

        def needs_shutting_down?
          obsolete? || recreate_for_non_network_reasons? || networks_changed? || network_settings_changed?
        end

        def vm_matches_plan?(vm)
          return false if vm.cloud_properties_json.nil?

          desired_instance_group = @desired_instance.instance_group
          desired_cloud_properties = @variables_interpolator.interpolate_with_versioning(
            @instance.cloud_properties,
            @instance.desired_variable_set,
          )
          vm_cloud_properties = @variables_interpolator.interpolate_with_versioning(
            JSON.parse(vm.cloud_properties_json),
            @instance.previous_variable_set,
          )

          vm.stemcell_name == @instance.stemcell.name &&
            vm.stemcell_version == @instance.stemcell.version &&
            JSON.parse(vm.env_json || '{}') == desired_instance_group.env.spec &&
            vm_cloud_properties == desired_cloud_properties
        end

        def needs_duplicate_vm?
          obsolete? || recreate_for_non_network_reasons? || networks_changed?
        end

        def recreate_for_non_network_reasons?
          instance.cloud_properties_changed? ||
            stemcell_changed? ||
            env_changed? ||
            recreation_requested?
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

          current_spec = sanitize_and_sort(@instance.current_job_spec)
          job_spec = sanitize_and_sort(job.spec)

          changed =  current_spec != job_spec
          log_changes(__method__, current_spec, job_spec, @instance) if changed
          changed
        end

        def tags_changed?
          desired_tags = @tags
          existing_tags = @existing_instance.deployment.tags if @existing_instance

          changed = desired_tags != existing_tags
          log_changes(__method__, existing_tags, desired_tags, @instance) if changed
          changed
        end

        def packages_changed?
          instance_group = @desired_instance.instance_group

          changed = comparable_package_spec(instance_group.package_spec) != @instance.current_packages
          log_changes(__method__, @instance.current_packages, instance_group.package_spec, @instance) if changed
          changed
        end

        def already_detached?
          return false if new?

          @existing_instance.state == 'detached'
        end

        def needs_disk?
          instance_group = @desired_instance.instance_group

          instance_group.persistent_disk_collection.needs_disk?
        end

        def persist_current_spec
          instance_model.update(spec: spec.full_spec)
        end

        def stemcell_model_for_cpi(instance)
          return instance.stemcell.models.first if instance&.availability_zone.nil? # no AZ, ergo no CPI
          return instance.stemcell.models.first if instance&.availability_zone&.cpi.nil? # no CPI, ergo no CPI

          # Don't use "instance.stemcell.name" ("bosh-vsphere-esxi-ubuntu-jammy-go_agent") to filter;
          # it's unique across CPIs (e.g. contains substring "vsphere") & won't match properly
          stemcell_model_cpi = Bosh::Director::Models::Stemcell.where(
            version: instance.stemcell.version,
            operating_system: instance.stemcell.os,
            cpi: instance.availability_zone.cpi,
          ).first

          # stemcell_model_cpi should ALWAYS have a value, but if for some reason it's nil we fallback to original behavior
          stemcell_model_cpi ||= instance.stemcell.models.first
          @logger.debug("#{__method__} instance: #{instance}, stemcell name: #{stemcell_model_cpi.name}, " \
                          "version: #{stemcell_model_cpi.version}, " \
                          "os: #{stemcell_model_cpi.operating_system}, " \
                          "cpi: #{stemcell_model_cpi.cpi}")

          stemcell_model_cpi
        end

        private

        def remove_dns_record_name_from_network_settings(network_settings)
          return network_settings if network_settings.nil?

          modified_network_settings = Bosh::Common::DeepCopy.copy(network_settings)

          modified_network_settings.each do |_name, network_setting|
            network_setting.delete_if { |key, _value| key == 'dns_record_name' }
          end
          modified_network_settings
        end

        def env_changed?
          instance_group = @desired_instance.instance_group

          if @existing_instance&.vm_env && instance_group.env.spec != @existing_instance.vm_env
            log_changes(__method__, @existing_instance.vm_env, instance_group.env.spec, @existing_instance)
            return true
          end
          false
        end

        def stemcell_changed?
          instance_stemcell_model = stemcell_model_for_cpi(instance)
          if existing_instance&.spec_p('stemcell.name') &&
            instance_stemcell_model.name != existing_instance.spec_p('stemcell.name')
            log_changes(
              __method__,
              existing_instance.spec_p('stemcell.name'),
              instance_stemcell_model.name,
              existing_instance,
            )
            return true
          end

          if existing_instance&.spec_p('stemcell.version') &&
            instance_stemcell_model.version != existing_instance.spec_p('stemcell.version')
            log_changes(
              __method__,
              "version: #{existing_instance.spec_p('stemcell.version')}",
              "version: #{instance_stemcell_model.version}",
              existing_instance,
            )
            return true
          end

          false
        end

        def log_changes(method_sym, old_state, new_state, instance)
          old_state_msg = old_state.is_a?(String) ? old_state : old_state.to_json
          new_state_msg = new_state.is_a?(String) ? new_state : new_state.to_json
          @logger.debug("#{method_sym} changed FROM: #{old_state_msg} TO: #{new_state_msg} on instance #{instance}")
        end

        def sanitize_and_sort(spec)
          return spec unless spec.is_a? Hash

          spec['templates'] = spec['templates'].sort_by { |t| t['name'] } if spec.key?('templates')
          spec.select { |k, _| %w[name templates].include?(k) }
        end

        def comparable_package_spec(package_spec)
          package_comparison_keys = %w[blobstore_id sha1 name version]

          comparable_package_spec = Bosh::Common::DeepCopy.copy(package_spec)
          comparable_package_spec.each do |_name, spec|
            spec.delete_if { |k, _| !package_comparison_keys.include?(k) }
          end
          comparable_package_spec
        end
      end
    end
  end
end
