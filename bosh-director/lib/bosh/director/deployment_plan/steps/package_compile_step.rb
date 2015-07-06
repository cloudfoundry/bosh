require 'bosh/director/compile_task_generator'
require 'digest/sha1'

module Bosh::Director
  module DeploymentPlan
    module Steps
      class PackageCompileStep
        include LockHelper

        attr_reader :compilations_performed

        # @param [DeploymentPlan] deployment_plan Deployment plan
        def initialize(deployment_plan, cloud, logger, event_log, director_job)
          @deployment_plan = deployment_plan

          @cloud = cloud
          @event_log = event_log
          @logger = logger
          @director_job = director_job

          @tasks_mutex = Mutex.new
          @network_mutex = Mutex.new
          @counter_mutex = Mutex.new

          compilation_config = @deployment_plan.compilation

          @network = compilation_config.network
          @compilation_resources = compilation_config.cloud_properties
          @compilation_env = compilation_config.env

          @vm_reuser = VmReuser.new

          @compile_task_generator = CompileTaskGenerator.new(@logger, @event_log)

          @compile_tasks = {}
          @ready_tasks = []
          @compilations_performed = 0
        end

        def perform
          @logger.info('Generating a list of compile tasks')
          prepare_tasks

          @compile_tasks.each_value do |task|
            if task.ready_to_compile?
              @logger.info("Package `#{task.package.desc}' is ready to be compiled for stemcell `#{task.stemcell.desc}'")
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

          with_compile_lock(package.id, stemcell.id) do
            # Check if the package was compiled in a parallel deployment
            compiled_package = task.find_compiled_package(@logger, @event_log)
            if compiled_package.nil?
              build = Models::CompiledPackage.generate_build_number(package, stemcell)
              task_result = nil

              prepare_vm(stemcell) do |vm_data|
                vm_metadata_updater.update(vm_data.vm, :compiling => package.name)
                agent_task =
                  vm_data.agent.compile_package(package.blobstore_id,
                                                package.sha1, package.name,
                                                "#{package.version}.#{build}",
                                                task.dependency_spec)
                task_result = agent_task['result']
              end

              compiled_package = Models::CompiledPackage.create do |p|
                p.package = package
                p.stemcell = stemcell
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
        # @yield [VmData] Yields a VmData object that contains all the data for the
        #     VM that should be used for compilation.  This may be a reused VM or a
        #     freshly created VM.
        def prepare_vm(stemcell)
          # If we're reusing VMs, try to just return an already-created VM.
          if @deployment_plan.compilation.reuse_compilation_vms
            vm_data = @vm_reuser.get_vm(stemcell)
            if vm_data
              @logger.info("Reusing compilation VM `#{vm_data.vm.cid}' for stemcell `#{stemcell.desc}'")
              begin
                yield vm_data
              ensure
                vm_data.release
              end
              return
            end
            # This shouldn't happen. If it does there's a bug.
            if @vm_reuser.get_num_vms(stemcell) >=
              @deployment_plan.compilation.workers
              raise PackageCompilationNotEnoughWorkersForReuse,
                    'There should never be more VMs for a stemcell than the number of workers in reuse_compilation_vms mode'
            end
          end

          @logger.info("Creating compilation VM for stemcell `#{stemcell.desc}'")

          reservation = reserve_network

          network_settings = {
            @network.name => @network.network_settings(reservation)
          }

          vm = VmCreator.create(@deployment_plan.model, stemcell,
                                @compilation_resources, network_settings,
                                nil, @compilation_env)
          vm_data = @vm_reuser.add_vm(reservation, vm, stemcell, network_settings)

          @logger.info("Configuring compilation VM: #{vm.cid}")

          begin
            agent = AgentClient.with_defaults(vm.agent_id)
            agent.wait_until_ready
            agent.update_settings(Bosh::Director::Config.trusted_certs)
            vm.update(:trusted_certs_sha1 => Digest::SHA1.hexdigest(Bosh::Director::Config.trusted_certs))

            configure_vm(vm, agent, network_settings)
            vm_data.agent = agent
            yield vm_data
          rescue RpcTimeout => e
            # if we time out waiting for the agent, we should clean up the the VM
            # as it will leave us in an unrecoverable state otherwise
            @vm_reuser.remove_vm(vm_data)
            tear_down_vm(vm_data)
            raise e
          ensure
            vm_data.release
            unless @deployment_plan.compilation.reuse_compilation_vms
              tear_down_vm(vm_data)
            end
          end
        end

        private

        def prepare_tasks
          @event_log.begin_stage('Preparing package compilation', 1)

          @event_log.track('Finding packages to compile') do
            @deployment_plan.jobs.each do |job|
              stemcell = job.resource_pool.stemcell

              template_descs = job.templates.map do |t|
                # we purposefully did NOT inline those because
                # when instance_double blows up,
                # it's obscure which double is at fault
                release_name = t.release.name
                template_name = t.name
                "`#{release_name}/#{template_name}'"
              end
              @logger.info("Job templates #{template_descs.join(', ')} need to run on stemcell `#{stemcell.model.desc}'")

              job.templates.each do |template|
                template.package_models.each do |package|
                  @compile_task_generator.generate!(@compile_tasks, job, template, package, stemcell.model)
                end
              end
            end
          end
        end

        def tear_down_vm(vm_data)
          vm = vm_data.vm
          if vm.exists?
            reservation = vm_data.reservation
            @logger.info("Deleting compilation VM: #{vm.cid}")
            @cloud.delete_vm(vm.cid)
            vm.destroy
            release_network(reservation)
          end
        end

        def reserve_network
          reservation = NetworkReservation.new_dynamic

          @network_mutex.synchronize do
            @network.reserve(reservation)
          end

          unless reservation.reserved?
            raise PackageCompilationNetworkNotReserved,
                  "Could not reserve network for package compilation: #{reservation.error}"
          end

          reservation
        end

        def release_network(reservation)
          @network_mutex.synchronize do
            @network.release(reservation)
          end
        end

        def compile_packages
          @event_log.begin_stage('Compiling packages', compilation_count)
          number_of_workers = @deployment_plan.compilation.workers

          begin
            ThreadPool.new(:max_threads => number_of_workers).wrap do |pool|
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
            if @deployment_plan.compilation.reuse_compilation_vms
              # Using a new ThreadPool instead of reusing the previous one,
              # as if there's a failed compilation, the thread pool will stop
              # processing any new thread.
              ThreadPool.new(:max_threads => number_of_workers).wrap do |pool|
                @vm_reuser.each do |vm_data|
                  pool.process { tear_down_vm(vm_data) }
                end
              end
            end
          end
        end

        def enqueue_unblocked_tasks(task)
          @tasks_mutex.synchronize do
            @logger.info("Unblocking dependents of `#{task.package.desc}` for `#{task.stemcell.desc}`")
            task.dependent_tasks.each do |dep_task|
              if dep_task.ready_to_compile?
                @logger.info("Package `#{dep_task.package.desc}' now ready to be compiled for `#{dep_task.stemcell.desc}'")
                @ready_tasks << dep_task
              end
            end
          end
        end

        def process_task(task)
          package_desc = task.package.desc
          stemcell_desc = task.stemcell.desc
          task_desc = "package `#{package_desc}' for stemcell `#{stemcell_desc}'"

          with_thread_name("compile_package(#{package_desc}, #{stemcell_desc})") do
            if director_job_cancelled?
              @logger.info("Cancelled compiling #{task_desc}")
            else
              @event_log.track(package_desc) do
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

        def configure_vm(vm, agent, network_settings)
          state = {
            'deployment' => @deployment_plan.name,
            'resource_pool' => {},
            'networks' => network_settings
          }

          vm.update(:apply_spec => state)
          agent.apply(state)
        end

        def compilation_count
          counter = 0
          @compile_tasks.each_value do |task|
            counter += 1 unless task.compiled?
          end
          counter
        end

        def vm_metadata_updater
          @vm_metadata_updater ||= VmMetadataUpdater.build
        end
      end
    end
  end
end
