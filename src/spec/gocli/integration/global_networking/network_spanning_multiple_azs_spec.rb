require_relative '../../spec_helper'

describe 'networks spanning multiple azs', type: :integration do
  with_reset_sandbox_before_each
  before do
    create_and_upload_test_release
    upload_stemcell
    upload_cloud_config(cloud_config_hash: cloud_config_hash)
    deploy_simple_manifest(manifest_hash: manifest)
  end

  let(:manifest) do
    manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups

    instance_group = manifest_hash['instance_groups'].first
    instance_group['networks'] = [
      {
        'name' => 'a',
        'default' => ['dns', 'gateway']
      },
    ]
    instance_group['instances'] = 2
    instance_group['azs'] = ['my-az', 'my-az2']
    manifest_hash
  end

  describe 'manual networks' do
    let(:cloud_config_hash) do
      cloud_config_hash = Bosh::Spec::NewDeployments.simple_cloud_config
      cloud_config_hash['azs'] = [{'name' => 'my-az'}, {'name' => 'my-az2'}]
      cloud_config_hash['compilation']['az'] = 'my-az'
      network_a = cloud_config_hash['networks'].first
      network_a['type'] = 'manual'
      network_a['subnets'] = [
        {
          'range' => '192.168.1.0/24',
          'gateway' => '192.168.1.1',
          'dns' => ['192.168.1.1', '192.168.1.2'],
          'reserved' => [],
          'cloud_properties' => {},
          'azs' => ['my-az', 'my-az2']
        }
      ]
      cloud_config_hash
    end

    it 'should deploy the vms to the azs, with ips from the single subnet' do
      instances = director.instances

      expect(instances.map(&:availability_zone)).to contain_exactly('my-az', 'my-az2')
      expect(instances.map(&:ips).flatten).to contain_exactly('192.168.1.2', '192.168.1.3')
    end
  end

  context 'when network is dynamic' do
    let(:cloud_config_hash) do
      cloud_config_hash = Bosh::Spec::NewDeployments.simple_cloud_config
      cloud_config_hash['azs'] = [{'name' => 'my-az'}, {'name' => 'my-az2'}]
      cloud_config_hash['compilation']['az'] = 'my-az'
      cloud_config_hash['networks'] = [{
          'name' => 'a',
          'type' => 'dynamic',
          'subnets' => [
           {
             'azs' => ['my-az', 'my-az2'],
             'cloud_properties' => {'dynamic' => 'property'}
           }
          ]
        }]
      cloud_config_hash
    end

    it 'should deploy the vms to the azs, with ips from the single subnet' do
      current_sandbox.cpi.invocations_for_method('create_vm').map do |invocation|
        expect(invocation.inputs['networks']['a']['cloud_properties']).to eq({'dynamic' => 'property'})
      end

      instances = director.instances
      expect(instances.map(&:availability_zone)).to contain_exactly('my-az', 'my-az2')
    end
  end
end
