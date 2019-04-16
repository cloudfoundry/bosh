require 'spec_helper'

# TODO: Remove test when done removing v1 manifest support
xdescribe 'legacy deployment', type: :integration do
  with_reset_sandbox_before_each

  let(:legacy_manifest_hash) do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest.merge(Bosh::Spec::Deployments.simple_cloud_config)
    manifest_hash['resource_pools'].find { |i| i['name'] == 'a' }['size'] = 5
    manifest_hash
  end

  before do
    create_and_upload_test_release
    upload_stemcell
  end

  context 'when a cloud config is uploaded' do
    it 'ignores the cloud config and deploys legacy style' do
      cloud_config_hash = Bosh::Spec::NewDeployments.simple_cloud_config

      upload_cloud_config(cloud_config_hash: cloud_config_hash)
      output = deploy_simple_manifest(manifest_hash: legacy_manifest_hash)
      expect(output).not_to include('Deployment manifest should not contain cloud config properties')
      expect_running_vms_with_names_and_count('foobar' => 3)
      expect_table('deployments', [
                     {
                       'name' => Bosh::Spec::Deployments::DEFAULT_DEPLOYMENT_NAME,
                       'release_s' => 'bosh-release/0+dev.1',
                       'stemcell_s' => 'ubuntu-stemcell/1',
                       'team_s' => '',
                     },
                   ])
    end
  end

  context 'when deploying v1 after uploaded cloud config and having one stale deployment' do
    let!(:test_release_manifest) { Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups }

    it 'ignores cloud config, fails to allocate already taken ips' do
      deploy_simple_manifest(manifest_hash: legacy_manifest_hash)

      cloud_config_hash = Bosh::Spec::NewDeployments.simple_cloud_config
      upload_cloud_config(cloud_config_hash: cloud_config_hash)
      output = deploy_simple_manifest(manifest_hash: test_release_manifest)
      expect(output).not_to include("Ignoring cloud config. Manifest contains 'network' section")

      legacy_manifest = legacy_manifest_hash
      legacy_manifest['name'] = 'simple_2'
      output, exit_code = deploy_simple_manifest(manifest_hash: legacy_manifest, return_exit_code: true, failure_expected: true)
      expect(exit_code).to_not eq(0)
      expect(exit_code).to_not eq(nil)

      expect(output).to match(/IP Address \d+\.\d+\.\d+\.\d+ in network '.*?' is already in use/)
    end
  end

  context 'when no cloud config is uploaded' do
    it 'respects the cloud related configurations in the deployment manifest' do
      deploy_simple_manifest(manifest_hash: legacy_manifest_hash)

      expect_running_vms_with_names_and_count('foobar' => 3)
      expect_table('deployments', [
                     {
                       'name' => Bosh::Spec::Deployments::DEFAULT_DEPLOYMENT_NAME,
                       'release_s' => 'bosh-release/0+dev.1',
                       'stemcell_s' => 'ubuntu-stemcell/1',
                       'team_s' => '',
                     },
                   ])
    end
  end
end
