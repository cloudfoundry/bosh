require 'spec_helper'
require 'fileutils'

describe 'Shutdown', type: :integration do
  with_reset_sandbox_before_each

  before do
    upload_cloud_config(cloud_config_hash: SharedSupport::DeploymentManifestHelper.simple_cloud_config)
    upload_stemcell
    create_and_upload_test_release
  end

  context 'when create swap delete is enabled', create_swap_delete: true do
    it 'shuts down orphaned vms' do
      manifest_deployment = SharedSupport::DeploymentManifestHelper.test_release_manifest_with_stemcell
      manifest_deployment['instance_groups'] = [
        SharedSupport::DeploymentManifestHelper.simple_instance_group(
          name: 'test-job',
          instances: 1,
        ),
      ]

      manifest_deployment['update'] = manifest_deployment['update'].merge('vm_strategy' => 'create-swap-delete')
      deploy_simple_manifest(manifest_hash: manifest_deployment)
      agent0 = director.instance('test-job', '0').agent_id

      manifest_deployment['instance_groups'].first['env'] = { 'bosh' => { 'password' => 'foobar' } }
      deploy_simple_manifest(manifest_hash: manifest_deployment)

      agent_log = File.read("#{current_sandbox.agent_tmp_path}/agent.#{agent0}.log")
      expect(agent_log).to include('Running sync action shutdown')
      expect(agent_log).to include('"method":"shutdown","arguments":[]')
    end
  end
end
