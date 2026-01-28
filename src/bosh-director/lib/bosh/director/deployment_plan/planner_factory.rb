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
          manifest_validator = Bosh::Director::DeploymentPlan::ManifestValidator.new
          deployment_repo = Bosh::Director::DeploymentPlan::DeploymentRepo.new

          new(
            manifest_validator,
            deployment_repo,
            logger
          )
        end

        def initialize(manifest_validator, deployment_repo, logger)
          @manifest_validator = manifest_validator
          @deployment_repo = deployment_repo
          @logger = logger
        end

        def create_from_model(deployment_model, options = {})
          manifest = Manifest.load_from_model(deployment_model)

          create_from_manifest(manifest, deployment_model.cloud_configs, deployment_model.runtime_configs, options)
        end

        def create_from_manifest(manifest, cloud_configs, runtime_configs, options)
          consolidated_cloud_config = Bosh::Director::CloudConfig::CloudConfigsConsolidator.new(cloud_configs)
          parse_from_manifest(manifest, consolidated_cloud_config, runtime_configs, options)
        end

        private

        def parse_from_manifest(manifest, cloud_config_consolidator, runtime_configs, options)
          runtime_config_consolidator = Bosh::Director::RuntimeConfig::RuntimeConfigsConsolidator.new(runtime_configs)
          @manifest_validator.validate(manifest.manifest_hash)

          cloud_manifest = manifest.cloud_config_hash
          manifest.resolve_aliases
          manifest_hash = manifest.manifest_hash
          @logger.debug("Deployment manifest:\n#{manifest_hash}")
          @logger.debug("Cloud config manifest:\n#{cloud_manifest}")
          name = manifest_hash['name']

          deployment_model = @deployment_repo.find_or_create_by_name(name, options)
          deployment_model.add_variable_set(created_at: Time.now, writable: true) if deployment_model.variable_sets.empty?

          plan_options = {
            'is_deploy_action' => !!options['deploy'],
            'recreate' => !!options['recreate'],
            'recreate_persistent_disks' => options['recreate_persistent_disks'] == true,
            'recreate_vm_created_before' => options['recreate_vm_created_before'],
            'fix' => !!options['fix'],
            'skip_drain' => options['skip_drain'],
            'job_states' => options['job_states'] || {},
            'max_in_flight' => validate_and_get_argument(options['max_in_flight'], 'max_in_flight'),
            'canaries' => validate_and_get_argument(options['canaries'], 'canaries'),
            'tags' => parse_tags(manifest_hash, runtime_config_consolidator),
          }

          @logger.info('Creating deployment plan')
          @logger.info("Deployment plan options: #{plan_options}")

          deployment = Planner.new(
            name,
            manifest.manifest_hash,
            manifest.manifest_text,
            cloud_config_consolidator.cloud_configs,
            [],
            deployment_model,
            plan_options,
            manifest_hash.fetch('properties', {}),
          )

          deployment.cloud_planner = CloudManifestParser.new(@logger).parse(cloud_manifest)

          DeploymentSpecParser.new(deployment, Config.event_log, @logger).parse(manifest_hash, plan_options)

          unless deployment.addons.empty?
            deployment.addons.each do |addon|
              addon.add_to_deployment(deployment)
            end
          end

          variables_spec_parser = Bosh::Director::DeploymentPlan::VariablesSpecParser.new(@logger, deployment.model)
          variables_interpolator = Bosh::Director::ConfigServer::VariablesInterpolator.new
          runtime_configs.each do |runtime_config|
            parsed_runtime_config = RuntimeConfig::RuntimeManifestParser.new(@logger, variables_spec_parser).parse(variables_interpolator.interpolate_runtime_manifest(runtime_config.raw_manifest, name))
            runtime_config_applies = false

            runtime_config_applies = true if parsed_runtime_config.addons.empty?

            parsed_runtime_config.get_applicable_releases(deployment).each do |release|
              runtime_config_applies = true
              release.add_to_deployment(deployment)
            end
            parsed_runtime_config.addons.each do |addon|
              runtime_config_applies = true
              addon.add_to_deployment(deployment)
            end
            deployment.add_variables(parsed_runtime_config.variables)

            if runtime_config_applies
              deployment.runtime_configs.push(runtime_config)
            end
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

        def validate_and_get_argument(arg, type)
          raise "#{type} value should be integer or percent" unless arg =~ /^\d+%$|\A[-+]?[0-9]+\z/ || arg.nil?
          arg
        end
      end
    end
  end
end
