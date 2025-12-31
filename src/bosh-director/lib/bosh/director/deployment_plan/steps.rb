module Bosh::Director
  module DeploymentPlan
    module Steps
    end
  end
end

require 'bosh/director/deployment_plan/steps/apply_vm_spec_step'
require 'bosh/director/deployment_plan/steps/attach_disk_step'
require 'bosh/director/deployment_plan/steps/attach_instance_disks_step'
require 'bosh/director/deployment_plan/steps/create_vm_step'
require 'bosh/director/deployment_plan/steps/commit_instance_network_settings_step'
require 'bosh/director/deployment_plan/steps/delete_vm_step'
require 'bosh/director/deployment_plan/steps/detach_disk_step'
require 'bosh/director/deployment_plan/steps/detach_dynamic_disk_step'
require 'bosh/director/deployment_plan/steps/detach_instance_disks_step'
require 'bosh/director/deployment_plan/steps/delete_dynamic_disk_step'
require 'bosh/director/deployment_plan/steps/elect_active_vm_step'
require 'bosh/director/deployment_plan/steps/mount_disk_step'
require 'bosh/director/deployment_plan/steps/mount_instance_disks_step'
require 'bosh/director/deployment_plan/steps/orphan_vm_step'
require 'bosh/director/deployment_plan/steps/prepare_instance_step'
require 'bosh/director/deployment_plan/steps/release_obsolete_networks_step'
require 'bosh/director/deployment_plan/steps/render_instance_job_templates_step'
require 'bosh/director/deployment_plan/steps/unmount_disk_step'
require 'bosh/director/deployment_plan/steps/unmount_instance_disks_step'
require 'bosh/director/deployment_plan/steps/update_instance_settings_step'
