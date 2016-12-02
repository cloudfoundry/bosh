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
      Config.logger.info("Acquiring stemcell lock on #{name}:#{version}")
      Lock.new("lock:stemcells:#{name}:#{version}", :timeout => timeout).
          lock { yield }
    end

    def with_release_lock(release_name, opts = {})
      with_release_locks([release_name], opts) { yield }
    end

    def with_release_locks(release_names, opts = {})
      timeout = opts[:timeout] || 10
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

    def with_compile_lock(package_id, stemcell_id, opts = {})
      timeout = opts[:timeout] || 15 * 60 # 15 minutes

      Config.logger.info("Acquiring compile lock on " +
                             "#{package_id} #{stemcell_id}")
      Lock.new("lock:compile:#{package_id}:#{stemcell_id}",
               :timeout => timeout).lock { yield }
    end
  end
end
