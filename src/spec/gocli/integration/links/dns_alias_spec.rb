require 'spec_helper'

describe 'Aliasing links to DNS addresses', type: :integration do
  with_reset_sandbox_before_each(local_dns: { 'enabled' => true })

  def upload_links_release
    FileUtils.cp_r(LINKS_RELEASE_TEMPLATE, ClientSandbox.links_release_dir, preserve: false)
    bosh_runner.run_in_dir('create-release --force', ClientSandbox.links_release_dir)
    bosh_runner.run_in_dir('upload-release', ClientSandbox.links_release_dir)
  end

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

  let(:provider_aliases) do
    [{ 'domain' => 'my-service.my-domain' }]
  end

  let(:first_provider_instance_group) do
    spec = Bosh::Spec::NewDeployments.simple_instance_group(
      name: 'mysql',
      jobs: [{
        'name' => 'database',
        'provides' => {
          'db' => {
            'aliases' => provider_aliases,
          },
        },
      }],
      instances: 1,
    )
    spec['azs'] = ['z1']
    spec['networks'] = [{ 'name' => 'manual-network' }]
    spec
  end

  let(:manifest) do
    manifest = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
    manifest['instance_groups'] = provider_instance_groups
    manifest
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

  let(:instances) { director.instances }

  let(:first_provider_instance) do
    director.find_instance(instances, 'mysql', '0')
  end

  let(:first_provider_group_id) do
    JSON.parse(first_provider_instance.read_job_template('database', '.bosh/links.json')).first['group']
  end

  let(:aliases) do
    first_provider_instance.dns_records['aliases']
  end

  context 'when deploying a single link provider with an alias' do
    let(:provider_instance_groups) do
      [first_provider_instance_group]
    end

    it 'encodes the link provider alias in an aliases.json file' do
      expect(aliases).to eq(
        'my-service.my-domain' => [
          "q-s0.q-g#{first_provider_group_id}.bosh",
        ],
      )
    end

    context 'when there are multiple aliases' do
      let(:provider_aliases) do
        [
          { 'domain' => 'my-service.my-domain' },
          { 'domain' => 'wilbur.my-other-domain' },
        ]
      end

      it 'encodes multiple aliases from the same provider' do
        expect(aliases).to eq(
          'my-service.my-domain' => [
            "q-s0.q-g#{first_provider_group_id}.bosh",
          ],
          'wilbur.my-other-domain' => [
            "q-s0.q-g#{first_provider_group_id}.bosh",
          ],
        )
      end
    end
  end

  context 'when deploying multiple providers with aliases' do
    let(:second_provider_instance) do
      director.find_instance(instances, 'yoursql', '0')
    end

    let(:second_provider_group_id) do
      JSON.parse(second_provider_instance.read_job_template('database', '.bosh/links.json'))[1]['group']
    end

    let(:second_provider_aliases) do
      second_provider_instance.dns_records['aliases']
    end

    let(:provider_instance_groups) do
      [first_provider_instance_group, second_provider_instance_group]
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

    context 'when multiple providers alias different domains' do
      let(:second_provider_aliases) do
        [{ 'domain' => 'texas.my-domain' }]
      end

      it 'provides both aliases' do
        expect(aliases).to eq(
          'my-service.my-domain' => [
            "q-s0.q-g#{first_provider_group_id}.bosh",
          ],
          'texas.my-domain' => [
            "q-s0.q-g#{second_provider_group_id}.bosh",
          ],
        )
      end
    end

    context 'when multiple providers alias the same domain' do
      let(:second_provider_aliases) do
        [{ 'domain' => 'my-service.my-domain' }]
      end

      it 'merges both targets into the same alias' do
        expect(aliases).to eq(
          'my-service.my-domain' => [
            "q-s0.q-g#{first_provider_group_id}.bosh",
            "q-s0.q-g#{second_provider_group_id}.bosh",
          ],
        )
      end
    end
  end
end
