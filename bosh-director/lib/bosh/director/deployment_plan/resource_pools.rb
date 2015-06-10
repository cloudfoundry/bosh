module Bosh::Director
  module DeploymentPlan
    class ResourcePools
      def initialize(event_log, resource_pool_updaters)
        @event_log = event_log
        @resource_pool_updaters = resource_pool_updaters
      end

      def update
        ThreadPool.new(:max_threads => Config.max_threads).wrap do |thread_pool|
          event_log.begin_stage('Creating bound missing VMs', sum_across_pools(:bound_missing_vm_count))
          resource_pool_updaters.each do |updater|
            updater.create_bound_missing_vms(thread_pool)
          end
        end
      end

      private

      attr_reader :event_log, :resource_pool_updaters

      def sum_across_pools(counting_method)
        resource_pool_updaters.inject(0) do |sum, updater|
          sum + updater.send(counting_method.to_sym)
        end
      end
    end
  end
end
