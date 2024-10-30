require 'spec_helper'

describe 'checking link properties', type: :integration do
  with_reset_sandbox_before_each

  def upload_links_release
    FileUtils.cp_r(LINKS_RELEASE_TEMPLATE, ClientSandbox.links_release_dir, preserve: true)
    bosh_runner.run_in_dir('create-release --force', ClientSandbox.links_release_dir)
    bosh_runner.run_in_dir('upload-release', ClientSandbox.links_release_dir)
  end

  let(:cloud_config) do
    cloud_config_hash = SharedSupport::DeploymentManifestHelper.simple_cloud_config
    cloud_config_hash['azs'] = [{ 'name' => 'z1' }]
    cloud_config_hash['networks'].first['subnets'].first['static'] = [
      '192.168.1.10',
      '192.168.1.11',
      '192.168.1.12',
      '192.168.1.13',
    ]
    cloud_config_hash['networks'].first['subnets'].first['az'] = 'z1'
    cloud_config_hash['compilation']['az'] = 'z1'
    cloud_config_hash['networks'] << {
      'name' => 'dynamic-network',
      'type' => 'dynamic',
      'subnets' => [{ 'az' => 'z1' }],
    }

    cloud_config_hash
  end

  let(:instance_group_with_nil_properties) do
    spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
      name: 'property_job',
      jobs: [
        {
          'name' => 'provider',
          'release' => 'bosh-release',
          'properties' => {
            'a' => 'deployment_a',
          },
        },
        {
          'name' => 'consumer',
          'release' => 'bosh-release',
        },
      ],
      instances: 1,
      static_ips: ['192.168.1.10'],
      properties: {},
    )
    spec['azs'] = ['z1']
    spec['networks'] << {
      'name' => 'dynamic-network',
      'default' => %w[dns gateway],
    }
    spec
  end

  let(:instance_group_with_manual_consumes_link) do
    spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
      name: 'property_job',
      jobs: [
        {
          'name' => 'consumer',
          'consumes' => {
            'provider' => {
              'properties' => { 'a' => 2, 'b' => 3, 'c' => 4, 'nested' => { 'one' => 'three', 'two' => 'four' } },
              'instances' => [{ 'name' => 'external_db', 'address' => '192.168.15.4' }],
              'networks' => { 'a' => 2, 'b' => 3 },
            },
          },
          'release' => 'bosh-release',
        },
      ],
      instances: 1,
      static_ips: ['192.168.1.10'],
      properties: {},
    )
    spec['azs'] = ['z1']
    spec['networks'] << {
      'name' => 'dynamic-network',
      'default' => %w[dns gateway],
    }
    spec
  end

  let(:instance_group_with_link_properties_not_defined_in_release_properties) do
    spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
      name: 'jobby',
      jobs: [{ 'name' => 'provider', 'properties' => { 'doesntExist' => 'someValue' }, 'release' => 'bosh-release' }],
      instances: 1,
      static_ips: ['192.168.1.10'],
      properties: {},
    )
    spec['azs'] = ['z1']
    spec['networks'] << {
      'name' => 'dynamic-network',
      'default' => %w[dns gateway],
    }
    spec
  end

  before do
    upload_links_release
    upload_stemcell

    upload_cloud_config(cloud_config_hash: cloud_config)
  end

  it 'should not raise an error when consuming links without properties' do
    manifest = SharedSupport::DeploymentManifestHelper.deployment_manifest
    manifest['releases'][0]['version'] = '0+dev.1'
    manifest['instance_groups'] = [instance_group_with_nil_properties]

    _, exit_code = deploy_simple_manifest(manifest_hash: manifest, return_exit_code: true)

    expect(exit_code).to eq(0)
  end

  it 'should not raise an error when a deployment template property is not defined in the release properties' do
    manifest = SharedSupport::DeploymentManifestHelper.deployment_manifest
    manifest['releases'][0]['version'] = '0+dev.1'
    manifest['instance_groups'] = [instance_group_with_link_properties_not_defined_in_release_properties]

    _, exit_code = deploy_simple_manifest(manifest_hash: manifest, return_exit_code: true)

    expect(exit_code).to eq(0)
  end

  it 'should be able to resolve a manual configuration in a consumes link' do
    manifest = SharedSupport::DeploymentManifestHelper.deployment_manifest
    manifest['instance_groups'] = [instance_group_with_manual_consumes_link]

    _, exit_code = deploy_simple_manifest(manifest_hash: manifest, return_exit_code: true)
    expect(exit_code).to eq(0)

    link_instance = director.instance('property_job', '0')

    template = YAML.safe_load(link_instance.read_job_template('consumer', 'config.yml'))

    expect(template['a']).to eq(2)
    expect(template['b']).to eq(3)
    expect(template['c']).to eq(4)
    expect(template['nested']['one']).to eq('three')
    expect(template['nested']['two']).to eq('four')
  end
end
