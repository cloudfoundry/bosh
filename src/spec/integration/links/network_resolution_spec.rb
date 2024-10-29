require 'spec_helper'

describe 'network resolution', type: :integration do
  with_reset_sandbox_before_each

  def upload_links_release
    FileUtils.cp_r(LINKS_RELEASE_TEMPLATE, ClientSandbox.links_release_dir, preserve: true)
    bosh_runner.run_in_dir('create-release --force', ClientSandbox.links_release_dir)
    bosh_runner.run_in_dir('upload-release', ClientSandbox.links_release_dir)
  end

  def should_contain_network_for_job(job, template, pattern)
    my_api_instance = director.instance(job, '0', deployment_name: 'simple')
    template = YAML.safe_load(my_api_instance.read_job_template(template, 'config.yml'))

    template['databases'].select { |key| key == 'main' || key == 'backup_db' }.each_value do |database|
      database.each do |instance|
        expect(instance['address']).to match(pattern)
      end
    end
  end

  let(:cloud_config) do
    cloud_config_hash = Bosh::Spec::DeploymentManifestHelper.simple_cloud_config
    cloud_config_hash['azs'] = [{ 'name' => 'z1' }]
    cloud_config_hash['networks'].first['subnets'].first['static'] = [
      '192.168.1.10', '192.168.1.11', '192.168.1.12', '192.168.1.13'
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

  let(:api_instance_group_spec) do
    spec = Bosh::Spec::DeploymentManifestHelper.simple_instance_group(
      name: 'my_api',
      jobs: [{ 'name' => 'api_server', 'release' => 'bosh-release', 'consumes' => links }],
      instances: 1,
    )
    spec['azs'] = ['z1']
    spec
  end

  let(:mysql_instance_group_spec) do
    spec = Bosh::Spec::DeploymentManifestHelper.simple_instance_group(
      name: 'mysql',
      jobs: [{ 'name' => 'database', 'release' => 'bosh-release' }],
      instances: 2,
      static_ips: ['192.168.1.10', '192.168.1.11'],
    )
    spec['azs'] = ['z1']
    spec['networks'] << {
      'name' => 'dynamic-network',
      'default' => %w[dns gateway],
    }
    spec
  end

  let(:postgres_instance_group_spec) do
    spec = Bosh::Spec::DeploymentManifestHelper.simple_instance_group(
      name: 'postgres',
      jobs: [{ 'name' => 'backup_database', 'release' => 'bosh-release' }],
      instances: 1,
      static_ips: ['192.168.1.12'],
    )
    spec['azs'] = ['z1']
    spec
  end

  let(:aliased_instance_group_spec) do
    spec = Bosh::Spec::DeploymentManifestHelper.simple_instance_group(
      name: 'aliased_postgres',
      jobs: [
        'name' => 'backup_database',
        'release' => 'bosh-release',
        'provides' => { 'backup_db' => { 'as' => 'link_alias' } },
      ],
      instances: 1,
    )
    spec['azs'] = ['z1']
    spec
  end

  let(:manifest) do
    manifest = Bosh::Spec::DeploymentManifestHelper.deployment_manifest
    manifest['instance_groups'] = [api_instance_group_spec, mysql_instance_group_spec, postgres_instance_group_spec]
    manifest
  end

  before do
    upload_links_release
    upload_stemcell

    upload_cloud_config(cloud_config_hash: cloud_config)
  end

  context 'when user specifies a network in consumes' do
    let(:links) do
      {
        'db' => { 'from' => 'db', 'network' => 'b' },
        'backup_db' => { 'from' => 'backup_db', 'network' => 'b' },
      }
    end

    it 'overrides the default network' do
      cloud_config['networks'] << {
        'name' => 'b',
        'type' => 'dynamic',
        'subnets' => [{ 'az' => 'z1' }],
      }

      mysql_instance_group_spec['networks'] << {
        'name' => 'b',
      }

      postgres_instance_group_spec['networks'] << {
        'name' => 'dynamic-network',
        'default' => %w[dns gateway],
      }

      postgres_instance_group_spec['networks'] << {
        'name' => 'b',
      }

      upload_cloud_config(cloud_config_hash: cloud_config)
      deploy_simple_manifest(manifest_hash: manifest)
      should_contain_network_for_job('my_api', 'api_server', /.b\.simple\.bosh/)
    end

    it 'raises an error if network name specified is not one of the networks on the link' do
      manifest['instance_groups'].first['jobs'].first['consumes'] = {
        'db' => { 'from' => 'db', 'network' => 'invalid_network' },
        'backup_db' => { 'from' => 'backup_db', 'network' => 'a' },
      }

      expect do
        deploy_simple_manifest(manifest_hash: manifest)
      end.to raise_error(
        RuntimeError,
        Regexp.new(<<~ERROR
          Failed to resolve links from deployment 'simple'. See errors below:
            - Failed to resolve link 'db' with type 'db' from job 'api_server' in instance group 'my_api'. Details below:
              - Link provider 'db' from job 'database' in instance group 'mysql' in deployment 'simple' does not belong to network 'invalid_network'
        ERROR
        .strip),
      )
    end

    it 'raises an error if network name specified is not one of the networks on the link but redeploy is successful' do
      manifest['instance_groups'].first['jobs'].first['consumes'] = {
        'db' => { 'from' => 'db', 'network' => 'invalid_network' },
        'backup_db' => { 'from' => 'backup_db', 'network' => 'a' },
      }

      expect do
        deploy_simple_manifest(manifest_hash: manifest)
      end.to raise_error(
        RuntimeError,
        Regexp.new(<<~ERROR
          Failed to resolve links from deployment 'simple'. See errors below:
            - Failed to resolve link 'db' with type 'db' from job 'api_server' in instance group 'my_api'. Details below:
              - Link provider 'db' from job 'database' in instance group 'mysql' in deployment 'simple' does not belong to network 'invalid_network'
        ERROR
        .strip),
      )

      manifest['instance_groups'].first['jobs'].first['consumes'] = {
        'db' => { 'from' => 'db' },
        'backup_db' => { 'from' => 'backup_db', 'network' => 'a' },
      }
      deploy_simple_manifest(manifest_hash: manifest)
    end

    it 'raises an error if network name specified is not one of the networks on the link and is a global network' do
      cloud_config['networks'] << {
        'name' => 'global_network',
        'type' => 'dynamic',
        'subnets' => [{ 'az' => 'z1' }],
      }

      manifest['instance_groups'].first['jobs'].first['consumes'] = {
        'db' => { 'from' => 'db', 'network' => 'global_network' },
        'backup_db' => { 'from' => 'backup_db', 'network' => 'a' },
      }

      upload_cloud_config(cloud_config_hash: cloud_config)
      expect do
        deploy_simple_manifest(manifest_hash: manifest)
      end.to raise_error(
        RuntimeError,
        Regexp.new(<<~ERROR
          Failed to resolve links from deployment 'simple'. See errors below:
            - Failed to resolve link 'db' with type 'db' from job 'api_server' in instance group 'my_api'. Details below:
              - Link provider 'db' from job 'database' in instance group 'mysql' in deployment 'simple' does not belong to network 'global_network'
        ERROR
        .strip),
      )
    end

    context 'user has duplicate implicit links provided in two jobs over separate networks' do
      let(:mysql_instance_group_spec) do
        spec = Bosh::Spec::DeploymentManifestHelper.simple_instance_group(
          name: 'mysql',
          jobs: [{ 'name' => 'database', 'release' => 'bosh-release' }],
          instances: 2,
          static_ips: ['192.168.1.10', '192.168.1.11'],
        )
        spec['azs'] = ['z1']
        spec['networks'] = [{
          'name' => 'dynamic-network',
          'default' => %w[dns gateway],
        }]
        spec
      end

      let(:links) do
        {
          'db' => { 'network' => 'dynamic-network' },
          'backup_db' => { 'network' => 'a' },
        }
      end

      it 'should choose link from correct network' do
        upload_cloud_config(cloud_config_hash: cloud_config)
        deploy_simple_manifest(manifest_hash: manifest)
      end
    end
  end

  context 'when user does not specify a network in consumes' do
    let(:links) do
      {
        'db' => { 'from' => 'db' },
        'backup_db' => { 'from' => 'backup_db' },
      }
    end

    it 'uses the network from link when only one network is available' do
      mysql_instance_group_spec = Bosh::Spec::DeploymentManifestHelper.simple_instance_group(
        name: 'mysql',
        jobs: [{ 'name' => 'database', 'release' => 'bosh-release' }],
        instances: 1,
        static_ips: ['192.168.1.10'],
      )
      mysql_instance_group_spec['azs'] = ['z1']

      manifest['instance_groups'] = [api_instance_group_spec, mysql_instance_group_spec, postgres_instance_group_spec]

      deploy_simple_manifest(manifest_hash: manifest)
      should_contain_network_for_job('my_api', 'api_server', /192.168.1.1(0|2)/)
    end

    it 'uses the default network when multiple networks are available from link' do
      postgres_instance_group_spec['networks'] << {
        'name' => 'dynamic-network',
        'default' => %w[dns gateway],
      }
      deploy_simple_manifest(manifest_hash: manifest)
      should_contain_network_for_job('my_api', 'api_server', /.dynamic-network./)
    end

    context 'when provider has addressable flag in one of its network' do

      before do
        cloud_config['networks'] << {
          'name' => 'another',
          'type' => 'dynamic',
          'subnets' => [{'az' => 'z1'}],
        }

        mysql_instance_group_spec['networks'] << {
          'name' => 'another',
          'default' => ['addressable'],
        }

        upload_cloud_config(cloud_config_hash: cloud_config)
        deploy_simple_manifest(manifest_hash: manifest)
      end

      it 'uses the default `addressable`' do
        should_contain_network_for_job('my_api', 'api_server', /\.another\.simple\.bosh/)
      end
    end
  end
end
