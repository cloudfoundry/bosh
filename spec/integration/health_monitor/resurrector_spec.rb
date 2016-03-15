require 'spec_helper'

describe 'resurrector', type: :integration, hm: true do
  with_reset_sandbox_before_each

  before do
    current_sandbox.health_monitor_process.start

    target_and_login
    create_and_upload_test_release
    upload_stemcell
  end

  after { current_sandbox.health_monitor_process.stop }

  let(:cloud_config_hash) do
    cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
    # remove size from resource pools due to bug #94220432
    # where resource pools with specified size reserve extra IPs
    cloud_config_hash['resource_pools'].first.delete('size')

    cloud_config_hash['networks'].first['subnets'].first['static'] =  ['192.168.1.10', '192.168.1.11']
    cloud_config_hash
  end

  let(:simple_manifest) do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['jobs'].first['instances'] = 1
    manifest_hash
  end

  context 'when we have legacy deployments deployed' do
    let(:legacy_manifest) do
      legacy_manifest = Bosh::Spec::Deployments.legacy_manifest
      legacy_manifest['jobs'].first['instances'] = 1
      legacy_manifest['resource_pools'].first.delete('size')
      legacy_manifest
    end

    it 'resurrects vms with old deployment ignoring cloud config' do
      deploy_simple_manifest(manifest_hash: legacy_manifest)
      vms = director.vms
      expect(vms.size).to eq(1)
      expect(vms.first.ips).to eq('192.168.1.2')

      cloud_config_hash['networks'].first['subnets'].first['reserved'] = ['192.168.1.2']
      upload_cloud_config(cloud_config_hash: cloud_config_hash)

      original_vm = director.vm('foobar', '0')
      original_vm.kill_agent
      resurrected_vm = director.wait_for_vm('foobar', '0', 300)
      expect(resurrected_vm.cid).to_not eq(original_vm.cid)
      vms = director.vms
      expect(vms.size).to eq(1)
      expect(vms.first.ips).to eq('192.168.1.2')
    end
  end
end
