module Bosh::Director
  # Coordinates the safe deletion of an instance and all associates resources.
  class InstanceDeleter
    include DnsHelper

    def initialize(deployment_plan)
      @deployment_plan = deployment_plan
      @cloud = Config.cloud
      @logger = Config.logger
    end

    # Deletes a list of instances
    # @param [Array<Models::Instance>] instances list of instances to delete
    # @param [Hash] options optional list of options controlling concurrency
    # @return [void]
    def delete_instances(instances, options = {})
      # TODO: make default externally configurable?
      max_threads = options[:max_threads] || 10
      ThreadPool.new(:max_threads => max_threads).wrap do |pool|
        instances.each do |instance|
          pool.process { delete_instance(instance) }
        end
      end
    end

    # Deletes a single instance and attached persistent disks
    # @param [Models::Instance] instance instance to delete
    # @return [void]
    def delete_instance(instance)
      vm = instance.vm
      @logger.info("Delete unneeded instance: #{vm.cid}")

      drain(vm.agent_id)
      @cloud.delete_vm(vm.cid)
      delete_persistent_disks(instance.persistent_disks)
      delete_dns_records(instance.job, instance.index)

      vm.db.transaction do
        instance.destroy
        vm.destroy
      end
    end

    # Drain the instance
    # @param [String] agent_id agent id
    # @return [void]
    def drain(agent_id)
      agent = AgentClient.new(agent_id)
      drain_time = agent.drain("shutdown")
      sleep(drain_time)
      agent.stop
    end

    # Delete persistent disks
    # @param [Array<Model::PersistentDisk>] persistent_disks disks
    # @return [void]
    def delete_persistent_disks(persistent_disks)
      persistent_disks.each do |disk|
        @logger.info("Deleting disk: '#{disk.disk_cid}', #{disk.active ? "active" : "inactive"}")
        begin
          @cloud.delete_disk(disk.disk_cid)
        rescue Bosh::Clouds::DiskNotFound => e
          @logger.warn("Disk not found: #{disk.disk_cid}")
          # TODO: investigate if we really want to swallow this for inactive disks
          raise if disk.active
        end
        disk.destroy
      end
    end

    # Deletes the DNS records
    # @param [String] job job name
    # @param [Numeric] index job index
    # @return [void]
    def delete_dns_records(job, index)
      if Config.dns_enabled?
        record_pattern = [index, canonical(job), "%", @deployment_plan.canonical_name, "bosh"].join(".")
        records = Models::Dns::Record.filter(:domain_id => @deployment_plan.dns_domain.id).
            filter(:name.like(record_pattern))
        records.each do |record|
          @logger.info("Deleting DNS record: #{record.name}")
          record.destroy
        end
      end
    end

  end
end
