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

        # TODO LINKS
        # process link will actually try to mix and match the links, here
        # this is done through the link path
        # is it the right place to even do that ??????????

        def validate_and_get_argument(arg, type)
          raise "#{type} value should be integer or percent" unless arg =~ /^\d+%$|\A[-+]?[0-9]+\z/ || arg.nil?
          arg
        end
      end
    end
  end
end
