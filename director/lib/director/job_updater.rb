module Bosh::Director

  class JobUpdater

    class RollbackException < StandardError; end

    def initialize(job)
      @job = job
    end

    def update
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