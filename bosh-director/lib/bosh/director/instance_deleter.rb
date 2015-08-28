module Bosh::Director
  # Coordinates the safe deletion of an instance and all associates resources.
  class InstanceDeleter
    include DnsHelper

    def initialize(deployment_plan, options={})
      @deployment_plan = deployment_plan
      @cloud = Config.cloud
      @logger = Config.logger
      @blobstore = App.instance.blobstores.blobstore

      @force = options.fetch(:force, false)
      @keep_snapshots_in_the_cloud = options.fetch(:keep_snapshots_in_the_cloud, false)
    end

    def delete_instance(instance, event_log_stage)
      @logger.info("Deleting instance '#{instance}'")

      event_log_stage.advance_and_track(instance.to_s) do
        error_ignorer.with_force_check do
          stop(instance)
        end

        instance_plan = DeploymentPlan::InstancePlan.create_from_deployment_plan_instance(instance)
        vm_deleter.delete_for_instance_plan(instance_plan, skip_disks: true)

        unless instance.model.compilation
          error_ignorer.with_force_check do
            delete_snapshots(instance.model)
          end

          error_ignorer.with_force_check do
            delete_persistent_disks(instance.model.persistent_disks)
          end

          error_ignorer.with_force_check do
            delete_dns(instance.job_name, instance.index)
          end

          error_ignorer.with_force_check do
            RenderedJobTemplatesCleaner.new(instance.model, @blobstore).clean_all
          end
        end

        release_network_reservations(instance)

        instance.model.destroy
      end
    end

    def delete_instances(instances, event_log_stage, options = {})
      max_threads = options[:max_threads] || Config.max_threads
      ThreadPool.new(:max_threads => max_threads).wrap do |pool|
        instances.each do |instance|
          pool.process { delete_instance(instance, event_log_stage) }
        end
      end
    end

    private

    def stop(instance)
      return if @skip_stop
      skip_drain = @deployment_plan.skip_drain_for_job?(instance.job_name)
      stopper = Stopper.new(instance, 'stopped', skip_drain, Config, @logger)
      stopper.stop
    end

    # FIXME: why do we hate dependency injection?
    def error_ignorer
      @error_ignorer ||= ErrorIgnorer.new(@force, @logger)
    end

    # FIXME: why do we hate dependency injection?
    def vm_deleter
      @vm_deleter ||= VmDeleter.new(@cloud, @logger, {force: @force})
    end

    def release_network_reservations(instance)
      instance.network_reservations.each do |reservation|
        @deployment_plan.ip_provider.release(reservation) if reservation.reserved?
      end
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

    def delete_snapshots(instance)
      snapshots = instance.persistent_disks.map { |disk| disk.snapshots }.flatten
      Bosh::Director::Api::SnapshotManager.delete_snapshots(snapshots, keep_snapshots_in_the_cloud: @keep_snapshots_in_the_cloud)
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
  end
end
