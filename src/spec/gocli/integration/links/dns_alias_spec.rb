require 'spec_helper'

describe 'Aliasing links to DNS addresses', type: :integration do
  with_reset_sandbox_before_each(local_dns: { 'enabled' => true })

  def upload_links_release
    FileUtils.cp_r(LINKS_RELEASE_TEMPLATE, ClientSandbox.links_release_dir, preserve: false)
    bosh_runner.run_in_dir('create-release --force', ClientSandbox.links_release_dir)
    bosh_runner.run_in_dir('upload-release', ClientSandbox.links_release_dir)
  end

  before do
    manifest['features'] = {
      'use_short_dns_addresses' => true,
      'use_link_dns_names' => true,
    }

    upload_links_release
    upload_stemcell

    upload_cloud_config(cloud_config_hash: cloud_config)
    deploy_simple_manifest(manifest_hash: manifest)
  end

  context 'when configuring aliases to links' do
    let(:instances) { director.instances }

    let(:cloud_config) do
      cloud_config_hash = Bosh::Spec::NewDeployments.simple_cloud_config
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
      manifest = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
      manifest['instance_groups'] = [
        first_provider_instance_group,
        second_provider_instance_group,
      ]
      manifest
    end

    let(:first_provider_instance_group) do
      spec = Bosh::Spec::NewDeployments.simple_instance_group(
        name: 'mysql',
        jobs: [{
          'name' => 'database',
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
        }],
        instances: 1,
      )
      spec['azs'] = ['z1']
      spec['networks'] = [{ 'name' => 'manual-network' }]
      spec
    end

    let(:second_provider_instance_group) do
      spec = Bosh::Spec::NewDeployments.simple_instance_group(
        name: 'yoursql',
        jobs: [{
          'name' => 'database',
          'provides' => {
            'db' => {
              'as' => 'mydb',
              'aliases' => second_provider_aliases,
            },
          },
        }],
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
end
