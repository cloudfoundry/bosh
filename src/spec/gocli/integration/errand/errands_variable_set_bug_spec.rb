require_relative '../../spec_helper'

describe "When an errand's az is changed on a re-deploy", type: :integration do
  with_reset_sandbox_before_each
  before do
    create_and_upload_test_release
    upload_stemcell
    upload_cloud_config(cloud_config_hash: cloud_config_hash)
  end

  let(:manifest) do
    manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_stemcell

    job = manifest_hash['jobs'].first
    job['networks'] = [
      {
        'name' => 'a',
        'default' => ['dns', 'gateway']
      },
    ]
    job['instances'] = 1
    job['lifecycle'] = 'errand'
    job['azs'] = ['my-az']
    manifest_hash
  end

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

  it 'should deploy successfully even when variable_sets cleanup fails' do
    deploy_simple_manifest(manifest_hash: manifest)
    manifest['jobs'].first['azs'] = ['my-az2']

    _, exit_code = deploy_simple_manifest(manifest_hash: manifest, return_exit_code: true)
    expect(exit_code).to eq(0)
  end
end
