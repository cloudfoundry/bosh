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
          planner = planner_without_vm_binding(manifest_hash, cloud_config_model, {})
          planner.bind_models
          planner
        end

        def planner(manifest_hash, cloud_config, options)
          @event_log.begin_stage('Preparing deployment', 9)
          @logger.info('Preparing deployment')

          planner = nil

          track_and_log('Binding deployment') do
            @logger.info('Binding deployment')
            planner = planner_without_vm_binding(manifest_hash, cloud_config, options)

            # AWS cpi initialization currently takes ~10sec
            # it is wrapped in event step to give user visible feedback
            initialize_cloud
          end

          planner.bind_models
          planner.validate_packages
          planner.compile_packages

          planner
        end

        def planner_without_vm_binding(manifest_hash, cloud_config, options)
          deployment_manifest, cloud_manifest = @deployment_manifest_migrator.migrate(manifest_hash, cloud_config)
          name = deployment_manifest['name']

          deployment_model = @deployment_repo.find_or_create_by_name(name)

          parse_from_manifest(deployment_manifest, cloud_manifest, deployment_model, cloud_config, options)
        end

        private

        def deployment_name(manifest_hash)
          name = manifest_hash['name']
          @canonicalizer.canonical(name)
        end

        def parse_from_manifest(deployment_manifest, cloud_manifest, deployment_model, cloud_config, options)
          attrs = {
            name: deployment_manifest['name'],
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
          ip_provider_factory = IpProviderFactory.new(@logger, global_networking: deployment.using_global_networking?)
          global_network_resolver = GlobalNetworkResolver.new(deployment)

          deployment.cloud_planner = CloudManifestParser.new(@logger).parse(cloud_manifest, ip_provider_factory, global_network_resolver)
          DeploymentSpecParser.new(deployment, @event_log, @logger).parse(deployment_manifest, plan_options)
        end

        def track_and_log(message)
          @event_log.track(message) do
            @logger.info(message)
            yield
          end
        end

        def initialize_cloud
          Config.cloud
        end
      end
    end
  end
end
