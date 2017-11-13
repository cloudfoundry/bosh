require_relative './integration_example_group'

module Bosh::Spec
  module BlockingDeployHelper
    extend IntegrationExampleGroup
    extend IntegrationSandboxHelpers

    def with_blocking_deploy(options={})
      first_deployment_manifest = Bosh::Spec::NetworkingManifest.deployment_manifest(name: 'blocking', instances: 1, job: 'job_with_blocking_compilation')
      task_id = Bosh::Spec::DeployHelper.start_deploy(first_deployment_manifest)

      director.wait_for_first_available_vm

      compilation_vm = director.vms.first
      expect(compilation_vm).to_not be_nil

      yield(task_id)

      task_id
    ensure
      if compilation_vm
        compilation_vm.unblock_package

        unless options[:skip_task_wait]
          _, first_success = Bosh::Spec::DeployHelper.wait_for_task(task_id)
          expect(first_success).to eq(true)
        end
      end
    end
  end
end
