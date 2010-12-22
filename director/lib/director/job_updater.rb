module Bosh::Director

  class JobUpdater

    class RollbackException < StandardError; end

    def initialize(job)
      @job = job
      @cloud = Config.cloud
      @logger = Config.logger
    end

    def delete_unneeded_instances
      @logger.info("Deleting no longer needed instances")
      unless @job.unneeded_instances.empty?
        pool = ThreadPool.new(:min_threads => 1, :max_threads => @job.update.max_in_flight)
        @job.unneeded_instances.each do |instance|
          vm = instance.vm
          disk_cid = instance.disk_cid
          vm_cid = vm.cid
          agent_id = vm.agent_id

          pool.process do
            agent = AgentClient.new(agent_id)
            drain_time = agent.drain
            sleep(drain_time)
            agent.stop

            @cloud.delete_vm(vm_cid)
            @cloud.delete_disk(disk_cid) if disk_cid
            vm.delete
            instance.delete
          end
        end
        pool.wait
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
        pool = ThreadPool.new(:min_threads => 1, :max_threads => @job.update.max_in_flight)
        num_canaries = [@job.update.canaries, instances.size].min

        @logger.info("Starting canary update")
        # canaries first
        num_canaries.times do
          instance = instances.shift
          pool.process do
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

        pool.wait
        @logger.info("Finished canary update")

        if @job.should_rollback?
          @logger.warn("Rolling back due to a canary failure")
          raise RollbackException
        end

        # continue with the rest of the updates
        @logger.info("Continuing the rest of the update")
        instances.each do |instance|
          pool.process do
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

        pool.wait
        @logger.info("Finished the rest of the update")

        if @job.should_rollback?
          @logger.warn("Rolling back due to an update failure")
          raise RollbackException
        end
      end
    end

  end
end