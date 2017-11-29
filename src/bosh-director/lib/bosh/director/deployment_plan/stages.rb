module Bosh::Director
  module DeploymentPlan
    module Stages
    end
  end
end

require 'bosh/director/deployment_plan/stages/cleanup_stemcell_references_stage'
require 'bosh/director/deployment_plan/stages/download_packages_stage'
require 'bosh/director/deployment_plan/stages/package_compile_stage'
require 'bosh/director/deployment_plan/stages/persist_deployment_stage'
require 'bosh/director/deployment_plan/stages/pre_cleanup_stage'
require 'bosh/director/deployment_plan/stages/setup_stage'
require 'bosh/director/deployment_plan/stages/update_active_vm_cpis_stage'
require 'bosh/director/deployment_plan/stages/update_errands_stage'
require 'bosh/director/deployment_plan/stages/update_jobs_stage'
require 'bosh/director/deployment_plan/stages/update_stage'
