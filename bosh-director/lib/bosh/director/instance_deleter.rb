module Bosh::Director
  # Coordinates the safe deletion of an instance and all associates resources.
  class InstanceDeleter
    include DnsHelper

    def initialize(ip_provider, skip_drain_decider, options={})
      @ip_provider = ip_provider
      @skip_drain_decider = skip_drain_decider
      @cloud = Config.cloud
      @logger = Config.logger
      @blobstore = App.instance.blobstores.blobstore

      @force = options.fetch(:force, false)
      @keep_snapshots_in_the_cloud = options.fetch(:keep_snapshots_in_the_cloud, false)
    end

    def delete_instance(instance, event_log_stage)
      @logger.info("Deleting instance '#{instance}'")

      event_log_stage.advance_and_track(instance.to_s) do
        instance_plan = DeploymentPlan::InstancePlan.create_from_deployment_plan_instance(instance, @logger)

        error_ignorer.with_force_check do
          stop(instance_plan)
        end

        vm_deleter.delete_for_instance_plan(instance_plan, skip_disks: true)

        unless instance.model.compilation
          error_ignorer.with_force_check do
            delete_snapshots(instance.model)
          end

          error_ignorer.with_force_check do
            delete_persistent_disks(instance.model.persistent_disks)
          end

          error_ignorer.with_force_check do
            delete_dns(instance)
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

    def stop(instance_plan)
      skip_drain = @skip_drain_decider.for_job(instance_plan.instance.job_name) # FIXME: can we do something better?
      stopper = Stopper.new(instance_plan, 'stopped', skip_drain, Config, @logger)
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
      instance.desired_network_reservations.each do |reservation|
        @ip_provider.release(reservation) if reservation.reserved?
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

    def delete_dns(instance)
      if Config.dns_enabled?
        dns_domain = Models::Dns::Domain.find(
          :name => dns_domain_name,
          :type => 'NATIVE',
        )
        dns_domain_id = dns_domain.nil? ? nil : dns_domain.id
        delete_dns_records(record_pattern(instance.index, instance.job_name, instance.model.deployment.name), dns_domain_id)
        delete_dns_records(record_pattern(instance.uuid, instance.job_name, instance.model.deployment.name), dns_domain_id)
      end
    end

    def record_pattern(hostname, job_name, deployment_name)
      [ hostname,
        canonical(job_name),
        "%",
        canonical(deployment_name),
        dns_domain_name
      ].join(".")
    end
  end
end
