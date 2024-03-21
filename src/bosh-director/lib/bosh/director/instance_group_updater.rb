module Bosh::Director
  class InstanceGroupUpdater
    def initialize(
      ip_provider:,
      instance_group:,
      disk_manager:,
      template_blob_cache:,
      dns_encoder:,
      link_provider_intents:
    )
      @ip_provider = ip_provider
      @instance_group = instance_group
      @template_blob_cache = template_blob_cache
      @dns_encoder = dns_encoder
      @link_provider_intents = link_provider_intents

      @logger = Config.logger
      @event_log = Config.event_log
      @disk_manager = disk_manager
    end

    def update
      @logger.info('Deleting no longer needed instances')
      delete_unneeded_instances

      instance_plans = @instance_group.needed_instance_plans.select do |instance_plan|
        if instance_plan.should_be_ignored?
          false
        elsif @instance_group.lifecycle == 'errand'
          @instance_group.instances.any?(&:vm_created?)
        elsif instance_plan.changed?
          true
        else
          # no changes necessary for the agent, but some metadata may have
          # changed (i.e. vm_type.name), so push state to the db regardless
          # variable set on instance should also be updated at this point as
          # instance updater will not do so
          instance_plan.persist_current_spec
          instance_plan.instance.update_variable_set
          if @links_manager.nil?
            @links_manager = Bosh::Director::Links::LinksManager.new(instance_plan.instance.deployment_model.links_serial_id)
          end
          @links_manager.bind_links_to_instance(instance_plan.instance)
          false
        end
      end

      if instance_plans.empty?
        @logger.info("No instances to update for '#{@instance_group.name}'")
        return
      else
        @instance_group.did_change = true
      end

      instance_plans.each do |instance_plan|
        changes = instance_plan.changes
        @logger.debug("Need to update instance '#{instance_plan.instance}', changes: #{changes.to_a.join(', ').inspect}")
      end

      @logger.info("Found #{instance_plans.size} instances to update")
      event_log_stage = @event_log.begin_stage('Updating instance', instance_plans.size, [@instance_group.name])

      if update_azs_in_parallel?
        update_instance_group(instance_plans, false, event_log_stage)
      else
        update_instance_group_by_az(instance_plans, event_log_stage)
      end
    end

    def update_instance_group(instance_plans, canaries_updated, event_log_stage)
      @logger.info("Starting to update instance group '#{@instance_group.name}'")

      ThreadPool.new(max_threads: @instance_group.update.max_in_flight(instance_plans.size)).wrap do |pool|
        unless canaries_updated
          num_canaries = [@instance_group.update.canaries(instance_plans.size), instance_plans.size].min
          @logger.info("Starting canary update num_canaries=#{num_canaries}")
          update_canaries(pool, instance_plans, num_canaries, event_log_stage)

          @logger.info('Waiting for canaries to update')
          pool.wait
          canaries_updated = true
          @logger.info('Finished canary update')
        end

        @logger.info('Continuing the rest of the update')
        update_instances(pool, instance_plans, event_log_stage)
        @logger.info('Finished the rest of the update')
      end

      @logger.info("Finished updating instance group '#{@instance_group.name}'")
    end

    def update_instance_group_by_az(instance_plans, event_log_stage)
      ordered_azs = []
      instance_plans.each do |instance_plan|
        unless ordered_azs.include?(instance_plan.instance.availability_zone)
          ordered_azs.push(instance_plan.instance.availability_zone)
        end
      end

      instance_plans_by_az = instance_plans.group_by { |instance_plan| instance_plan.instance.availability_zone }

      canaries_updated = false
      ordered_azs.each do |az|
        az_instance_plans = instance_plans_by_az[az]

        @logger.info("Starting to update az '#{az}'")
        update_instance_group(az_instance_plans, canaries_updated, event_log_stage)
        @logger.info("Finished updating az '#{az}'")

        canaries_updated = true
      end
    end

    private

    def update_azs_in_parallel?
      @instance_group.update.update_azs_in_parallel_on_initial_deploy? && initial_deploy?
    end

    def initial_deploy?
      deployment_model = Bosh::Director::Models::Deployment.find(name: @instance_group.deployment_name)
      deployment_model.manifest.nil?
    end

    def delete_unneeded_instances
      unneeded_instance_plans = @instance_group.obsolete_instance_plans
      return if unneeded_instance_plans.empty?

      @instance_group.did_change = true

      event_log_stage = @event_log.begin_stage(
        'Deleting unneeded instances',
        unneeded_instance_plans.size,
        [@instance_group.name],
      )

      deleter = InstanceDeleter.new(@disk_manager)

      deleter.delete_instance_plans(
        unneeded_instance_plans,
        event_log_stage,
        max_threads: @instance_group.update.max_in_flight(unneeded_instance_plans.size),
      )

      @logger.info('Deleted no longer needed instances')
    end

    def update_canaries(pool, instance_plans, num_canaries, event_log_stage)
      num_canaries.times do
        instance_plan = instance_plans.shift
        pool.process { update_canary_instance(instance_plan, event_log_stage) }
      end
    end

    def update_canary_instance(instance_plan, event_log_stage)
      update_instance_common(instance_plan, event_log_stage, canary: true)
    end

    def update_instances(pool, instance_plans, event_log_stage)
      instance_plans.each do |instance_plan|
        pool.process { update_instance(instance_plan, event_log_stage) }
      end
    end

    def update_instance(instance_plan, event_log_stage)
      update_instance_common(instance_plan, event_log_stage, canary: false)
    end

    private

    def update_instance_common(instance_plan, event_log_stage, canary:)
      if canary
        event_name = "#{instance_plan.instance.model} (canary)"
        thread_name = "canary_update(#{instance_plan.instance.model})"
        error_prefix = 'Error updating canary instance'
      else
        event_name = "#{instance_plan.instance.model}"
        thread_name = "instance_update(#{instance_plan.instance.model})"
        error_prefix = 'Error updating instance'
      end

      event_log_stage.advance_and_track(event_name) do |task|
        with_thread_name(thread_name) do
          InstanceUpdater.new_instance_updater(
            @ip_provider, @template_blob_cache,
            @dns_encoder, @link_provider_intents, task
          ).update(instance_plan, canary: canary)
        rescue Exception => e
          @logger.error("#{error_prefix}: #{e.inspect}\n#{e.backtrace.join("\n")}")
          raise
        end
      end
    end
  end
end
