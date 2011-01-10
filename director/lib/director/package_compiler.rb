module Bosh::Director

  class PackageCompiler

    class CompileTask
      attr_accessor :key
      attr_accessor :package
      attr_accessor :stemcell
      attr_accessor :compiled_package
      attr_accessor :dependencies

      def dependencies_satisfied?
        @dependencies.find { |dependent_task| dependent_task.compiled_package.nil? }.nil?
      end

      def ready_to_compile?
        @compiled_package.nil? && dependencies_satisfied?
      end
    end

    def initialize(deployment_plan)
      @deployment_plan = deployment_plan
      @cloud = Config.cloud
      @logger = Config.logger
    end

    def compile
      compile_tasks = get_compile_tasks
      reverse_dependencies = generate_reverse_dependencies(compile_tasks)

      ready_tasks = []
      tasks_mutex = Mutex.new

      compile_tasks.each_value do |task|
        if task.ready_to_compile?
          @logger.info("Marking package ready for compilation: #{task.package.name}/#{task.stemcell.name}")
          ready_tasks << task
        end
      end

      if ready_tasks.empty?
        @logger.info("All packages are already compiled")
        return
      end

      network = @deployment_plan.compilation.network
      networks = []
      networks_mutex = Mutex.new
      @deployment_plan.compilation.workers.times do
        networks << {network.name => network.network_settings(network.allocate_dynamic_ip)}
      end

      pool = ThreadPool.new(:min_threads => 1, :max_threads => @deployment_plan.compilation.workers)
      loop do
        loop do
          task = ready_tasks.pop
          break if task.nil?

          package = task.package
          package_sha1 = package.sha1
          package_blobstore_id = package.blobstore_id
          package_name = package.name
          package_version = package.version

          stemcell = task.stemcell
          stemcell_cid = stemcell.cid
          stemcell_name = stemcell.name
          stemcell_version = stemcell.version
          compilation_resources = @deployment_plan.compilation.cloud_properties

          dependencies = {}
          task.dependencies.each do |dependency|
            dependencies[dependency.package.name] = {
              "name" => dependency.package.name,
              "version" => dependency.package.version,
              "sha1" => dependency.compiled_package.sha1,
              "blobstore_id" => dependency.compiled_package.blobstore_id
            }
          end

          @logger.info("Enqueuing package ready for compilation: #{package_name}/#{stemcell_name}")

          pool.process do
            with_thread_name("compile_package(#{package_name}/#{package_version}, " +
                                 "#{stemcell_name}/#{stemcell_version})") do

              @logger.info("Compiling package: #{package_name}/#{package_version} on " +
                               "stemcell: #{stemcell_name}/#{stemcell_version}")
              network_settings = nil
              networks_mutex.synchronize do
                network_settings = networks.shift
              end

              agent_id = generate_agent_id
              @logger.info("Creating compilation VM with agent id: #{agent_id}")
              vm_cid = @cloud.create_vm(agent_id, stemcell_cid, compilation_resources, network_settings)
              @logger.info("Configuring compilation VM: #{vm_cid}")
              begin
                agent = AgentClient.new(agent_id)
                agent.wait_until_ready

                configure_vm(agent, network_settings)

                @logger.info("Compiling package on compilation VM")
                agent_task = agent.compile_package(package_blobstore_id, package_sha1, package_name, package_version,
                                                   dependencies)
                while agent_task["state"] == "running"
                  sleep(1.0)
                  agent_task = agent.get_task(agent_task["agent_task_id"])
                end
              ensure
                @logger.info("Deleting compilation VM: #{vm_cid}")
                @cloud.delete_vm(vm_cid)
              end

              networks_mutex.synchronize do
                networks << network_settings
              end

              task_result = agent_task["result"]
              task.compiled_package = create_compiled_package(package, stemcell,
                                                              task_result["blobstore_id"], task_result["sha1"])

              @logger.info("Looking for packages waiting for this compilation")
              tasks_mutex.synchronize do
                dependencies = reverse_dependencies[task.key]
                if dependencies
                  dependencies.each do |blocked_task|
                    if blocked_task.ready_to_compile?
                      @logger.info("Marking unblocked package for compilation: " +
                                       "#{task.package.name}/#{task.stemcell.name}")
                      ready_tasks << blocked_task
                    end
                  end
                end
              end
              @logger.info("Finished compiling package: #{package_name}/#{package_version} on " +
                               "stemcell: #{stemcell_name}/#{stemcell_version}")
            end
          end
        end

        break if !pool.working? && ready_tasks.empty?
        sleep(0.1)
      end

      networks.each do |network_settings|
        ip = network_settings[network.name]["ip"]
        network.release_dynamic_ip(ip)
      end
    end

    def get_compile_tasks
      compile_tasks = {}
      release_version = @deployment_plan.release.release_version

      @logger.info("Generating a list of compile tasks")

      @deployment_plan.jobs.each do |job|
        @logger.info("Processing job: #{job.name}")
        stemcell = job.resource_pool.stemcell.stemcell
        @logger.info("Job will be deployed on: #{job.resource_pool.stemcell.name}")
        template = job.template
        template.packages.each do |package|
          @logger.info("Processing package: #{package.name}")
          compiled_package = Models::CompiledPackage.find(:package_id => package.id,
                                                          :stemcell_id => stemcell.id).first
          if compiled_package
            @logger.info("Found compiled_package: #{compiled_package.id}")
          else
            @logger.info("Package \"#{package.name}\" needs to be compiled on \"#{stemcell.name}\"")
          end

          compile_task = compile_tasks[[package.name, stemcell.id]]
          if compile_task.nil?
            compile_task = CompileTask.new
            compile_task.key = [package.name, stemcell.id]
            compile_task.stemcell = stemcell
            compile_tasks[compile_task.key] = compile_task
          end

          compile_task.package = package
          compile_task.compiled_package = compiled_package
          compile_task.dependencies = []

          @logger.info("Processing dependencies")
          package.dependency_set.each do |dependency|
            @logger.info("Processing dependency: #{dependency}")
            dependent_task = compile_tasks[[dependency, stemcell.id]]
            if dependent_task.nil?
              dependent_task = CompileTask.new
              dependent_task.key = [dependency, stemcell.id]
              dependent_task.stemcell = stemcell
              compile_tasks[dependent_task.key] = dependent_task
            end

            compile_task.dependencies << dependent_task
          end
        end
      end

      @logger.info("Filling in compile tasks for dependencies")
      compile_tasks.each do |key, task|
        package_name, stemcell_id = key
        if task.package.nil?
          @logger.info("Filling in dependencies for package: #{package_name}")
          package = release_version.packages.find(:name => package_name).first
          compiled_package = Models::CompiledPackage.find(:package_id => package.id,
                                                          :stemcell_id => stemcell_id).first
          task.package = package
          task.compiled_package = compiled_package
          task.dependencies = []

          package.dependency_set.each { |dependency| task.dependencies << compile_tasks[[dependency, stemcell_id]] }
        end
      end

      compile_tasks
    end

    def generate_reverse_dependencies(compile_tasks)
      reverse_dependencies = {}
      compile_tasks.each_value do |task|
        task.dependencies.each do |dependent_task|
          (reverse_dependencies[dependent_task.key] ||= []) << task
        end
      end
      reverse_dependencies
    end

    def create_compiled_package(package, stemcell, blobstore_id, sha1)
      compiled_package              = Models::CompiledPackage.new
      compiled_package.package      = package
      compiled_package.stemcell     = stemcell
      compiled_package.sha1         = sha1
      compiled_package.blobstore_id = blobstore_id
      compiled_package.save!
      compiled_package
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
