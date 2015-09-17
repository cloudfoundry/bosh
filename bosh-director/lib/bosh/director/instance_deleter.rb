module Bosh::Director
  # Coordinates the safe deletion of an instance and all associates resources.
  class InstanceDeleter
    include DnsHelper

    def initialize(deployment_plan)
      @deployment_plan = deployment_plan
      @cloud = Config.cloud
      @logger = Config.logger
      @blobstore = App.instance.blobstores.blobstore
    end

    # Deletes a list of instances
    # @param [Array<Models::Instance>] instances list of instances to delete
    # @param [Hash] options optional list of options controlling concurrency
    # @return [void]
    def delete_instances(instances, event_log_stage, options = {})
      max_threads = options[:max_threads] || Config.max_threads
      ThreadPool.new(:max_threads => max_threads).wrap do |pool|
        instances.each do |instance|
          pool.process { delete_instance(instance, event_log_stage) }
        end
      end
    end

    # Deletes a single instance and attached persistent disks
    # @param [Models::Instance] instance instance to delete
    # @return [void]
    def delete_instance(instance, event_log_stage)
      vm = instance.vm
      @logger.info("Delete unneeded instance: #{vm.cid}")

      event_log_stage.advance_and_track(vm.cid) do
        drain(vm.agent_id)
        @cloud.delete_vm(vm.cid)
        delete_snapshots(instance)
        delete_persistent_disks(instance.persistent_disks)
        delete_dns(instance.job, instance.index)

        RenderedJobTemplatesCleaner.new(instance, @blobstore, @logger).clean_all

        vm.db.transaction do
          instance.destroy
          vm.destroy
        end
      end
    end

    # Drain the instance
    # @param [String] agent_id agent id
    # @return [void]
    def drain(agent_id)
      agent = AgentClient.with_defaults(agent_id)

      drain_time = agent.drain("shutdown")
      while drain_time < 0
        drain_time = drain_time.abs
        begin
          Config.job_cancelled?
          @logger.info("Drain - check back in #{drain_time} seconds")
          sleep(drain_time)
          drain_time = agent.drain("status")
        rescue => e
          @logger.warn("Failed to check drain-status: #{e.inspect}")
          raise if e.kind_of?(Bosh::Director::TaskCancelled)
          break
        end
      end

      sleep(drain_time)
      agent.stop
    end

    def delete_snapshots(instance)
      snapshots = instance.persistent_disks.map { |disk| disk.snapshots }.flatten
      Bosh::Director::Api::SnapshotManager.delete_snapshots(snapshots)
    end

    # Delete persistent disks
    # @param [Array<Model::PersistentDisk>] persistent_disks disks
    # @return [void]
    def delete_persistent_disks(persistent_disks)
      persistent_disks.each do |disk|
        @logger.info("Deleting disk: `#{disk.disk_cid}', " +
                     "#{disk.active ? "active" : "inactive"}")
        begin
          @cloud.delete_disk(disk.disk_cid)
        rescue Bosh::Clouds::DiskNotFound => e
          @logger.warn("Disk not found: #{disk.disk_cid}")
          raise if disk.active
        end
        disk.destroy
      end
    end

    # Deletes the DNS records
    # @param [String] job job name
    # @param [Numeric] index job index
    # @return [void]
    def delete_dns(job, index)
      if Config.dns_enabled?
        record_pattern = [index, canonical(job), "%",
                          @deployment_plan.canonical_name, dns_domain_name].join(".")
        delete_dns_records(record_pattern, @deployment_plan.dns_domain.id)
      end
    end
  end
end
