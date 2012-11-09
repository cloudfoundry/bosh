module Bosh::Director
  module LockHelper
    def with_deployment_lock(deployment, opts = {})
      if deployment.respond_to?(:name)
        name = deployment.name
      elsif deployment.kind_of?(String)
        name = deployment
      else
        raise ArgumentError, "invalid deployment: #{deployment}"
      end
      timeout = opts[:timeout] || 10
      Config.logger.info("Acquiring deployment lock on #{name}")
      Lock.new("lock:deployment:#{name}", :timeout => timeout).lock { yield }
    end

    def with_stemcell_lock(name, version, opts = {})
      timeout = opts[:timeout] || 10
      Config.logger.info("Acquiring deployment lock on #{name}:#{version}")
      Lock.new("lock:stemcells:#{name}:#{version}", :timeout => timeout).
          lock { yield }
    end

    def with_release_lock(release, opts = {})
      timeout = opts[:timeout] || 10
      Config.logger.info("Acquiring deployment lock on #{release}")
      Lock.new("lock:release:#{release}", :timeout => timeout).lock { yield }
    end

    def with_release_locks(deployment_plan, opts = {})
      timeout = opts[:timeout] || 10
      release_names = deployment_plan.releases.map do |release|
        release.name
      end

      # Sorting to enforce lock order to avoid deadlocks
      locks = release_names.sort.map do |release_name|
        Config.logger.info("Acquiring release lock: #{release_name}")
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