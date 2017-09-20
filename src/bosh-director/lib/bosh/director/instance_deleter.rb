module Bosh::Director
  # Coordinates the safe deletion of an instance and all associates resources.
  class InstanceDeleter

    def initialize(ip_provider, powerdns_manager, disk_manager, options={})
      @ip_provider = ip_provider
      @powerdns_manager = powerdns_manager
      @disk_manager = disk_manager
      @logger = Config.logger
      encoder = LocalDnsEncoderManager.create_dns_encoder(false)
      @local_dns_manager = LocalDnsManager.create(Config.root_domain, @logger, encoder)

      @blobstore = App.instance.blobstores.blobstore
      @force = options.fetch(:force, false)
      @virtual_delete_vm = options.fetch(:virtual_delete_vm, false)
    end

    def delete_instance_plan(instance_plan, event_log_stage)
      instance_model = instance_plan.new? ? instance_plan.instance.model : instance_plan.existing_instance
      deployment_name = instance_model.deployment.name
      instance_name = instance_model.name
      parent_id = add_event(deployment_name, instance_name)
      event_log_stage.advance_and_track(instance_model.to_s) do
        error_ignorer.with_force_check do
          stop(instance_plan)
        end

        vm_deleter.delete_for_instance(instance_model)

        unless instance_model.compilation
          error_ignorer.with_force_check do
            @disk_manager.delete_persistent_disks(instance_model)
          end

          error_ignorer.with_force_check do
            @powerdns_manager.delete_dns_for_instance(instance_model)
          end

          error_ignorer.with_force_check do
            @local_dns_manager.delete_dns_for_instance(instance_model)
          end

          error_ignorer.with_force_check do
            RenderedJobTemplatesCleaner.new(instance_model, @blobstore, @logger).clean_all
          end
        end

        instance_plan.network_plans.each do |network_plan|
          reservation = network_plan.reservation
          @ip_provider.release(reservation) if reservation.reserved?
        end
        instance_plan.release_all_network_plans

        instance_model.destroy
      end
    rescue Exception => e
      raise e
    ensure
      add_event(deployment_name, instance_name, parent_id, e) if parent_id
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

    def add_event(deployment_name, instance_name, parent_id = nil, error = nil)
      event  = Config.current_job.event_manager.create_event(
          {
              parent_id:   parent_id,
              user:        Config.current_job.username,
              action:      'delete',
              object_type: 'instance',
              object_name: instance_name,
              task:        Config.current_job.task_id,
              deployment:  deployment_name,
              instance:    instance_name,
              error:       error
          })
      event.id
    end

    def stop(instance_plan)
      stopper = Stopper.new(instance_plan, 'stopped', Config, @logger)
      stopper.stop
    end

    # FIXME: why do we hate dependency injection?
    def error_ignorer
      @error_ignorer ||= ErrorIgnorer.new(@force, @logger)
    end

    # FIXME: why do we hate dependency injection?
    def vm_deleter
      @vm_deleter ||= VmDeleter.new(@logger, @force, @virtual_delete_vm)
    end
  end
end
