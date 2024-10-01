require 'spec_helper'

describe 'multiple versions of a release are uploaded', type: :integration do
  with_reset_sandbox_before_each

  let(:cloud_config) do
    cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
    cloud_config_hash['azs'] = [{ 'name' => 'z1' }]
    cloud_config_hash['networks'].first['subnets'].first['az'] = 'z1'
    cloud_config_hash['compilation']['az'] = 'z1'
    cloud_config_hash
  end

  let(:instance_group_consumes_link_spec_for_addon) do
    spec = Bosh::Spec::Deployments.simple_instance_group(
      name: 'deployment-job',
      jobs: [{ 'name' => 'api_server', 'consumes' => links, 'release' => 'simple-link-release' }],
    )
    spec
  end

  let(:deployment_manifest) do
    manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
    manifest['releases'].clear
    manifest['releases'] << {
      'name' => 'simple-link-release',
      'version' => '1.0',
    }

    manifest['instance_groups'] = [mysql_instance_group_spec, postgres_instance_group_spec]
    manifest['addons'] = [instance_group_consumes_link_spec_for_addon]
    manifest
  end

  let(:mysql_instance_group_spec) do
    spec = Bosh::Spec::Deployments.simple_instance_group(
      name: 'mysql',
      jobs: [{ 'name' => 'database', 'release' => 'simple-link-release' }],
      instances: 1,
    )
    spec['azs'] = ['z1']
    spec
  end

  let(:postgres_instance_group_spec) do
    spec = Bosh::Spec::Deployments.simple_instance_group(
      name: 'postgres',
      jobs: [{ 'name' => 'backup_database', 'release' => 'simple-link-release' }],
      instances: 1,
    )
    spec['azs'] = ['z1']
    spec
  end

  let(:links) do
    {
      'db' => { 'from' => 'db' },
      'backup_db' => { 'from' => 'backup_db' },
    }
  end

  before do
    upload_stemcell
    upload_cloud_config(cloud_config_hash: cloud_config)
  end

  context 'when a release job is being used as an addon' do
    # story link for context: https://www.pivotaltracker.com/n/projects/956238/stories/152689259
    it 'should ONLY use the release version specified in manifest' do
      bosh_runner.run("upload-release #{asset_path('links_releases/simple-link-release-v1.0.tgz')}")

      # release with broken links
      bosh_runner.run("upload-release #{asset_path('links_releases/simple-link-release-v2.0.tgz')}")

      _, exit_code = deploy_simple_manifest(manifest_hash: deployment_manifest, return_exit_code: true)
      expect(exit_code).to eq(0)
    end
  end
end
