require 'spec_helper'

describe 'orphaned networks', type: :integration do
  include Bosh::Spec::CreateReleaseOutputParsers
  with_reset_sandbox_before_each(networks: { 'enable_cpi_management' => true })
  let(:cloud_config_hash) { SharedSupport::DeploymentManifestHelper.simple_cloud_config_with_multiple_azs }
  let(:manifest_hash) { SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups }
  before do
    bosh_runner.reset
    manifest_hash['name'] = 'first-deployment'
    manifest_hash['instance_groups'].first['instances'] = 1
    manifest_hash['instance_groups'].first['azs'] = ['z1']
    manifest_hash['instance_groups'].first['networks'] = [{ 'name' => 'a' }]
  end

  it 'should return orphan networks' do
    cloud_config_hash['networks'] = [
      {
        'name' => 'a',
        'type' => 'manual',
        'managed' => true,
        'subnets' => [
          {
            'azs' => ['z1'],
            'name' => 'dummysubnet1',
            'range' => '192.168.10.0/24',
            'gateway' => '192.168.10.1',
            'cloud_properties' => { 't0_id' => '123456' },
            'dns' => ['8.8.8.8'],
          },
        ],
      },
      {
        'name' => 'b',
        'type' => 'manual',
        'managed' => true,
        'subnets' => [
          {
            'azs' => ['z1'],
            'name' => 'dummysubnet2',
            'range' => '192.168.20.0/24',
            'gateway' => '192.168.20.1',
            'cloud_properties' => { 't0_id' => '123456' },
            'dns' => ['8.8.8.8'],
          },
        ],
      },
    ]

    upload_cloud_config(cloud_config_hash: cloud_config_hash)
    deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)

    manifest_hash['name'] = 'second-deployment'
    manifest_hash['instance_groups'].first['networks'] = [{ 'name' => 'b' }]
    a = {
      'name' => 'a',
      'type' => 'manual',
      'created_at' => 'xxx xxx xx xx:xx:xx UTC xxxx',
      'orphaned_at' => 'xxx xxx xx xx:xx:xx UTC xxxx',
    }

    b = {
      'name' => 'b',
      'type' => 'manual',
      'created_at' => 'xxx xxx xx xx:xx:xx UTC xxxx',
      'orphaned_at' => 'xxx xxx xx xx:xx:xx UTC xxxx',
    }
    deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash)

    bosh_runner.run('delete-deployment', deployment_name: 'first-deployment')
    result = table(bosh_runner.run('networks --orphaned', json: true))
    result = scrub_event_time(result)

    expect(result).to contain_exactly(a)

    bosh_runner.run('delete-deployment', deployment_name: 'second-deployment')

    result = table(bosh_runner.run('networks --orphaned', json: true))
    result = scrub_event_time(result)
    expect(result).to contain_exactly(a, b)

    deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash)
    result = table(bosh_runner.run('networks --orphaned', json: true))
    result = scrub_event_time(result)
    expect(result).to contain_exactly(a)
  end

  context 'when there are no orphaned networks' do
    it 'should indicate that there are no orphaned networks' do
      result = bosh_runner.run('networks --orphaned')
      expect(result).to include '0 networks'
    end
  end

  it 'should delete an orphaned network' do
    cloud_config_hash['networks'] = [
      {
        'name' => 'a',
        'type' => 'manual',
        'managed' => true,
        'subnets' => [
          {
            'azs' => ['z1'],
            'name' => 'dummysubnet1',
            'range' => '192.168.10.0/24',
            'gateway' => '192.168.10.1',
            'cloud_properties' => { 't0_id' => '123456' },
            'dns' => ['8.8.8.8'],
          },
        ],
      },
    ]
    deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash)
    bosh_runner.run('delete-deployment', deployment_name: 'first-deployment')
    bosh_runner.run('delete-network a')
    delete_network_invocations = current_sandbox.cpi.invocations_for_method('delete_network')
    expect(delete_network_invocations.count).to eq(1)

    result = bosh_runner.run('networks --orphaned')
    expect(result).to include '0 networks'
  end
end
