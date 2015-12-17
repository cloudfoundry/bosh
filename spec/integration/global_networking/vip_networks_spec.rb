require 'spec_helper'

describe 'vip networks', type: :integration do
  with_reset_sandbox_before_each

  before do
    target_and_login
    create_and_upload_test_release
    upload_stemcell
  end

  let(:cloud_config_hash) do
    cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
    cloud_config_hash['networks'] << {
      'name' => 'vip-network',
      'type' => 'vip',
      'static_ips' => ['69.69.69.69'],
    }
    cloud_config_hash
  end

  let(:simple_manifest) do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['jobs'].first['instances'] = 1
    manifest_hash['jobs'].first['networks'] = [
      {'name' => cloud_config_hash['networks'].first['name'], 'default' => ['dns', 'gateway']},
      {'name' => 'vip-network', 'static_ips' => ['69.69.69.69']}
    ]
    manifest_hash
  end

  let(:updated_simple_manifest) do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['jobs'].first['instances'] = 2
    manifest_hash['jobs'].first['networks'] = [
      {'name' => cloud_config_hash['networks'].first['name'], 'default' => ['dns', 'gateway']},
      {'name' => 'vip-network', 'static_ips' => ['68.68.68.68', '69.69.69.69']}
    ]
    manifest_hash
  end

  it 'reuses instance vip network IP on subsequent deploy' do
    upload_cloud_config(cloud_config_hash: cloud_config_hash)
    deploy_simple_manifest(manifest_hash: simple_manifest)
    original_vms = director.vms
    expect(original_vms.size).to eq(1)
    expect(original_vms.first.ips).to eq(['192.168.1.2', '69.69.69.69'])

    cloud_config_hash['networks'][1]['static_ips'] = ['68.68.68.68', '69.69.69.69']
    upload_cloud_config(cloud_config_hash: cloud_config_hash)
    deploy_simple_manifest(manifest_hash: updated_simple_manifest)
    new_vms = director.vms
    expect(new_vms.size).to eq(2)
    vm_with_original_vip_ip = new_vms.find { |new_vm| new_vm.ips.include?('69.69.69.69') }
    expect(vm_with_original_vip_ip.instance_uuid).to eq(original_vms.first.instance_uuid)
  end
end
