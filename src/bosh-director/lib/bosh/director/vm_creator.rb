require 'common/deep_copy'
require 'securerandom'

module Bosh::Director
  # Creates VM model and call out to CPI to create VM in IaaS
  class VmCreator
    include PasswordHelper

    def initialize(logger, template_blob_cache, dns_encoder, agent_broadcaster, link_provider_intents)
      @logger = logger
      @template_blob_cache = template_blob_cache
      @dns_encoder = dns_encoder
      @agent_broadcaster = agent_broadcaster
      @link_provider_intents = link_provider_intents

      @config_server_client_factory = Bosh::Director::ConfigServer::ClientFactory.create(@logger)
    end

    def create_for_instance_plans(instance_plans, ip_provider, tags = {})
      return @logger.info('No missing vms to create') if instance_plans.empty?

      total = instance_plans.size
      agendas = []
      instance_plans.each do |instance_plan|
        disks = [instance_plan.instance.model.managed_persistent_disk_cid].compact

        agendas << get_agenda_for_instance_plan(instance_plan, disks, tags, ip_provider, total)
      end

      StepExecutor.new('Creating missing vms', agendas).run
    end

    def create_for_instance_plan(instance_plan, ip_provider, disks, tags, use_existing = false)
      agenda = get_agenda_for_instance_plan(instance_plan, disks, tags, ip_provider, 1, use_existing)

      StepExecutor.new('Creating VM', [agenda], track: false).run
    end

    private

    def get_agenda_for_instance_plan(instance_plan, disks, tags, ip_provider, total, use_existing = false)
      instance_string = instance_plan.instance.model.to_s

      agenda = DeploymentPlan::Stages::Agenda.new.tap do |a|
        a.report = DeploymentPlan::Stages::Report.new.tap do |r|
          r.network_plans = instance_plan.network_plans
        end

        a.thread_name = "create_missing_vm(#{instance_string}/#{total})"
        a.info = 'Creating missing VM'
        a.task_name = instance_string
      end

      instance = instance_plan.instance
      already_had_active_vm = instance.vm_created?

      agenda.steps = [
        DeploymentPlan::Steps::CreateVmStep.new(
          instance_plan,
          @agent_broadcaster,
          disks,
          tags,
          use_existing,
        ),
      ]

      agenda.steps << DeploymentPlan::Steps::ElectActiveVmStep.new unless already_had_active_vm

      agenda.steps << DeploymentPlan::Steps::CommitInstanceNetworkSettingsStep.new

      agenda.steps << DeploymentPlan::Steps::ReleaseObsoleteNetworksStep.new(ip_provider) unless instance_plan.should_create_swap_delete?

      # TODO(mxu, cdutra): find cleaner way to express when you need to Attach and Mount the disk
      if instance_plan.needs_disk?
        if !instance_plan.should_create_swap_delete? || creating_first_create_swap_delete_vm?(instance_plan, already_had_active_vm)
          agenda.steps << DeploymentPlan::Steps::AttachInstanceDisksStep.new(instance.model, tags)
          agenda.steps << DeploymentPlan::Steps::MountInstanceDisksStep.new(instance.model)
        end
      end

      agenda.steps << DeploymentPlan::Steps::UpdateInstanceSettingsStep.new(instance_plan)
      agenda.steps << DeploymentPlan::Steps::ApplyVmSpecStep.new(instance_plan)
      agenda.steps << DeploymentPlan::Steps::RenderInstanceJobTemplatesStep.new(
        instance_plan,
        @template_blob_cache,
        @dns_encoder,
        @link_provider_intents,
      )

      agenda
    end

    def creating_first_create_swap_delete_vm?(instance_plan, already_had_active_vm)
      instance_plan.should_create_swap_delete? && !already_had_active_vm
    end
  end
end
