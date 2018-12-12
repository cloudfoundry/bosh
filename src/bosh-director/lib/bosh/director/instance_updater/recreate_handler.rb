module Bosh::Director
  class InstanceUpdater
    class RecreateHandler
      attr_reader :instance, :instance_plan, :instance_report, :new_vm, :instance_model, :deleted_vm, :deleted_vm_id
      def initialize(logger, vm_creator, ip_provider, instance_plan, instance_report, instance)
        @logger = logger
        @vm_creator = vm_creator
        @ip_provider = ip_provider
        @instance_plan = instance_plan
        @instance_report = instance_report
        @did_delete_vm = false
        @deleted_vm_id = -1
        @instance_model = instance_plan.instance.model
        @new_vm = instance_model.most_recent_inactive_vm || instance_model.active_vm
        @instance = instance
      end

      def perform
        @logger.debug('Failed to update in place. Recreating VM')
        if instance_plan.unresponsive_agent?
          delete_unresponsive_vm
        else
          detach_disks
        end

        if any_create_swap_delete_vms?
          elect_active_vm

          orphan_inactive_vms

          attach_disks if instance_plan.needs_disk?

          instance.update_instance_settings
        else
          delete_vm unless did_delete_vm?

          create_vm
        end
      end

      private

      def delete_vm
        DeploymentPlan::Steps::DeleteVmStep
          .new(true, false, Config.enable_virtual_delete_vms)
          .perform(instance_report)
      end

      def detach_disks
        DeploymentPlan::Steps::UnmountInstanceDisksStep.new(instance_model).perform(instance_report)
        DeploymentPlan::Steps::DetachInstanceDisksStep.new(instance_model).perform(instance_report)
      end

      def attach_disks
        DeploymentPlan::Steps::AttachInstanceDisksStep.new(instance_model, instance_plan.tags).perform(instance_report)
        DeploymentPlan::Steps::MountInstanceDisksStep.new(instance_model).perform(instance_report)
      end

      def orphan_inactive_vms
        inactive_vms.each do |inactive_vm|
          ips = inactive_vm.ip_addresses.map(&:address_str)
          DeploymentPlan::Steps::OrphanVmStep.new(inactive_vm).perform(instance_report)
          instance_plan.remove_obsolete_network_plans_for_ips(ips)
        end
      end

      def inactive_vms
        instance_model.vms.reject { |vm| vm.id == new_vm.id || vm.id == deleted_vm_id }
      end

      def elect_active_vm
        instance_report.vm = new_vm
        DeploymentPlan::Steps::ElectActiveVmStep.new.perform(instance_report)
        instance_report.vm = instance_model.active_vm
      end

      def active_persistent_disk_cids
        instance_model.active_persistent_disks.collection
                      .map(&:model)
                      .map(&:disk_cid).compact
      end

      def create_vm
        @vm_creator.create_for_instance_plan(
          instance_plan,
          @ip_provider,
          active_persistent_disk_cids,
          instance_plan.tags,
        )
      end

      def did_delete_vm?
        @did_delete_vm
      end

      def delete_unresponsive_vm
        @deleted_vm_id = instance_report.vm.id
        @did_delete_vm = true

        delete_vm
      end

      def any_create_swap_delete_vms?
        instance_plan.should_create_swap_delete? && instance_model.vms.count > 1
      end
    end
  end
end
