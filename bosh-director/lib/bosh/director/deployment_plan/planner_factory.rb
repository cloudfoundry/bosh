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
        def self.create(event_log, logger)
          deployment_manifest_migrator = Bosh::Director::DeploymentPlan::ManifestMigrator.new
          canonicalizer = Class.new { include Bosh::Director::DnsHelper }.new
          deployment_repo = Bosh::Director::DeploymentPlan::DeploymentRepo.new(canonicalizer)

          new(
            canonicalizer,
            deployment_manifest_migrator,
            deployment_repo,
            event_log,
            logger
          )
        end

        def initialize(canonicalizer, deployment_manifest_migrator, deployment_repo, event_log, logger)
          @canonicalizer = canonicalizer
          @deployment_manifest_migrator = deployment_manifest_migrator
          @deployment_repo = deployment_repo
          @event_log = event_log
          @logger = logger
        end

        def create_from_model(deployment_model)
          manifest_hash = Psych.load(deployment_model.manifest)
          cloud_config_model = deployment_model.cloud_config
          create_from_manifest(manifest_hash, cloud_config_model, {})
        end

        def create_from_manifest(manifest_hash, cloud_config, options)
          @event_log.begin_stage('Preparing deployment', 9)
          @logger.info('Preparing deployment')

          planner = nil

          @event_log.track('Binding deployment') do
            @logger.info('Binding deployment')
            planner = parse_from_manifest(manifest_hash, cloud_config, options)
          end

          planner
        end

        private

        def parse_from_manifest(manifest_hash, cloud_config, options)
          deployment_manifest, cloud_manifest = @deployment_manifest_migrator.migrate(manifest_hash, cloud_config)
          @logger.debug("Migrated deployment manifest:\n#{deployment_manifest}")
          @logger.debug("Migrated cloud config manifest:\n#{cloud_manifest}")
          name = deployment_manifest['name']

          deployment_model = @deployment_repo.find_or_create_by_name(name)

          attrs = {
            name: name,
            properties: deployment_manifest.fetch('properties', {}),
          }

          plan_options = {
            'recreate' => !!options['recreate'],
            'skip_drain' => options['skip_drain'],
            'job_states' => options['job_states'] || {},
            'job_rename' => options['job_rename'] || {}
          }

          @logger.info('Creating deployment plan')
          @logger.info("Deployment plan options: #{plan_options}")

          deployment = Planner.new(attrs, deployment_manifest, cloud_config, deployment_model, plan_options)
          global_network_resolver = GlobalNetworkResolver.new(deployment)

          deployment.cloud_planner = CloudManifestParser.new(@logger).parse(cloud_manifest, global_network_resolver)
          DeploymentSpecParser.new(deployment, @event_log, @logger).parse(deployment_manifest, plan_options)
          DeploymentValidator.new.validate(deployment)
          deployment
        end
      end
    end
  end
end
