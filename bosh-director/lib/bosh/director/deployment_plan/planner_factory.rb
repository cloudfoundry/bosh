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

          director_job = nil
          cloud = nil
          planner = nil

          track_and_log('Binding deployment') do
            @logger.info('Binding deployment')
            planner = planner_without_vm_binding(manifest_hash, cloud_config, options)
            cloud = Config.cloud
          end

          planner.bind_models
          validate_packages(planner)

          vm_deleter = VmDeleter.new(cloud, @logger)
          vm_creator = Bosh::Director::VmCreator.new(cloud, @logger, vm_deleter)
          compilation_instance_pool = CompilationInstancePool.new(InstanceReuser.new, vm_creator, vm_deleter, planner, @logger)
          package_compile_step = DeploymentPlan::Steps::PackageCompileStep.new(
            planner.jobs,
            planner.compilation,
            compilation_instance_pool,
            @logger,
            @event_log,
            director_job
          )
          package_compile_step.perform

          planner
        end

        def planner_without_vm_binding(manifest_hash, cloud_config, options)
          deployment_manifest, cloud_manifest = @deployment_manifest_migrator.migrate(manifest_hash, cloud_config)
          name = deployment_manifest['name']

          deployment_model = @deployment_repo.find_or_create_by_name(name)
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
          ip_provider_factory = IpProviderFactory.new(@logger, global_networking: deployment.using_global_networking?)
          global_network_resolver = GlobalNetworkResolver.new(deployment)

          deployment.cloud_planner = CloudManifestParser.new(@logger).parse(cloud_manifest, ip_provider_factory, global_network_resolver)
          DeploymentSpecParser.new(deployment, @event_log, @logger).parse(deployment_manifest, plan_options)
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
