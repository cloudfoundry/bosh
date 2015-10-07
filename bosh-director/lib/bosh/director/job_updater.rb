module Bosh::Director
  class JobUpdater
    # @param [Bosh::Director::DeploymentPlan::Planner] deployment_plan
    # @param [Bosh::Director::DeploymentPlan::Job] job
    # @param [Bosh::Director::JobRenderer] job_renderer
    def initialize(deployment_plan, job, job_renderer, links_resolver)
      @deployment_plan = deployment_plan
      @job = job
      @job_renderer = job_renderer
      @links_resolver = links_resolver

      @logger = Config.logger
      @event_log = Config.event_log
    end

    def update
      @logger.info('Deleting no longer needed instances')
      delete_unneeded_instances

      @job_renderer.render_job_instances

      instance_plans = @job.needed_instance_plans
                         .select do |instance_plan|
        instance_plan.changed?
      end

      if instance_plans.empty?
        @logger.info("No instances to update for `#{@job.name}'")
        return
      end

      instance_plans.each do |instance_plan|
        changes = instance_plan.changes
        @logger.debug("Need to update instance '#{instance_plan.instance}', changes: #{changes.to_a.join(', ').inspect}")
      end

      @logger.info("Found #{instance_plans.size} instances to update")
      event_log_stage = @event_log.begin_stage('Updating job', instance_plans.size, [ @job.name ])

      ThreadPool.new(:max_threads => @job.update.max_in_flight).wrap do |pool|
        num_canaries = [ @job.update.canaries, instance_plans.size ].min
        @logger.info("Starting canary update num_canaries=#{num_canaries}")
        update_canaries(pool, instance_plans, num_canaries, event_log_stage)

        @logger.info('Waiting for canaries to update')
        pool.wait

        @logger.info('Finished canary update')

        @logger.info('Continuing the rest of the update')
        update_instances(pool, instance_plans, event_log_stage)
      end

      @logger.info('Finished the rest of the update')
    end

    private

    def delete_unneeded_instances
      unneeded_instance_plans = @job.obsolete_instance_plans
      unneeded_instances = @job.unneeded_instances
      return if unneeded_instances.empty?

      event_log_stage = @event_log.begin_stage('Deleting unneeded instances', unneeded_instances.size, [@job.name])
      dns_manager = DnsManager.create
      deleter = InstanceDeleter.new(@deployment_plan.ip_provider, @deployment_plan.skip_drain, dns_manager)
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
      instance = instance_plan.instance
      desc = "#{@job.name}/#{instance.index}"
      event_log_stage.advance_and_track("#{desc} (canary)") do
        with_thread_name("canary_update(#{desc})") do
          begin
            InstanceUpdater.create(@job_renderer).update(instance_plan, :canary => true)
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
      desc = "#{@job.name}/#{instance_plan.instance.index}"
      event_log_stage.advance_and_track(desc) do
        with_thread_name("instance_update(#{desc})") do
          begin
            InstanceUpdater.create(@job_renderer).update(instance_plan)
          rescue Exception => e
            @logger.error("Error updating instance: #{e.inspect}\n#{e.backtrace.join("\n")}")
            raise
          end
        end
      end
    end
  end
end
