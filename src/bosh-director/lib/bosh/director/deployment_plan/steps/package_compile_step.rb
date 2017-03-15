require 'bosh/director/compile_task_generator'
require 'digest/sha1'

module Bosh::Director
  module DeploymentPlan
    module Steps
      class PackageCompileStep
        include LockHelper

        attr_reader :compilations_performed

        def initialize(jobs_to_compile, compilation_config, compilation_instance_pool, logger, director_job)
          @event_log_stage = nil
          @logger = logger
          @director_job = director_job

          @tasks_mutex = Mutex.new
          @counter_mutex = Mutex.new

          @compilation_instance_pool = compilation_instance_pool
          @compile_tasks = {}
          @ready_tasks = []
          @compilations_performed = 0
          @jobs_to_compile = jobs_to_compile
          @compilation_config = compilation_config
        end

        def perform
          @logger.info('Generating a list of compile tasks')
          prepare_tasks

          @compile_tasks.each_value do |task|
            if task.ready_to_compile?
              @logger.info("Package '#{task.package.desc}' is ready to be compiled for stemcell '#{task.stemcell.desc}'")
              @ready_tasks << task
            end
          end

          if @ready_tasks.empty?
            @logger.info('All packages are already compiled')
          else
            compile_packages
            director_job_checkpoint
          end
        end

        def compile_tasks_count
          @compile_tasks.size
        end

        def ready_tasks_count
          @tasks_mutex.synchronize { @ready_tasks.size }
        end

        def compile_package(task)
          package = task.package
          stemcell = task.stemcell

          with_compile_lock(package.id, "#{stemcell.os}/#{stemcell.version}") do
            # Check if the package was compiled in a parallel deployment
            compiled_package = task.find_compiled_package(@logger, @event_log_stage)
            if compiled_package.nil?
              build = Models::CompiledPackage.generate_build_number(package, stemcell.os, stemcell.version)
              task_result = nil

              prepare_vm(stemcell) do |instance|
                metadata_updater.update_vm_metadata(instance.model, :compiling => package.name)
                agent_task =
                  instance.agent_client.compile_package(
                    package.blobstore_id,
                    package.sha1,
                    package.name,
                    "#{package.version}.#{build}",
                    task.dependency_spec
                  )

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

        # This method will create a VM for each stemcell in the stemcells array
        # passed in.  The VMs are yielded and their destruction is ensured.
        # @param [Models::Stemcell] stemcell The stemcells that need to have
        #     compilation VMs created.
        # @yield [DeploymentPlan::Instance] Yields an instance that should be used for compilation.  This may be a reused VM or a
        def prepare_vm(stemcell)
          if @compilation_config.reuse_compilation_vms
            @compilation_instance_pool.with_reused_vm(stemcell, &Proc.new)
          else
            @compilation_instance_pool.with_single_use_vm(stemcell, &Proc.new)
          end
        end

        private

        def prepare_tasks
          @event_log_stage = Config.event_log.begin_stage('Preparing package compilation', 1)
          @compile_task_generator = CompileTaskGenerator.new(@logger, @event_log_stage)

          @event_log_stage.advance_and_track('Finding packages to compile') do
            @jobs_to_compile.each do |instance_group|
              stemcell = instance_group.stemcell

              job_descs = instance_group.jobs.map do |job|
                # we purposefully did NOT inline those because
                # when instance_double blows up,
                # it's obscure which double is at fault
                release_name = job.release.name
                job_name = job.name
                "'#{release_name}/#{job_name}'"
              end
              @logger.info("Job templates #{job_descs.join(', ')} need to run on stemcell '#{stemcell.desc}'")

              instance_group.jobs.each do |job|
                job.package_models.each do |package|
                  @compile_task_generator.generate!(@compile_tasks, instance_group, job, package, stemcell)
                end
              end
            end
          end
        end

        def compile_packages
          @event_log_stage = Config.event_log.begin_stage('Compiling packages', compilation_count)

          begin
            ThreadPool.new(:max_threads => @compilation_config.workers).wrap do |pool|
              loop do
                # process as many tasks without waiting
                loop do
                  break if director_job_cancelled?
                  task = @tasks_mutex.synchronize { @ready_tasks.pop }
                  break if task.nil?

                  pool.process { process_task(task) }
                end

                break if !pool.working? && (director_job_cancelled? || @ready_tasks.empty?)
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
            if director_job_cancelled?
              @logger.info("Cancelled compiling #{task_desc}")
            else
              @event_log_stage.advance_and_track(package_desc) do
                @logger.info("Compiling #{task_desc}")
                compile_package(task)
                @logger.info("Finished compiling #{task_desc}")
                enqueue_unblocked_tasks(task)
              end
            end
          end
        end

        def director_job_cancelled?
          @director_job && @director_job.task_cancelled?
        end

        def director_job_checkpoint
          @director_job.task_checkpoint if @director_job
        end

        def compilation_count
          counter = 0
          @compile_tasks.each_value do |task|
            counter += 1 unless task.compiled?
          end
          counter
        end

        def metadata_updater
          @metadata_updater ||= MetadataUpdater.build
        end
      end
    end
  end
end
