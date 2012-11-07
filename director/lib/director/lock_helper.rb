module Bosh::Director
  module LockHelper
    def with_deployment_lock(deployment, options = {})
      if deployment.respond_to?(:name)
        name = deployment.name
      elsif deployment.kind_of?(String)
        name = deployment
      else
        raise ArgumentError, "invalid deployment: #{deployment}"
      end
      timeout = options[:timeout] || 10
      logger.info("Acquiring deployment lock on #{deployment_name}")
      Lock.new("lock:deployment:#{name}", :timeout => timeout).lock { yield }
    end

    def with_release_locks(deployment_plan, options = {})
      timeout = options[:timeout] || 10
      release_names = deployment_plan.releases.map do |release|
        release.name
      end

      # Sorting to enforce lock order to avoid deadlocks
      locks = release_names.sort.map do |release_name|
        logger.info("Acquiring release lock: #{release_name}")
        Lock.new("lock:release:#{release_name}", :timeout => timeout)
      end

      begin
        locks.each { |lock| lock.lock }
        yield
      ensure
        locks.reverse_each { |lock| lock.release }
      end
    end
  end
end