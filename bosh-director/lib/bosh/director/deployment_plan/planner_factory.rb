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

        def create_from_model(deployment_model, options={})
          manifest = Manifest.load_from_model(deployment_model)
          create_from_manifest(manifest, deployment_model.cloud_config, deployment_model.runtime_config, options)
        end

        def create_from_manifest(manifest, cloud_config, runtime_config, options)
          parse_from_manifest(manifest, cloud_config, runtime_config, options)
        end

        private

        def parse_from_manifest(manifest, cloud_config, runtime_config, options)
          @manifest_validator.validate(manifest.hybrid_manifest_hash, manifest.cloud_config_hash)

          migrated_manifest_object, cloud_manifest = @deployment_manifest_migrator.migrate(manifest, manifest.cloud_config_hash)
          manifest.resolve_aliases
          migrated_hybrid_manifest_hash = migrated_manifest_object.hybrid_manifest_hash
          @logger.debug("Migrated deployment manifest:\n#{migrated_manifest_object.raw_manifest_hash}")
          @logger.debug("Migrated cloud config manifest:\n#{cloud_manifest}")
          name = migrated_hybrid_manifest_hash['name']

          deployment_model = @deployment_repo.find_or_create_by_name(name, options)

          attrs = {
            name: name,
            properties: migrated_hybrid_manifest_hash.fetch('properties', {}),
          }

          plan_options = {
            'recreate' => !!options['recreate'],
            'fix' => !!options['fix'],
            'skip_drain' => options['skip_drain'],
            'job_states' => options['job_states'] || {},
            'max_in_flight' => parse_numerical_arguments(options['max_in_flight']),
            'canaries' => parse_numerical_arguments(options['canaries'])
          }

          @logger.info('Creating deployment plan')
          @logger.info("Deployment plan options: #{plan_options}")

          deployment = Planner.new(attrs, migrated_manifest_object.raw_manifest_hash, cloud_config, runtime_config, deployment_model, plan_options)
          global_network_resolver = GlobalNetworkResolver.new(deployment, Config.director_ips, @logger)
          ip_provider_factory = IpProviderFactory.new(deployment.using_global_networking?, @logger)
          deployment.cloud_planner = CloudManifestParser.new(@logger).parse(cloud_manifest, global_network_resolver, ip_provider_factory)

          DeploymentSpecParser.new(deployment, Config.event_log, @logger).parse(migrated_hybrid_manifest_hash, plan_options)

          if runtime_config
            parsed_runtime_config =  RuntimeConfig::RuntimeManifestParser.new.parse(runtime_config.manifest)

            #TODO: only add releases for runtime jobs that will be added.
            parsed_runtime_config.releases.each do |release|
              release.add_to_deployment(deployment)
            end
            parsed_runtime_config.addons.each do |addon|
              addon.add_to_deployment(deployment)
            end
          end

          process_links(deployment)

          DeploymentValidator.new.validate(deployment)

          deployment
        end

        def process_links(deployment)
          errors = []

          deployment.instance_groups.each do |current_instance_group|
            current_instance_group.templates.each do |current_job|
              if current_job.link_infos.has_key?(current_instance_group.name) && current_job.link_infos[current_instance_group.name].has_key?('consumes')
                current_job.link_infos[current_instance_group.name]['consumes'].each do |name, source|
                  link_path = LinkPath.new(deployment, current_instance_group.name, current_job.name)

                  begin
                    link_path.parse(source)
                  rescue Exception => e
                    errors.push e
                  end

                  if !link_path.skip
                    current_instance_group.add_link_path(current_job.name, name, link_path)
                  end
                end
              end

              template_properties = current_job.template_scoped_properties[current_instance_group.name]

              if current_job.link_infos.has_key?(current_instance_group.name) && current_job.link_infos[current_instance_group.name].has_key?('provides')
                current_job.link_infos[current_instance_group.name]['provides'].each do |link_name, provided_link|
                  if provided_link['link_properties_exported']
                    ## Get default values for this job
                    default_properties = get_default_properties(deployment, current_job)

                    provided_link['mapped_properties'] = process_link_properties(template_properties, default_properties, provided_link['link_properties_exported'], errors)
                  end
                end
              end
            end
          end

          if errors.length > 0
            message = 'Unable to process links for deployment. Errors are:'

            errors.each do |e|
              message = "#{message}\n   - #{e.message.gsub(/\n/, "\n     ")}"
            end

            raise message
          end
        end

        def get_default_properties(deployment, template)
          release_manager = Api::ReleaseManager.new

          release_versions_templates_models_hash = {}

          template_name = template.name
          release_name = template.release.name

          release = deployment.release(release_name)

          if !release_versions_templates_models_hash.has_key?(release_name)
            release_model = release_manager.find_by_name(release_name)
            current_release_version = release_manager.find_version(release_model, release.version)
            release_versions_templates_models_hash[release_name] = current_release_version.templates
          end

          templates_models_list = release_versions_templates_models_hash[release_name]
          current_template_model = templates_models_list.find {|target| target.name == template_name }

          if current_template_model.properties != nil
            default_prop = {}
            default_prop['properties'] = current_template_model.properties
            default_prop["template_name"] = template.name
            return default_prop
          end

          return {"template_name" => template.name}
        end

        def process_link_properties(scoped_properties, default_properties, link_property_list, errors)
          mapped_properties = {}
            link_property_list.each do |link_property|
              property_path = link_property.split(".")
              result = find_property(property_path, scoped_properties)
              if !result['found']
                if default_properties.has_key?('properties') && default_properties['properties'].has_key?(link_property)
                  if default_properties['properties'][link_property].has_key?('default')
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
          return mapped_properties
        end

        def find_property(property_path, scoped_properties)
          current_node = scoped_properties
          property_path.each do |key|
            if !current_node || !current_node.has_key?(key)
              return {'found'=> false, 'value' => nil}
            else
              current_node = current_node[key]
            end
          end
          return {'found'=> true,'value'=> current_node}
        end

        def update_mapped_properties(mapped_properties, property_path, value)
          current_node = mapped_properties
          property_path.each_with_index do |key, index|
            if index == property_path.size - 1
              current_node[key] = value
            else
              if !current_node.has_key?(key)
                current_node[key] = {}
              end
              current_node = current_node[key]
            end
          end
          return mapped_properties
        end

        def parse_numerical_arguments arg
          case arg
            when nil
              nil
            when /%/
              raise 'percentages not yet supported for max in flight and canary cli overrides'
            when /\A[-+]?[0-9]+\z/
              arg.to_i
            else
              raise 'cannot be converted to integer'
          end
        end
      end
    end
  end
end
