require_relative '../../spec_helper'

describe 'vip networks', type: :integration do
  with_reset_sandbox_before_each

  before do
    create_and_upload_test_release
    upload_stemcell
  end

  let(:cloud_config_hash) do
    cloud_config_hash = Bosh::Spec::NewDeployments.simple_cloud_config
    cloud_config_hash['networks'] << {
      'name' => 'vip-network',
      'type' => 'vip',
      'static_ips' => ['69.69.69.69'],
    }
    cloud_config_hash
  end

  let(:simple_manifest) do
    manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
    manifest_hash['instance_groups'].first['instances'] = 1
    manifest_hash['instance_groups'].first['networks'] = [
      {'name' => cloud_config_hash['networks'].first['name'], 'default' => ['dns', 'gateway']},
      {'name' => 'vip-network', 'static_ips' => ['69.69.69.69']}
    ]
    manifest_hash
  end

  let(:updated_simple_manifest) do
    manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
    manifest_hash['instance_groups'].first['instances'] = 2
    manifest_hash['instance_groups'].first['networks'] = [
      {'name' => cloud_config_hash['networks'].first['name'], 'default' => ['dns', 'gateway']},
      {'name' => 'vip-network', 'static_ips' => ['68.68.68.68', '69.69.69.69']}
    ]
    manifest_hash
  end

  it 'reuses instance vip network IP on subsequent deploy' do
    upload_cloud_config(cloud_config_hash: cloud_config_hash)
    deploy_simple_manifest(manifest_hash: simple_manifest)
    original_instances = director.instances
    expect(original_instances.size).to eq(1)
    expect(original_instances.first.ips).to eq(['192.168.1.2', '69.69.69.69'])

    cloud_config_hash['networks'][1]['static_ips'] = ['68.68.68.68', '69.69.69.69']
    upload_cloud_config(cloud_config_hash: cloud_config_hash)
    deploy_simple_manifest(manifest_hash: updated_simple_manifest)
    new_instances = director.instances
    expect(new_instances.size).to eq(2)
    instance_with_original_vip_ip = new_instances.find { |new_instance| new_instance.ips.include?('69.69.69.69') }
    expect(instance_with_original_vip_ip.id).to eq(original_instances.first.id)
  end
end
