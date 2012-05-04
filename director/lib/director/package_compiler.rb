# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  class PackageCompiler

    attr_accessor :compile_tasks
    attr_accessor :ready_tasks
    attr_accessor :network_reservations

    # @param [Bosh::Director::DeploymentPlan] deployment_plan Deployment plan
    def initialize(deployment_plan)
      @deployment_plan = deployment_plan

      @cloud = Config.cloud
      @event_log = Config.event_log
      @logger = Config.logger
      @job = Config.current_job

      @tasks_mutex = Mutex.new
      @networks_mutex = Mutex.new

      compilation_config = @deployment_plan.compilation

      @network = compilation_config.network
      @compilation_resources = compilation_config.cloud_properties
      @compilation_env = compilation_config.env

      @vm_reuser = VmReuser.new
    end

    def compile
      @ready_tasks = []

      @logger.info("Building package index for this release")
      generate_package_indices

      # TODO: probably can be made easier to read if scheduling is decoupled
      #       from the actual compilation
      @logger.info("Generating a list of compile tasks")
      generate_compile_tasks
      generate_reverse_dependencies

      @compile_tasks.each_value do |task|
        if task.ready_to_compile?
          @logger.info("Marking package ready for compilation: `%s/%s'" % [
            task.package.name, stemcell_name_version(task.stemcell)])
          @ready_tasks << task
        end
      end

      if @ready_tasks.empty?
        @logger.info("All packages are already compiled")
        return
      end

      reserve_networks
      compile_packages
      release_networks

      @job.task_checkpoint if @job
    end

    def compile_packages
      @event_log.begin_stage("Compiling packages", compilation_count)
      number_of_workers = @deployment_plan.compilation.workers

      ThreadPool.new(:max_threads => number_of_workers).wrap do |pool|
        begin
          loop do
            # process as many tasks without waiting
            loop do
              task = @ready_tasks.pop

              break unless task
              break if @job && @job.task_cancelled?
              @logger.info("Enqueuing package ready for compilation: '#{task}'")
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
      package = task.package
      stemcell = task.stemcell

      package_desc = "#{package.name}/#{package.version}"
      stemcell_desc = stemcell_name_version(stemcell)

      with_thread_name("compile_package(#{package_desc}, #{stemcell_desc})") do
        if @job && @job.task_cancelled?
          @logger.info("Cancelled compiling package #{package_desc} " +
                         "on stemcell #{stemcell_desc}")
        else
          @event_log.track(package_desc) do
            compile_package(task)
            enqueue_unblocked_tasks(task)
            @logger.info("Finished compiling package: #{package_desc} " +
                           "on stemcell: #{stemcell_desc}")
          end
        end
      end
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
        reservation = NetworkReservation.new(
            :type => NetworkReservation::DYNAMIC)
        @network.reserve(reservation)
        unless reservation.reserved?
          # TODO: proper exception
          raise "Could not reserve network for package compilation: %s" % (
          reservation.error)
        end

        @network_reservations << reservation
      end
    end

    def release_networks
      @network_reservations.each do |reservation|
        @network.release(reservation)
      end
    end

    # A helper function for creating the stemcell string name/version commonly
    # printed out.
    # @param [Models::Stemcell] stemcell The stemcells to create a string for.
    # @return [String] The string name for the stemcell.
    def stemcell_name_version(stemcell)
      "#{stemcell.name}/#{stemcell.version}"
    end

    def compile_package(task)
      package = task.package
      stemcell = task.stemcell

      build = generate_build_number(package, stemcell)
      agent_task = nil

      @logger.info("Compiling package: #{package.name}/#{package.version} on " +
                   "stemcell: #{stemcell_name_version(stemcell)}")

      prepare_vm(stemcell) do |vm_data|
        agent_task = vm_data.agent.compile_package(package.blobstore_id,
            package.sha1, package.name, "#{package.version}.#{build}",
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

      task.compiled_package = compiled_package
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
        unless vm_data.nil?
          @logger.info("Reusing compilation VM cid #{vm_data.vm.cid} for " +
                       "stemcell #{stemcell_name_version(stemcell)}.")
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
          raise "There should never be more VMs for a stemcell than the " +
                "number of workers in reuse_compilation_vms mode."
        end
      end

      @logger.info("Creating new compilation VM for stemcell " +
                   "#{stemcell_name_version(stemcell)}.")
      reservation = nil
      @networks_mutex.synchronize do
        reservation = @network_reservations.shift
      end

      network_settings = {
        @network.name => @network.network_settings(reservation)
      }

      vm = VmCreator.new.create(@deployment_plan.deployment, stemcell,
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

    def enqueue_unblocked_tasks(task)
      @logger.info("Looking for packages waiting for this compilation")
      @tasks_mutex.synchronize do
        dependencies = @reverse_dependencies[task.key]
        if dependencies
          dependencies.each do |blocked_task|
            if blocked_task.ready_to_compile?
              @logger.info("Marking unblocked package for compilation: " +
                             "#{blocked_task.package.name}/" +
                             stemcell_name_version(blocked_task.stemcell))
              @ready_tasks << blocked_task
            end
          end
        end
      end
    end

    # Returns JSON-encoded stable representation of package dependencies. This
    # representation doesn't include release name, so differentiating packages
    # with the same name from different releases is up to the caller.
    # @param [Array<Bosh::Director::Models::Package>] packages List of packages
    # @return [String] JSON-encoded dependency key
    def generate_dependency_key(packages)
      key = packages.map { |package| [package.name, package.version] }
      key.sort! { |a, b| a.first <=> b.first }

      Yajl::Encoder.encode(key)
    end

    # Generates all compilation tasks required to compile all packages
    # in the jobs defined by deployment plan
    # @return [void]
    def generate_compile_tasks
      @compile_tasks = {}

      @deployment_plan.jobs.each do |job|
        @logger.info("Processing job: #{job.release.name}/#{job.name}")
        stemcell = job.resource_pool.stemcell

        @logger.info("Job will be compiled for: " +
                       stemcell_name_version(stemcell))

        job.template.packages.each do |package|
          schedule_compilation(job, package, stemcell.stemcell)
        end
      end

      bind_dependent_tasks
    end

    # Schedules package compilation for a given (package, stemcell) tuple
    # @param [Bosh::Director::DeploymentPlan::JobSpec] job Job spec
    # @param [Bosh::Director::Models::Package] package Package model
    # @param [Bosh::Director::Models::Stemcell] stemcell Stemcell model
    def schedule_compilation(job, package, stemcell)
      @logger.info("Processing package: #{package.name}")

      dependencies = get_dependencies(package)
      dependency_key = generate_dependency_key(dependencies)

      compiled_package = Models::CompiledPackage[
        :package_id => package.id,
        :stemcell_id => stemcell.id,
        :dependency_key => dependency_key
      ]

      if compiled_package
        @logger.info("Found compiled_package: #{compiled_package.id}")
      else
        @logger.info("Package '#{package.name}' needs to be compiled on " +
                       stemcell_name_version(stemcell))
      end

      task_key = [package.id, stemcell.id]

      # Could have been partially created during dependency scan
      compile_task = @compile_tasks[task_key]
      if compile_task.nil?
        compile_task = CompileTask.new(task_key)
        compile_task.stemcell = stemcell
        @compile_tasks[compile_task.key] = compile_task
      end

      # Only do these once when the task is fully created
      unless compile_task.package
        compile_task.package = package
        compile_task.dependency_key = dependency_key
        compile_task.compiled_package = compiled_package

        process_task_dependencies(compile_task, dependencies)
      end

      compile_task.add_job(job)
    end

    # @param [Bosh::Director::CompileTask] compile_task Compilation task
    # @param [Array<Bosh::Director::Models::Package>] dependencies Dependencies
    #   of the compile task package
    def process_task_dependencies(compile_task, dependencies)
      @logger.info("Processing dependencies")

      dependencies.each do |dependency|
        @logger.info("Processing dependency: #{dependency.name}")
        task_key = [dependency.id, compile_task.stemcell.id]
        dependent_task = @compile_tasks[task_key]
        if dependent_task.nil?
          dependent_task = CompileTask.new(task_key)
          dependent_task.stemcell = compile_task.stemcell
          @compile_tasks[dependent_task.key] = dependent_task
        end
        compile_task.dependencies << dependent_task
      end
    end

    # Generates a number of helpful indices to look up packages.
    # Treats packages from different releases with the same name as different
    # packages.
    # @return [void]
    def generate_package_indices
      @package_name_index = {}
      @package_id_index = {}

      @deployment_plan.releases.each do |release|
        release_id = release.release.id

        # We bucket packages by release name and package name, as packages
        # from different releases might have the same name
        @package_name_index[release_id] = {}

        release.release_version.packages.each do |package|
          @package_name_index[release_id][package.name] = package
          @package_id_index[package.id] = package
        end
      end
    end

    # Traverses compilation tasks, finds and generates their dependencies
    def bind_dependent_tasks
      @logger.info("Filling in compile tasks for dependencies")
      @compile_tasks.each do |key, task|
        package_id, stemcell_id = key

        if task.package.nil?
          package = @package_id_index[package_id]

          @logger.info("Filling in dependencies for package: #{package.name}")

          dependencies = get_dependencies(package)
          dependency_key = generate_dependency_key(dependencies)

          compiled_package = Models::CompiledPackage[
            :package_id => package.id,
            :stemcell_id => stemcell_id,
            :dependency_key => dependency_key
          ]

          task.package = package
          task.dependency_key = dependency_key
          task.compiled_package = compiled_package
          task.dependencies = []

          dependencies.each do |dependency|
            dependency_task_key = [dependency.id, stemcell_id]
            task.dependencies << @compile_tasks[dependency_task_key]
          end
        end
      end
    end

    def generate_reverse_dependencies
      @reverse_dependencies = {}
      @compile_tasks.each_value do |task|
        task.dependencies.each do |dependent_task|
          (@reverse_dependencies[dependent_task.key] ||= []) << task
        end
      end
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

    # Returns the list of dependencies for a given package
    # @param [Bosh::Director::Models::Package]
    # @return [Array<Bosh::Director::Models::Package>] List of dependencies
    def get_dependencies(package)
      package.dependency_set.map do |dependency_name|
        @package_name_index[package.release_id][dependency_name]
      end
    end

    def generate_build_number(package, stemcell)
      build = Models::CompiledPackage.filter(
        :package_id => package.id,
        :stemcell_id => stemcell.id).max(:build)

      build ? build + 1 : 1
    end

    def compilation_count
      counter = 0
      @compile_tasks.each_value do |task|
        counter += 1 if task.compiled_package.nil?
      end
      counter
    end

    def generate_agent_id
      UUIDTools::UUID.random_create.to_s
    end
  end
end
