# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  class PackageCompiler
    include LockHelper
    include MetadataHelper

    attr_reader :compilations_performed

    # @param [DeploymentPlan] deployment_plan Deployment plan
    def initialize(deployment_plan)
      @deployment_plan = deployment_plan

      @cloud = Config.cloud
      @event_log = Config.event_log
      @logger = Config.logger
      @director_job = Config.current_job

      @tasks_mutex = Mutex.new
      @network_mutex = Mutex.new
      @counter_mutex = Mutex.new

      compilation_config = @deployment_plan.compilation

      @network = compilation_config.network
      @compilation_resources = compilation_config.cloud_properties
      @compilation_env = compilation_config.env

      @vm_reuser = VmReuser.new

      @compile_tasks = {}
      @ready_tasks = []
      @compilations_performed = 0
    end

    # @return [Integer] How many compile tasks are present
    def compile_tasks_count
      @compile_tasks.size
    end

    # @return [Integer] How many compile tasks are ready
    def ready_tasks_count
      @tasks_mutex.synchronize { @ready_tasks.size }
    end

    # Generates compilation tasks for all packages in all job templates included
    # in the current deployment and kicks off compilation.
    # @return [void]
    def compile
      @logger.info("Generating a list of compile tasks")
      prepare_tasks

      @compile_tasks.each_value do |task|
        if task.ready_to_compile?
          @logger.info("Package `#{task.package.desc}' is ready to be " +
                       "compiled for stemcell `#{task.stemcell.desc}'")
          @ready_tasks << task
        end
      end

      if @ready_tasks.empty?
        @logger.info("All packages are already compiled")
      else
        compile_packages
        director_job_checkpoint
      end
    end

    # Generates all compilation tasks required to compile all packages
    # in the jobs defined by deployment plan
    # @return [void]
    def prepare_tasks
      @event_log.begin_stage("Preparing package compilation", 1)

      @event_log.track("Finding packages to compile") do
        @deployment_plan.jobs.each do |job|
          job_desc = "#{job.release.name}/#{job.name}"
          stemcell = job.resource_pool.stemcell

          @logger.info("Job `#{job_desc}' needs to run " +
                       "on stemcell `#{stemcell.model.desc}'")

          job.templates.each do |template|
            template.package_models.each do |package|
              generate_compile_task(job, package, stemcell.model)
            end
          end
        end
      end
    end

    # Generates compilation task for a given (package, stemcell) tuple
    # @param [DeploymentPlan::Job] job Job spec
    # @param [Models::Package] package Package model
    # @param [Models::Stemcell] stemcell Stemcell model
    # @return [CompileTask] Compilation task for this package/stemcell tuple
    def generate_compile_task(job, package, stemcell)
      # Our assumption here is that package dependency graph
      # has no cycles: this is being enforced on release upload.
      # Other than that it's a vanilla DFS.

      @logger.info("Checking whether package `#{package.desc}' needs " +
                   "to be compiled for stemcell `#{stemcell.desc}'")
      task_key = [package.id, stemcell.id]
      task = @compile_tasks[task_key]

      if task # We already visited this task and its dependencies
        task.add_job(job) # But we still need to register this job with task
        return task
      end

      dependencies = package.dependency_set.map do |name|
        job.release.get_package_model_by_name(name)
      end

      task = CompileTask.new(package, stemcell, dependencies, job)

      compiled_package = find_compiled_package(task)
      if compiled_package
        task.use_compiled_package(compiled_package)
      end

      @logger.info("Processing package `#{package.desc}' dependencies")
      dependencies.each do |dependency|
        @logger.info("Package `#{package.desc}' depends on " +
                     "package `#{dependency.desc}'")
        dependency_task = generate_compile_task(job, dependency, stemcell)
        task.add_dependency(dependency_task)
      end

      @compile_tasks[task_key] = task
      task
    end

    def reserve_network
      reservation = NetworkReservation.new_dynamic

      @network_mutex.synchronize do
        @network.reserve(reservation)
      end

      if !reservation.reserved?
        raise PackageCompilationNetworkNotReserved,
          "Could not reserve network for package compilation: " +
          reservation.error.to_s
      end

      reservation
    end

    def release_network(reservation)
      @network_mutex.synchronize do
        @network.release(reservation)
      end
    end

    def compile_packages
      @event_log.begin_stage("Compiling packages", compilation_count)
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

            break if !pool.working? && @ready_tasks.empty?
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

    def compile_package(task)
      package = task.package
      stemcell = task.stemcell

      with_compile_lock(package.id, stemcell.id) do
        # Check if the package was compiled in a parallel deployment
        compiled_package = find_compiled_package(task)
        if compiled_package.nil?
          build = Models::CompiledPackage.generate_build_number(package, stemcell)
          task_result = nil

          prepare_vm(stemcell) do |vm_data|
            update_vm_metadata(vm_data.vm, :compiling => package.name)
            agent_task =
              vm_data.agent.compile_package(package.blobstore_id,
                                            package.sha1, package.name,
                                            "#{package.version}.#{build}",
                                            task.dependency_spec)
            task_result = agent_task["result"]
          end

          compiled_package = Models::CompiledPackage.create do |p|
            p.package = package
            p.stemcell = stemcell
            p.sha1 = task_result["sha1"]
            p.build = build
            p.blobstore_id = task_result["blobstore_id"]
            p.dependency_key = task.dependency_key
          end

          if Config.use_compiled_package_cache?
            if BlobUtil.exists_in_global_cache?(package, task.cache_key)
              @logger.info("Already exists in global package cache, skipping upload")
            else
              @logger.info("Uploading to global package cache")
              BlobUtil.save_to_global_cache(compiled_package, task.cache_key)
            end
          else
            @logger.info("Global blobstore not configured, skipping upload")
          end

          @counter_mutex.synchronize { @compilations_performed += 1 }
        end

        task.use_compiled_package(compiled_package)
      end
    end

    def enqueue_unblocked_tasks(task)
      @tasks_mutex.synchronize do
        @logger.info("Unblocking dependents of " +
                     "`#{task.package.desc}` for `#{task.stemcell.desc}`")
        task.dependent_tasks.each do |dep_task|
          if dep_task.ready_to_compile?
            @logger.info("Package `#{dep_task.package.desc}' now ready to be " +
                         "compiled for `#{dep_task.stemcell.desc}'")
            @ready_tasks << dep_task
          end
        end
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
          @logger.info("Reusing compilation VM `#{vm_data.vm.cid}' for " +
                       "stemcell `#{stemcell.desc}'")
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
                "There should never be more VMs for a stemcell than the " +
                "number of workers in reuse_compilation_vms mode"
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
        agent = AgentClient.new(vm.agent_id)
        agent.wait_until_ready

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

    # Tears down a VM and releases the network reservations.
    # @param [VmData] vm_data The VmData object for the VM to tear down.
    def tear_down_vm(vm_data)
      vm = vm_data.vm
      reservation = vm_data.reservation
      @logger.info("Deleting compilation VM: #{vm.cid}")
      @cloud.delete_vm(vm.cid)
      vm.destroy
      release_network(reservation)
    end

    # @param [CompileTask] task
    # @return [Models::CompiledPackage]
    def find_compiled_package(task)
      package = task.package
      stemcell = task.stemcell
      dependency_key = task.dependency_key

      # Check if this package is already compiled
      compiled_package = Models::CompiledPackage[
        :package_id => package.id,
        :stemcell_id => stemcell.id,
        :dependency_key => dependency_key
      ]
      if compiled_package
        @logger.info("Found compiled version of package `#{package.desc}' " +
                     "for stemcell `#{stemcell.desc}'")
      else
        if Config.use_compiled_package_cache?
          if BlobUtil.exists_in_global_cache?(package, task.cache_key)
            @event_log.track("Downloading '#{package.desc}' from global cache") do
              # has side effect of putting CompiledPackage model in db
              compiled_package = BlobUtil.fetch_from_global_cache(package, stemcell, task.cache_key, dependency_key)
            end
          end
        end

        if compiled_package
          @logger.info("Package `Found compiled version of package `#{package.desc}'" +
                       "for stemcell `#{stemcell.desc}' in global cache")
        else
          @logger.info("Package `#{package.desc}' " +
                       "needs to be compiled on `#{stemcell.desc}'")
        end
      end

      compiled_package
    end

    def director_job_cancelled?
      @director_job && @director_job.task_cancelled?
    end

    def director_job_checkpoint
      @director_job.task_checkpoint if @director_job
    end

    def configure_vm(vm, agent, network_settings)
      state = {
        "deployment" => @deployment_plan.name,
        "resource_pool" => "package_compiler",
        "networks" => network_settings
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
  end
end
