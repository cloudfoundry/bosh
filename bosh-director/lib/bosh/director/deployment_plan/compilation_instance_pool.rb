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
            instance_plan, instance = create_instance_plan(stemcell)
            configure_instance_plan(instance_plan)
            @instance_reuser.add_in_use_instance(instance_plan.instance, stemcell)
          else
            @logger.info("Reusing compilation VM `#{instance.vm.model.cid}' for stemcell `#{stemcell.model.desc}'")
          end

          yield instance

          @instance_reuser.release_instance(instance)
        rescue => e
          unless instance.nil? || instance_plan.nil?
            @instance_reuser.remove_instance(instance)
            delete_instance(instance_plan)
          end
          raise e
        end
      end

      def with_single_use_vm(stemcell)
        begin
          instance_plan, instance = create_instance_plan(stemcell)
          configure_instance_plan(instance_plan)
          yield instance
        ensure
          delete_instance(instance_plan) unless instance.nil?
        end
      end

      def delete_instances(number_of_workers)
        ThreadPool.new(:max_threads => number_of_workers).wrap do |pool|
           @instance_reuser.each do |instance|
            pool.process do
              @instance_reuser.remove_instance(instance)
              instance_plan = DeploymentPlan::InstancePlan.new(
                existing_instance: instance.model,
                instance: instance,
                desired_instance: DeploymentPlan::DesiredInstance.new,
                network_plans: []
              )
              delete_instance(instance_plan)
            end
          end
        end
      end

      private

      def delete_instance(instance_plan)
        @instance_deleter.delete_instance_plan(instance_plan, EventLog::NullStage.new)
      end

      def create_instance_plan(stemcell)
        vm_type = CompilationVmType.new(@deployment_plan.compilation.cloud_properties)
        env = Env.new(@deployment_plan.compilation.env)

        @compile_job = CompilationJob.new(vm_type, stemcell, env, @deployment_plan.compilation.network_name)
        availability_zone = @deployment_plan.compilation.availability_zone
        instance = Instance.create_from_job(@compile_job, 0, 'started', @deployment_plan.model, {}, availability_zone, @logger)
        instance.bind_new_instance_model

        compilation_network = @deployment_plan.network(@deployment_plan.compilation.network_name)
        reservation = DesiredNetworkReservation.new_dynamic(instance, compilation_network)
        desired_instance = DeploymentPlan::DesiredInstance.new(@compile_job, nil)
        instance_plan = DeploymentPlan::InstancePlan.new(
          existing_instance: instance.model,
          instance: instance,
          desired_instance: desired_instance,
          network_plans: [DeploymentPlan::NetworkPlanner::Plan.new(reservation: reservation)]
        )

        @compile_job.add_instance_plans([instance_plan])

        return instance_plan, instance
      end

      def configure_instance_plan(instance_plan)
        instance_plan.instance.bind_unallocated_vm

        @deployment_plan.ip_provider.reserve(instance_plan.network_plans.first.reservation)
        @vm_creator.create_for_instance_plan(instance_plan, [])
      end
    end

    private

    class CompilationVmType
      attr_reader :cloud_properties

      def initialize(cloud_properties)
        @cloud_properties = cloud_properties
      end

      def spec
        {}
      end
    end

    class CompilationJob
      attr_reader :vm_type, :stemcell, :env, :name
      attr_reader :instance_plans

      def initialize(vm_type, stemcell, env, compilation_network_name)
        @vm_type = vm_type
        @stemcell = stemcell
        @env = env
        @network = compilation_network_name
        @name = "compilation-#{SecureRandom.uuid}"
        @instance_plans = []
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

      def add_instance_plans(instance_plans)
        @instance_plans = instance_plans
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

      def persistent_disk_type
        nil
      end

      def compilation?
        true
      end
    end
  end
end
