# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  class PackageCompiler

    # TODO Support nested dependencies
    # TODO Decouple tsort from the actual compilation
    # TODO (optimization) Compile packages with the most dependents first

    attr_reader :compilations_performed

    # @param [DeploymentPlan] deployment_plan Deployment plan
    def initialize(deployment_plan)
      @deployment_plan = deployment_plan

      @cloud = Config.cloud
      @event_log = Config.event_log
      @logger = Config.logger
      @director_job = Config.current_job

      @tasks_mutex = Mutex.new
      @networks_mutex = Mutex.new
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
        reserve_networks
        compile_packages
        release_networks
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

      return task if task # We already visited this task and its dependencies

      dependencies = package.dependency_set.map do |name|
        job.release.get_package_model_by_name(name)
      end

      task = CompileTask.new(package, stemcell)
      task.dependency_key = generate_dependency_key(dependencies)
      task.add_job(job)

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

    def reserve_networks
      @network_reservations = []
      num_workers = @deployment_plan.compilation.workers
      num_stemcells = @ready_tasks.map { |task| task.stemcell }.uniq.size
      # If we're reusing VMs, we allow up to num_stemcells * num_workers VMs.
      # This is the simplest approach to dealing with a deployment that has more
      # than 1 stemcell.
      num_networks = @deployment_plan.compilation.reuse_compilation_vms ?
        num_stemcells * num_workers : num_workers

      num_networks.times do
        reservation = NetworkReservation.new_dynamic
        @network.reserve(reservation)
        unless reservation.reserved?
          raise PackageCompilationNetworkNotReserved,
                "Could not reserve network for package compilation: " +
                  reservation.error.to_s
        end

        @network_reservations << reservation
      end
    end

    def compile_packages
      @event_log.begin_stage("Compiling packages", compilation_count)
      number_of_workers = @deployment_plan.compilation.workers

      ThreadPool.new(:max_threads => number_of_workers).wrap do |pool|
        begin
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
        ensure
          # Delete all of the VMs if we were reusing compilation VMs. This can't
          # happen until everything was done compiling.
          if @deployment_plan.compilation.reuse_compilation_vms
            @vm_reuser.each do |vm_data|
              tear_down_vm(vm_data)
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

      build = generate_build_number(package, stemcell)
      agent_task = nil

      prepare_vm(stemcell) do |vm_data|
        agent_task =
          vm_data.agent.compile_package(package.blobstore_id,
                                        package.sha1, package.name,
                                        "#{package.version}.#{build}",
                                        task.dependency_spec)
      end

      task_result = agent_task["result"]

      compiled_package = Models::CompiledPackage.create do |p|
        p.package = package
        p.stemcell = stemcell
        p.sha1 = task_result["sha1"]
        p.build = build
        p.blobstore_id = task_result["blobstore_id"]
        p.dependency_key = task.dependency_key
      end

      @counter_mutex.synchronize { @compilations_performed += 1 }

      task.use_compiled_package(compiled_package)
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

    def release_networks
      @network_reservations.each do |reservation|
        @network.release(reservation)
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
      reservation = nil
      @networks_mutex.synchronize do
        reservation = @network_reservations.shift
      end

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
      @networks_mutex.synchronize do
        @network_reservations << reservation
      end
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
        return compiled_package
      end

      # Check if packages with the same sha1 have already been compiled
      similar_packages_dataset = Models::Package.filter(:sha1 => package.sha1)
      similar_packages = similar_packages_dataset.exclude(:id => package.id).all
      similar_package_ids = similar_packages.map { |package| package.id }

      search_attr = {
        :package_id => similar_package_ids,
        :stemcell_id => stemcell.id,
        :dependency_key => dependency_key
      }
      compiled_package = Models::CompiledPackage.filter(search_attr).first

      unless compiled_package
        @logger.info("Package `#{package.desc}' " +
                     "needs to be compiled on `#{stemcell.desc}'")
        return nil
      end

      # Found a compiled package that matches the given package and stemcell
      @logger.info("Found compiled version of package `#{package.desc}' " +
                   "for stemcell `#{stemcell.desc}'")

      # Make a copy of this compiled package
      blobstore_id = BlobUtil.copy_blob(compiled_package.blobstore_id)

      # Add a new entry for this package
      Models::CompiledPackage.create do |p|
        p.package = package
        p.stemcell = stemcell
        p.sha1 = compiled_package.sha1
        p.build = generate_build_number(package, stemcell)
        p.blobstore_id = blobstore_id
        p.dependency_key = dependency_key
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
        "deployment" => @deployment_plan.name,
        "resource_pool" => "package_compiler",
        "networks" => network_settings
      }

      vm.update(:apply_spec => state)
      agent.apply(state)
    end

    # Returns JSON-encoded stable representation of package dependencies. This
    # representation doesn't include release name, so differentiating packages
    # with the same name from different releases is up to the caller.
    # @param [Array<Models::Package>] packages List of packages
    # @return [String] JSON-encoded dependency key
    def generate_dependency_key(packages)
      Models::CompiledPackage.generate_dependency_key(packages)
    end

    def generate_build_number(package, stemcell)
      attrs = {
        :package_id => package.id,
        :stemcell_id => stemcell.id
      }

      Models::CompiledPackage.filter(attrs).max(:build).to_i + 1
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
