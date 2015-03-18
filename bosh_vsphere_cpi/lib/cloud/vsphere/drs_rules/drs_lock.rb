module VSphereCloud
  class DrsLock
    include RetryBlock

    DRS_LOCK_NAME = 'drs_lock'
    MAX_LOCK_TIMEOUT_IN_SECONDS = 30

    class LockError < RuntimeError; end

    def initialize(vm_attribute_manager, logger)
      @vm_attribute_manager = vm_attribute_manager
      @logger = logger
    end

    def with_drs_lock
      acquire_lock
      @logger.debug('Acquired drs lock')
      # Ensure to release the lock only after it is successfully acquired
      begin
        yield
      ensure
        @logger.debug('Releasing drs lock')
        release_lock
      end
    end

    private

    def acquire_lock
      retry_with_timeout(MAX_LOCK_TIMEOUT_IN_SECONDS) do
        @vm_attribute_manager.create(DRS_LOCK_NAME)
      end
    rescue VSphereCloud::RetryBlock::TimeoutError
      @logger.debug('Failed to acquire drs lock')
      raise LockError.new('Failed to acquire DRS lock')
    end

    def release_lock
      @vm_attribute_manager.delete(DRS_LOCK_NAME)
    end
  end
end
