require 'bosh/director/compiled_package_requirement_generator'
require 'digest/sha1'

module Bosh::Director
  module DeploymentPlan
    module Stages
      class PackageCompileStage
        include LockHelper

        attr_reader :compilations_performed

        def self.create(deployment_plan)
          new(
            deployment_plan.name,
            deployment_plan.instance_groups,
            deployment_plan.compilation,
            CompilationInstancePool.create(deployment_plan),
            Bosh::Director::Api::ReleaseManager.new,
            DeploymentPlan::PackageValidator.new(Config.logger),
            DeploymentPlan::CompiledPackageFinder.new(Config.logger),
            Config.logger,
          )
        end

        def initialize(
          deployment_name,
          instance_groups_to_compile,
          compilation_config,
          compilation_instance_pool,
          release_manager,
          package_validator,
          compiled_package_finder,
          logger
        )
          @event_log_stage = nil
          @logger = logger

          @requirements_mutex = Mutex.new
          @counter_mutex = Mutex.new

          @compilation_instance_pool = compilation_instance_pool
          @ready_requirements = []
          @compilations_performed = 0
          @instance_groups_to_compile = instance_groups_to_compile
          @compilation_config = compilation_config
          @deployment_name = deployment_name

          @release_manager = release_manager
          @package_validator = package_validator
          @compiled_package_finder = compiled_package_finder
          @blobstore = App.instance.blobstores.blobstore
        end

        def perform
          validate_packages(@instance_groups_to_compile)

          @logger.info('Generating a list of compile requirements')
          compile_requirements = prepare_requirements(@instance_groups_to_compile)

          compile_requirements.each_value do |requirement|
            next unless requirement.ready_to_compile?

            @logger.info(
              "Package '#{requirement.package.desc}' is ready to be compiled for "\
              "stemcell '#{requirement.stemcell.desc}'",
            )
            @ready_requirements << requirement
          end

          if @ready_requirements.empty?
            @logger.info('All packages are already compiled')
            return
          end

          compile_packages(compile_requirements)
        end

        def ready_requirements_count
          @requirements_mutex.synchronize { @ready_requirements.size }
        end

        def compile_package(requirement)
          package = requirement.package
          stemcell = requirement.stemcell

          with_compile_lock(package.id, "#{stemcell.os}/#{stemcell.version}", @deployment_name) do
            # Check if the package was compiled in a parallel deployment
            compiled_package = @compiled_package_finder.find_compiled_package(
              package: package,
              stemcell: stemcell,
              dependency_key: requirement.dependency_key,
              cache_key: requirement.cache_key,
              event_log_stage: @event_log_stage,
            )

            if compiled_package.nil?
              build = Models::CompiledPackage.generate_build_number(package, stemcell.os, stemcell.version)
              task_result = nil

              version = "#{package.version}.#{build}"
              prepare_vm(stemcell, package) do |instance|
                if @blobstore.can_sign_urls?(stemcell.api_version)
                  compiled_package_blobstore_id = @blobstore.generate_object_id
                  package_get_signed_url = @blobstore.sign(package.blobstore_id)
                  upload_signed_url = @blobstore.sign(compiled_package_blobstore_id, 'put')

                  blobstore_headers = {}
                  blobstore_headers.merge!(@blobstore.signed_url_encryption_headers) if @blobstore.encryption?
                  blobstore_headers.merge!(@blobstore.put_headers) if @blobstore.put_headers?

                  request = {
                    'package_get_signed_url' => package_get_signed_url,
                    'upload_signed_url' => upload_signed_url,
                    'digest' => package.sha1,
                    'name' => package.name,
                    'version' => version,
                    'deps' => add_signed_urls(requirement.dependency_spec, blobstore_headers),
                  }

                  request['blobstore_headers'] = blobstore_headers unless blobstore_headers.empty?

                  agent_task = instance.agent_client.compile_package_with_signed_url(request) { Config.job_cancelled? }
                  task_result = agent_task['result']
                  task_result['blobstore_id'] = compiled_package_blobstore_id
                else
                  agent_task =
                    instance.agent_client.compile_package(
                      package.blobstore_id,
                      package.sha1,
                      package.name,
                      version,
                      requirement.dependency_spec,
                    ) { Config.job_cancelled? }
                  task_result = agent_task['result']
                end
              end

              compiled_package = Models::CompiledPackage.create do |p|
                p.package = package
                p.stemcell_os = stemcell.os
                p.stemcell_version = stemcell.version
                p.sha1 = task_result['sha1']
                p.build = build
                p.blobstore_id = task_result['blobstore_id']
                p.dependency_key = requirement.dependency_key
              end

              @counter_mutex.synchronize { @compilations_performed += 1 }
            end

            requirement.use_compiled_package(compiled_package)
          end
        end

        def prepare_vm(...)
          if @compilation_config.reuse_compilation_vms
            @compilation_instance_pool.with_reused_vm(...)
          else
            @compilation_instance_pool.with_single_use_vm(...)
          end
        end

        private

        def validate_packages(instance_groups_to_compile)
          instance_groups_to_compile.each do |instance_group|
            instance_group.jobs.each do |job|
              release_model = @release_manager.find_by_name(job.release.name)
              job_packages = job.package_models.map(&:name)
              release_version_model = @release_manager.find_version(release_model, job.release.version)

              @package_validator.validate(release_version_model, instance_group.stemcell, job_packages, job.release.exported_from)
            end
          end

          @package_validator.handle_faults
        end

        def prepare_requirements(instance_groups_to_compile)
          compile_requirements = {}
          event_log_stage = Config.event_log.begin_stage('Preparing package compilation', 1)

          event_log_stage.advance_and_track('Finding packages to compile') do
            compile_requirement_generator = CompiledPackageRequirementGenerator.new(
              @logger,
              event_log_stage,
              @compiled_package_finder,
            )

            instance_groups_to_compile.each do |instance_group|
              stemcell = instance_group.stemcell

              job_descs = instance_group.jobs.map { |job| "'#{job.release.name}/#{job.name}'" }
              @logger.info("Job templates #{job_descs.join(', ')} need to run on stemcell '#{stemcell.desc}'")

              instance_group.jobs.each do |job|
                job.package_models.each do |package|
                  requirement = compile_requirement_generator.generate!(
                    compile_requirements,
                    instance_group,
                    job,
                    package,
                    stemcell,
                  )

                  instance_group.use_compiled_package(requirement.compiled_package) if requirement.compiled?
                end
              end
            end
          end
          compile_requirements
        end

        def cancelled?
          Config.job_cancelled?
          false
        rescue TaskCancelled
          true
        end

        def compile_packages(compile_requirements)
          compilation_count = compile_requirements.values.count { |requirement| !requirement.compiled? }
          @event_log_stage = Config.event_log.begin_stage('Compiling packages', compilation_count)
          return if cancelled?

          begin
            ThreadPool.new(max_threads: @compilation_config.workers).wrap do |pool|
              loop do
                # process as many requirements without waiting
                loop do
                  requirement = @requirements_mutex.synchronize { @ready_requirements.pop }
                  break if requirement.nil?

                  pool.process { process_requirement(requirement) }
                end

                break if !pool.working? && @ready_requirements.empty?

                sleep(0.1)
              end
            end
          ensure
            # Delete all of the VMs if we were reusing compilation VMs. This can't
            # happen until everything was done compiling.
            if @compilation_config.reuse_compilation_vms
              # Using a new ThreadPool instead of reusing the previous one,
              # as if there's a failed compilation, the thread pool will stop
              # processing any new thread.
              @compilation_instance_pool.delete_instances(@compilation_config.workers)
            end
          end
        end

        def enqueue_unblocked_requirements(requirement)
          @requirements_mutex.synchronize do
            @logger.info("Unblocking dependents of '#{requirement.package.desc}' for '#{requirement.stemcell.desc}'")
            requirement.dependent_requirements.each do |dep_requirement|
              next unless dep_requirement.ready_to_compile?

              @logger.info(
                "Package '#{dep_requirement.package.desc}' now ready to be "\
                "compiled for '#{dep_requirement.stemcell.desc}'",
              )
              @ready_requirements << dep_requirement
            end
          end
        end

        def process_requirement(requirement)
          package_desc = requirement.package.desc
          stemcell_desc = requirement.stemcell.desc
          requirement_desc = "package '#{package_desc}' for stemcell '#{stemcell_desc}'"

          with_thread_name("compile_package(#{package_desc}, #{stemcell_desc})") do
            @event_log_stage.advance_and_track(package_desc) do
              @logger.info("Compiling #{requirement_desc}")
              compile_package(requirement)
              @logger.info("Finished compiling #{requirement_desc}")
              enqueue_unblocked_requirements(requirement)
            end
          end
        end

        def add_signed_urls(dependency_spec, blobstore_headers)
          dependency_spec.each do |_, spec|
            spec['package_get_signed_url'] = @blobstore.sign(spec['blobstore_id'])
            spec['blobstore_headers'] = blobstore_headers unless blobstore_headers.empty?
          end
        end
      end
    end
  end
end
