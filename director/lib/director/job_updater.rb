module Bosh::Director

  class JobUpdater

    class RollbackException < StandardError; end

    def initialize(job)
      @job = job
      @cloud = Config.cloud
    end

    def delete_unneeded_instances
      unless @job.unneeded_instances.empty?
        pool = ActionPool::Pool.new(:min_threads => 1, :max_threads => @job.update.max_in_flight)
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
        sleep(0.1) while pool.working + pool.action_size > 0
      end
    end

    def update
      delete_unneeded_instances

      instances = []
      @job.instances.each do |instance|
        instances << instance if instance.changed?
      end

      unless instances.empty?
        pool = ActionPool::Pool.new(:min_threads => 1, :max_threads => @job.update.max_in_flight)
        num_canaries = [@job.update.canaries, instances.size].min

        # canaries first
        num_canaries.times do
          instance = instances.shift
          pool.process do
            unless @job.should_rollback?
              begin
                InstanceUpdater.new(instance).update(:canary => true)
              rescue Exception => e
                @job.record_update_error(e, :canary => true)
              end
            end
          end
        end

        sleep(0.1) while pool.working + pool.action_size > 0

        raise RollbackException if @job.should_rollback?

        # continue with the rest of the updates
        instances.each do |instance|
          pool.process do
            unless @job.should_rollback?
              begin
                InstanceUpdater.new(instance).update
              rescue Exception => e
                @job.record_update_error(e)
              end
            end
          end
        end

        sleep(0.1) while pool.working + pool.action_size > 0

        raise RollbackException if @job.should_rollback?
      end
    end

  end
end