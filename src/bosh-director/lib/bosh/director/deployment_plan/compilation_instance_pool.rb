module Bosh::Director
  module DeploymentPlan
    class CompilationInstancePool

      def self.create(deployment_plan)
        logger = Config.logger
        disk_manager = DiskManager.new(logger)
        agent_broadcaster = AgentBroadcaster.new
        powerdns_manager = PowerDnsManagerProvider.create
        vm_deleter = VmDeleter.new(logger, false, Config.enable_virtual_delete_vms)
        dns_encoder = LocalDnsEncoderManager.new_encoder_with_updated_index(deployment_plan.availability_zones.map(&:name))
        vm_creator = Bosh::Director::VmCreator.new(logger, vm_deleter, disk_manager, deployment_plan.template_blob_cache, dns_encoder, agent_broadcaster)
        instance_deleter = Bosh::Director::InstanceDeleter.new(deployment_plan.ip_provider, powerdns_manager, disk_manager)
        instance_provider = InstanceProvider.new(deployment_plan, vm_creator, logger)

        new(
          InstanceReuser.new,
          instance_provider,
          logger,
          instance_deleter,
          deployment_plan.compilation.workers,
        )
      end

      def initialize(instance_reuser, instance_provider, logger, instance_deleter, max_instance_count)
        @instance_reuser = instance_reuser
        @logger = logger
        @instance_deleter = instance_deleter
        @max_instance_count = max_instance_count
        @instance_provider = instance_provider
        @mutex = Mutex.new
      end

      def with_reused_vm(stemcell)
        begin
          instance_memo = obtain_instance_memo(stemcell)
          yield instance_memo.instance
          release_instance(instance_memo)
        rescue => e
          remove_instance(instance_memo)
          unless instance_memo.instance_plan.nil?
            if Config.keep_unreachable_vms
              @logger.info('Keeping reused compilation VM for debugging')
            else
              destroy_instance(instance_memo.instance_plan)
            end
          end
          raise e
        end
      end

      def with_single_use_vm(stemcell)
        begin
          keep_failing_vm = false
          instance_memo = InstanceMemo.new(@instance_provider, stemcell)
          yield instance_memo.instance
        rescue => e
          @logger.info('Keeping single-use compilation VM for debugging')
          keep_failing_vm = Config.keep_unreachable_vms
          raise e
        ensure
          unless instance_memo.instance.nil? || keep_failing_vm
            destroy_instance(instance_memo.instance_plan)
          end
        end
      end

      def delete_instances(number_of_workers)
        ThreadPool.new(:max_threads => number_of_workers).wrap do |pool|
          @instance_reuser.each do |instance_memo|
            pool.process do
              @instance_reuser.remove_instance(instance_memo)
              instance_plan = DeploymentPlan::InstancePlan.new(
                existing_instance: instance_memo.instance.model,
                instance: instance_memo.instance,
                desired_instance: DeploymentPlan::DesiredInstance.new,
                network_plans: []
              )
              destroy_instance(instance_plan)
            end
          end
        end
      end

      private

      def remove_instance(instance_memo)
        @mutex.synchronize do
          @instance_reuser.remove_instance(instance_memo)
        end
      end

      def release_instance(instance_memo)
        @mutex.synchronize do
          @instance_reuser.release_instance(instance_memo)
        end
      end

      def obtain_instance_memo(stemcell)
        instance_memo = nil
        @mutex.synchronize do
          instance_memo = @instance_reuser.get_instance(stemcell)
          if instance_memo.nil?
            if @instance_reuser.total_instance_count >= @max_instance_count
              instance_memo = @instance_reuser.remove_idle_instance_not_matching_stemcell(stemcell)
              destroy_instance(instance_memo.instance_plan)
            end
            @logger.debug("Creating new compilation VM for stemcell '#{stemcell.desc}'")
            instance_memo = InstanceMemo.new(@instance_provider, stemcell)
            @instance_reuser.add_in_use_instance(instance_memo, stemcell)
          else
            @logger.info("Reusing compilation VM '#{instance_memo.instance.model.vm_cid}' for stemcell '#{stemcell.desc}'")
          end
        end
        return instance_memo
      end

      def destroy_instance(instance_plan)
        @instance_deleter.delete_instance_plan(instance_plan, EventLog::NullStage.new)
      end
    end

    private

    class InstanceProvider
      def initialize(deployment_plan, vm_creator, logger)
        @deployment_plan = deployment_plan
        @vm_creator = vm_creator
        @logger = logger
      end

      def create_instance_plan(stemcell)
        if @deployment_plan.compilation.vm_type
          vm_type = @deployment_plan.compilation.vm_type
        else
          vm_type = CompilationVmType.new(@deployment_plan.compilation.cloud_properties)
        end

        vm_extensions = @deployment_plan.compilation.vm_extensions
        env = Env.new(@deployment_plan.compilation.env)

        compile_job = CompilationJob.new(vm_type, vm_extensions, stemcell, env, @deployment_plan.compilation.network_name, @logger)
        availability_zone = @deployment_plan.compilation.availability_zone
        instance = Instance.create_from_job(compile_job, 0, 'started', @deployment_plan.model, {}, availability_zone, @logger)
        instance.bind_new_instance_model

        compilation_network = @deployment_plan.network(@deployment_plan.compilation.network_name)
        reservation = DesiredNetworkReservation.new_dynamic(instance.model, compilation_network)
        desired_instance = DeploymentPlan::DesiredInstance.new(compile_job, nil)
        instance_plan = DeploymentPlan::InstancePlan.new(
          existing_instance: instance.model,
          instance: instance,
          desired_instance: desired_instance,
          network_plans: [DeploymentPlan::NetworkPlanner::Plan.new(reservation: reservation)]
        )

        compile_job.add_instance_plans([instance_plan])
        instance_plan
      end

      def create_instance(instance_plan)
        instance_model = instance_plan.instance.model
        parent_id = add_event(instance_model.deployment.name, instance_model.name)
        @deployment_plan.ip_provider.reserve(instance_plan.network_plans.first.reservation)
        @vm_creator.create_for_instance_plan(instance_plan, [], {})
        instance_plan.instance
      rescue Exception => e
        raise e
      ensure
        add_event(instance_model.deployment.name, instance_model.name, parent_id, e)
      end

      private

      def add_event(deployment_name, instance_name = nil, parent_id = nil, error = nil)
        user = Config.current_job.username
        event = Config.current_job.event_manager.create_event(
          {
            parent_id: parent_id,
            user: user,
            action: 'create',
            object_type: 'instance',
            object_name: instance_name,
            task: Config.current_job.task_id,
            deployment: deployment_name,
            instance: instance_name,
            error: error
          })
        event.id
      end
    end

    class InstanceMemo
      attr_reader :instance_plan

      def initialize(instance_provider, stemcell)
        @instance_provider = instance_provider
        @stemcell = stemcell
      end

      def instance
        return @instance if @called
        @called = true
        @instance_plan = @instance_provider.create_instance_plan(@stemcell)
        @instance = @instance_plan.instance
        @instance_provider.create_instance(@instance_plan)
        @instance
      end
    end

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
      attr_reader :vm_type, :vm_extensions, :stemcell, :env, :name
      attr_reader :instance_plans

      def initialize(vm_type, vm_extensions, stemcell, env, compilation_network_name, logger)
        @vm_type = vm_type
        @vm_extensions = vm_extensions
        @stemcell = stemcell
        @env = env
        @network = compilation_network_name
        @name = "compilation-#{SecureRandom.uuid}"
        @instance_plans = []
        @logger = logger
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

      def resolved_links
        {}
      end

      def update_spec
        nil
      end

      def lifecycle
        nil
      end

      def persistent_disk_collection
        PersistentDiskCollection.new(@logger)
      end

      def compilation?
        true
      end
    end
  end
end
