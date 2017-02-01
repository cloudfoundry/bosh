require_relative '../spec_helper'

describe 'cck vm extensions', type: :integration do
  let(:manifest) {Bosh::Spec::Deployments.simple_manifest}
  let(:deployment_name) {manifest['name']}

  context 'when cloud config is updated after deploying' do
    with_reset_sandbox_before_each
    let(:cloud_config_hash) { Bosh::Spec::Deployments.simple_cloud_config }

    before do
      manifest['stemcells'] = [Bosh::Spec::Deployments.stemcell]
      manifest['jobs'][0]['instances'] = 1
      manifest['jobs'][0]['vm_type'] = 'vm-type-name'
      manifest['jobs'][0]['vm_extensions'] = ['vm-extension-name']
      manifest['jobs'][0].delete('resource_pool')
      manifest['jobs'][0]['stemcell'] = 'default'

      cloud_config_hash.delete('resource_pools')
      cloud_config_hash['vm_types'] = [{
        'name' => 'vm-type-name',
        'cloud_properties' => {'my' => 'vm_type_cloud_property'},
      }]
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
