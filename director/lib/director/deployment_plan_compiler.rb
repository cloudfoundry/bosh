module Bosh::Director
  class DeploymentPlanCompiler
    include IpUtil

    def initialize(deployment_plan)
      @deployment_plan = deployment_plan
      @cloud = Config.cloud
      @logger = Config.logger
      @event_logger = Config.event_logger
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

        if state["job"]["name"] != instance.job || state["index"] != instance.index
          raise "Instance state out of sync: #{state.pretty_inspect}"
        end
      end
    end

    def bind_release
      release_spec = @deployment_plan.release
      release = Models::Release[:name => release_spec.name]
      raise "Can't find release" if release.nil?
      @logger.debug("Found release: #{release.pretty_inspect}")
      release_spec.release = release
      release_version = Models::ReleaseVersion[:release_id => release.id,
                                               :version    => release_spec.version]
      raise "Can't find release version" if release_version.nil?
      @logger.debug("Found release version: #{release_version.pretty_inspect}")
      release_spec.release_version = release_version

      @logger.debug("Locking the release from deletion")
      deployment = @deployment_plan.deployment
      deployment.release = release
      deployment.save

      unless deployment.release_versions.include?(release_version)
        @logger.debug("Binding release version to deployment")
        deployment.add_release_version(release_version)
      end
    end

    def bind_existing_deployment
      lock = Mutex.new
      ThreadPool.new(:max_threads => 32).wrap do |pool|
        vms = Models::Vm.filter(:deployment_id => @deployment_plan.deployment.id)
        vms.each do |vm|
          pool.process do
            with_thread_name("bind_existing_deployment(#{vm.agent_id})") do
              @logger.debug("Requesting current VM state for: #{vm.agent_id}")
              instance = vm.instance
              agent = AgentClient.new(vm.agent_id)
              state = agent.get_state
              @logger.debug("Received VM state: #{state.pretty_inspect}")

              verify_state(instance, state, vm)
              @logger.debug("Verified VM state")

              lock.synchronize do
                @logger.debug("Processing IP reservations")
                ip_reservations = process_ip_reservations(state)
                @logger.debug("Processed IP reservations")

                # does the job instance exist in the new deployment?
                if instance
                  @logger.debug("Binding instance VM")
                  if (job = @deployment_plan.job(instance.job)) && (instance_spec = job.instance(instance.index))
                    @logger.debug("Found job and instance spec")
                    instance_spec.instance = instance
                    instance_spec.current_state = state

                    @logger.debug("Copying network reservations")
                    # copy network reservations
                    instance_spec.networks.each do |network_config|
                      reservation = ip_reservations[network_config.name]
                      network_config.use_reservation(reservation[:ip], reservation[:static?]) if reservation
                    end

                    @logger.debug("Copying resource pool reservation")
                    # copy resource pool reservation
                    instance_spec.job.resource_pool.mark_active_vm
                  else
                    @logger.debug("Job/instance not found, marking for deletion")
                    @deployment_plan.delete_instance(instance)
                  end
                else
                  @logger.debug("Binding resource pool VM")
                  resource_pool = @deployment_plan.resource_pool(state["resource_pool"]["name"])
                  if resource_pool
                    @logger.debug("Adding to resource pool")
                    idle_vm = resource_pool.add_idle_vm
                    idle_vm.vm = vm
                    idle_vm.current_state = state
                    network_reservation = ip_reservations[resource_pool.network.name]
                    idle_vm.ip = network_reservation[:ip] if network_reservation && !network_reservation[:static?]
                  else
                    @logger.debug("Resource pool doesn't exist, marking for deletion")
                    @deployment_plan.delete_vm(vm)
                  end
                end
                @logger.debug("Finished binding VM")
              end
            end
          end
        end
      end
    end

    def bind_resource_pools
      @deployment_plan.resource_pools.each do |resource_pool|
        missing_vms = resource_pool.size - (resource_pool.active_vms + resource_pool.idle_vms.size)

        if missing_vms > 0
          network = resource_pool.network
          missing_vms.times do
            idle_vm = resource_pool.add_idle_vm
            idle_vm.ip = network.allocate_dynamic_ip
          end
        end
      end
    end

    def bind_unallocated_vms
      @deployment_plan.jobs.each do |job|
        job.instances.each do |instance_spec|
          # create the instance model if this is a new instance
          instance = instance_spec.instance

          if instance.nil?
            # look up the instance again, in case it wasn't associated with a VM
            instance_attrs = {
              :deployment_id => @deployment_plan.deployment.id,
              :job => job.name,
              :index => instance_spec.index
            }

            instance = Models::Instance[instance_attrs] || Models::Instance.new(instance_attrs)
            instance_spec.instance = instance
          end

          if instance_spec.state
            # Deployment plan already has state for this instance
            instance.update(:state => instance_spec.state)
          elsif instance.state
            # Instance has its state persisted from the previous deployment
            instance_spec.state = instance.state
          else
            # Target instance state is unknown, assume started
            # This should not normally be triggered because state has a 'not null' constraint.
            instance_spec.state = "started"
            instance.update(:state => "started")
          end

          unless instance.vm
            idle_vm = instance_spec.job.resource_pool.allocate_vm
            instance_spec.idle_vm = idle_vm

            if idle_vm.vm
              # try to reuse the existing reservation if possible
              instance_network = instance_spec.network(idle_vm.resource_pool.network.name)
              if instance_network && idle_vm.ip
                instance_network.use_reservation(idle_vm.ip, false)
              end
            else
              # if the VM is about to be created, then use this instance's networking configuration
              idle_vm.bound_instance = instance_spec

              # this also means we no longer need the reserved IP for this VM
              idle_vm.resource_pool.network.release_dynamic_ip(idle_vm.ip)
              idle_vm.ip = nil
            end
          end
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
                if reservation == :static
                  network_config.use_reservation(network_config.ip, true)
                elsif reservation == :dynamic
                  raise "Job: '#{job.name}'/'#{instance.index}' asked for a static IP: " +
                            "#{ip_to_netaddr(network_config.ip).ip} but it's in the dynamic pool"
                else
                  raise "Job: '#{job.name}'/'#{instance.index}' asked for a static IP: " +
                            "#{ip_to_netaddr(network_config.ip).ip} but it's already reserved/in use"
                end
              else
                ip = network.allocate_dynamic_ip
                network_config.use_reservation(ip, false)
              end
            end
          end
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
        template_spec.template = template

        packages = []
        template.package_names.each { |package_name| packages << package_name_index[package_name] }
        template_spec.packages = packages

        @logger.debug("Bound template: #{template_spec.pretty_inspect}")
      end
    end

    def bind_stemcells
      @deployment_plan.resource_pools.each do |resource_pool|
        stemcell_spec = resource_pool.stemcell
        lock = Lock.new("lock:stemcells:#{stemcell_spec.name}:#{stemcell_spec.version}", :timeout => 10)
        lock.lock do
          stemcell = Models::Stemcell[:name => stemcell_spec.name, :version => stemcell_spec.version]
          raise "Can't find stemcell: #{stemcell_spec.name}/#{stemcell_spec.version}" unless stemcell
          if stemcell.deployments_dataset.filter(:deployment_id => @deployment_plan.deployment.id).empty?
            stemcell.add_deployment(@deployment_plan.deployment)
          end
          stemcell_spec.stemcell = stemcell
        end
      end
    end

    def bind_configuration
      @deployment_plan.jobs.each { |job| ConfigurationHasher.new(job).hash }
    end

    def bind_instance_vms
      ThreadPool.new(:max_threads => 32).wrap do |pool|
        @deployment_plan.jobs.each do |job|
          job.instances.each do |instance_spec|
            # Don't allocate resource pool VMs to instances in detached state
            next if instance_spec.state == "detached"

            instance = instance_spec.instance
            next if instance.vm

            idle_vm = instance_spec.idle_vm
            instance.update(:vm => idle_vm.vm)

            pool.process do
              # Apply the assignment to the VM
              state = idle_vm.current_state
              state["job"] = job.spec
              state["index"] = instance.index
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
    end

    def delete_unneeded_vms
      unless @deployment_plan.unneeded_vms.empty?
        total = @deployment_plan.unneeded_vms.size
        # TODO: make pool size configurable?
        ThreadPool.new(:max_threads => 10).wrap do |pool|
          @deployment_plan.unneeded_vms.each_with_index do |vm, index|
            vm_cid = vm.cid
            @event_logger.progress_log("Delete unneeded VMs", "vm #{vm_cid}", index, total)
            pool.process do
              @cloud.delete_vm(vm_cid)
              vm.destroy
            end
          end
        end
      end
    end

    def delete_unneeded_instances
      unless @deployment_plan.unneeded_instances.empty?
        total = @deployment_plan.unneeded_instances.size
        # TODO: make pool size configurable?
        ThreadPool.new(:max_threads => 10).wrap do |pool|
          @deployment_plan.unneeded_instances.each_with_index do |instance, index|
            vm = instance.vm
            disk_cid = instance.disk_cid
            vm_cid = vm.cid
            agent_id = vm.agent_id
            @event_logger.progress_log("Delete unneeded instances", "#{vm_cid} - #{agent_id}",
                                       index, total)
            pool.process do
              agent = AgentClient.new(agent_id)
              drain_time = agent.drain("shutdown")
              sleep(drain_time)
              agent.stop

              @cloud.delete_vm(vm_cid)
              @cloud.delete_disk(disk_cid) if disk_cid
              instance.destroy
              vm.destroy
            end
          end
        end
      end
    end
  end
end
