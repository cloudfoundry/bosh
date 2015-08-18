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

    def delete_instances(instances, event_log_stage, options = {})
      max_threads = options[:max_threads] || Config.max_threads
      ThreadPool.new(:max_threads => max_threads).wrap do |pool|
        instances.each do |instance|
          pool.process { delete_instance(instance, event_log_stage) }
        end
      end
    end

    def drain(vm)
      agent = AgentClient.with_vm(vm)

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

    def delete_dns(job, index)
      if Config.dns_enabled?
        record_pattern = [
          index,
          canonical(job),
          "%",
          @deployment_plan.canonical_name,
          dns_domain_name
        ].join(".")
        delete_dns_records(record_pattern, @deployment_plan.dns_domain.id)
      end
    end

    private

    def delete_instance(instance, event_log_stage)
      vm_model = instance.model.vm
      @logger.info("Delete unneeded instance '#{instance}'")

      event_log_stage.advance_and_track(instance.to_s) do
        drain(vm_model) unless instance.model.compilation || vm_model.nil?

        vm_deleter.delete_for_instance(instance, skip_disks: true)

        unless instance.model.compilation
          delete_snapshots(instance.model)
          delete_persistent_disks(instance.model.persistent_disks)
          delete_dns(instance.job_name, instance.index)
          RenderedJobTemplatesCleaner.new(instance.model, @blobstore).clean_all
        end

        instance.delete
      end
    end

    def vm_deleter
      @vm_deleter ||= VmDeleter.new(@cloud, @logger)
    end
  end
end
