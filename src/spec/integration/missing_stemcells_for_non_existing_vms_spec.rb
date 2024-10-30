require 'spec_helper'

describe 'missing stemcells for non existing vms', type: :integration do
  let(:manifest_hash) { SharedSupport::DeploymentManifestHelper.manifest_with_errand }
  let(:deployment_name) { manifest_hash['name'] }

  context 'when errand script exits with 0 exit code' do
    with_reset_sandbox_before_each

    it 'returns 0 as exit code from the cli and indicates that errand ran successfully' do
      manifest = SharedSupport::DeploymentManifestHelper.manifest_with_errand
      deploy_from_scratch(
        manifest_hash: manifest,
        cloud_config_hash: SharedSupport::DeploymentManifestHelper.simple_cloud_config,
      )

      _, exit_code = bosh_runner.run(
        'run-errand fake-errand-name',
        return_exit_code: true,
        json: true,
        deployment_name: 'errand',
      )

      expect(exit_code).to eq(0)

      upload_stemcell_2
      manifest['stemcells'] = [
        {
          'alias' => 'default',
          'os' => 'toronto-centos',
          'version' => 'latest',
        },
      ]
      deploy_simple_manifest(
        manifest_hash: manifest,
        cloud_config_hash: SharedSupport::DeploymentManifestHelper.simple_cloud_config,
      )

      bosh_runner.run('clean-up --all')

      manifest['instance_groups'].pop

      # this should not fail with missing stemcell
      deploy_simple_manifest(
        manifest_hash: manifest,
        cloud_config_hash: SharedSupport::DeploymentManifestHelper.simple_cloud_config,
      )
    end
  end
end
