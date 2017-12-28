require 'common/deep_copy'
require 'securerandom'

module Bosh::Director
  # Creates VM model and call out to CPI to create VM in IaaS
  class VmCreator
    include PasswordHelper

    def initialize(logger, vm_deleter, template_blob_cache, dns_encoder, agent_broadcaster)
      @logger = logger
      @vm_deleter = vm_deleter
      @template_blob_cache = template_blob_cache
      @dns_encoder = dns_encoder
      @agent_broadcaster = agent_broadcaster

      @config_server_client_factory = Bosh::Director::ConfigServer::ClientFactory.create(@logger)
    end

    def create_for_instance_plans(instance_plans, ip_provider, tags={})
      return @logger.info('No missing vms to create') if instance_plans.empty?

      total = instance_plans.size
      event_log_stage = Config.event_log.begin_stage('Creating missing vms', total)
      ThreadPool.new(max_threads: Config.max_threads, logger: @logger).wrap do |pool|
        instance_plans.each do |instance_plan|
          instance = instance_plan.instance
          pool.process do
            with_thread_name("create_missing_vm(#{instance.model}/#{total})") do
              event_log_stage.advance_and_track(instance.model.to_s) do
                @logger.info('Creating missing VM')
                disks = [instance.model.managed_persistent_disk_cid].compact
                create_for_instance_plan(instance_plan, disks, tags)
                instance_plan.release_obsolete_network_plans(ip_provider)
              end
            end
          end
        end
      end
    end

    def create_for_instance_plan(instance_plan, disks, tags, use_existing=false)
      DeploymentPlan::Steps::CreateVmStep.new(
        instance_plan,
        @agent_broadcaster,
        @vm_deleter,
        disks,
        tags, # definitely d on't need to put these tags here, because they come off the instance plan
        use_existing,
      ).perform

      instance = instance_plan.instance

      unless instance.vm_created?
        DeploymentPlan::Steps::ElectActiveVmStep.new(instance.model.most_recent_inactive_vm).perform
      end

      begin
        if instance_plan.needs_disk?
          DeploymentPlan::Steps::AttachInstanceDisksStep.new(instance.model, tags).perform
          DeploymentPlan::Steps::MountInstanceDisksStep.new(instance.model).perform
        end
        DeploymentPlan::Steps::UpdateInstanceSettingsStep.new(instance_plan.instance, instance.model.active_vm).perform
      rescue Exception => e
        # cleanup in case of failure
        @logger.error("Failed to create/contact VM #{instance.model.vm_cid}: #{e.inspect}")
        # TODO: what is appropriate response to this error case ? orphan ?
        if Config.keep_unreachable_vms
          @logger.info('Keeping the VM for debugging')
        else
          @vm_deleter.delete_for_instance(instance.model)
        end
        raise e
      end

      # use a STANDARD way to get the "new vm" off the instance

      vm = instance.model.active_vm
      # apply initial state (collection of steps)
      apply_initial_vm_state(instance_plan, vm)

      # def perform
      #   vm = @instance_plan.instance.most_recent_inactive_vm
      #   apply_initial_vm_state(instance_plan, vm)
      # end

      # update instance_plan state
      # per story task, move this to where we activate the vm





      instance_plan.mark_desired_network_plans_as_existing
    end

    private

    def apply_initial_vm_state(instance_plan, vm)
      vm_state = DeploymentPlan::VmSpecApplier.new.apply_initial_vm_state(instance_plan.spec, vm)

      instance_plan.instance.add_state_to_model(vm_state)

      DeploymentPlan::Steps::RenderInstanceJobTemplatesStep.new(instance_plan, blob_cache: @template_blob_cache, dns_encoder: @dns_encoder).perform
    end
  end
end
