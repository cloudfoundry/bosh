
module Bosh::Director
  module DeploymentPlan
    class CompilationVmPool

      def initialize(vm_reuser, vm_creator, deployment_plan, cloud, logger)
        @vm_reuser = vm_reuser
        @vm_creator = vm_creator
        @deployment_plan =  deployment_plan
        @compilation_resources = deployment_plan.compilation.cloud_properties
        @network = deployment_plan.compilation.network
        @compilation_env = deployment_plan.compilation.env
        @cloud = cloud
        @logger = logger
        @network_mutex = Mutex.new
      end

      def with_reused_vm(stemcell)
        begin
          vm_data = @vm_reuser.get_vm(stemcell)
          if vm_data.nil?
            vm_data = create_vm(stemcell)
            configure_vm(vm_data)
            @vm_reuser.add_in_use_vm(vm_data)
          else
            @logger.info("Reusing compilation VM `#{vm_data.vm.cid}' for stemcell `#{stemcell.desc}'")
          end

          yield vm_data

          @vm_reuser.release_vm(vm_data)
        rescue RpcTimeout => e
          unless vm_data.nil?
            @vm_reuser.remove_vm(vm_data)
            tear_down_vm(vm_data)
          end
          raise e
        end
      end

      def with_single_use_vm(stemcell)
        begin
          vm_data = create_vm(stemcell)
          configure_vm(vm_data)
          yield vm_data
        ensure
          tear_down_vm(vm_data) unless vm_data.nil?
        end
      end

      def tear_down_vms(number_of_workers)
        ThreadPool.new(:max_threads => number_of_workers).wrap do |pool|
           @vm_reuser.each do |vm_data|
            pool.process do
              @vm_reuser.remove_vm(vm_data)
              tear_down_vm(vm_data)
            end
          end
        end
      end

      def tear_down_vm(vm_data)
        vm = vm_data.vm
        if vm.exists?
          reservation = vm_data.reservation
          @logger.info("Deleting compilation VM: #{vm.cid}")
          @cloud.delete_vm(vm.cid)
          vm.destroy
          release_network(reservation)
        end
      end

      def reserve_network
        reservation = NetworkReservation.new_dynamic

        @network_mutex.synchronize do
          @network.reserve(reservation)
        end

        unless reservation.reserved?
          raise PackageCompilationNetworkNotReserved,
            "Could not reserve network for package compilation: #{reservation.error}"
        end
        reservation
      end

      private

      def create_vm(stemcell)
        @logger.info("Creating compilation VM for stemcell `#{stemcell.desc}'")

        reservation = reserve_network

        network_settings = {
          @network.name => @network.network_settings(reservation)
        }

        vm_model = @vm_creator.create(@deployment_plan.model, stemcell,
          @compilation_resources, network_settings,
          nil, @compilation_env)
        VmData.new(reservation,vm_model,stemcell,network_settings)
      end

      def configure_vm(vm_data)
        vm_data.agent.wait_until_ready
        vm_data.agent.update_settings(Bosh::Director::Config.trusted_certs)
        state = {
          'deployment' => @deployment_plan.name,
          'resource_pool' => {},
          'networks' => vm_data.network_settings
        }
        vm_data.vm.update(:apply_spec => state, :trusted_certs_sha1 => Digest::SHA1.hexdigest(Bosh::Director::Config.trusted_certs))
        vm_data.agent.apply(state)
      end

      def release_network(reservation)
        @network_mutex.synchronize do
          @network.release(reservation)
        end
      end
    end
  end
end
