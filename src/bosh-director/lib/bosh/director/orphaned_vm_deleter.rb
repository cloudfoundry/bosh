module Bosh::Director
  class OrphanedVMDeleter
    def initialize(logger)
      @logger = logger
      @vm_deleter = VmDeleter.new(logger)
      @db_ip_repo = DeploymentPlan::DatabaseIpRepo.new(logger)
    end

    def delete_all(lock_timeout = 5)
      ThreadPool.new(max_threads: Config.max_threads).wrap do |pool|
        Models::OrphanedVm.all.each do |vm|
          pool.process do
            delete_vm(vm, lock_timeout)
          end
        end
      end
    end

    def delete_vm(vm, lock_timeout)
      begin
        Lock.new("lock:orphan_vm_cleanup:#{vm.cid}", timeout: lock_timeout).lock do
          @vm_deleter.delete_vm_by_cid(vm.cid, vm.stemcell_api_version, vm.cpi)
          destroy_vm(vm)
        end
      rescue Bosh::Clouds::VMNotFound => e
        @logger.debug('VM already gone; deleting orphaned references')
        destroy_vm(vm)
      rescue Timeout => e
        @logger.debug("Timed out acquiring lock to delete #{vm.cid}")
      rescue StandardError => e
        @logger.debug('Failed to delete Orphaned VM due to unhandled exception')
      ensure
        add_event(vm.cid, e)
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