require_relative '../spec_helper'

describe 'cck vm extensions', type: :integration do
  let(:manifest) {Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups}
  let(:deployment_name) {manifest['name']}

  context 'when cloud config is updated after deploying' do
    with_reset_sandbox_before_each
    let(:cloud_config_hash) { Bosh::Spec::NewDeployments.simple_cloud_config }

    before do
      manifest['instance_groups'][0]['instances'] = 1
      manifest['instance_groups'][0]['vm_extensions'] = ['vm-extension-name']

      cloud_config_hash['vm_extensions'] = [{
        'name' => 'vm-extension-name',
        'cloud_properties' => {'my' => 'vm_extension_cloud_property'},
      }]

      deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest)

      create_vm_invocation = current_sandbox.cpi.invocations_for_method('create_vm').last
      expect(create_vm_invocation.inputs['cloud_properties']).to eq({'my' => 'vm_extension_cloud_property'}), 'failed during deploy'
      expect(current_sandbox.cpi.invocations_for_method('create_vm').count).to eq(3)
    end

    it 'recreates VMs with vm extensions' do
      current_sandbox.cpi.vm_cids.each do |vm_cid|
        current_sandbox.cpi.delete_vm(vm_cid)
      end

      bosh_runner.run('cloud-check --auto', deployment_name: 'simple')

      create_vm_invocation = current_sandbox.cpi.invocations_for_method('create_vm').last
      expect(current_sandbox.cpi.invocations_for_method('create_vm').count).to eq(4)
      expect(create_vm_invocation.inputs['cloud_properties']).to eq({'my' => 'vm_extension_cloud_property'}), 'failed after resurrection'
    end
  end
end
