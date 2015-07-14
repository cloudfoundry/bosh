module Bosh::Director
  module DeploymentPlan
    class CompilationInstancePool
      def initialize(instance_reuser, vm_creator, vm_deleter, deployment_plan, logger)
        @instance_reuser = instance_reuser
        @vm_creator = vm_creator
        @vm_deleter = vm_deleter
        @deployment_plan =  deployment_plan
        @logger = logger
      end

      def with_reused_vm(stemcell)
        begin
          instance = @instance_reuser.get_instance(stemcell)
          if instance.nil?
            instance = create_instance(stemcell)
            configure_instance(instance)
            @instance_reuser.add_in_use_instance(instance, stemcell)
          else
            @logger.info("Reusing compilation VM `#{instance.vm.model.cid}' for stemcell `#{stemcell.model.desc}'")
          end

          yield instance

          @instance_reuser.release_instance(instance)
        rescue => e
          unless instance.nil?
            @instance_reuser.remove_instance(instance)
            tear_down_vm(instance)
          end
          raise e
        end
      end

      def with_single_use_vm(stemcell)
        begin
          instance = create_instance(stemcell)
          configure_instance(instance)
          yield instance
        ensure
          tear_down_vm(instance) unless instance.nil?
        end
      end

      def tear_down_vms(number_of_workers)
        ThreadPool.new(:max_threads => number_of_workers).wrap do |pool|
           @instance_reuser.each do |instance|
            pool.process do
              @instance_reuser.remove_instance(instance)
              tear_down_vm(instance)
            end
          end
        end
      end

      private

      def tear_down_vm(instance)
        @vm_deleter.delete_for_instance(instance)
        instance.delete
      end

      def create_instance(stemcell)
        resource_pool = CompilationResourcePool.new(
          stemcell,
          @deployment_plan.compilation.cloud_properties,
          @deployment_plan.compilation.env
        )
        compile_job = CompilationJob.new(resource_pool, @deployment_plan.compilation.network.name)
        Instance.new(compile_job, 0, 'started', @deployment_plan, @logger)
      end

      def configure_instance(instance)
        instance.bind_unallocated_vm

        reservation = NetworkReservation.new_dynamic
        instance.add_network_reservation(@deployment_plan.compilation.network.name, reservation)
        instance.reserve_networks

        @vm_creator.create_for_instance(instance, nil)
      end
    end

    private

    class CompilationResourcePool
      attr_reader :stemcell, :cloud_properties, :env

      def initialize(stemcell, cloud_properties, env)
        @stemcell = stemcell
        @cloud_properties = cloud_properties
        @env = env
      end

      def spec
        {}
      end
    end

    class CompilationJob
      attr_reader :resource_pool, :name

      def initialize(resource_pool, network)
        @resource_pool = resource_pool
        @network = network
        @name = "compilation-#{SecureRandom.uuid}"
      end

      def default_network
        {
          'dns' => @network,
          'gateway' => @network
        }
      end

      def spec
        {}
      end

      def starts_on_deploy?
        false
      end
    end
  end
end
