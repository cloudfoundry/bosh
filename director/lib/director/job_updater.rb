module Bosh::Director

  class JobUpdater

    class RollbackException < StandardError; end

    def initialize(job)
      @job = job
      @cloud = Config.cloud
      @logger = Config.logger
      @event_logger = Config.event_logger
    end

    def delete_unneeded_instances
      @logger.info("Deleting no longer needed instances")
      unless @job.unneeded_instances.empty?
        total = @job.unneeded_instances.size
        ThreadPool.new(:max_threads => @job.update.max_in_flight).wrap do |pool|
          @job.unneeded_instances.each_with_index do |instance, index|
            vm = instance.vm
            disk_cid = instance.disk_cid
            vm_cid = vm.cid
            agent_id = vm.agent_id

            progress_log("Deleting unneeded instance", index + 1, total)
            pool.process do
              agent = AgentClient.new(agent_id)
              drain_time = agent.drain("shutdown")
              sleep(drain_time)
              agent.stop

              @cloud.delete_vm(vm_cid)
              @cloud.delete_disk(disk_cid) if disk_cid

              instance.destroy
              vm.destroy
            end
          end
        end
      end
      @logger.info("Deleted no longer needed instances")
    end

    def update
      delete_unneeded_instances

      instances = []
      @job.instances.each do |instance|
        instances << instance if instance.changed?
      end

      unless instances.empty?

        ThreadPool.new(:max_threads => @job.update.max_in_flight).wrap do |pool|
          num_canaries = [@job.update.canaries, instances.size].min

          @logger.info("Starting canary update")
          # canaries first
          num_canaries.times do |index|
            instance = instances.shift
            progress_log("canary update", index + 1, num_canaries)
            pool.process do
              with_thread_name("canary_update(#{@job.name}/#{instance.index})") do
                unless @job.should_rollback?
                  begin
                    InstanceUpdater.new(instance).update(:canary => true)
                  rescue Exception => e
                    @logger.error("Error updating canary instance: #{e} - #{e.backtrace.join("\n")}")
                    @job.record_update_error(e, :canary => true)
                  end
                end
              end
            end
          end

          pool.wait
          @logger.info("Finished canary update")

          if @job.should_rollback?
            @logger.warn("Rolling back due to a canary failure")
            raise RollbackException
          end

          # continue with the rest of the updates
          @logger.info("Continuing the rest of the update")
          total = instances.size
          instances.each_with_index do |instance, index|
            progress_log("Updating instance", index + 1, total)
            pool.process do
              with_thread_name("instance_update(#{@job.name}/#{instance.index})") do
                unless @job.should_rollback?
                  begin
                    InstanceUpdater.new(instance).update
                  rescue Exception => e
                    @logger.error("Error updating instance: #{e} - #{e.backtrace.join("\n")}")
                    @job.record_update_error(e)
                  end
                end
              end
            end
          end
        end

        @logger.info("Finished the rest of the update")

        if @job.should_rollback?
          @logger.warn("Rolling back due to an update failure")
          raise RollbackException
        end
      end
    end

    private
    def progress_log(msg, index, total)
      @event_logger.progress_log("Updating job #{@job.name}", msg, index, total)
    end
  end
end
