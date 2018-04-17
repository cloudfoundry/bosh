module Bosh::Director
  module Jobs
    class ScheduledOrphanedVMCleanup < BaseJob
      @queue = :normal

      def self.job_type
        :scheduled_orphaned_vm_cleanup
      end

      def self.has_work(_)
        Models::OrphanedVm.any?
      end

      def initialize(params)
        logger.debug("ScheduledOrphanedVMCleanup initialized with params: #{params.inspect}")
        @vm_deleter = VmDeleter.new(logger)
        @db_ip_repo = DeploymentPlan::DatabaseIpRepo.new(logger)
      end

      def perform(lock_timeout = 5)
        orphaned_vms = Models::OrphanedVm.all
        ThreadPool.new(max_threads: Config.max_threads).wrap do |pool|
          orphaned_vms.each do |vm|
            pool.process do
              begin
                Lock.new("lock:orphan_vm_cleanup:#{vm.cid}", timeout: lock_timeout).lock do
                  @vm_deleter.delete_vm_by_cid(vm.cid, vm.stemcell_api_version, vm.cpi)
                  destroy_vm(vm)
                end
              rescue Bosh::Clouds::VMNotFound => e
                logger.debug('VM already gone; deleting orphaned references')
                destroy_vm(vm)
              rescue Timeout => e
                logger.debug("Timed out acquiring lock to delete #{vm.cid}")
              rescue StandardError => e
                logger.debug('Failed to delete Orphaned VM due to unhandled exception')
              ensure
                add_event(vm.cid, e)
              end
            end
          end
        end
      end

      private

      def destroy_vm(vm)
        vm.ip_addresses.each do |ip_addr|
          @db_ip_repo.delete(ip_addr.address, nil)
        end
        vm.destroy
      end

      def add_event(object_name = nil, error = nil)
        Config.current_job.event_manager.create_event(
          user:        Config.current_job.username,
          action:      'delete',
          object_type: 'vm',
          object_name: object_name,
          task:        Config.current_job.task_id,
          error:       error,
        )
      end
    end
  end
end
