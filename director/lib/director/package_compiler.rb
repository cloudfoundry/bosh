module Bosh::Director

  class PackageCompiler

    def initialize(deployment_plan)
      @deployment_plan = deployment_plan
      @cloud = Config.cloud
    end

    def find_uncompiled_packages
      uncompiled_packages = []
      release_version = @deployment_plan.release.release
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
      uncompiled_packages = find_uncompiled_packages
      return if uncompiled_packages.empty?

      network = @deployment_plan.compilation.network

      networks = []
      networks_mutex = Mutex.new
      @deployment_plan.compilation.workers.times do
        networks << network.network_settings(network.allocate_dynamic_ip)
      end

      pool = ActionPool::Pool.new(:min_threads => 1, :max_threads => @deployment_plan.compilation.workers)
      uncompiled_packages.each do |uncompiled_package|

        package = uncompiled_package[:package]
        package_name = package.name
        package_version = package.version
        package_sha1 = package.sha1
        release_name = package.release.name

        stemcell = uncompiled_package[:stemcell]
        stemcell_cid = stemcell.cid
        compilation_resources = stemcell.compilation_resources

        pool.process do
          network_settings = nil
          networks_mutex.synchronize do
            network_settings = networks.shift
          end

          agent_id = generate_agent_id
          vm_cid = @cloud.create_vm(agent_id, stemcell_cid, compilation_resources, network_settings)
          agent = AgentClient.new(agent_id)
          task = agent.compile_package(release_name, package_name, package_version, package_sha1)
          while task["state"] == "running"
            task = agent.get_task(task["id"])
          end

          # TODO: fetch the compiled packages

          @cloud.delete_vm(vm_cid)
          networks_mutex.synchronize do
            networks << network_settings
          end
        end
      end

      sleep(0.1) while pool.working + pool.action_size > 0

      networks.each do |network_settings|
        network.release_dynamic_ip(network_settings["ip"])
      end
    end

    def generate_agent_id
      UUIDTools::UUID.random_create.to_s
    end

  end

end