require 'spec_helper'

describe 'cli: locks', type: :integration do
  include Bosh::Spec::BlockingDeployHelper
  with_reset_sandbox_before_each

  context 'when a previous task fails' do
    it 'returns no locks' do
      prepare_for_deploy

      manifest = Bosh::Spec::NetworkingManifest.deployment_manifest(name: 'blocking', instances: 1, template: 'job_with_blocking_compilation')
      Bosh::Spec::DeployHelper.start_deploy(manifest)

      director.wait_for_first_available_vm

      expect(bosh_runner.run('locks')).to match(/\s*\|\s*deployment\s*\|\s*blocking\s*\|/)

      current_sandbox.director_service.hard_stop
      current_sandbox.director_service.start(current_sandbox.director_config)

      waiter.wait(10) {expect(bosh_runner.run('locks')).to match /No locks/}
    end
  end
end
