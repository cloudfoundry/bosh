module Bosh::Director
  # Coordinates the safe deletion of an instance and all associates resources.
  class InstanceDeleter
    include DnsHelper

    def initialize(ip_provider, skip_drain_decider, dns_manager, options={})
      @ip_provider = ip_provider
      @skip_drain_decider = skip_drain_decider
      @dns_manager = dns_manager
      @cloud = Config.cloud
      @logger = Config.logger
      @blobstore = App.instance.blobstores.blobstore

      @force = options.fetch(:force, false)
      @keep_snapshots_in_the_cloud = options.fetch(:keep_snapshots_in_the_cloud, false)
    end

    def delete_instance_plan(instance_plan, event_log_stage)
      delete_instance(instance_plan.instance, instance_plan, event_log_stage)

      instance_plan.release_all_ips
    end

    def delete_instance(instance, instance_plan, event_log_stage)
      @logger.info("Deleting instance '#{instance.inspect}'")

      event_log_stage.advance_and_track(instance.to_s) do

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
            @dns_manager.delete_dns_for_instance(instance.model)
          end

          error_ignorer.with_force_check do
            RenderedJobTemplatesCleaner.new(instance.model, @blobstore).clean_all
          end
        end

        instance_plan.release_all_ips

        instance.model.destroy
      end
    end

    def delete_instances(instances, event_log_stage, options = {})
      max_threads = options[:max_threads] || Config.max_threads
      ThreadPool.new(:max_threads => max_threads).wrap do |pool|
        instances.each do |instance|
          pool.process do
            # FIXME: We should not be relying on type checking. Can we do some of this logic in the caller?
            if instance.is_a?(Models::Instance)
              instance_plan = DeploymentPlan::InstancePlan.new(
                existing_instance: instance,
                instance: DeploymentPlan::InstanceFromDatabase.create_from_model(instance, @logger),
                desired_instance: DeploymentPlan::DesiredInstance.new,
                network_plans: []
              )
              instance = DeploymentPlan::InstanceFromDatabase.create_from_model(instance, @logger)
             else
              instance_plan = DeploymentPlan::InstancePlan.new(
                existing_instance: instance.model,
                instance: instance,
                desired_instance: DeploymentPlan::DesiredInstance.new,
                network_plans: []
              )
            end
            delete_instance(instance, instance_plan, event_log_stage)
          end
        end
      end
    end

    def delete_instance_plans(instance_plans, event_log_stage, options = {})
      max_threads = options[:max_threads] || Config.max_threads
      ThreadPool.new(:max_threads => max_threads).wrap do |pool|
        instance_plans.each do |instance_plan|
          pool.process { delete_instance_plan(instance_plan, event_log_stage) }
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
  end
end
