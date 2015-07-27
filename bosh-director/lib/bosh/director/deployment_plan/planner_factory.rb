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

        def planner(manifest_hash, cloud_config, plan_options)
          planner = planner_without_vm_binding(manifest_hash, cloud_config, plan_options)
          bind_vms(planner)
        end

        def planner_without_vm_binding(manifest_hash, cloud_config, options)
          @event_log.begin_stage('Preparing deployment', 9)
          @logger.info('Preparing deployment')

          deployment_manifest, cloud_manifest = @deployment_manifest_migrator.migrate(manifest_hash, cloud_config)
          name = deployment_manifest['name']

          deployment_model = nil
          @event_log.track('Binding deployment') do
            @logger.info('Binding deployment')
            deployment_model = @deployment_repo.find_or_create_by_name(name)
          end

          attrs = {
            name: name,
            properties: deployment_manifest.fetch('properties', {}),
          }
          assemble_without_vm_binding(attrs, deployment_manifest, cloud_manifest, deployment_model, cloud_config, options)
        end

        private

        def deployment_name(manifest_hash)
          name = manifest_hash['name']
          @canonicalizer.canonical(name)
        end

        def assemble_without_vm_binding(attrs, deployment_manifest, cloud_manifest, deployment_model, cloud_config, options)
          plan_options = {
            'recreate' => !!options['recreate'],
            'job_states' => options['job_states'] || {},
            'job_rename' => options['job_rename'] || {}
          }
          @logger.info('Creating deployment plan')
          @logger.info("Deployment plan options: #{plan_options.pretty_inspect}")

          deployment = Planner.new(attrs, deployment_manifest, cloud_config, deployment_model, plan_options)
          deployment = CloudManifestParser.new(deployment, @logger).parse(cloud_manifest)
          DeploymentSpecParser.new(deployment, @event_log, @logger).parse(deployment_manifest, plan_options)
        end

        def bind_vms(planner)
          @logger.info('Created deployment plan')
          director_job = nil
          cloud = Config.cloud
          vm_deleter = VmDeleter.new(cloud, @logger)
          vm_creator = Bosh::Director::VmCreator.new(cloud, @logger, vm_deleter)

          compilation_instance_pool = CompilationInstancePool.new(InstanceReuser.new, vm_creator, vm_deleter, planner, @logger)
          package_compile_step = DeploymentPlan::Steps::PackageCompileStep.new(
            planner,
            compilation_instance_pool,
            @logger,
            @event_log,
            director_job
          )

          prepare(planner, cloud)
          package_compile_step.perform

          planner
        end

        def prepare(planner, cloud)
          stemcell_manager = Api::StemcellManager.new
          blobstore = nil # not used for this assembler purposes
          assembler = DeploymentPlan::Assembler.new(
            planner,
            stemcell_manager,
            cloud,
            blobstore,
            @logger,
            @event_log
          )

          track_and_log('Binding releases') do
            assembler.bind_releases
          end

          track_and_log('Binding existing deployment') do
            assembler.bind_existing_deployment
          end

          track_and_log('Binding stemcells') do
            assembler.bind_stemcells
          end

          track_and_log('Binding templates') do
            assembler.bind_templates
          end

          track_and_log('Binding properties') do
            assembler.bind_properties
          end

          track_and_log('Binding unallocated VMs') do
            assembler.bind_unallocated_vms
          end

          track_and_log('Binding networks') do
            assembler.bind_instance_networks
          end

          track_and_log('Binding DNS') do
            assembler.bind_dns
          end

          assembler.bind_links
        end

        def track_and_log(message)
          @event_log.track(message) do
            @logger.info(message)
            yield
          end
        end
      end
    end
  end
end
