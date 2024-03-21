module Bosh::Director::Links
  class LinksParser
    class LinkProvidersParser
      include Bosh::Director::ValidationHelper

      def initialize
        @logger = Bosh::Director::Config.logger
        @link_helper = LinkHelpers.new
      end

      def parse_providers_from_job(manifest_job_spec, deployment_model, current_release_template_model, manifest_details = {})
        job_properties = manifest_details.fetch(:job_properties, {})
        instance_group_name = get_instance_group_name(deployment_model, manifest_job_spec, manifest_details)

        @links_manager = Bosh::Director::Links::LinksManager.new(deployment_model.links_serial_id)

        manifest_provides_links = Bosh::Common::DeepCopy.copy(safe_property(manifest_job_spec, 'provides',
                                                                            class: Hash, optional: true, default: {}))
        custom_manifest_providers = Bosh::Common::DeepCopy.copy(safe_property(manifest_job_spec, 'custom_provider_definitions',
                                                                              class: Array, optional: true, default: []))
        job_name = safe_property(manifest_job_spec, 'name', class: String)

        @link_helper.validate_custom_providers(
          custom_manifest_providers,
          current_release_template_model.provides,
          job_name,
          instance_group_name,
          current_release_template_model.release.name,
        )

        errors = []

        errors.concat(
          process_custom_providers(
            current_release_template_model,
            custom_manifest_providers,
            manifest_provides_links,
            deployment_model,
            job_properties: job_properties,
            instance_group_name: instance_group_name,
          ),
          process_release_providers(
            current_release_template_model,
            manifest_provides_links,
            deployment_model,
            instance_group_name,
            job_properties,
          ),
        )

        unless manifest_provides_links.empty?
          warning = 'Manifest defines unknown providers:'
          manifest_provides_links.each_key do |link_name|
            warning << "\n  - Job '#{job_name}' does not define link provider '#{link_name}' in the release spec"
          end
          @logger.warn(warning)
        end

        raise errors.join("\n") unless errors.empty?
      end

      def parse_provider_from_disk(disk_spec, deployment_model, instance_group_name)
        @links_manager = Bosh::Director::Links::LinksManager.new(deployment_model.links_serial_id)

        disk_name = disk_spec['name'] # All the parsing we need

        provider = @links_manager.find_or_create_provider(
          deployment_model: deployment_model,
          instance_group_name: instance_group_name,
          name: instance_group_name,
          type: 'disk',
        )

        create_disk_provider_intent(deployment_model, disk_name, provider)
      end

      private

      def get_instance_group_name(deployment_model, manifest_job_spec, manifest_details)
        migrated_from = manifest_details.fetch(:migrated_from, [])

        migrated_from_instange_group = migrated_from.find do |migration_block|
          job_name = safe_property(manifest_job_spec, 'name', class: String)

          true if Bosh::Director::Models::Links::LinkProvider.find(
            deployment: deployment_model,
            instance_group: migration_block['name'],
            name: job_name,
            type: 'job',
          )
        end

        return migrated_from_instange_group['name'] if migrated_from_instange_group

        manifest_details.fetch(:instance_group_name, nil)
      end

      def create_disk_provider_intent(deployment_model, disk_name, provider)
        provider_intent = @links_manager.find_or_create_provider_intent(
          link_provider: provider,
          link_original_name: disk_name,
          link_type: 'disk',
        )

        provider_intent.shared = false
        provider_intent.name = disk_name
        provider_intent.content = Bosh::Director::DeploymentPlan::DiskLink.new(deployment_model.name, disk_name).spec.to_json
        provider_intent.save
      end

      def process_providers(release_properties, provider_definitions, manifest_provides_links, deployment_model, job_details = {})
        job_properties = job_details.fetch(:job_properties, {})
        instance_group_name = job_details.fetch(:instance_group_name, nil)
        job_name = job_details.fetch(:job_name, nil)
        are_custom_definitions = job_details.fetch(:are_custom_definitions, false)

        provider = @links_manager.find_or_create_provider(
          deployment_model: deployment_model,
          instance_group_name: instance_group_name,
          name: job_name,
          type: 'job',
        )

        process_provider_definitions(
          manifest_provides_links,
          provider,
          provider_definitions,
          release_properties,
          are_custom_definitions: are_custom_definitions,
          instance_group_name: instance_group_name,
          job_name: job_name,
          job_properties: job_properties,
        )
      end

      def process_provider_definitions(
        manifest_provides_links,
        provider,
        provider_definitions,
        release_properties,
        manifest_details = {}
      )
        are_custom_definitions, instance_group_name, job_name, job_properties =
          @link_helper.extract_provider_definition_properties(manifest_details)
        errors = []

        provider_definitions.each do |provider_definition|
          provider_intent_params = {
            'original_name' => provider_definition['name'],
            'type' => provider_definition['type'],
            'alias' => provider_definition['name'],
            'shared' => false,
            'consumable' => true,
          }

          if manifest_provides_links.key?(provider_definition['name'])
            manifest_source = manifest_provides_links.delete(provider_definition['name'])

            validation_errors = @link_helper.validate_provide_link(
              manifest_source, provider_definition['name'], job_name, instance_group_name
            )
            errors.concat(validation_errors)
            next unless validation_errors.empty?

            provider_intent_params = @link_helper.generate_provider_intent_params(manifest_source, provider_intent_params)
          end

          mapped_properties, properties_errors = @link_helper.process_link_properties(
            job_properties, provider_definition['properties'], release_properties, job_name
          )
          errors.concat(properties_errors)

          next unless properties_errors.empty?

          create_provider_intent(are_custom_definitions, mapped_properties, provider, provider_intent_params)
        end
        errors
      end

      def create_provider_intent(are_custom_definitions, mapped_properties, provider, provider_intent_params)
        provider_intent = @links_manager.find_or_create_provider_intent(
          link_provider: provider,
          link_original_name: provider_intent_params['original_name'],
          link_type: provider_intent_params['type'],
        )

        provider_intent.name = provider_intent_params['alias']
        provider_intent.shared = provider_intent_params['shared']
        is_custom = are_custom_definitions || false
        provider_intent.metadata = {
          mapped_properties: mapped_properties,
          custom: is_custom,
          dns_aliases: provider_intent_params['dns_aliases'],
        }.to_json
        provider_intent.consumable = provider_intent_params['consumable']
        provider_intent.save
      end

      def process_custom_providers(
        current_release_template_model,
        custom_manifest_providers,
        manifest_provides_links,
        deployment_model,
        manifest_details = {}
      )
        job_properties = manifest_details.fetch(:job_properties, {})
        instance_group_name = manifest_details.fetch(:instance_group_name, nil)
        return [] if custom_manifest_providers.empty?

        process_providers(
          current_release_template_model.properties,
          custom_manifest_providers,
          manifest_provides_links,
          deployment_model,
          job_properties: job_properties,
          instance_group_name: instance_group_name,
          job_name: current_release_template_model.name,
          are_custom_definitions: true,
        )
      end

      def process_release_providers(
        current_release_template_model,
        manifest_provides_links,
        deployment_model,
        instance_group_name,
        job_properties
      )
        job_name = current_release_template_model.name

        return [] if current_release_template_model.provides.empty?

        process_providers(
          current_release_template_model.properties,
          current_release_template_model.provides,
          manifest_provides_links,
          deployment_model,
          job_properties: job_properties,
          instance_group_name: instance_group_name,
          job_name: job_name,
          are_custom_definitions: false,
        )
      end
    end
  end
end
