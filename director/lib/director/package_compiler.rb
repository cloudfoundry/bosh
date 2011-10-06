module Bosh::Director

  class PackageCompiler

    class CompileTask
      attr_accessor :key
      attr_accessor :jobs
      attr_accessor :package
      attr_accessor :stemcell
      attr_reader   :compiled_package
      attr_accessor :dependency_key
      attr_accessor :dependencies

      def initialize(key)
        @key = key
        @jobs = []
      end

      def dependencies_satisfied?
        @dependencies.find { |dependent_task| dependent_task.compiled_package.nil? }.nil?
      end

      def ready_to_compile?
        @compiled_package.nil? && dependencies_satisfied?
      end

      def compiled_package= (compiled_package)
        @compiled_package = compiled_package
        @jobs.each { |job| job.add_package(@package, @compiled_package) } if @compiled_package
      end

      def add_job(job)
        @jobs << job
        job.add_package(@package, @compiled_package) if @compiled_package
      end

      def dependency_spec
        spec = {}
        @dependencies.each do |dependency|
          package = dependency.package
          compiled_package = dependency.compiled_package
          spec[package.name] = {
              "name"         => package.name,
              "version"      => "#{package.version}.#{compiled_package.build}",
              "sha1"         => compiled_package.sha1,
              "blobstore_id" => compiled_package.blobstore_id
          }
        end
        spec
      end
    end

    def initialize(deployment_plan, job = nil)
      @deployment_plan = deployment_plan
      @cloud = Config.cloud
      @event_log = Config.event_log
      @logger = Config.logger
      @tasks_mutex = Mutex.new
      @networks_mutex = Mutex.new
      @job = job
    end

    def compile
      @ready_tasks = []
      generate_compile_tasks
      generate_reverse_dependencies

      @compile_tasks.each_value do |task|
        if task.ready_to_compile?
          @logger.info("Marking package ready for compilation: #{task.package.name}/#{task.stemcell.name}")
          @ready_tasks << task
        end
      end

      if @ready_tasks.empty?
        @logger.info("All packages are already compiled")
        return
      end

      @compilation_resources = @deployment_plan.compilation.cloud_properties
      @compilation_env = @deployment_plan.compilation.env

      @network = @deployment_plan.compilation.network
      @networks = []
      @deployment_plan.compilation.workers.times do
        defaults = DeploymentPlan::NetworkSpec::VALID_DEFAULT_NETWORK_PROPERTIES_ARRAY
        @networks << {@network.name => @network.network_settings(@network.allocate_dynamic_ip, defaults)}
      end

      compilations_count = @compile_tasks.inject(0) do |sum, (key, task)|
        sum += 1 if task.compiled_package.nil?
        sum
      end

      @event_log.begin_stage("Compiling packages", compilations_count)

      ThreadPool.new(:max_threads => @deployment_plan.compilation.workers).wrap do |pool|
        loop do
          loop do
            task = @ready_tasks.pop
            break if task.nil?
            break if @job && @job.task_cancelled?

            package = task.package
            stemcell = task.stemcell

            @logger.info("Enqueuing package ready for compilation: #{package.name}/#{stemcell.name}")

            pool.process do
              package_desc = "#{package.name}/#{package.version}"
              stemcell_desc = "#{stemcell.name}/#{stemcell.version})"

              with_thread_name("compile_package(#{package_desc}, #{stemcell_desc})") do
                if @job && @job.task_cancelled?
                  @logger.info("Cancelled compiling package #{package_desc} on stemcell #{stemcell_desc}")
                else
                  @event_log.track(package_desc) do
                    compile_package(task)
                    enqueue_unblocked_tasks(task)
                    @logger.info("Finished compiling package: #{package_desc} on stemcell: #{stemcell_desc}")
                  end
                end
              end
            end
          end

          break if !pool.working? && @ready_tasks.empty?
          sleep(0.1)
        end
      end

      @networks.each do |network_settings|
        ip = network_settings[@network.name]["ip"]
        @network.release_dynamic_ip(ip)
      end
      @job.task_checkpoint if @job
    end

    def compile_package(task)
      package  = task.package
      stemcell = task.stemcell

      build = Models::CompiledPackage.filter(:package_id => package.id, :stemcell_id => stemcell.id).max(:build)
      build = build ? build + 1 : 1

      @logger.info("Compiling package: #{package.name}/#{package.version} on " +
                       "stemcell: #{stemcell.name}/#{stemcell.version}")
      network_settings = nil
      @networks_mutex.synchronize do
        network_settings = @networks.shift
      end

      agent_id = generate_agent_id
      vm = Models::Vm.create(:deployment => @deployment_plan.deployment, :agent_id => agent_id)
      @logger.info("Creating compilation VM with agent id: #{agent_id}")
      vm_cid = @cloud.create_vm(agent_id, stemcell.cid, @compilation_resources, network_settings, nil, @compilation_env)
      vm.cid = vm_cid
      vm.save

      @logger.info("Configuring compilation VM: #{vm_cid}")
      begin
        agent = AgentClient.new(agent_id)
        agent.wait_until_ready

        configure_vm(agent, network_settings)

        @logger.info("Compiling package on compilation VM")
        agent_task = agent.compile_package(package.blobstore_id, package.sha1, package.name,
                                           "#{package.version}.#{build}", task.dependency_spec)
        while agent_task["state"] == "running"
          sleep(1.0)
          agent_task = agent.get_task(agent_task["agent_task_id"])
        end
      ensure
        @logger.info("Deleting compilation VM: #{vm_cid}")
        @cloud.delete_vm(vm_cid)
        vm.destroy
      end

      @networks_mutex.synchronize do
        @networks << network_settings
      end

      task_result = agent_task["result"]

      compiled_package = Models::CompiledPackage.create(:package => package,
                                                        :stemcell => stemcell,
                                                        :sha1 => task_result["sha1"],
                                                        :build => build,
                                                        :blobstore_id => task_result["blobstore_id"],
                                                        :dependency_key => task.dependency_key)

      task.compiled_package = compiled_package
    end

    def enqueue_unblocked_tasks(task)
      @logger.info("Looking for packages waiting for this compilation")
      @tasks_mutex.synchronize do
        dependencies = @reverse_dependencies[task.key]
        if dependencies
          dependencies.each do |blocked_task|
            if blocked_task.ready_to_compile?
              @logger.info("Marking unblocked package for compilation: " +
                               "#{task.package.name}/#{task.stemcell.name}")
              @ready_tasks << blocked_task
            end
          end
        end
      end
    end

    def generate_dependency_key(dependencies, packages_by_name)
      dependency_key = []
      dependencies.each do |dependency|
        package = packages_by_name[dependency]
        dependency_key << [package.name, package.version]
      end
      dependency_key.sort! { |a, b| a.first <=> b.first }
      dependency_key = Yajl::Encoder.encode(dependency_key)
      dependency_key
    end

    def generate_compile_tasks
      @compile_tasks = {}
      release_version = @deployment_plan.release.release_version

      @logger.info("Building package index for this release")
      packages = release_version.packages
      packages_by_name = {}
      packages.each { |package| packages_by_name[package.name] = package}

      @logger.info("Generating a list of compile tasks")

      @deployment_plan.jobs.each do |job|
        @logger.info("Processing job: #{job.name}")
        stemcell = job.resource_pool.stemcell.stemcell
        @logger.info("Job will be deployed on: #{job.resource_pool.stemcell.name}")
        template = job.template
        template.packages.each do |package|
          @logger.info("Processing package: #{package.name}")
          dependencies = package.dependency_set
          dependency_key = generate_dependency_key(dependencies, packages_by_name)
          compiled_package = Models::CompiledPackage[:package_id => package.id,
                                                     :stemcell_id => stemcell.id,
                                                     :dependency_key => dependency_key]
          if compiled_package
            @logger.info("Found compiled_package: #{compiled_package.id}")
          else
            @logger.info("Package \"#{package.name}\" needs to be compiled on \"#{stemcell.name}\"")
          end

          task_key = [package.name, stemcell.id]
          compile_task = @compile_tasks[task_key]
          if compile_task.nil?
            compile_task = CompileTask.new(task_key)
            compile_task.stemcell = stemcell
            @compile_tasks[compile_task.key] = compile_task
          end

          compile_task.add_job(job)
          compile_task.package = package
          compile_task.dependency_key = dependency_key
          compile_task.compiled_package = compiled_package
          compile_task.dependencies = []

          @logger.info("Processing dependencies")
          dependencies.each do |dependency|
            @logger.info("Processing dependency: #{dependency}")
            task_key = [dependency, stemcell.id]
            dependent_task = @compile_tasks[task_key]
            if dependent_task.nil?
              dependent_task = CompileTask.new(task_key)
              dependent_task.stemcell = stemcell
              @compile_tasks[dependent_task.key] = dependent_task
            end

            compile_task.dependencies << dependent_task
          end
        end
      end

      bind_dependent_tasks(packages_by_name)
    end


    def bind_dependent_tasks(packages_by_name)
      @logger.info("Filling in compile tasks for dependencies")
      @compile_tasks.each do |key, task|
        package_name, stemcell_id = key

        if task.package.nil?
          @logger.info("Filling in dependencies for package: #{package_name}")
          package               = packages_by_name[package_name]
          dependencies          = package.dependency_set
          dependency_key        = generate_dependency_key(dependencies, packages_by_name)
          compiled_package      = Models::CompiledPackage[:package_id  => package.id,
                                                          :stemcell_id => stemcell_id,
                                                          :dependency_key => dependency_key]
          task.package          = package
          task.dependency_key   = dependency_key
          task.compiled_package = compiled_package
          task.dependencies     = []

          dependencies.each { |dependency| task.dependencies << @compile_tasks[[dependency, stemcell_id]] }
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

    def configure_vm(agent, network_settings)
      task = agent.apply({
        "deployment"    => @deployment_plan.name,
        "resource_pool" => "package_compiler",
        "networks"      => network_settings
      })
      while task["state"] == "running"
        sleep(1.0)
        task = agent.get_task(task["agent_task_id"])
      end
    end

    def generate_agent_id
      UUIDTools::UUID.random_create.to_s
    end

  end

end
