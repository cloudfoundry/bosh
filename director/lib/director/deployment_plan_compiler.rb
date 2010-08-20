module Bosh::Director
  class DeploymentPlanCompiler
    include IpUtil

    def initialize(deployment_plan)
      @deployment_plan = deployment_plan
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

        if state["job"] != instance.job || state["index"] != instance.index
          raise "Instance state out of sync: #{state.pretty_inspect}"
        end
      end
    end

    def bind_existing_deployment
      vms = Models::Vm.find(:deployment_id => @deployment_plan.deployment.id)
      vms.each do |vm|
        instance = Models::Instance.find(:vm_id => vm.id).first
        agent = AgentClient.new(vm.agent_id)
        state = agent.get_state

        verify_state(instance, state, vm)

        ip_reservations = process_ip_reservations(state)

        # does the job instance exist in the new deployment?
        if instance
          if (job = @deployment_plan.job(instance.job)) && (instance_spec = job.instance(instance.index))
            instance_spec.instance = instance
            instance_spec.current_state = state

            # copy network reservations
            instance_spec.networks.each do |network_config|
              reservation = ip_reservations[network_config.name]
              network_config.use_reservation(reservation[:ip], reservation[:static?]) if reservation
            end

            # copy resource pool reservation
            instance_spec.vm = instance.vm
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
      release_version = @deployment_plan.release.release
      @deployment_plan.jobs.each do |job|
        stemcell = job.resource_pool.stemcell.stemcell
        template = Models::Template.find(:release_version_id => release_version.id, :name => job.template).first
        template.packages.each do |package|
          compiled_package = Models::CompiledPackage.find(:package_id => package.id,
                                                          :stemcell_id => stemcell.id).first
          job.add_package(package.name, package.version, compiled_package.sha1)
        end
      end
    end

    def bind_instance_vms
      @deployment_plan.jobs.each do |job|
        job.instances.each do |instance_spec|
          # create the instance model if this is a new instance
          if instance_spec.instance.nil?
            instance = Models::Instance.new
            instance.deployment = @deployment_plan.deployment
            instance.job = job.name
            instance.index = instance_spec.index
            instance.save!
            instance_spec.instance = instance
          end

          unless instance_spec.vm
            idle_vm = instance_spec.job.resource_pool.allocate_vm
            instance_spec.vm = idle_vm.vm
            instance_spec.current_state = idle_vm.current_state
          end
        end
      end
    end

  end
end