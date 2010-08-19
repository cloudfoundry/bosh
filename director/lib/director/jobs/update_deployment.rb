module Bosh::Director

  module Jobs

    class UpdateDeployment

      @queue = :normal

      def self.perform(task_id, manifest_file)
        UpdateDeployment.new(task_id, manifest_file).perform
      end

      def initialize(task_id, manifest_file)
        @task = Models::Task[task_id]
        raise TaskInvalid if @task.nil?

        @manifest_file = manifest_file
        @cloud = Bosh::Director::Config.cloud
        @vm_manager = Bosh::Director::VmManager.new
      end

      def find_or_create_deployment(name)
        deployment = Models::Deployment.find(:name => name).first
        if deployment.nil?
          deployment = Models::Deployment.new(:name => name)
          deployment.save
        end
        deployment
      end

      def process_ip_reservations(deployment_plan, state)
        ip_reservations = {}
        state["networks"].each do |name, network_config|
          network = deployment_plan.network(name)
          if network
            ip = network_config["ip"]
            reservation = network.reserve_ip(ip)
            ip_reservations[name] = {:ip => ip, :static? => reservation == :static} if reservation
          end
        end
        ip_reservations
      end

      def verify_state(instance, state, vm)
        if state["deployment"] != deployment.name
          raise "Deployment state out of sync: #{state}"
        end

        if instance
          if instance.deployment.id != vm.deployment.id
            raise "Vm/Instance models out of sync: #{state}"
          end

          if state["job"] != instance.job || state["index"] != instance.index
            raise "Instance state out of sync: #{state}"
          end
        end
      end

      def bind_existing_deployment(deployment_plan)
        vms = Models::Vm.find(:deployment_id => deployment_plan.deployment.id)
        vms.each do |vm|
          instance = Models::Instance.find(:vm_id => vm.id)
          agent = AgentClient.new(vm.agent_id)
          state = agent.get_state

          verify_state(instance, state, vm)

          ip_reservations = process_ip_reservations(deployment_plan, state)
          
          # does the job instance exist in the new deployment?
          if instance
            if (job = deployment_plan.job(instance.job)) && (instance_spec = job.instance(instance.index))
              instance_spec.instance = instance
              instance_spec.current_state = state

              # copy network reservations
              instance_spec.networks.each do |network_config|
                reservation = ip_reservations[network_config.name]
                network_config.use_reservation(reservation[:ip], reservation[:static?]) if reservation
              end

              # copy resource pool reservation
              instance_spec.vm = instance.vm
              instance_spec.resource_pool.add_allocated_vm
            else
              deployment_plan.delete_instance(instance)
            end
          else
            resource_pool = deployment_plan.resource_pool(state["resource_pool"]["name"])
            if resource_pool
              idle_vm = resource_pool.add_idle_vm
              idle_vm.vm = vm
              idle_vm.current_state = state
              network_reservation = ip_reservations[resource_pool.stemcell.network.name]
              idle_vm.ip = network_reservation[:ip] if network_reservation && !network_reservation[:static?]
            else
              deployment_plan.delete_vm(vm)
            end
          end
        end
      end

      def bind_resource_pool_networks(deployment_plan)
        deployment_plan.resource_pools.each do |resource_pool|
          network = resource_pool.stemcell.network
          resource_pool.unallocated_vms.times do
            idle_vm = resource_pool.add_idle_vm
            idle_vm.ip = network.allocate_dynamic_ip
          end
        end
      end

      def bind_instance_networks(deployment_plan)
        deployment_plan.jobs.each do |job|
          job.instances.each do |instance|
            instance.networks.each do |network_config|
              unless network_config.reserved
                network = deployment_plan.network(network_config.name)
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

      def compile_packages(deployment_plan)
        uncompiled_packages = []
        release_version = deployment_plan.release.release
        deployment_plan.jobs.each do |job|
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

        PackageCompiler.new(uncompiled_packages).compile unless uncompiled_packages.empty?
      end

      def bind_packages(deployment_plan)
        release_version = deployment_plan.release.release        
        deployment_plan.jobs.each do |job|
          stemcell = job.resource_pool.stemcell.stemcell
          template = Models::Template.find(:release_version_id => release_version.id, :name => job.template).first
          template.packages.each do |package|
            compiled_package = Models::CompiledPackage.find(:package_id => package.id,
                                                            :stemcell_id => stemcell.id).first
            job.add_package(package.name, package.version, compiled_package.sha1)
          end
        end        
      end

      def bind_instance_vms(deployment_plan)
        deployment_plan.jobs.each do |job|
          job.instances.each do |instance|
            unless instance.vm
              idle_vm = instance.job.resource_pool.allocate_vm
              instance.vm = idle_vm.vm
              instance.current_state = idle_vm.current_state
            end
          end
        end
      end

      def perform
        @task.state = :processing
        @task.timestamp = Time.now.to_i
        @task.save

        deployment_plan = DeploymentPlan.new(YAML.load_file(@manifest_file))

        begin
          deployment_lock = Lock.new("lock:deployment:#{deployment_plan.name}")
          deployment_lock.lock do
            release_lock = Lock.new("lock:release:#{deployment_plan.release.name}")
            release_lock.lock do

              deployment = find_or_create_deployment(deployment_plan.name)
              deployment_plan.deployment = deployment

              bind_existing_deployment(deployment_plan)
              bind_resource_pool_networks(deployment_plan)
              bind_instance_networks(deployment_plan)

              compile_packages(deployment_plan)
              bind_packages(deployment_plan)

              deployment_plan.resource_pools.each do |resource_pool|
                ResourcePoolUpdater.new(resource_pool).update
              end

              bind_instance_vms(deployment_plan)

              deployment_plan.jobs.each do |job|
                JobUpdater.new(job).update
              end

              @task.state = :done
              # TODO: generate result
              @task.timestamp = Time.now.to_i
              @task.save
            end
          end
        rescue => e
          @task.state = :error
          @task.result = e.to_s
          @task.timestamp = Time.now.to_i
          @task.save

          raise e
        ensure
          # TODO: cleanup?
        end
      end

    end
  end
end
