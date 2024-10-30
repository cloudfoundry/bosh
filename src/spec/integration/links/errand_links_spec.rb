require 'spec_helper'

describe 'Links in errands', type: :integration do
  with_reset_sandbox_before_each

  def upload_links_release
    FileUtils.cp_r(LINKS_RELEASE_TEMPLATE, ClientSandbox.links_release_dir, preserve: true)
    bosh_runner.run_in_dir('create-release --force', ClientSandbox.links_release_dir)
    bosh_runner.run_in_dir('upload-release', ClientSandbox.links_release_dir)
  end

  context 'when the errand is on a manual network and it contains a provider' do
    let(:cloud_config) do
      SharedSupport::DeploymentManifestHelper.simple_cloud_config.tap do |config|
        config['azs'] = [{ 'name' => 'z1' }]
        config['compilation']['az'] = 'z1'
        config['compilation']['network'] = 'manual-network'
        config['networks'] = [
          {
            'name' => 'manual-network',
            'type' => 'manual',
            'subnets' => [
              {
                'range' => '10.10.0.0/24',
                'gateway' => '10.10.0.1',
                'az' => 'z1',
              },
            ],
          },
          {
            'name' => 'vip-network',
            'type' => 'vip',
          },
          {
            'name' => 'dynamic-network',
            'type' => 'dynamic',
            'subnets' => [{ 'az' => 'z1' }],
          },
        ]
      end
    end

    let(:manifest) do
      SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups.tap do |manifest|
        manifest['instance_groups'] = [
          SharedSupport::DeploymentManifestHelper.simple_instance_group(
            name: 'first_ig',
            jobs: [{ 'name' => 'provider', 'release' => 'bosh-release' }],
            azs: ['z1'],
            instances: 1,
          ).tap do |ig|
            ig['lifecycle'] = 'errand'
            ig['networks'] = [{ 'name' => 'manual-network' }]
          end,
        ]
        manifest.delete('jobs')
      end
    end

    before do
      upload_links_release
      upload_stemcell

      upload_cloud_config(cloud_config_hash: cloud_config)
    end

    it 'should deploy successfully' do
      deploy_simple_manifest(manifest_hash: manifest)
    end

    context 'when the provider is shared' do
      let(:manifest) do
        SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups.tap do |manifest|
          manifest['instance_groups'] = [
            SharedSupport::DeploymentManifestHelper.simple_instance_group(
              name: 'first_ig',
              jobs: [{ 'name' => 'provider', 'release' => 'bosh-release', 'provides' => { 'provider' => { 'shared' => true } } }],
              azs: ['z1'],
              instances: 1,
            ).tap do |ig|
              ig['lifecycle'] = 'errand'
              ig['networks'] = [{ 'name' => 'manual-network' }]
            end,
          ]
          manifest.delete('jobs')
        end
      end

      it 'should fail the deploy' do
        _, code = deploy_simple_manifest(manifest_hash: manifest, failure_expected: true, return_exit_code: true)
        expect(code).to_not eq(0)
      end
    end

    context 'when the provider is consumed' do
      let(:manifest) do
        SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups.tap do |manifest|
          manifest['instance_groups'] = [
            SharedSupport::DeploymentManifestHelper.simple_instance_group(
              name: 'consuming_ig',
              jobs: [{ 'name' => 'consumer', 'release' => 'bosh-release', 'consumes' => { 'provider' => { 'from' => 'foo' } } }],
              azs: ['z1'],
              instances: 1,
            ).tap do |ig|
              ig['lifecycle'] = 'errand'
              ig['networks'] = [{ 'name' => 'manual-network' }]
            end,
            SharedSupport::DeploymentManifestHelper.simple_instance_group(
              name: 'first_ig',
              jobs: [{ 'name' => 'provider', 'release' => 'bosh-release', 'provides' => { 'provider' => { 'as' => 'foo' } } }],
              azs: ['z1'],
              instances: 1,
            ).tap do |ig|
              ig['lifecycle'] = 'errand'
              ig['networks'] = [{ 'name' => 'manual-network' }]
            end,
          ]
          manifest.delete('jobs')
        end
      end

      it 'should fail the deploy' do
        _, code = deploy_simple_manifest(manifest_hash: manifest, failure_expected: true, return_exit_code: true)
        expect(code).to_not eq(0)
      end
    end
  end
end
