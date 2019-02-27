require 'bosh/director/compile_task_generator'
require 'digest/sha1'

module Bosh::Director
  module DeploymentPlan
    module Stages
      class PackageCompileStage
        include LockHelper

        attr_reader :compilations_performed

        def self.create(deployment_plan)
          # compiled_package_finder = DeploymentPlan::CompiledPackageFinder.new(Config.logger)
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

          @tasks_mutex = Mutex.new
          @counter_mutex = Mutex.new

          @compilation_instance_pool = compilation_instance_pool
          @ready_tasks = []
          @compilations_performed = 0
          @instance_groups_to_compile = instance_groups_to_compile
          @compilation_config = compilation_config
          @deployment_name = deployment_name

          @release_manager = release_manager
          @package_validator = package_validator
          @compiled_package_finder = compiled_package_finder
        end

        def perform
          validate_packages(@instance_groups_to_compile)

          @logger.info('Generating a list of compile tasks')
          compile_tasks = prepare_tasks(@instance_groups_to_compile)

          compile_tasks.each_value do |task|
            if task.ready_to_compile?
              @logger.info("Package '#{task.package.desc}' is ready to be compiled for stemcell '#{task.stemcell.desc}'")
              @ready_tasks << task
            end
          end

          if @ready_tasks.empty?
            @logger.info('All packages are already compiled')
            return
          end

          compile_packages(compile_tasks)
        end

        def ready_tasks_count
          @tasks_mutex.synchronize { @ready_tasks.size }
        end

        def compile_package(task)
          package = task.package
          stemcell = task.stemcell

          with_compile_lock(package.id, "#{stemcell.os}/#{stemcell.version}", @deployment_name) do
            # Check if the package was compiled in a parallel deployment
            compiled_package = @compiled_package_finder.find_compiled_package(
              package,
              stemcell,
              task.dependency_key,
              task.cache_key,
              @event_log_stage,
            )

            if compiled_package.nil?
              build = Models::CompiledPackage.generate_build_number(package, stemcell.os, stemcell.version)
              task_result = nil

              prepare_vm(stemcell, package) do |instance|
                agent_task =
                  instance.agent_client.compile_package(
                    package.blobstore_id,
                    package.sha1,
                    package.name,
                    "#{package.version}.#{build}",
                    task.dependency_spec,
                  ) { Config.job_cancelled? }

                task_result = agent_task['result']
              end

              compiled_package = Models::CompiledPackage.create do |p|
                p.package = package
                p.stemcell_os = stemcell.os
                p.stemcell_version = stemcell.version
                p.sha1 = task_result['sha1']
                p.build = build
                p.blobstore_id = task_result['blobstore_id']
                p.dependency_key = task.dependency_key
              end

              if Config.use_compiled_package_cache?
                if BlobUtil.exists_in_global_cache?(package, task.cache_key)
                  @logger.info('Already exists in global package cache, skipping upload')
                else
                  @logger.info('Uploading to global package cache')
                  BlobUtil.save_to_global_cache(compiled_package, task.cache_key)
                end
              else
                @logger.info('Global blobstore not configured, skipping upload')
              end

              @counter_mutex.synchronize { @compilations_performed += 1 }
            end

            task.use_compiled_package(compiled_package)
          end
        end

        def prepare_vm(stemcell, package)
          if @compilation_config.reuse_compilation_vms
            @compilation_instance_pool.with_reused_vm(stemcell, package, &Proc.new)
          else
            @compilation_instance_pool.with_single_use_vm(stemcell, package, &Proc.new)
          end
        end

        private

        def validate_packages(instance_groups_to_compile)
          instance_groups_to_compile.each do |instance_group|
            instance_group.jobs.each do |job|
              release_model = @release_manager.find_by_name(job.release.name)
              job_packages = job.package_models.map(&:name)
              release_version_model = @release_manager.find_version(release_model, job.release.version)

              @package_validator.validate(release_version_model, instance_group.stemcell, job_packages)
            end
          end

          @package_validator.handle_faults
        end

        def prepare_tasks(instance_groups_to_compile)
          compile_tasks = {}
          event_log_stage = Config.event_log.begin_stage('Preparing package compilation', 1)

          event_log_stage.advance_and_track('Finding packages to compile') do
            compile_task_generator = CompileTaskGenerator.new(@logger, event_log_stage, @compiled_package_finder)

            instance_groups_to_compile.each do |instance_group|
              stemcell = instance_group.stemcell

              job_descs = instance_group.jobs.map { |job| "'#{job.release.name}/#{job.name}'" }
              @logger.info("Job templates #{job_descs.join(', ')} need to run on stemcell '#{stemcell.desc}'")

              instance_group.jobs.each do |job|
                job.package_models.each do |package|
                  task = compile_task_generator.generate!(compile_tasks, instance_group, job, package, stemcell)

                  instance_group.use_compiled_package(task.compiled_package) if task.compiled?
                end
              end
            end
          end
          compile_tasks
        end

        def cancelled?
          Config.job_cancelled?
          false
        rescue TaskCancelled
          true
        end

        def compile_packages(compile_tasks)
          compilation_count = compile_tasks.values.count { |task| !task.compiled? }
          @event_log_stage = Config.event_log.begin_stage('Compiling packages', compilation_count)
          return if cancelled?

          begin
            ThreadPool.new(max_threads: @compilation_config.workers).wrap do |pool|
              loop do
                # process as many tasks without waiting
                loop do
                  task = @tasks_mutex.synchronize { @ready_tasks.pop }
                  break if task.nil?

                  pool.process { process_task(task) }
                end

                break if !pool.working? && @ready_tasks.empty?

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

        def enqueue_unblocked_tasks(task)
          @tasks_mutex.synchronize do
            @logger.info("Unblocking dependents of '#{task.package.desc}' for '#{task.stemcell.desc}'")
            task.dependent_tasks.each do |dep_task|
              if dep_task.ready_to_compile?
                @logger.info("Package '#{dep_task.package.desc}' now ready to be compiled for '#{dep_task.stemcell.desc}'")
                @ready_tasks << dep_task
              end
            end
          end
        end

        def process_task(task)
          package_desc = task.package.desc
          stemcell_desc = task.stemcell.desc
          task_desc = "package '#{package_desc}' for stemcell '#{stemcell_desc}'"

          with_thread_name("compile_package(#{package_desc}, #{stemcell_desc})") do
            @event_log_stage.advance_and_track(package_desc) do
              @logger.info("Compiling #{task_desc}")
              compile_package(task)
              @logger.info("Finished compiling #{task_desc}")
              enqueue_unblocked_tasks(task)
            end
          end
        end
      end
    end
  end
end
