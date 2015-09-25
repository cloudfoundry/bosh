module Bosh::Director
  module DeploymentPlan
    class CompilationInstancePool
      def initialize(instance_reuser, vm_creator, deployment_plan, logger, instance_deleter)
        @instance_reuser = instance_reuser
        @vm_creator = vm_creator
        @deployment_plan =  deployment_plan
        @logger = logger
        @instance_deleter = instance_deleter
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
            delete_instance(instance)
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
          delete_instance(instance) unless instance.nil?
        end
      end

      def delete_instances(number_of_workers)
        ThreadPool.new(:max_threads => number_of_workers).wrap do |pool|
           @instance_reuser.each do |instance|
            pool.process do
              @instance_reuser.remove_instance(instance)
              delete_instance(instance)
            end
          end
        end
      end

      private

      def delete_instance(instance)
        @instance_deleter.delete_instance(instance, EventLog::NullStage.new)
      end

      def create_instance(stemcell)
        resource_pool = CompilationResourcePool.new(
          stemcell,
          @deployment_plan.compilation.cloud_properties,
          @deployment_plan.compilation.env
        )
        compile_job = CompilationJob.new(resource_pool, @deployment_plan)
        availability_zone = @deployment_plan.compilation.availability_zone
        Instance.new(compile_job, 0, 'started', @deployment_plan, {}, availability_zone, false, @logger)
      end

      def configure_instance(instance)
        instance.bind_unallocated_vm

        compilation_network = @deployment_plan.network(@deployment_plan.compilation.network_name)
        reservation = DesiredNetworkReservation.new_dynamic(instance, compilation_network)
        instance.add_network_reservation(reservation)
        @deployment_plan.ip_provider.reserve(reservation)

        instance_plan = DeploymentPlan::InstancePlan.create_from_deployment_plan_instance(instance, @logger)
        @vm_creator.create_for_instance_plan(instance_plan, [])
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
      attr_reader :resource_pool, :name, :deployment

      def initialize(resource_pool,deployment)
        @resource_pool = resource_pool
        @network = deployment.compilation.network_name
        @name = "compilation-#{SecureRandom.uuid}"
        @deployment = deployment
      end

      def default_network
        {
          'dns' => @network,
          'gateway' => @network
        }
      end

      def availability_zones
        nil
      end

      def spec
        {
          'name' => @name
        }
      end

      def package_spec
        {}
      end

      def properties
        {}
      end

      def link_spec
        {}
      end

      def persistent_disk_pool
        nil
      end

      def compilation?
        true
      end

      def can_run_as_errand?
        true
      end
    end
  end
end
