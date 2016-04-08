module Bosh::Director
  class JobUpdater
    # @param [Bosh::Director::DeploymentPlan::Planner] deployment_plan
    # @param [Bosh::Director::DeploymentPlan::Job] job
    # @param [Bosh::Director::JobRenderer] job_renderer
    def initialize(deployment_plan, job, links_resolver, disk_manager)
      @deployment_plan = deployment_plan
      @job = job
      @links_resolver = links_resolver

      @logger = Config.logger
      @event_log = Config.event_log
      @disk_manager = disk_manager
    end

    def update
      @logger.info('Deleting no longer needed instances')
      delete_unneeded_instances

      instance_plans = @job.needed_instance_plans.select do | instance_plan |
        if instance_plan.changed?
          true
        else
          # no changes necessary for the agent, but some metadata may have
          # changed (i.e. vm_type.name), so push state to the db regardless
          instance_plan.persist_current_spec
          false
        end
      end

      if instance_plans.empty?
        @logger.info("No instances to update for '#{@job.name}'")
        return
      else
        @job.did_change = true
      end

      instance_plans.each do |instance_plan|
        changes = instance_plan.changes
        @logger.debug("Need to update instance '#{instance_plan.instance}', changes: #{changes.to_a.join(', ').inspect}")
      end

      @logger.info("Found #{instance_plans.size} instances to update")
      event_log_stage = @event_log.begin_stage('Updating job', instance_plans.size, [ @job.name ])

      ordered_azs = []
      instance_plans.each do | instance_plan |
        unless ordered_azs.include?(instance_plan.instance.availability_zone)
          ordered_azs.push(instance_plan.instance.availability_zone)
        end
      end

      instance_plans_by_az = instance_plans.group_by{ |instance_plan| instance_plan.instance.availability_zone }
      canaries_done = false

      ordered_azs.each do | az |
        az_instance_plans = instance_plans_by_az[az]
        @logger.info("Starting to update az '#{az}'")
        ThreadPool.new(:max_threads => @job.update.max_in_flight).wrap do |pool|
          unless canaries_done
            num_canaries = [@job.update.canaries, az_instance_plans.size].min
            @logger.info("Starting canary update num_canaries=#{num_canaries}")
            update_canaries(pool, az_instance_plans, num_canaries, event_log_stage)

            @logger.info('Waiting for canaries to update')
            pool.wait

            @logger.info('Finished canary update')

            canaries_done = true
          end

          @logger.info('Continuing the rest of the update')
          update_instances(pool, az_instance_plans, event_log_stage)
          @logger.info('Finished the rest of the update')
        end
        @logger.info("Finished updating az '#{az}'")
      end
    end

    private

    def delete_unneeded_instances
      unneeded_instance_plans = @job.obsolete_instance_plans
      unneeded_instances = @job.unneeded_instances
      if unneeded_instances.empty?
        return
      else
        @job.did_change = true
      end

      event_log_stage = @event_log.begin_stage('Deleting unneeded instances', unneeded_instances.size, [@job.name])
      dns_manager = DnsManagerProvider.create
      deleter = InstanceDeleter.new(@deployment_plan.ip_provider, dns_manager, @disk_manager)
      deleter.delete_instance_plans(unneeded_instance_plans, event_log_stage, max_threads: @job.update.max_in_flight)

      @logger.info('Deleted no longer needed instances')
    end

    def update_canaries(pool, instance_plans, num_canaries, event_log_stage)
      num_canaries.times do
        instance_plan = instance_plans.shift
        pool.process { update_canary_instance(instance_plan, event_log_stage) }
      end
    end

    def update_canary_instance(instance_plan, event_log_stage)
      event_log_stage.advance_and_track("#{instance_plan.instance.model} (canary)") do
        with_thread_name("canary_update(#{instance_plan.instance.model})") do
          begin
            InstanceUpdater.new_instance_updater(@deployment_plan.ip_provider).update(instance_plan, :canary => true)
          rescue Exception => e
            @logger.error("Error updating canary instance: #{e.inspect}\n#{e.backtrace.join("\n")}")
            raise
          end
        end
      end
    end

    def update_instances(pool, instance_plans, event_log_stage)
      instance_plans.each do |instance_plan|
        pool.process { update_instance(instance_plan, event_log_stage) }
      end
    end

    def update_instance(instance_plan, event_log_stage)
      event_log_stage.advance_and_track("#{instance_plan.instance.model}") do
        with_thread_name("instance_update(#{instance_plan.instance.model})") do
          begin
            InstanceUpdater.new_instance_updater(@deployment_plan.ip_provider).update(instance_plan)
          rescue Exception => e
            @logger.error("Error updating instance: #{e.inspect}\n#{e.backtrace.join("\n")}")
            raise
          end
        end
      end
    end
  end
end
