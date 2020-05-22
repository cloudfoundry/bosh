require 'bosh/director/rendered_job_templates_cleaner'

module Bosh::Director
  class InstanceUpdater
    MAX_RECREATE_ATTEMPTS = 3

    def self.new_instance_updater(ip_provider, template_blob_cache,
                                  dns_encoder, link_provider_intents, task)
      new(
        dns_state_updater: DirectorDnsStateUpdater.new,
        logger: Config.logger, ip_provider: ip_provider,
        blobstore: App.instance.blobstores.blobstore,
        vm_deleter: VmDeleter.new(false, Config.enable_virtual_delete_vms),
        vm_creator: vm_creator(dns_encoder, template_blob_cache,
                               link_provider_intents),
        disk_manager: disk_manager, task: task,
        rendered_templates_persistor: rendered_templates_persister
      )
    end

    def initialize(logger:,
                   ip_provider:,
                   blobstore:,
                   dns_state_updater:,
                   vm_deleter:,
                   vm_creator:,
                   disk_manager:,
                   rendered_templates_persistor:,
                   task:)
      @logger = logger
      @blobstore = blobstore
      @dns_state_updater = dns_state_updater
      @vm_deleter = vm_deleter
      @vm_creator = vm_creator
      @disk_manager = disk_manager
      @ip_provider = ip_provider
      @rendered_templates_persistor = rendered_templates_persistor
      @current_state = {}
      @task = task
    end

    def update(instance_plan, options = {})
      instance = instance_plan.instance
      @links_manager = Bosh::Director::Links::LinksManager.new(instance.deployment_model.links_serial_id)
      instance_report = DeploymentPlan::Stages::Report.new.tap { |r| r.vm = instance.model.active_vm }

      update_procedure = get_update_procedure(instance, instance_plan, options, instance_report)

      if instance_plan.changed?
        parent_id = add_event(instance.deployment_model.name,
                              update_procedure.action,
                              instance.model.name,
                              update_procedure.context)
      end
      @logger.info("Updating instance #{instance}, changes: #{instance_plan.changes.to_a.join(', ').inspect}")

      InstanceUpdater::InstanceState.with_instance_update_and_event_creation(
        instance.model,
        parent_id,
        instance.deployment_model.name,
        update_procedure.action,
        &update_procedure
      )
    end

    def needs_recreate?(instance_plan)
      if instance_plan.needs_shutting_down?
        @logger.debug('VM needs to be shutdown before it can be updated.')
        return true
      end

      false
    end

    private_class_method def self.rendered_templates_persister
      RenderedTemplatesPersister.new(
        App.instance.blobstores.blobstore, Config.logger
      )
    end

    private_class_method def self.disk_manager
      DiskManager.new(Config.logger)
    end

    private_class_method def self.vm_creator(dns_encoder, template_blob_cache,
                                             link_provider_intents)
      VmCreator.new(Config.logger, template_blob_cache,
                    dns_encoder, AgentBroadcaster.new,
                    link_provider_intents)
    end

    private

    def get_update_procedure(instance, instance_plan, options, instance_report)
      UpdateProcedure.new(
        instance,
        instance_plan,
        options,
        @blobstore,
        needs_recreate?(instance_plan),
        instance_report,
        @disk_manager,
        @rendered_templates_persistor,
        @vm_creator,
        @links_manager,
        @ip_provider,
        @dns_state_updater,
        @logger,
        @task,
      )
    end

    def add_event(deployment_name,
                  action, instance_name = nil,
                  context = nil,
                  parent_id = nil,
                  error = nil)
      event = Config.current_job.event_manager.create_event(
        parent_id: parent_id,
        user: Config.current_job.username,
        action: action,
        object_type: 'instance',
        object_name: instance_name,
        task: Config.current_job.task_id,
        deployment: deployment_name,
        instance: instance_name,
        error: error,
        context: context ? context : {},
      )
      event.id
    end
  end
end
