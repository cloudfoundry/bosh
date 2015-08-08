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

          vm_deleter = VmDeleter.new(cloud, @logger)
          vm_creator = Bosh::Director::VmCreator.new(cloud, @logger, vm_deleter)

          prepare(planner, cloud)
          validate_packages(planner)

          compilation_instance_pool = CompilationInstancePool.new(InstanceReuser.new, vm_creator, vm_deleter, planner, @logger)
          package_compile_step = DeploymentPlan::Steps::PackageCompileStep.new(
            planner,
            compilation_instance_pool,
            @logger,
            @event_log,
            director_job
          )
          package_compile_step.perform

          planner
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
          ip_provider_factory = IpProviderFactory.new(@logger, global_networking: deployment.using_global_networking?)
          global_network_resolver = GlobalNetworkResolver.new(deployment)

          deployment.cloud_planner = CloudManifestParser.new(@logger).parse(cloud_manifest, ip_provider_factory, global_network_resolver)
          DeploymentSpecParser.new(deployment, @event_log, @logger).parse(deployment_manifest, plan_options)
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
            assembler.bind_job_renames

            instance_repo = Bosh::Director::DeploymentPlan::Instance
            instance_planner = InstancePlanner.new(@logger, instance_repo)
            desired_jobs = planner.jobs

            desired_jobs.each do |desired_job|
              desired_instances = desired_job.desired_instances
              existing_instances = desired_job.existing_instances
              instance_plans_for_desired_instances = instance_planner.plan_job_instances(desired_job, desired_instances, existing_instances)
              desired_job.instance_plans = instance_plans_for_desired_instances
            end

            all_the_instance_plans = desired_jobs.flat_map(&:instance_plans)
            assembler.bind_current_instance_states(all_the_instance_plans)
            desired_jobs.each do |desired_job|
              reserve_ips_for_job(desired_job) # will change job.instances
            end

            instance_plans_obsolete_within_a_job = desired_jobs.flat_map(&:instance_plans).select(&:obsolete?)
            instance_plans_for_obsolete_jobs = instance_planner.plan_obsolete_jobs(desired_jobs, planner.existing_instances)
            obsolete_instance_plans = instance_plans_for_obsolete_jobs + instance_plans_obsolete_within_a_job
            obsolete_instance_plans.map(&:instance).each { |instance| planner.mark_instance_for_deletion(instance) }

            assembler.mark_unknown_vms_for_deletion
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

        def validate_packages(planner)
          release_manager = Bosh::Director::Api::ReleaseManager.new
          planner.jobs.each { |job|
            job.templates.each{ |template|
              release_model = release_manager.find_by_name(template.release.name)
              template.package_models.each{ |package|

                release_version_model = release_manager.find_version(release_model, template.release.version)
                packages_list = release_version_model.transitive_dependencies(package)
                packages_list << package

                packages_list.each { |needed_package|
                  if needed_package.sha1.nil? || needed_package.blobstore_id.nil?
                    compiled_packages_list = Bosh::Director::Models::CompiledPackage[:package_id => needed_package.id, :stemcell_id => job.resource_pool.stemcell.model.id]
                    if compiled_packages_list.nil?
                      msg = "Can't deploy `#{release_version_model.release.name}/#{release_version_model.version}': it is not " +
                          "compiled for `#{job.resource_pool.stemcell.model.desc}' and no source package is available"
                      raise PackageMissingSourceCode, msg
                    end
                  end
                }
              }
            }
          }
        end

        def track_and_log(message)
          @event_log.track(message) do
            @logger.info(message)
            yield
          end
        end

        def reserve_ips_for_job(job)
          # FIXME: this stuff should be cleaned up, the ordering dependency here isn't obvious,
          # compilation IPs don't get released correctly on failure if we call take_old_reservations too early
          job.networks.each do |network|
            job.instances.each_with_index do |instance, index|
              # TODO: care about instance.availabililty_zone
              static_ips = network.static_ips

              if static_ips
                reservation = StaticNetworkReservation.new(instance, network.deployment_network, static_ips[index])
              else
                reservation = DynamicNetworkReservation.new(instance, network.deployment_network)
              end
              instance.add_network_reservation(reservation)
            end
          end

          job.instances.each do |instance|
            instance.take_old_reservations
          end
        end
      end
    end
  end
end
