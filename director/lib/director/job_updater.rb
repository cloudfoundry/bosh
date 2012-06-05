# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director

  class JobUpdater

    # @param [Bosh::Director::DeploymentPlan] deployment_plan
    # @param [DeploymentPlan::JobSpec] job
    def initialize(deployment_plan, job)
      @deployment_plan = deployment_plan
      @job = job
      @cloud = Config.cloud
      @logger = Config.logger
      @event_log = Config.event_log
    end

    def delete_unneeded_instances
      @logger.info("Deleting no longer needed instances")
      unneeded_instances = @job.unneeded_instances

      return if unneeded_instances.empty?

      @event_log.begin_stage("Deleting unneeded instances",
                             unneeded_instances.size, [@job.name])
      InstanceDeleter.new(@deployment_plan).
        delete_instances(unneeded_instances,
                         :max_threads => @job.update.max_in_flight)

      @logger.info("Deleted no longer needed instances")
    end

    def update
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

      @event_log.begin_stage("Updating job", instances.size, [ @job.name ])

      ThreadPool.new(:max_threads => @job.update.max_in_flight).wrap do |pool|
        num_canaries = [ @job.update.canaries, instances.size ].min

        @logger.info("Starting canary update")
        # Canaries first
        num_canaries.times do
          instance = instances.shift

          pool.process do
            desc = "#{@job.name}/#{instance.index}"
            @event_log.track("#{desc} (canary)") do |ticker|
              with_thread_name("canary_update(#{desc})") do
                unless @job.should_halt?
                  begin
                    InstanceUpdater.new(instance, ticker).
                      update(:canary => true)
                  rescue Exception => e
                    @logger.error("Error updating canary instance: #{e}\n" +
                                  "#{e.backtrace.join("\n")}")
                    @job.record_update_error(e, :canary => true)
                  end
                end
              end
            end
          end
        end

        pool.wait
        @logger.info("Finished canary update")

        if @job.should_halt?
          @logger.warn("Halting deployment due to a canary failure")
          halt
        end

        # Continue with the rest of the updates
        @logger.info("Continuing the rest of the update")
        instances.each do |instance|
          pool.process do
            desc = "#{@job.name}/#{instance.index}"
            @event_log.track(desc) do |ticker|
              with_thread_name("instance_update(#{desc})") do
                unless @job.should_halt?
                  begin
                    InstanceUpdater.new(instance, ticker).update
                  rescue Exception => e
                    @logger.error("Error updating instance: #{e}\n" +
                                  "#{e.backtrace.join("\n")}")
                    @job.record_update_error(e)
                  end
                end
              end
            end
          end
        end
      end

      @logger.info("Finished the rest of the update")

      if @job.should_halt?
        @logger.warn("Halting deployment due to an update failure")
        halt
      end
    end

    def halt
      error = @job.halt_exception ||
        RuntimeError.new("Deployment has been halted")
      raise error
    end

  end
end
