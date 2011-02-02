module Bosh::Director
  class DeploymentPlanCompiler
    include IpUtil

    def initialize(deployment_plan)
      @deployment_plan = deployment_plan
      @cloud = Config.cloud
      @logger = Config.logger
    end

    def process_ip_reservations(state)
      ip_reservations = {}
      state["networks"].each do |name, network_config|
        network = @deployment_plan.network(name)
        if network
          ip = ip_to_i(network_config["ip"])
          reservation = network.reserve_ip(ip)
          ip_reservations[name] = {:ip => ip, :static? => reservation == :static} if reservation
        end
      end
      ip_reservations
    end

    def verify_state(instance, state, vm)
      if state["deployment"] != @deployment_plan.deployment.name
        raise "Deployment state out of sync: #{state.pretty_inspect}"
      end

      if instance
        if instance.deployment.id != vm.deployment.id
          raise "Vm/Instance models out of sync: #{state.pretty_inspect}"
        end

        if state["job"]["name"] != instance.job || state["index"] != instance.index.to_i
          raise "Instance state out of sync: #{state.pretty_inspect}"
        end
      end
    end

    def bind_release
      release_spec = @deployment_plan.release
      release = Models::Release.find(:name => release_spec.name).first
      raise "Can't find release" if release.nil?
      @logger.debug("Found release: #{release.pretty_inspect}")
      release_spec.release = release
      release_version = Models::ReleaseVersion.find(:release_id => release_spec.release.id,
                                                    :version    => release_spec.version).first
      raise "Can't find release version" if release_version.nil?
      @logger.debug("Found release version: #{release_version.pretty_inspect}")
      release_spec.release_version = release_version

      @logger.debug("Locking the release from deletion")
      deployment = @deployment_plan.deployment
      deployment.release = release
      deployment.save!
    end

    def bind_existing_deployment
      lock = Mutex.new
      pool = ThreadPool.new(:min_threads => 1, :max_threads => 32)
      begin
        vms = Models::Vm.find(:deployment_id => @deployment_plan.deployment.id)
        vms.each do |vm|
          pool.process do
            @logger.debug("Requesting current VM state for: #{vm.agent_id}")
            instance = Models::Instance.find(:vm_id => vm.id).first
            agent = AgentClient.new(vm.agent_id)
            state = agent.get_state
            @logger.debug("Received VM state: #{state.pretty_inspect}")

            verify_state(instance, state, vm)

            lock.synchronize do
              ip_reservations = process_ip_reservations(state)

              # does the job instance exist in the new deployment?
              if instance
                if (job = @deployment_plan.job(instance.job)) && (instance_spec = job.instance(instance.index.to_i))
                  instance_spec.instance = instance
                  instance_spec.current_state = state

                  # copy network reservations
                  instance_spec.networks.each do |network_config|
                    reservation = ip_reservations[network_config.name]
                    network_config.use_reservation(reservation[:ip], reservation[:static?]) if reservation
                  end

                  # copy resource pool reservation
                  instance_spec.job.resource_pool.add_allocated_vm
                else
                  @deployment_plan.delete_instance(instance)
                end
              else
                resource_pool = @deployment_plan.resource_pool(state["resource_pool"]["name"])
                if resource_pool
                  idle_vm = resource_pool.add_idle_vm
                  idle_vm.vm = vm
                  idle_vm.current_state = state
                  network_reservation = ip_reservations[resource_pool.stemcell.network.name]
                  idle_vm.ip = network_reservation[:ip] if network_reservation && !network_reservation[:static?]
                else
                  @deployment_plan.delete_vm(vm)
                end
              end
            end
          end
        end
        pool.wait
      ensure
        pool.shutdown
      end
    end

    def bind_resource_pools
      @deployment_plan.resource_pools.each do |resource_pool|
        network = resource_pool.stemcell.network
        resource_pool.unallocated_vms.times do
          idle_vm = resource_pool.add_idle_vm
          idle_vm.ip = network.allocate_dynamic_ip
        end
      end
    end

    def bind_instance_networks
      @deployment_plan.jobs.each do |job|
        job.instances.each do |instance|
          instance.networks.each do |network_config|
            unless network_config.reserved
              network = @deployment_plan.network(network_config.name)
              # static ip that wasn't reserved
              if network_config.ip
                reservation = network.reserve_ip(network_config.ip)
                raise "bad static IP reservation" unless reservation == :static
                network_config.use_reservation(network_config.ip, true)
              else
                ip = network.allocate_dynamic_ip
                network_config.use_reservation(ip, false)
              end
            end
          end
        end
      end
    end

    def bind_packages
      @deployment_plan.jobs.each do |job|
        @logger.info("Binding packages for: #{job.name}")
        stemcell = job.resource_pool.stemcell.stemcell
        template = job.template
        template.packages.each do |package|
          compiled_package = Models::CompiledPackage.find(:package_id => package.id,
                                                          :stemcell_id => stemcell.id).first
          @logger.debug("Adding package: #{package.pretty_inspect}/#{compiled_package.pretty_inspect}")
          job.add_package(package, compiled_package)
        end
      end
    end

    def bind_templates
      release_version = @deployment_plan.release.release_version

      template_name_index = {}
      release_version.templates.each do |template|
        template_name_index[template.name] = template
      end

      package_name_index = {}
      release_version.packages.each do |package|
        package_name_index[package.name] = package
      end

      @deployment_plan.templates.each do |template_spec|
        @logger.info("Binding template: #{template_spec.name}")
        template = template_name_index[template_spec.name]
        raise "Can't find template: #{template_spec.name}" if template.nil?
        template_spec.version = template.version
        template_spec.sha1 = template.sha1
        template_spec.blobstore_id = template.blobstore_id

        packages = []
        template.packages.each { |package_name| packages << package_name_index[package_name] }
        template_spec.packages = packages

        @logger.debug("Bound template: #{template_spec.pretty_inspect}")
      end
    end

    def bind_stemcells
      deployment = @deployment_plan.deployment
      @deployment_plan.resource_pools.each do |resource_pool|
        stemcell_spec = resource_pool.stemcell
        lock = Lock.new("lock:stemcells:#{stemcell_spec.name}:#{stemcell_spec.version}", :timeout => 10)
        lock.lock do
          stemcell = Models::Stemcell.find(:name => stemcell_spec.name,
                                           :version => stemcell_spec.version).first
          stemcell.deployments << @deployment_plan.deployment
          deployment.stemcells << stemcell
          stemcell_spec.stemcell = stemcell
        end
      end
    end

    def bind_configuration
      @deployment_plan.jobs.each { |job| ConfigurationHasher.new(job).hash }
    end

    def bind_instance_vms
      pool = ThreadPool.new(:min_threads => 1, :max_threads => 32)
      begin
        @deployment_plan.jobs.each do |job|
          job.instances.each do |instance_spec|
            # create the instance model if this is a new instance
            instance = instance_spec.instance

            if instance.nil?
              # look up the instance again, in case it wasn't associated with a VM
              instance = Models::Instance.find(:deployment_id => @deployment_plan.deployment.id, :job => job.name,
                                               :index => instance_spec.index).first
              if instance.nil?
                instance = Models::Instance.new
                instance.deployment = @deployment_plan.deployment
                instance.job = job.name
                instance.index = instance_spec.index
              end
              instance_spec.instance = instance
            end

            unless instance.vm
              idle_vm = instance_spec.job.resource_pool.allocate_vm
              instance.vm = idle_vm.vm
              instance.save!

              pool.process do
                # Apply the assignment to the VM
                state = idle_vm.current_state
                state["job"] = job.spec
                state["index"] = instance.index.to_i
                state["release"] = @deployment_plan.release.spec
                agent = AgentClient.new(idle_vm.vm.agent_id)
                task = agent.apply(state)
                while task["state"] == "running"
                  sleep(1.0)
                  task = agent.get_task(task["agent_task_id"])
                end

                instance_spec.current_state = state
              end
            end
          end
        end
        pool.wait
      ensure
        pool.shutdown
      end
    end

    def delete_unneeded_vms
      unless @deployment_plan.unneeded_vms.empty?
        # TODO: make pool size configurable?
        pool = ThreadPool.new(:min_threads => 1, :max_threads => 10)
        begin
          @deployment_plan.unneeded_vms.each do |vm|
            vm_cid = vm.cid
            pool.process do
              @cloud.delete_vm(vm_cid)
              vm.delete
            end
          end
          pool.wait
        ensure
          pool.shutdown
        end
      end
    end

    def delete_unneeded_instances
      unless @deployment_plan.unneeded_instances.empty?
        # TODO: make pool size configurable?
        pool = ThreadPool.new(:min_threads => 1, :max_threads => 10)
        begin
          @deployment_plan.unneeded_instances.each do |instance|
            vm = instance.vm
            disk_cid = instance.disk_cid
            vm_cid = vm.cid
            agent_id = vm.agent_id

            pool.process do
              agent = AgentClient.new(agent_id)
              drain_time = agent.drain
              sleep(drain_time)
              agent.stop

              @cloud.delete_vm(vm_cid)
              @cloud.delete_disk(disk_cid) if disk_cid
              vm.delete
              instance.delete
            end
          end
          pool.wait
        ensure
          pool.shutdown
        end
      end
    end

  end
end
