require_relative '../spec_helper'
require 'fileutils'

describe 'deploy with hotswap', type: :integration do
  context 'a very simple deploy' do
    with_reset_sandbox_before_each

    let(:manifest) do
      manifest = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups(instances: 1)
      manifest['update'] = manifest['update'].merge({'strategy' => 'hot-swap'})
      manifest
    end

    before do
      cloud_config = Bosh::Spec::NewDeployments.simple_cloud_config
      cloud_config['networks'][0]['type'] = 'dynamic'

      manifest['instance_groups'][0]['networks'][0].delete('static_ips')
      deploy_from_scratch(manifest_hash: manifest, cloud_config_hash: cloud_config)
      deploy_simple_manifest(manifest_hash: manifest, recreate: true)
    end

    it 'should create vms that require recreation and download packages to them before updating' do
      output = bosh_runner.run('task 4')

      expect(output).to match(/Creating missing vms: foobar\/.*\n.*Downloading packages: foobar.*\n.*Updating instance foobar/)
    end

    it 'should show new vms in bosh vms command' do
      vms = table(bosh_runner.run('vms', json: true))

      expect(vms.length).to eq(2)

      vm_pattern = {
        'az' => '',
        'instance' => /foobar\/[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}/,
        'ips' => /[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/,
        'process_state' => 'running',
        'vm_cid' => /[0-9]{1,6}/,
        'vm_type' => 'a',
      }

      vm0 = vms[0]
      vm1 = vms[1]

      expect(vm0).to match(vm_pattern)
      expect(vm1).to match(vm_pattern)

      expect(vm0['az']).to eq(vm1['az'])
      expect(vm0['vm_type']).to eq(vm1['vm_type'])
      expect(vm0['instance']).to eq(vm1['instance'])
      expect(vm0['vm_cid']).to_not eq(vm1['vm_cid'])
      expect(vm0['process_state']).to eq(vm1['process_state'])
      expect(vm0['ips']).to_not eq(vm1['ips'])
    end
  end
end
