require 'bosh/director/deployment_plan/deployment_spec_parser'
require 'bosh/director/deployment_plan/cloud_manifest_parser'

module Bosh
  module Director
    module DeploymentPlan
      class TransientDeployment
        def initialize(name, manifest, release_versions)
          @name = name
          @manifest = manifest
          @release_versions = release_versions
          @vms = []
        end
        attr_accessor :name, :manifest, :release_versions, :vms
      end

      class PlannerFactory
        include ValidationHelper

        def self.create(logger)
          deployment_manifest_migrator = Bosh::Director::DeploymentPlan::ManifestMigrator.new
          manifest_validator = Bosh::Director::DeploymentPlan::ManifestValidator.new
          deployment_repo = Bosh::Director::DeploymentPlan::DeploymentRepo.new

          new(
            deployment_manifest_migrator,
            manifest_validator,
            deployment_repo,
            logger
          )
        end

        def initialize(deployment_manifest_migrator, manifest_validator, deployment_repo, logger)
          @deployment_manifest_migrator = deployment_manifest_migrator
          @manifest_validator = manifest_validator
          @deployment_repo = deployment_repo
          @logger = logger
        end

        def create_from_model(deployment_model, options = {})
          manifest = Manifest.load_from_model(deployment_model)
          create_from_manifest(manifest, deployment_model.cloud_configs, deployment_model.runtime_configs, options)
        end

        def create_from_manifest(manifest, cloud_configs, runtime_configs, options)
          consolidated_runtime_config = Bosh::Director::RuntimeConfig::RuntimeConfigsConsolidator.new(runtime_configs)
          consolidated_cloud_config = Bosh::Director::CloudConfig::CloudConfigsConsolidator.new(cloud_configs)
          parse_from_manifest(manifest, consolidated_cloud_config, consolidated_runtime_config, options)
        end

        private

        def parse_from_manifest(manifest, cloud_config_consolidator, runtime_config_consolidator, options)
          @manifest_validator.validate(manifest.manifest_hash, manifest.cloud_config_hash)

          migrated_manifest_object, cloud_manifest = @deployment_manifest_migrator.migrate(manifest, manifest.cloud_config_hash)
          manifest.resolve_aliases
          migrated_manifest_hash = migrated_manifest_object.manifest_hash
          @logger.debug("Migrated deployment manifest:\n#{migrated_manifest_object.manifest_hash}")
          @logger.debug("Migrated cloud config manifest:\n#{cloud_manifest}")
          name = migrated_manifest_hash['name']

          deployment_model = @deployment_repo.find_or_create_by_name(name, options)
          deployment_model.add_variable_set(created_at: Time.now, writable: true) if deployment_model.variable_sets.empty?

          attrs = {
            name: name,
            properties: migrated_manifest_hash.fetch('properties', {})
          }

          plan_options = {
            'recreate' => !!options['recreate'],
            'fix' => !!options['fix'],
            'skip_drain' => options['skip_drain'],
            'job_states' => options['job_states'] || {},
            'max_in_flight' => validate_and_get_argument(options['max_in_flight'], 'max_in_flight'),
            'canaries' => validate_and_get_argument(options['canaries'], 'canaries'),
            'tags' => parse_tags(migrated_manifest_hash, runtime_config_consolidator)
          }

          @logger.info('Creating deployment plan')
          @logger.info("Deployment plan options: #{plan_options}")

          deployment = Planner.new(attrs, migrated_manifest_object.manifest_hash, migrated_manifest_object.manifest_text, cloud_config_consolidator.cloud_configs, runtime_config_consolidator.runtime_configs, deployment_model, plan_options)
          global_network_resolver = GlobalNetworkResolver.new(deployment, Config.director_ips, @logger)
          ip_provider_factory = IpProviderFactory.new(deployment.using_global_networking?, @logger)
          deployment.cloud_planner = CloudManifestParser.new(@logger).parse(cloud_manifest, global_network_resolver, ip_provider_factory)

          DeploymentSpecParser.new(deployment, Config.event_log, @logger).parse(migrated_manifest_hash, plan_options)

          unless deployment.addons.empty?
            deployment.addons.each do |addon|
              addon.add_to_deployment(deployment)
            end
          end

          if runtime_config_consolidator.have_runtime_configs?
            parsed_runtime_config = RuntimeConfig::RuntimeManifestParser.new(@logger).parse(runtime_config_consolidator.interpolate_manifest_for_deployment(name))

            # TODO: only add releases for runtime jobs that will be added.
            parsed_runtime_config.releases.each do |release|
              release.add_to_deployment(deployment)
            end
            parsed_runtime_config.addons.each do |addon|
              addon.add_to_deployment(deployment)
            end
            deployment.add_variables(parsed_runtime_config.variables)
          end

          process_links(deployment)

          DeploymentValidator.new.validate(deployment)

          deployment
        end

        def parse_tags(manifest_hash, runtime_config_consolidator)
          deployment_name = manifest_hash['name']
          tags = {}

          if manifest_hash.key?('tags')
            safe_property(manifest_hash, 'tags', class: Hash).each_pair do |key, value|
              tags[key] = value
            end
          end

          runtime_config_consolidator.tags(deployment_name).merge!(tags)
        end

        def process_links(deployment)
          errors = []

          deployment.instance_groups.each do |current_instance_group|
            current_instance_group.jobs.each do |current_job|
              current_job.consumes_links_for_instance_group_name(current_instance_group.name).each do |name, source|
                link_path = LinkPath.new(deployment.name, deployment.instance_groups, current_instance_group.name, current_job.name)

                begin
                  link_path.parse(source)
                rescue Exception => e
                  errors.push e
                end

                unless link_path.skip
                  current_instance_group.add_link_path(current_job.name, name, link_path)
                end
              end

              template_properties = current_job.properties[current_instance_group.name]

              current_job.provides_links_for_instance_group_name(current_instance_group.name).each do |_link_name, provided_link|
                next unless provided_link['link_properties_exported']
                ## Get default values for this job
                default_properties = get_default_properties(deployment, current_job)

                provided_link['mapped_properties'] = process_link_properties(template_properties, default_properties, provided_link['link_properties_exported'], errors)
              end
            end
          end

          unless errors.empty?
            combined_errors = errors.map { |error| "- #{error.message.strip}" }.join("\n")
            header = 'Unable to process links for deployment. Errors are:'
            message = Bosh::Director::FormatterHelper.new.prepend_header_and_indent_body(header, combined_errors.strip, indent_by: 2)

            raise message
          end
        end

        def get_default_properties(deployment, template)
          release_manager = Api::ReleaseManager.new

          release_versions_templates_models_hash = {}

          template_name = template.name
          release_name = template.release.name

          release = deployment.release(release_name)

          unless release_versions_templates_models_hash.key?(release_name)
            release_model = release_manager.find_by_name(release_name)
            current_release_version = release_manager.find_version(release_model, release.version)
            release_versions_templates_models_hash[release_name] = current_release_version.templates
          end

          templates_models_list = release_versions_templates_models_hash[release_name]
          current_template_model = templates_models_list.find { |target| target.name == template_name }

          unless current_template_model.properties.nil?
            default_prop = {}
            default_prop['properties'] = current_template_model.properties
            default_prop['template_name'] = template.name
            return default_prop
          end

          { 'template_name' => template.name }
        end

        def process_link_properties(scoped_properties, default_properties, link_property_list, errors)
          mapped_properties = {}
          link_property_list.each do |link_property|
            property_path = link_property.split('.')
            result = find_property(property_path, scoped_properties)
            if !result['found']
              if default_properties.key?('properties') && default_properties['properties'].key?(link_property)
                if default_properties['properties'][link_property].key?('default')
                  mapped_properties = update_mapped_properties(mapped_properties, property_path, default_properties['properties'][link_property]['default'])
                else
                  mapped_properties = update_mapped_properties(mapped_properties, property_path, nil)
                end
              else
                e = Exception.new("Link property #{link_property} in template #{default_properties['template_name']} is not defined in release spec")
                errors.push(e)
              end
            else
              mapped_properties = update_mapped_properties(mapped_properties, property_path, result['value'])
            end
          end
          mapped_properties
        end

        def find_property(property_path, scoped_properties)
          current_node = scoped_properties
          property_path.each do |key|
            if !current_node || !current_node.key?(key)
              return { 'found' => false, 'value' => nil }
            else
              current_node = current_node[key]
            end
          end
          { 'found' => true, 'value' => current_node }
        end

        def update_mapped_properties(mapped_properties, property_path, value)
          current_node = mapped_properties
          property_path.each_with_index do |key, index|
            if index == property_path.size - 1
              current_node[key] = value
            else
              current_node[key] = {} unless current_node.key?(key)
              current_node = current_node[key]
            end
          end
          mapped_properties
        end

        def validate_and_get_argument(arg, type)
          raise "#{type} value should be integer or percent" unless arg =~ /^\d+%$|\A[-+]?[0-9]+\z/ || arg.nil?
          arg
        end
      end
    end
  end
end
