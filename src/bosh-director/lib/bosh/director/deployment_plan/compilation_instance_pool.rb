module Bosh::Director
  module DeploymentPlan
    class CompilationInstancePool
      class << self
        def create(deployment_plan)
          logger = Config.logger

          new(
            InstanceReuser.new,
            make_instance_provider(logger, deployment_plan),
            logger,
            make_instance_deleter(logger),
            deployment_plan.compilation,
          )
        end

        private

        def make_instance_deleter(logger)
          Bosh::Director::InstanceDeleter.new(
            PowerDnsManagerProvider.create,
            DiskManager.new(logger),
          )
        end

        def make_instance_provider(logger, deployment_plan)
          InstanceProvider.new(
            deployment_plan,
            Bosh::Director::VmCreator.new(
              logger,
              deployment_plan.template_blob_cache,
              LocalDnsEncoderManager.create_dns_encoder(deployment_plan.use_short_dns_addresses?, deployment_plan.use_link_dns_names?),
              AgentBroadcaster.new,
              deployment_plan.link_provider_intents,
            ),
            logger,
          )
        end
      end

      def initialize(instance_reuser, instance_provider, logger, instance_deleter, config)
        @instance_reuser = instance_reuser
        @logger = logger
        @instance_deleter = instance_deleter
        @config = config
        @instance_provider = instance_provider
        @mutex = Mutex.new
        @variables_interpolator = Bosh::Director::ConfigServer::VariablesInterpolator.new
      end

      def with_reused_vm(stemcell, package, &block)
        instance_memo = obtain_instance_memo(stemcell)
        @instance_provider.update_instance_compilation_metadata(instance_memo.instance, package)
        block.call instance_memo.instance
        release_instance(instance_memo)
      rescue StandardError => e
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

      def with_single_use_vm(stemcell, package, &block)
        keep_failing_vm = false
        instance_memo = InstanceMemo.new(@instance_provider, stemcell)
        @instance_provider.update_instance_compilation_metadata(instance_memo.instance, package)
        block.call instance_memo.instance
      rescue StandardError => e
        @logger.info('Keeping single-use compilation VM for debugging')
        keep_failing_vm = Config.keep_unreachable_vms
        raise e
      ensure
        destroy_instance(instance_memo.instance_plan) unless instance_memo.instance.nil? || keep_failing_vm
      end

      def delete_instances(number_of_workers)
        ThreadPool.new(max_threads: number_of_workers).wrap do |pool|
          @instance_reuser.each do |instance_memo|
            pool.process do
              @instance_reuser.remove_instance(instance_memo)
              instance_plan = DeploymentPlan::InstancePlan.new(
                existing_instance: instance_memo.instance.model,
                instance: instance_memo.instance,
                desired_instance: DeploymentPlan::DesiredInstance.new,
                network_plans: [],
                variables_interpolator: @variables_interpolator,
              )
              destroy_instance(instance_plan)
            end
          end
        end
      end

      private

      def remove_instance(instance_memo)
        @mutex.synchronize { @instance_reuser.remove_instance(instance_memo) }
      end

      def release_instance(instance_memo)
        @mutex.synchronize { @instance_reuser.release_instance(instance_memo) }
      end

      def obtain_instance_memo(stemcell)
        instance_memo = nil
        @mutex.synchronize do
          instance_memo = @instance_reuser.get_instance(stemcell)
          if instance_memo.nil?
            if @instance_reuser.total_instance_count >= @config.workers
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
        instance_memo
      end

      def destroy_instance(instance_plan)
        if @config.orphan_workers
          instance_plan.instance_model.vms.each do |vm|
            Steps::OrphanVmStep.new(vm).perform(nil)
          end
          instance_plan.release_all_network_plans
        end

        @instance_deleter.delete_instance_plan(instance_plan, EventLog::NullStage.new)
      end
    end

    class InstanceProvider
      def initialize(deployment_plan, vm_creator, logger)
        @deployment_plan = deployment_plan
        @vm_creator = vm_creator
        @tags = deployment_plan.tags
        @logger = logger
        @variables_interpolator = Bosh::Director::ConfigServer::VariablesInterpolator.new
        @metadata_updater = MetadataUpdater.build
      end

      def create_instance_plan(stemcell)
        vm_type = if @deployment_plan.compilation.vm_type
                    @deployment_plan.compilation.vm_type
                  else
                    CompilationVmType.new(@deployment_plan.compilation.cloud_properties)
                  end

        vm_resources = @deployment_plan.compilation.vm_resources
        vm_extensions = @deployment_plan.compilation.vm_extensions
        env = Env.new(@deployment_plan.compilation.env)

        compile_instance_group = CompilationInstanceGroup.new(
          vm_type,
          vm_resources,
          vm_extensions,
          stemcell,
          env,
          @deployment_plan.compilation.network_name,
          @logger,
        )
        availability_zone = @deployment_plan.compilation.availability_zone
        instance = Instance.create_from_instance_group(
          compile_instance_group,
          0,
          'started',
          @deployment_plan.model,
          {},
          availability_zone,
          @logger,
          @variables_interpolator,
        )
        instance.bind_new_instance_model

        if vm_resources
          vm_cloud_properties = @deployment_plan.vm_resources_cache
                                                .get_vm_cloud_properties(
                                                  instance.availability_zone&.cpi,
                                                  vm_resources.spec,
                                                )

          instance.update_vm_cloud_properties(vm_cloud_properties)
        end

        compilation_network = @deployment_plan.network(@deployment_plan.compilation.network_name)
        reservation = DesiredNetworkReservation.new_dynamic(instance.model, compilation_network)
        desired_instance = DeploymentPlan::DesiredInstance.new(compile_instance_group)
        instance_plan = DeploymentPlan::InstancePlan.new(
          existing_instance: instance.model,
          instance: instance,
          desired_instance: desired_instance,
          network_plans: [DeploymentPlan::NetworkPlanner::Plan.new(reservation: reservation)],
          tags: @tags,
          variables_interpolator: @variables_interpolator
        )

        compile_instance_group.add_instance_plans([instance_plan])
        instance_plan
      end

      def create_instance(instance_plan)
        instance_model = instance_plan.instance.model
        parent_id = add_event(instance_model.deployment.name, instance_model.name)
        @deployment_plan.ip_provider.reserve(instance_plan.network_plans.first.reservation)
        @vm_creator.create_for_instance_plan(instance_plan, @deployment_plan.ip_provider, [], instance_plan.tags)
        instance_plan.instance
      rescue StandardError => e
        raise e
      ensure
        add_event(instance_model.deployment.name, instance_model.name, parent_id, e)
      end

      def update_instance_compilation_metadata(instance, package)
        @metadata_updater.update_vm_metadata(
          instance.model,
          instance.model.active_vm,
          @tags.merge(compiling: package.name),
        )
      end

      private

      def add_event(deployment_name, instance_name = nil, parent_id = nil, error = nil)
        user = Config.current_job.username
        event = Config.current_job.event_manager.create_event(
          parent_id: parent_id,
          user: user,
          action: 'create',
          object_type: 'instance',
          object_name: instance_name,
          task: Config.current_job.task_id,
          deployment: deployment_name,
          instance: instance_name,
          error: error,
        )
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

    class CompilationInstanceGroup
      attr_reader :vm_type, :vm_resources, :vm_extensions, :stemcell, :env, :name
      attr_reader :instance_plans, :tags

      def initialize(vm_type, vm_resources, vm_extensions, stemcell, env, compilation_network_name, logger)
        @vm_type = vm_type
        @vm_resources = vm_resources
        @vm_extensions = vm_extensions
        @stemcell = stemcell
        @env = env
        @network = compilation_network_name
        @name = "compilation-#{SecureRandom.uuid}"
        @instance_plans = []
        @logger = logger
        @tags = {}
      end

      def default_network
        {
          'dns' => @network,
          'gateway' => @network,
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
          'name' => @name,
        }
      end

      def package_spec
        {}
      end

      def properties
        {}
      end

      def update_spec
        nil
      end

      def lifecycle
        nil
      end

      def create_swap_delete?
        false
      end

      def should_create_swap_delete?
        false
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
