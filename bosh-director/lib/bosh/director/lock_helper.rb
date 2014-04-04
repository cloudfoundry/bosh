module Bosh::Director
  # Helper for managing BOSH locks.
  module LockHelper

    # Surround with deployment lock.
    #
    # @param [DeploymentPlan|String] deployment plan or name.
    # @option opts [Number] timeout how long to wait before giving up
    # @return [void]
    # @yield [void] block to surround
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

    # Surround with stemcell lock.
    #
    # @param [String] name stemcell name.
    # @param [String] version stemcell version.
    # @option opts [Number] timeout how long to wait before giving up
    # @return [void]
    # @yield [void] block to surround
    def with_stemcell_lock(name, version, opts = {})
      timeout = opts[:timeout] || 10
      Config.logger.info("Acquiring stemcell lock on #{name}:#{version}")
      Lock.new("lock:stemcells:#{name}:#{version}", :timeout => timeout).
          lock { yield }
    end

    # Surround with release lock.
    #
    # @param [String] release name.
    # @option opts [Number] timeout how long to wait before giving up
    # @return [void]
    # @yield [void] block to surround
    def with_release_lock(release, opts = {})
      timeout = opts[:timeout] || 10
      Config.logger.info("Acquiring release lock on #{release}")
      Lock.new("lock:release:#{release}", :timeout => timeout).lock { yield }
    end

    # Surround with deployment releases lock.
    #
    # @param [DeploymentPlan] deployment plan.
    # @option opts [Number] timeout how long to wait before giving up
    # @return [void]
    # @yield [void] block to surround
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

    # Surround with compile lock.
    #
    # @param [String|Number] package_id package id.
    # @param [String|Number] stemcell_id stemcell id.
    # @option opts [Number] timeout how long to wait before giving up
    # @return [void]
    # @yield [void] block to surround
    def with_compile_lock(package_id, stemcell_id, opts = {})
      timeout = opts[:timeout] || 15 * 60 # 15 minutes

      Config.logger.info("Acquiring compile lock on " +
                             "#{package_id} #{stemcell_id}")
      Lock.new("lock:compile:#{package_id}:#{stemcell_id}",
               :timeout => timeout).lock { yield }
    end
  end
end
