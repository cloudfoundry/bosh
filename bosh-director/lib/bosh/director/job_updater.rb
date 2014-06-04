module Bosh::Director
  class JobUpdater
    # @param [Bosh::Director::DeploymentPlan::Planner] deployment_plan
    # @param [Bosh::Director::DeploymentPlan::Job] job
    # @param [Bosh::Director::JobRenderer] job_renderer
    def initialize(deployment_plan, job, job_renderer)
      @deployment_plan = deployment_plan
      @job = job
      @job_renderer = job_renderer

      @logger = Config.logger
      @event_log = Config.event_log
    end

    def update
      @logger.info('Deleting no longer needed instances')
      delete_unneeded_instances

      instances = []
      @job.instances.each do |instance|
        instances << instance if instance.changed?
      end

      if instances.empty?
        @logger.info("No instances to update for `#{@job.name}'")
        return
      end

      @logger.info("Found #{instances.size} instances to update")
      event_log_stage = @event_log.begin_stage("Updating job", instances.size, [ @job.name ])

      ThreadPool.new(:max_threads => @job.update.max_in_flight).wrap do |pool|
        num_canaries = [ @job.update.canaries, instances.size ].min
        @logger.info("Starting canary update num_canaries=#{num_canaries}")
        update_canaries(pool, instances, num_canaries, event_log_stage)

        @logger.info('Waiting for canaries to update')
        pool.wait

        @logger.info("Finished canary update")

        @logger.info("Continuing the rest of the update")
        update_instances(pool, instances, event_log_stage)
      end

      @logger.info("Finished the rest of the update")
    end

    private

    def delete_unneeded_instances
      unneeded_instances = @job.unneeded_instances
      return if unneeded_instances.empty?

      event_log_stage = @event_log.begin_stage("Deleting unneeded instances", unneeded_instances.size, [@job.name])
      deleter = InstanceDeleter.new(@deployment_plan)
      deleter.delete_instances(unneeded_instances, event_log_stage, max_threads: @job.update.max_in_flight)

      @logger.info("Deleted no longer needed instances")
    end

    def update_canaries(pool, instances, num_canaries, event_log_stage)
      num_canaries.times do
        instance = instances.shift
        pool.process { update_canary_instance(instance, event_log_stage) }
      end
    end

    def update_canary_instance(instance, event_log_stage)
      desc = "#{@job.name}/#{instance.index}"
      event_log_stage.advance_and_track("#{desc} (canary)") do |ticker|
        with_thread_name("canary_update(#{desc})") do
          begin
            InstanceUpdater.new(instance, ticker, @job_renderer).update(:canary => true)
          rescue Exception => e
            @logger.error("Error updating canary instance: #{e.inspect}\n#{e.backtrace.join("\n")}")
            raise
          end
        end
      end
    end

    def update_instances(pool, instances, event_log_stage)
      instances.each do |instance|
        pool.process { update_instance(instance, event_log_stage) }
      end
    end

    def update_instance(instance, event_log_stage)
      desc = "#{@job.name}/#{instance.index}"
      event_log_stage.advance_and_track(desc) do |ticker|
        with_thread_name("instance_update(#{desc})") do
          begin
            InstanceUpdater.new(instance, ticker, @job_renderer).update
          rescue Exception => e
            @logger.error("Error updating instance: #{e.inspect}\n#{e.backtrace.join("\n")}")
            raise
          end
        end
      end
    end
  end
end
