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
            'skip_drain' => options['skip_drain'],
            'job_states' => options['job_states'] || {},
            'job_rename' => options['job_rename'] || {}
          }
          @logger.info('Creating deployment plan')
          @logger.info("Deployment plan options: #{plan_options}")

          deployment = Planner.new(attrs, deployment_manifest, cloud_config, deployment_model, plan_options)
          deployment = CloudManifestParser.new(deployment, @logger).parse(cloud_manifest)
          DeploymentSpecParser.new(deployment, @event_log, @logger).parse(deployment_manifest, plan_options)
        end

        def bind_vms(planner)
          stemcell_manager = Api::StemcellManager.new
          cloud = Config.cloud
          blobstore = nil # not used for this assembler purposes
          director_job = nil
          assembler = DeploymentPlan::Assembler.new(
            planner,
            stemcell_manager,
            cloud,
            blobstore,
            @logger,
            @event_log
          )
          @logger.info('Created deployment plan')

          run_prepare_step(assembler)

          validate_packages(planner)

          DeploymentPlan::Steps::PackageCompileStep.new(
            planner,
            cloud,
            @logger,
            @event_log,
            director_job
          ).perform
          @event_log.begin_stage('Preparing DNS', 1)
          track_and_log('Binding DNS') do
            assembler.bind_dns
          end

          planner
        end

        def validate_packages(planner)
          faults = {}
          release_manager = Bosh::Director::Api::ReleaseManager.new
          planner.jobs.each { |job|
            job.templates.each{ |template|
              release_model = release_manager.find_by_name(template.release.name)
              template.package_models.each{ |package|

                release_version_model = release_manager.find_version(release_model, template.release.version)
                packages_list = release_version_model.transitive_dependencies(package)
                packages_list << package

                release_desc = "#{release_version_model.release.name}/#{release_version_model.version}"

                packages_list.each { |needed_package|
                  if needed_package.sha1.nil? || needed_package.blobstore_id.nil?
                    compiled_packages_list = Bosh::Director::Models::CompiledPackage[:package_id => needed_package.id, :stemcell_id => job.resource_pool.stemcell.model.id]
                    if compiled_packages_list.nil?
                      (faults[release_desc] ||= []) << {:package => needed_package, :stemcell => job.resource_pool.stemcell.model}
                    end
                  end
                }
              }
            }
          }
          handle_faults(faults) unless faults.empty?
        end

        def handle_faults(faults)
          msg = "\n"
          faults.each { |release_desc, packages_and_stemcells_list|
            msg += "\nCan't deploy release `#{release_desc}'. It references packages (see below) without source code and are not compiled against intended stemcells:\n"
            sorted_packages_and_stemcells = packages_and_stemcells_list.sort_by { |p| p[:package].name }
            sorted_packages_and_stemcells.each { |item|
              msg += " - `#{item[:package].name}/#{item[:package].version}' against `#{item[:stemcell].desc}'\n"
            }
          }
          raise PackageMissingSourceCode, msg
        end

        def run_prepare_step(assembler)
          @event_log.begin_stage('Preparing deployment', 9)
          @logger.info('Preparing deployment')

          track_and_log('Binding releases') do
            assembler.bind_releases
          end

          track_and_log('Binding existing deployment') do
            assembler.bind_existing_deployment
          end

          track_and_log('Binding resource pools') do
            assembler.bind_resource_pools
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

          track_and_log('Binding instance networks') do
            assembler.bind_instance_networks
          end
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
