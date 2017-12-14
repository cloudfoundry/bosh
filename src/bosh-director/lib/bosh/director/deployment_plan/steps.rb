module Bosh::Director
  module DeploymentPlan
    module Steps
    end
  end
end

require 'bosh/director/deployment_plan/steps/attach_disk_step'
require 'bosh/director/deployment_plan/steps/attach_instance_disks_step'
require 'bosh/director/deployment_plan/steps/detach_disk_step'
require 'bosh/director/deployment_plan/steps/detach_instance_disks_step'
require 'bosh/director/deployment_plan/steps/prepare_instance_step'
require 'bosh/director/deployment_plan/steps/render_instance_job_templates_step'
require 'bosh/director/deployment_plan/steps/unmount_disk_step'
require 'bosh/director/deployment_plan/steps/unmount_instance_disks_step'
require 'bosh/director/deployment_plan/steps/update_instance_settings_step'
require 'bosh/director/deployment_plan/steps/mount_disk_step'
