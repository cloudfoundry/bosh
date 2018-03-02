require_relative '../../../gocli/spec_helper'

xdescribe 'Links', type: :integration do
  with_reset_sandbox_before_each

  def upload_links_release
    FileUtils.cp_r(LINKS_RELEASE_TEMPLATE, ClientSandbox.links_release_dir, preserve: true)
    bosh_runner.run_in_dir('create-release --force', ClientSandbox.links_release_dir)
    bosh_runner.run_in_dir('upload-release', ClientSandbox.links_release_dir)
  end

  let(:cloud_config) do
    cloud_config_hash = Bosh::Spec::NewDeployments.simple_cloud_config
    cloud_config_hash['azs'] = [{ 'name' => 'z1' }]
    cloud_config_hash['networks'].first['subnets'].first['static'] = ['192.168.1.10', '192.168.1.11', '192.168.1.12', '192.168.1.13']
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
    upload_links_release
    upload_stemcell
    upload_cloud_config(cloud_config_hash: cloud_config)
  end

  let(:implicit_provider_instance_group) do
    Bosh::Spec::NewDeployments.simple_instance_group(
      name: 'implicit_provider_ig',
      jobs: [{ 'name' => 'backup_database' }],
      instances: 1,
      azs: ['z1'],
    )
  end

  let(:implicit_consumer_instance_group) do
    Bosh::Spec::NewDeployments.simple_instance_group(
      name: 'implicit_consumer_ig',
      jobs: [{ 'name' => 'api_server' }],
      instances: 1,
      azs: ['z1'],
    )
  end

  let(:implicit_manifest) do
    Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups.tap do |manifest|
      manifest['name'] = 'implicit_deployment'
      manifest['instance_groups'] = [implicit_provider_instance_group, implicit_consumer_instance_group]
    end
  end

  let(:explicit_provider_instance_group) do
    Bosh::Spec::NewDeployments.simple_instance_group(
      name: 'explicit_provider_ig',
      jobs: [
        {
          'name' => 'backup_database',
          'provides' => {
            'backup_db' => { 'as' => 'explicit_db' },
          },
        },
      ],
      instances: 1,
      azs: ['z1'],
    )
  end

  let(:explicit_consumer_instance_group) do
    Bosh::Spec::NewDeployments.simple_instance_group(
      name: 'explicit_consumer_ig',
      jobs: [
        {
          'name' => 'api_server',
          'consumes' => {
            'db' => { 'from' => 'explicit_db' },
            'backup_db' => { 'from' => 'explicit_db' },
          },
        },
      ],
      instances: 1,
      azs: ['z1'],
    )
  end

  let(:explicit_manifest) do
    Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups.tap do |manifest|
      manifest['name'] = 'explicit_deployment'
      manifest['instance_groups'] = [explicit_provider_instance_group, explicit_consumer_instance_group]
    end
  end

  let(:shared_provider_instance_group) do
    Bosh::Spec::NewDeployments.simple_instance_group(
      name: 'shared_provider_ig',
      jobs: [
        {
          'name' => 'database',
          'provides' => {
            'db' => { 'shared' => true, 'as' => 'my_shared_db' },
          },
        },
      ],
      instances: 1,
      azs: ['z1'],
    )
  end

  let(:shared_provider_manifest) do
    Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups.tap do |manifest|
      manifest['name'] = 'shared_provider_deployment'
      manifest['instance_groups'] = [shared_provider_instance_group]
    end
  end

  let(:shared_consumer_instance_group) do
    Bosh::Spec::NewDeployments.simple_instance_group(
      name: 'shared_consumer_ig',
      jobs: [
        {
          'name' => 'api_server',
          'consumes' => {
            'db' => { 'from' => 'my_shared_db', 'deployment' => 'shared_provider_deployment' },
            'backup_db' => { 'from' => 'my_shared_db', 'deployment' => 'shared_provider_deployment' },
          },
        },
      ],
      instances: 1,
      azs: ['z1'],
    )
  end

  let(:shared_consumer_deployment) do
    Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups.tap do |manifest|
      manifest['name'] = 'shared_consumer_deployment'
      manifest['instance_groups'] = [shared_consumer_instance_group]
    end
  end

  let(:errand_provider_instance_group) do
    Bosh::Spec::NewDeployments.simple_instance_group(
      name: 'errand_provider_ig',
      jobs: [{ 'name' => 'database' }],
      instances: 1,
      azs: ['z1'],
    )
  end

  let(:errand_consumer_instance_group) do
    Bosh::Spec::NewDeployments.simple_instance_group(
      name: 'errand_consumer_ig',
      jobs: [{ 'name' => 'errand_with_links' }],
      instances: 1,
      azs: ['z1'],
    ).tap do |ig|
      ig['lifecycle'] = 'errand'
    end
  end

  let(:errand_manifest) do
    Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups.tap do |manifest|
      manifest['name'] = 'errand_deployment'
      manifest['instance_groups'] = [errand_provider_instance_group, errand_consumer_instance_group]
    end
  end

  it 'sets up initial state' do
    puts 'Errand Deployment'
    deploy_simple_manifest(manifest_hash: errand_manifest)

    puts 'Shared Provider Deployment'
    deploy_simple_manifest(manifest_hash: shared_provider_manifest)

    puts 'Shared Consumer Deployment'
    deploy_simple_manifest(manifest_hash: shared_consumer_deployment)
    new_instance = director.instance('shared_consumer_ig', '0', deployment_name: 'shared_consumer_deployment')
    puts YAML.safe_load(new_instance.read_job_template('api_server', 'config.yml'))

    puts 'Implicit Deployment'
    deploy_simple_manifest(manifest_hash: implicit_manifest)
    new_instance = director.instance('implicit_consumer_ig', '0', deployment_name: 'implicit_deployment')
    puts YAML.safe_load(new_instance.read_job_template('api_server', 'config.yml'))

    puts 'Explicit Deployment'
    deploy_simple_manifest(manifest_hash: explicit_manifest)
    new_instance = director.instance('explicit_consumer_ig', '0', deployment_name: 'explicit_deployment')
    puts YAML.safe_load(new_instance.read_job_template('api_server', 'config.yml'))

    bosh_runner.run('-d errand_deployment stop --hard')
    bosh_runner.run('-d shared_provider_deployment stop --hard')
    bosh_runner.run('-d shared_consumer_deployment stop --hard')
    bosh_runner.run('-d implicit_deployment stop --hard')
    bosh_runner.run('-d explicit_deployment stop --hard')
    puts 'All good!'
  end
end
