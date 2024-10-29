require 'spec_helper'

describe 'cli: cloudcheck', type: :integration do
  let(:manifest) { Bosh::Spec::DeploymentManifestHelper.simple_manifest_with_instance_groups }
  let(:director_name) { current_sandbox.director_name }
  let(:deployment_name) { manifest['name'] }
  let(:runner) { bosh_runner_in_work_dir(ClientSandbox.test_release_dir) }

  def prepend_namespace(key)
    "/#{director_name}/#{deployment_name}/#{key}"
  end

  context 'with dns enabled' do
    with_reset_sandbox_before_each

    let(:num_instances) { 3 }

    before do
      bosh_runner.run("upload-stemcell #{asset_path('valid_stemcell_with_api_version.tgz')}")
      upload_cloud_config(cloud_config_hash: Bosh::Spec::DeploymentManifestHelper.simple_cloud_config)
      create_and_upload_test_release

      manifest['instance_groups'][0]['persistent_disk'] = 100
      manifest['instance_groups'][0]['instances'] = num_instances

      deploy(manifest_hash: manifest)

      expect(runner.run('cloud-check --report', deployment_name: 'simple')).to match(regexp('0 problems'))
    end

    context 'when deployment uses an old cloud config' do
      let(:initial_cloud_config) do
        cloud_config = Bosh::Spec::DeploymentManifestHelper.simple_cloud_config_with_multiple_azs
        cloud_config['vm_types'][0]['cloud_properties']['stage'] = 'before'
        cloud_config
      end

      let(:new_cloud_config) do
        cloud_config = Bosh::Spec::DeploymentManifestHelper.simple_cloud_config_with_multiple_azs
        cloud_config['azs'].pop
        cloud_config['networks'][0]['subnets'].pop
        cloud_config['vm_types'][0]['cloud_properties']['stage'] = 'after'
        cloud_config
      end

      let(:deployment_manifest) do
        manifest = Bosh::Spec::DeploymentManifestHelper.simple_manifest_with_instance_groups
        manifest['instance_groups'][0]['azs'] = %w[z1 z2]
        manifest['instance_groups'][0]['instances'] = 2
        manifest
      end

      it 'reuses the old config on update', hm: false do
        upload_cloud_config(cloud_config_hash: initial_cloud_config)
        create_and_upload_test_release
        upload_stemcell

        deploy_simple_manifest(manifest_hash: deployment_manifest)

        upload_cloud_config(cloud_config_hash: new_cloud_config)

        current_sandbox.cpi.vm_cids.each do |cid|
          current_sandbox.cpi.delete_vm(cid)
        end

        bosh_runner.run('cloud-check --auto', deployment_name: 'simple')

        expect_table(
          'deployments',
          [{
            'name' => 'simple',
            'release_s' => 'bosh-release/0+dev.1',
            'stemcell_s' => 'ubuntu-stemcell/1',
            'team_s' => '',
          }],
        )
        expect(current_sandbox.cpi.invocations_for_method('create_vm').last.inputs['cloud_properties']['stage']).to eq('before')
      end
    end
  end
end
