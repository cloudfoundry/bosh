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
      instance = instance_plan.instance
      already_had_active_vm = instance.vm_created?
      instance_report = DeploymentPlan::Stages::Report.new
      instance_report.network_plans = instance_plan.network_plans

      DeploymentPlan::Steps::CreateVmStep.new(
        instance_plan,
        @agent_broadcaster,
        @vm_deleter,
        disks,
        tags,
        use_existing,
      ).perform(instance_report)

      unless already_had_active_vm
        DeploymentPlan::Steps::ElectActiveVmStep.new.perform(instance_report)
      end

      if instance_plan.needs_disk? && instance_plan.instance.strategy != DeploymentPlan::UpdateConfig::STRATEGY_HOT_SWAP
        DeploymentPlan::Steps::AttachInstanceDisksStep.new(instance.model, tags).perform(instance_report)
        DeploymentPlan::Steps::MountInstanceDisksStep.new(instance.model).perform(instance_report)
      end
      DeploymentPlan::Steps::UpdateInstanceSettingsStep.new(instance_plan.instance).perform(instance_report)

      # instance_report.vm = instance.model.active_vm
      DeploymentPlan::Steps::ApplyVmSpecStep.new(instance_plan).perform(instance_report)

      DeploymentPlan::Steps::RenderInstanceJobTemplatesStep.new(
        instance_plan,
        @template_blob_cache,
        @dns_encoder,
      ).perform(instance_report)

      DeploymentPlan::Steps::CommitInstanceNetworkSettingsStep.new.perform(instance_report)
    end
  end
end
