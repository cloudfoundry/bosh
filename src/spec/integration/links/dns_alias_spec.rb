require 'spec_helper'

describe 'Aliasing links to DNS addresses', type: :integration do
  with_reset_sandbox_before_each(local_dns: { 'enabled' => true })

  before do
    manifest['features'] = {
      'use_short_dns_addresses' => true,
      'use_link_dns_names' => true,
    }

    upload_links_release(bosh_runner_options: {})
    upload_stemcell

    upload_cloud_config(cloud_config_hash: cloud_config)
    deploy_simple_manifest(manifest_hash: manifest)
  end

  context 'when configuring aliases to release links' do
    let(:instances) { director.instances }

    let(:cloud_config) do
      cloud_config_hash = SharedSupport::DeploymentManifestHelper.simple_cloud_config
      cloud_config_hash['azs'] = [{ 'name' => 'z1' }]
      cloud_config_hash['networks'].first['subnets'].first['az'] = 'z1'
      cloud_config_hash['compilation']['az'] = 'z1'
      cloud_config_hash['networks'] << {
        'name' => 'manual-network',
        'type' => 'manual',
        'subnets' => [
          { 'range' => '10.10.0.0/24',
            'gateway' => '10.10.0.1',
            'az' => 'z1' },
        ],
      }
      cloud_config_hash['networks'] << {
        'name' => 'dynamic-network',
        'type' => 'dynamic',
        'subnets' => [{ 'az' => 'z1' }],
      }

      cloud_config_hash
    end

    let(:manifest) do
      manifest = SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups
      manifest['instance_groups'] = [
        first_provider_instance_group,
        second_provider_instance_group,
      ]
      manifest
    end

    let(:first_provider_instance_group) do
      spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
        name: 'mysql',
        jobs: [
          {
            'name' => 'database',
            'release' => 'bosh-release',
            'provides' => {
              'db' => {
                'aliases' => [
                  {
                    'domain' => 'my-service.my-domain',
                    'health_filter' => 'all',
                    'initial_health_check' => 'synchronous',
                    'placeholder_type' => 'uuid',
                  },
                ],
              },
            },
          },
        ],
        instances: 1,
      )
      spec['azs'] = ['z1']
      spec['networks'] = [{ 'name' => 'manual-network' }]
      spec
    end

    let(:second_provider_instance_group) do
      spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
        name: 'yoursql',
        jobs: [
          {
            'name' => 'database',
            'release' => 'bosh-release',
            'provides' => {
              'db' => {
                'as' => 'mydb',
                'aliases' => second_provider_aliases,
              },
            },
          },
        ],
        instances: 1,
      )
      spec['azs'] = ['z1']
      spec['networks'] = [
        {
          'name' => 'manual-network',
        },
      ]
      spec
    end

    let(:second_provider_aliases) do
      [
        { 'domain' => 'texas.my-domain', 'health_filter' => 'all' },
        { 'domain' => 'my-service.my-domain' },
      ]
    end

    it 'provides both aliases' do
      first_provider_instance = director.find_instance(instances, 'mysql', '0')
      first_provider_group_id = JSON.parse(
        first_provider_instance.read_job_template('database', '.bosh/links.json'),
      ).first['group']

      second_provider_instance = director.find_instance(instances, 'yoursql', '0')
      second_provider_group_id = JSON.parse(
        second_provider_instance.read_job_template('database', '.bosh/links.json'),
      )[0]['group']
      expect(first_provider_instance.dns_records['aliases']).to match(
        'my-service.my-domain' => [
          {
            'root_domain' => 'bosh',
            'group_id' => first_provider_group_id.to_s,
            'health_filter' => 'all',
            'initial_health_check' => 'synchronous',
            'placeholder_type' => 'uuid',
          },
          {
            'root_domain' => 'bosh',
            'group_id' => second_provider_group_id.to_s,
            'health_filter' => nil,
            'initial_health_check' => nil,
            'placeholder_type' => nil,
          },
        ],
        'texas.my-domain' => [
          {
            'root_domain' => 'bosh',
            'group_id' => second_provider_group_id.to_s,
            'health_filter' => 'all',
            'initial_health_check' => nil,
            'placeholder_type' => nil,
          },
        ],
      )
    end
  end

  context 'when configuring aliases to custom provided links' do
    let(:instances) { director.instances }

    let(:cloud_config) do
      cloud_config_hash = SharedSupport::DeploymentManifestHelper.simple_cloud_config
      cloud_config_hash['azs'] = [{ 'name' => 'z1' }]
      cloud_config_hash['networks'].first['subnets'].first['az'] = 'z1'
      cloud_config_hash['compilation']['az'] = 'z1'
      cloud_config_hash['networks'] << {
        'name' => 'manual-network',
        'type' => 'manual',
        'subnets' => [
          { 'range' => '10.10.0.0/24',
            'gateway' => '10.10.0.1',
            'az' => 'z1' },
        ],
      }
      cloud_config_hash['networks'] << {
        'name' => 'dynamic-network',
        'type' => 'dynamic',
        'subnets' => [{ 'az' => 'z1' }],
      }

      cloud_config_hash
    end

    let(:manifest) do
      manifest = SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups
      manifest['instance_groups'] = [
        first_provider_instance_group,
        second_provider_instance_group,
      ]
      manifest
    end

    let(:first_provider_instance_group) do
      spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
        name: 'mysql',
        jobs: [
          {
            'name' => 'database',
            'release' => 'bosh-release',
            'custom_provider_definitions' => [
              {
                'name' => 'my-custom-link',
                'type' => 'my-custom-link-type',
              },
            ],
            'provides' => {
              'my-custom-link' => {
                'aliases' => [
                  {
                    'domain' => 'my-service.my-domain',
                    'health_filter' => 'all',
                    'initial_health_check' => 'synchronous',
                    'placeholder_type' => 'uuid',
                  },
                ],
              },
            },
          },
          {
            'name' => 'provider',
            'release' => 'bosh-release',
            'provides' => {
              'provider' => {
                'aliases' => [
                  { 'domain' => 'provider-service.my-domain' },
                ],
              },
            },
          },
        ],
        instances: 1,
      )
      spec['azs'] = ['z1']
      spec['networks'] = [{ 'name' => 'manual-network' }]
      spec
    end

    let(:second_provider_instance_group) do
      spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
        name: 'yoursql',
        jobs: [
          {
            'name' => 'database',
            'release' => 'bosh-release',
            'provides' => {
              'db' => {
                'as' => 'mydb',
                'aliases' => second_provider_aliases,
              },
            },
          },
        ],
        instances: 1,
      )
      spec['azs'] = ['z1']
      spec['networks'] = [{ 'name' => 'manual-network' }]
      spec
    end

    let(:second_provider_aliases) do
      [
        { 'domain' => 'texas.my-domain', 'health_filter' => 'all' },
        { 'domain' => 'my-service.my-domain' },
      ]
    end

    it 'provides the alias' do
      # links.json
      first_provider_instance = director.find_instance(instances, 'mysql', '0')
      first_provider_database_links = JSON.parse(
        first_provider_instance.read_job_template('database', '.bosh/links.json'),
      )
      first_provider_provider_links = JSON.parse(
        first_provider_instance.read_job_template('provider', '.bosh/links.json'),
      )

      expect(first_provider_database_links).to include(
        'name' => 'my-custom-link', 'type' => 'my-custom-link-type', 'group' => '3',
      )
      expect(first_provider_provider_links).to_not include(
        'name' => 'my-custom-link', 'type' => 'my-custom-link-type', 'group' => '3',
      )

      # records.json
      group_id_index = first_provider_instance.dns_records['record_keys'].index 'group_ids'

      first_provider_record_info = first_provider_instance.dns_records['record_infos'][0]
      expect(first_provider_record_info[group_id_index]).to match(include('3'))

      second_provider_instance = director.find_instance(instances, 'yoursql', '0')
      second_provider_record_info = second_provider_instance.dns_records['record_infos'][1]
      expect(second_provider_record_info[group_id_index]).to_not match(include('3'))
    end
  end
end
