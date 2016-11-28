require 'spec_helper'

describe 'networks spanning multiple azs', type: :integration do
  with_reset_sandbox_before_each
  before do
    target_and_login
    create_and_upload_test_release
    upload_stemcell
    upload_cloud_config(cloud_config_hash: cloud_config_hash)
    deploy_simple_manifest(manifest_hash: manifest)
  end

  let(:manifest) do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest

    job = manifest_hash['jobs'].first
    job['networks'] = [
      {
        'name' => 'a',
        'default' => ['dns', 'gateway']
      },
    ]
    job['instances'] = 2
    job['azs'] = ['my-az', 'my-az2']
    manifest_hash
  end

  describe 'manual networks' do
    let(:cloud_config_hash) do
      cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
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
      vms = director.vms

      expect(vms[0].availability_zone).to eq('my-az')
      expect(vms[0].ips).to eq('192.168.1.2')

      expect(vms[1].availability_zone).to eq('my-az2')
      expect(vms[1].ips).to eq('192.168.1.3')
    end
  end

  context 'when network is dynamic' do
    let(:cloud_config_hash) do
      cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
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

      vms = director.vms
      expect(vms[0].availability_zone).to eq('my-az')
      expect(vms[1].availability_zone).to eq('my-az2')
    end
  end
end
