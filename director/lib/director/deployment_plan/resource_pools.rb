module Bosh::Director
  module DeploymentPlan
    class ResourcePools
      def initialize(event_log, resource_pool_updaters)
        @event_log = event_log
        @resource_pool_updaters = resource_pool_updaters
      end

      def update
        ThreadPool.new(:max_threads => Config.max_threads).wrap do |thread_pool|
          # Delete extra VMs across resource pools
          event_log.begin_stage('Deleting extra VMs', sum_across_pools(:extra_vm_count))
          resource_pool_updaters.each do |updater|
            updater.delete_extra_vms(thread_pool)
          end
          thread_pool.wait

          # Delete outdated idle vms across resource pools, outdated allocated
          # VMs are handled by instance updater
          event_log.begin_stage('Deleting outdated idle VMs', sum_across_pools(:outdated_idle_vm_count))

          resource_pool_updaters.each do |updater|
            updater.delete_outdated_idle_vms(thread_pool)
          end
          thread_pool.wait

          # Create missing VMs across resource pools phase 1:
          # only creates VMs that have been bound to instances
          # to avoid refilling the resource pool before instances
          # that are no longer needed have been deleted.
          event_log.begin_stage('Creating bound missing VMs', sum_across_pools(:bound_missing_vm_count))
          resource_pool_updaters.each do |updater|
            updater.create_bound_missing_vms(thread_pool)
          end
        end
      end

      def refill
        # Instance updaters might have added some idle vms
        # so they can be returned to resource pool. In that case
        # we need to pre-allocate network settings for all of them.
        resource_pool_updaters.each do |resource_pool_updater|
          resource_pool_updater.reserve_networks
        end

        event_log.begin_stage('Refilling resource pools', sum_across_pools(:missing_vm_count))
        ThreadPool.new(:max_threads => Config.max_threads).wrap do |thread_pool|
          # Create missing VMs across resource pools phase 2:
          # should be called after all instance updaters are finished to
          # create additional VMs in order to balance resource pools
          resource_pool_updaters.each do |resource_pool_updater|
            resource_pool_updater.create_missing_vms(thread_pool)
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
