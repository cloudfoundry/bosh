require 'spec_helper'

describe 'broken links', type: :integration do
  with_reset_sandbox_before_each

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

  before do
    upload_links_release(bosh_runner_options: {})
    upload_stemcell

    upload_cloud_config(cloud_config_hash: cloud_config)
  end

  let(:manifest) do
    manifest = SharedSupport::DeploymentManifestHelper.deployment_manifest
    manifest['instance_groups'] = [first_node_instance_group_spec, second_node_instance_group_spec]
    manifest
  end

  let(:first_node_instance_group_spec) do
    SharedSupport::DeploymentManifestHelper.simple_instance_group(
      name: 'first_node',
      jobs: [
        'name' => 'node',
        'release' => 'bosh-release',
        'consumes' => first_node_links,
        'provides' => { 'node2' => { 'as' => 'alias2' } },
      ],
      instances: 1,
      static_ips: ['192.168.1.10'],
      azs: ['z1'],
    )
  end

  let(:first_node_links) do
    {
      'node1' => { 'from' => 'node1' },
      'node2' => { 'from' => 'alias2' },
    }
  end

  let(:second_node_instance_group_spec) do
    SharedSupport::DeploymentManifestHelper.simple_instance_group(
      name: 'second_node',
      jobs: [
        'name' => 'node',
        'release' => 'bosh-release',
        'consumes' => second_node_links,
        'provides' => { 'node2' => { 'as' => 'alias2' } },
      ],
      instances: 1,
      static_ips: ['192.168.1.11'],
      azs: ['z1'],
    )
  end

  let(:second_node_links) do
    {
      'node1' => { 'from' => 'broken', 'deployment' => 'broken' },
      'node2' => { 'from' => 'blah', 'deployment' => 'other' },
    }
  end

  context 'when validation of link resolution fails' do
    let(:manifest) do
      manifest = SharedSupport::DeploymentManifestHelper.deployment_manifest
      manifest['instance_groups'] = [
        first_consumer_instance,
        second_consumer_instance,
        first_provider_instance,
        second_provider_instance,
      ]
      manifest
    end

    let(:first_provider_instance) do
      SharedSupport::DeploymentManifestHelper.simple_instance_group(
        name: 'first_provider',
        jobs: [{ 'name' => 'provider', 'release' => 'bosh-release', 'provides' => provide_links }],
        instances: 1,
        static_ips: ['192.168.1.11'],
        azs: ['z1'],
      )
    end

    let(:second_provider_instance) do
      SharedSupport::DeploymentManifestHelper.simple_instance_group(
        name: 'second_provider',
        jobs: [{ 'name' => 'provider', 'release' => 'bosh-release', 'provides' => provide_links }],
        instances: 1,
        static_ips: ['192.168.1.12'],
        azs: ['z1'],
      )
    end

    let(:provide_links) do
      {
        'provider' => { 'as' => 'alias1' },
      }
    end

    let(:first_consumer_instance) do
      SharedSupport::DeploymentManifestHelper.simple_instance_group(
        name: 'first_consumer',
        jobs: [{ 'name' => 'consumer', 'release' => 'bosh-release', 'consumes' => consume_links }],
        instances: 1,
        static_ips: ['192.168.1.13'],
        azs: ['z1'],
      )
    end

    let(:second_consumer_instance) do
      SharedSupport::DeploymentManifestHelper.simple_instance_group(
        name: 'second_consumer',
        jobs: [{ 'name' => 'consumer', 'release' => 'bosh-release' }],
        instances: 1,
        static_ips: ['192.168.1.14'],
        azs: ['z1'],
      )
    end

    let(:consume_links) do
      {
        'provider' => { 'from' => 'alias1' },
      }
    end

    it 'should raise an error listing all issues before updating vms' do
      output, exit_code = deploy_simple_manifest(manifest_hash: manifest, failure_expected: true, return_exit_code: true)
      expect(exit_code).not_to eq(0)
      expect(director.instances).to eq([])
      expect(output).to include(<<OUTPUT.strip)
  - Failed to resolve link 'provider' with alias 'alias1' and type 'provider' from job 'consumer' in instance group 'first_consumer'. Multiple link providers found:
    - Link provider 'provider' with alias 'alias1' from job 'provider' in instance group 'first_provider' in deployment 'simple'
    - Link provider 'provider' with alias 'alias1' from job 'provider' in instance group 'second_provider' in deployment 'simple'
OUTPUT
      expect(output).to include(<<OUTPUT.strip)
  - Failed to resolve link 'provider' with type 'provider' from job 'consumer' in instance group 'second_consumer'. Multiple link providers found:
    - Link provider 'provider' with alias 'alias1' from job 'provider' in instance group 'first_provider' in deployment 'simple'
    - Link provider 'provider' with alias 'alias1' from job 'provider' in instance group 'second_provider' in deployment 'simple'
OUTPUT
    end
  end

  context 'when a previous deploy failed' do

    let(:manifest) do
      manifest = SharedSupport::DeploymentManifestHelper.deployment_manifest
      manifest['instance_groups'] = [first_node_instance_group_spec, second_node_instance_group_spec]
      manifest
    end

    let(:first_node_instance_group_spec) do
      SharedSupport::DeploymentManifestHelper.simple_instance_group(
        name: 'first_node',
        jobs: [
          'name' => 'node',
          'release' => 'bosh-release',
          'consumes' => first_node_links,
          'provides' => { 'node2' => { 'as' => 'alias1' } },
        ],
        instances: 1,
        static_ips: ['192.168.1.10'],
        azs: ['z1'],
        )
    end

    let(:first_node_links) do
      {
        'node1' => { 'from' => 'node1' },
        'node2' => { 'from' => 'alias2' },
      }
    end

    let(:second_node_instance_group_spec) do
      SharedSupport::DeploymentManifestHelper.simple_instance_group(
        name: 'second_node',
        jobs: [
          'name' => 'node',
          'release' => 'bosh-release',
          'consumes' => second_node_links,
          'provides' => { 'node1' => { 'as' => 'node1a' }, 'node2' => { 'as' => 'alias2' } },
        ],
        instances: 1,
        static_ips: ['192.168.1.11'],
        azs: ['z1'],
        )
    end

    let(:second_node_links) do
      {
        'node1' => { 'from' => 'node1a' },
        'node2' => { 'from' => 'alias1' },
      }
    end


    it 'performing a restart uses the last known successfully deployed links' do
      deploy_simple_manifest(manifest_hash: manifest)

      manifest['instance_groups'][0]['azs'] = ['z4']

      _, exit = deploy_simple_manifest(manifest_hash: manifest, failure_expected: true, return_exit_code: true)
      expect(exit).to_not eq(0)

      expect { bosh_runner.run('restart', deployment_name: 'simple') }.to_not raise_error
    end
  end
end
