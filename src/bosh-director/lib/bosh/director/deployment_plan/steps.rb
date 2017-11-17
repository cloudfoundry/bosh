module Bosh::Director
  module DeploymentPlan
    module Steps
    end
  end
end

require 'bosh/director/deployment_plan/steps/cleanup_stemcell_references_step'
require 'bosh/director/deployment_plan/steps/download_packages_step'
require 'bosh/director/deployment_plan/steps/package_compile_step'
require 'bosh/director/deployment_plan/steps/persist_deployment_step'
require 'bosh/director/deployment_plan/steps/pre_cleanup_step'
require 'bosh/director/deployment_plan/steps/prepare_instance_step'
require 'bosh/director/deployment_plan/steps/setup_step'
require 'bosh/director/deployment_plan/steps/update_active_vm_cpis_step'
require 'bosh/director/deployment_plan/steps/update_errands_step'
require 'bosh/director/deployment_plan/steps/update_jobs_step'
require 'bosh/director/deployment_plan/steps/update_step'
