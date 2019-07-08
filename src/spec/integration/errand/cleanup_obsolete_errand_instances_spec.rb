require_relative '../../spec_helper'

describe "#146961875 When an errand's az is changed on a re-deploy", type: :integration do
  with_reset_sandbox_before_each

  let(:number_of_instances) { 1 }
  let(:manifest) do
    manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups

    job = manifest_hash['instance_groups'].first
    job['networks'] = [
      {
        'name' => 'a',
        'default' => ['dns', 'gateway']
      },
    ]
    job['instances'] = number_of_instances
    job['lifecycle'] = 'errand'
    job['azs'] = ['my-az1']
    manifest_hash
  end

  let(:cloud_config_hash) do
    cloud_config_hash = Bosh::Spec::NewDeployments.simple_cloud_config
    cloud_config_hash['azs'] = [{'name' => 'my-az1'}, {'name' => 'my-az2'}]
    cloud_config_hash['compilation']['az'] = 'my-az1'
    network_a = cloud_config_hash['networks'].first
    network_a['type'] = 'manual'
    network_a['subnets'] = [
      {
        'range' => '192.168.1.0/24',
        'gateway' => '192.168.1.1',
        'dns' => ['192.168.1.1', '192.168.1.2'],
        'reserved' => [],
        'cloud_properties' => {},
        'azs' => ['my-az1', 'my-az2']
      }
    ]
    cloud_config_hash
  end

  before do
    create_and_upload_test_release
    upload_stemcell
    upload_cloud_config(cloud_config_hash: cloud_config_hash)

    deploy_simple_manifest(manifest_hash: manifest)
    instances = director.instances
    expect(instances.count).to eq(number_of_instances)

    instances.each do |instance|
      expect(instance.availability_zone).to eq('my-az1')
    end

    manifest['instance_groups'].first['azs'] = ['my-az2']

    deploy_simple_manifest(manifest_hash: manifest, return_exit_code: true)
  end

  it 'there should only be one instance in the new az' do
    instances = director.instances
    expect(instances.count).to eq(number_of_instances)
    instances.each do |instance|
      expect(instance.availability_zone).to eq('my-az2')
    end
  end

  context 'when a user specifies more than one instance' do
    let(:number_of_instances) { 5 }
    it 'there should only 5 instances in the new az' do
      instances = director.instances
      expect(instances.count).to eq(number_of_instances)
      instances.each do |instance|
        expect(instance.availability_zone).to eq('my-az2')
      end
    end
  end
end
