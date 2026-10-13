require 'spec_helper'

describe 'Removing a provided link', type: :integration do
  with_reset_sandbox_before_each(local_dns: { 'enabled' => true })

  let(:cloud_config) do
    cloud_config_hash = SharedSupport::DeploymentManifestHelper.simple_cloud_config
    cloud_config_hash['azs'] = [{ 'name' => 'z1' }]
    cloud_config_hash['networks'].first['subnets'].first['az'] = 'z1'
    cloud_config_hash['compilation']['az'] = 'z1'
    cloud_config_hash
  end

  let(:custom_provider_job) do
    {
      'name' => 'database',
      'release' => 'bosh-release',
      'custom_provider_definitions' => [
        {
          'name' => 'my-custom-link',
          'type' => 'my-custom-link-type',
        },
      ],
    }
  end

  let(:manifest) do
    manifest = SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups
    manifest['features'] = { 'use_short_dns_addresses' => true }
    instance_group = SharedSupport::DeploymentManifestHelper.simple_instance_group(
      name: 'mysql',
      jobs: [custom_provider_job],
      instances: 1,
    )
    instance_group['azs'] = ['z1']
    manifest['instance_groups'] = [instance_group]
    manifest
  end

  def mysql_instance
    director.find_instance(director.instances, 'mysql', '0')
  end

  def database_links
    JSON.parse(mysql_instance.read_job_template('database', '.bosh/links.json'))
  end

  def mysql_group_ids
    dns_records = mysql_instance.dns_records
    group_ids_index = dns_records['record_keys'].index('group_ids')
    dns_records['record_infos'].map { |record_info| record_info[group_ids_index] }.flatten
  end

  before do
    upload_links_release(bosh_runner_options: {})
    upload_stemcell
    upload_cloud_config(cloud_config_hash: cloud_config)
  end

  it 'removes the link from links.json and the DNS records in the same deploy' do
    deploy_simple_manifest(manifest_hash: manifest)

    custom_link = database_links.find { |link| link['name'] == 'my-custom-link' }
    expect(custom_link).to_not be_nil
    expect(mysql_group_ids).to include(custom_link['group'])

    custom_provider_job.delete('custom_provider_definitions')
    deploy_simple_manifest(manifest_hash: manifest)

    expect(database_links.map { |link| link['name'] }).to_not include('my-custom-link')
    expect(mysql_group_ids).to_not include(custom_link['group'])

    output = deploy_simple_manifest(manifest_hash: manifest)
    expect(output).to_not match(/Updating instance mysql/)
  end

  it 'removes a link that a new release version no longer provides in the same deploy' do
    deploy_simple_manifest(manifest_hash: manifest)

    db_link = database_links.find { |link| link['name'] == 'db' }
    expect(db_link).to_not be_nil
    expect(mysql_group_ids).to include(db_link['group'])

    database_spec_path = File.join(IntegrationSupport::Sandbox.links_release_dir, 'jobs', 'database', 'spec')
    database_spec = YAML.load_file(database_spec_path)
    database_spec.delete('provides')
    File.write(database_spec_path, YAML.dump(database_spec))
    bosh_runner.run_in_dir('create-release --force', IntegrationSupport::Sandbox.links_release_dir)
    bosh_runner.run_in_dir('upload-release', IntegrationSupport::Sandbox.links_release_dir)

    manifest['releases'].first['version'] = '0+dev.2'
    deploy_simple_manifest(manifest_hash: manifest)

    expect(database_links.map { |link| link['name'] }).to_not include('db')
    expect(mysql_group_ids).to_not include(db_link['group'])

    output = deploy_simple_manifest(manifest_hash: manifest)
    expect(output).to_not match(/Updating instance mysql/)
  end
end
