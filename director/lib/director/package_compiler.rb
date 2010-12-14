module Bosh::Director

  class PackageCompiler

    def initialize(deployment_plan)
      @deployment_plan = deployment_plan
      @cloud = Config.cloud
      @logger = Config.logger
    end

    def find_uncompiled_packages
      uncompiled_packages = []
      release_version = @deployment_plan.release.release_version
      @deployment_plan.jobs.each do |job|
        stemcell = job.resource_pool.stemcell.stemcell
        template = Models::Template.find(:release_version_id => release_version.id, :name => job.template).first
        template.packages.each do |package|
          job.packages[package.name] = package.version
          compiled_package = Models::CompiledPackage.find(:package_id => package.id,
                                                          :stemcell_id => stemcell.id).first
          unless compiled_package
            uncompiled_packages << {
              :package => package,
              :stemcell => stemcell
            }
          end
        end
      end
      uncompiled_packages
    end

    def compile
      @logger.info("Looking for packages that need to be compiled")
      uncompiled_packages = find_uncompiled_packages
      @logger.info("Found: #{uncompiled_packages.join(",")}")
      return if uncompiled_packages.empty?

      network = @deployment_plan.compilation.network

      networks = []
      networks_mutex = Mutex.new
      @deployment_plan.compilation.workers.times do
        networks << {network.name => network.network_settings(network.allocate_dynamic_ip)}
      end

      pool = ThreadPool.new(:min_threads => 1, :max_threads => @deployment_plan.compilation.workers)
      uncompiled_packages.each do |uncompiled_package|

        package = uncompiled_package[:package]
        package_sha1 = package.sha1
        package_blobstore_id = package.blobstore_id
        package_name = package.name
        package_version = package.version

        stemcell = uncompiled_package[:stemcell]
        stemcell_cid = stemcell.cid
        stemcell_name = stemcell.name
        stemcell_version = stemcell.version
        compilation_resources = stemcell.compilation_resources

        pool.process do
          @logger.info("Compiling package: #{package_name}/#{package_version} on " +
                           "stemcell: #{stemcell_name}/#{stemcell_version}")
          network_settings = nil
          networks_mutex.synchronize do
            network_settings = networks.shift
          end

          agent_id = generate_agent_id
          vm_cid = @cloud.create_vm(agent_id, stemcell_cid, compilation_resources, network_settings)
          agent = AgentClient.new(agent_id)
          agent.wait_until_ready
          task = agent.compile_package(package_blobstore_id, package_sha1, package_name, package_version)
          while task["state"] == "running"
            task = agent.get_task(task["id"])
          end

          @cloud.delete_vm(vm_cid)
          networks_mutex.synchronize do
            networks << network_settings
          end

          compiled_package = Models::CompiledPackage.new
          compiled_package.package = package
          compiled_package.stemcell = stemcell
          compiled_package.sha1 = task["result"]["sha1"]
          compiled_package.blobstore_id = task["result"]["blobstore_id"]
          compiled_package.save!
          @logger.info("Compiled package #{package_name}/#{package_version} on " +
                           "stemcell: #{stemcell_name}/#{stemcell_version}, saved in #{compiled_package.blobstore_id}")
        end
      end

      pool.wait

      networks.each do |network_settings|
        ip = network_settings[network.name]["ip"]
        network.release_dynamic_ip(ip)
      end
    end

    def generate_agent_id
      UUIDTools::UUID.random_create.to_s
    end

  end

end
