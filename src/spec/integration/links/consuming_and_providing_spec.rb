require 'spec_helper'

describe 'consuming and providing', type: :integration do
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

  before do
    upload_links_release
    upload_stemcell

    upload_cloud_config(cloud_config_hash: cloud_config)
  end

  context 'when the job consumes only links provided in job specs' do
    context 'when the co-located job has implicit links' do
      let(:provider_instance_group) do
        spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
          name: 'provider_instance_group',
          jobs: [
            {
              'name' => 'provider',
              'release' => 'bosh-release',
            },
            {
              'name' => 'app_server',
              'release' => 'bosh-release',
            },
          ],
          instances: 1,
        )
        spec['azs'] = ['z1']
        spec
      end
      let(:manifest) do
        manifest = SharedSupport::DeploymentManifestHelper.deployment_manifest
        manifest['instance_groups'] = [provider_instance_group]
        manifest
      end
      it 'should NOT be able to reach the links from the co-located job' do
        out, exit_code = deploy_simple_manifest(manifest_hash: manifest, failure_expected: true, return_exit_code: true)
        expect(exit_code).to eq(1)
        expect(out).to include(<<~OUTPUT.strip)
          Error: Unable to render instance groups for deployment. Errors are:
            - Unable to render jobs for instance group 'provider_instance_group'. Errors are:
              - Unable to render templates for job 'app_server'. Errors are:
                - Error filling in template 'config.yml.erb' (line 2: Can't find link 'provider')
        OUTPUT
      end
    end

    context 'when the co-located job has explicit links' do
      let(:provider_instance_group) do
        spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
          name: 'provider_instance_group',
          jobs: [
            {
              'name' => 'provider',
              'release' => 'bosh-release',
              'provides' => { 'provider' => { 'as' => 'link_provider' } },
            },
            {
              'name' => 'app_server',
              'release' => 'bosh-release',
            },
          ],
          instances: 1,
        )
        spec['azs'] = ['z1']
        spec
      end
      let(:manifest) do
        manifest = SharedSupport::DeploymentManifestHelper.deployment_manifest
        manifest['instance_groups'] = [provider_instance_group]
        manifest
      end
      it 'should NOT be able to reach the links from the co-located job' do
        out, exit_code = deploy_simple_manifest(manifest_hash: manifest, failure_expected: true, return_exit_code: true)
        expect(exit_code).to eq(1)
        expect(out).to include(<<~OUTPUT.strip)
          Error: Unable to render instance groups for deployment. Errors are:
            - Unable to render jobs for instance group 'provider_instance_group'. Errors are:
              - Unable to render templates for job 'app_server'. Errors are:
                - Error filling in template 'config.yml.erb' (line 2: Can't find link 'provider')
        OUTPUT
      end
    end

    context 'when the co-located job uses links from adjacent jobs' do
      let(:provider_instance_group) do
        spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
          name: 'provider_instance_group',
          jobs: [
            {
              'name' => 'provider',
              'release' => 'bosh-release',
            },
            {
              'name' => 'consumer',
              'release' => 'bosh-release',
            },
            {
              'name' => 'app_server',
              'release' => 'bosh-release',
            },
          ],
          instances: 1,
        )
        spec['azs'] = ['z1']
        spec
      end
      let(:manifest) do
        manifest = SharedSupport::DeploymentManifestHelper.deployment_manifest
        manifest['instance_groups'] = [provider_instance_group]
        manifest
      end
      it 'should NOT be able to reach the links from the co-located jobs' do
        out, exit_code = deploy_simple_manifest(manifest_hash: manifest, failure_expected: true, return_exit_code: true)
        expect(exit_code).to eq(1)
        expect(out).to include(<<~OUTPUT.strip)
          Error: Unable to render instance groups for deployment. Errors are:
            - Unable to render jobs for instance group 'provider_instance_group'. Errors are:
              - Unable to render templates for job 'app_server'. Errors are:
                - Error filling in template 'config.yml.erb' (line 2: Can't find link 'provider')
        OUTPUT
      end
    end

    context 'when the job tests for number of instances' do
      let(:manifest) do
        manifest = SharedSupport::DeploymentManifestHelper.deployment_manifest
        manifest['instance_groups'] = [instance_group]
        manifest
      end
      let(:instance_group) do
        spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
          name: 'instance_group',
          jobs: [
            {
              'name' => 'api_server_2_instances',
              'release' => 'bosh-release',
            },
            {
              'name' => 'database',
              'release' => 'bosh-release',
            },
          ],
          instances: 2,
        )
        spec['azs'] = ['z1']
        spec
      end

      it 'should deploy successfully with correct link selection' do
        deploy_simple_manifest(manifest_hash: manifest)

        manifest['instance_groups'][0]['instances'] = 3

        out, exit_code = deploy_simple_manifest(manifest_hash: manifest, failure_expected: true, return_exit_code: true)
        expect(exit_code).to eq(1)
        expect(out).to include(<<~OUTPUT.strip)
          Error: Unable to render instance groups for deployment. Errors are:
            - Unable to render jobs for instance group 'instance_group'. Errors are:
              - Unable to render templates for job 'api_server_2_instances'. Errors are:
                - Error filling in template 'config.yml.erb' (line 2: Expected exactly two instances of db in current deployment)
        OUTPUT
        manifest['instance_groups'][0]['instances'] = 2
        deploy_simple_manifest(manifest_hash: manifest)
      end
    end

    context 'when jobs scale down removing a link' do
      let(:manifest) do
        manifest = SharedSupport::DeploymentManifestHelper.deployment_manifest
        manifest['instance_groups'] = [instance_group, db_instance_group]
        manifest
      end
      let(:instance_group) do
        spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
          name: 'instance_group',
          jobs: [
            {
              'name' => 'database',
              'release' => 'bosh-release',
            },
            {
              'name' => 'errand_with_optional_links',
              'release' => 'bosh-release',
            },
          ],
          instances: 1,
        )
        spec['azs'] = ['z1']
        spec
      end

      let(:db_instance_group) do
        spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
          name: 'provider_instance_group',
          job_name: 'provider',
          instances: 1,
        )
        spec['azs'] = ['z1']
        spec
      end

      let(:db_instance_group2) do
        spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
          name: 'provider_instance_group2',
          job_name: 'provider',
          instances: 1,
        )
        spec['azs'] = ['z1']
        spec
      end

      it 'should deploy and run errand' do
        manifest['instance_groups'][1]['instances'] = 1
        deploy_simple_manifest(manifest_hash: manifest)
        out = run_errand('errand_with_optional_links', deployment_name: 'simple')
        expect(out).to include(/provider 192.168.1.3/)

        manifest['instance_groups'] = [instance_group]
        deploy_simple_manifest(manifest_hash: manifest)
        out = run_errand('errand_with_optional_links', deployment_name: 'simple')
        expect(out).to include(/db 192.168.1.2/)

        bosh_runner.run('recreate instance_group/0', deployment_name: 'simple')
        out = run_errand('errand_with_optional_links', deployment_name: 'simple')
        expect(out).to include(/db 192.168.1.2/)
      end
    end

    context 'when provider jobs is removed, with an optional link' do
      let(:manifest) do
        manifest = SharedSupport::DeploymentManifestHelper.deployment_manifest
        manifest['instance_groups'] = [instance_group]
        manifest
      end
      let(:instance_group) do
        spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
          name: 'instance_group',
          jobs: [
            { 'name' => 'database', 'release' => 'bosh-release' },
            { 'name' => 'errand_with_optional_links', 'release' => 'bosh-release' },
            { 'name' => 'provider', 'release' => 'bosh-release' },
          ],
          instances: 1,
        )
        spec['azs'] = ['z1']
        spec
      end

      it 'should deploy and run errand' do
        deploy_simple_manifest(manifest_hash: manifest)
        out = run_errand('errand_with_optional_links', deployment_name: 'simple')
        expect(out).to include(/provider 192.168.1.2/)

        manifest['instance_groups'][0]['jobs'].delete_at(2)
        deploy_simple_manifest(manifest_hash: manifest)
        out = run_errand('errand_with_optional_links', deployment_name: 'simple')
        expect(out).to include(/db 192.168.1.2/)

        bosh_runner.run('recreate instance_group/0', deployment_name: 'simple')
        out = run_errand('errand_with_optional_links', deployment_name: 'simple')
        expect(out).to include(/db 192.168.1.2/)
      end
    end
  end

  context 'when the job consumes multiple links of the same type' do
    let(:provider_instance_group) do
      spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
        name: 'provider_instance_group',
        jobs: [
          {
            'name' => 'database',
            'provides' => { 'db' => { 'as' => 'link_db_alias' } },
            'properties' => {
              'foo' => 'props_db_bar',
            },
            'release' => 'bosh-release',
          },
          {
            'name' => 'backup_database',
            'provides' => { 'backup_db' => { 'as' => 'link_backup_db_alias' } },
            'properties' => {
              'foo' => 'props_backup_db_bar',
            },
            'release' => 'bosh-release',
          },
        ],
        instances: 1,
      )
      spec['azs'] = ['z1']
      spec
    end

    let(:consumer_instance_group) do
      spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
        name: 'consumer_instance_group',
        jobs: [
          {
            'name' => 'api_server',
            'consumes' => {
              'db' => { 'from' => 'link_db_alias' },
              'backup_db' => { 'from' => 'link_backup_db_alias' },
            },
            'release' => 'bosh-release',
          },
        ],
        instances: 1,
      )
      spec['azs'] = ['z1']
      spec
    end

    let(:manifest) do
      manifest = SharedSupport::DeploymentManifestHelper.deployment_manifest
      manifest['instance_groups'] = [provider_instance_group, consumer_instance_group]
      manifest
    end

    it 'should have different content for each link if consumed from different sources' do
      deploy_simple_manifest(manifest_hash: manifest)
      consumer_instance = director.instance('consumer_instance_group', '0')
      template = YAML.safe_load(consumer_instance.read_job_template('api_server', 'config.yml'))

      expect(template['databases']['main_properties']).to eq('props_db_bar')
      expect(template['databases']['backup_properties']).to eq('props_backup_db_bar')
    end
  end

  context 'when consumer and provider has different types' do
    let(:cloud_config) { SharedSupport::DeploymentManifestHelper.simple_cloud_config }

    let(:provider_alias) { 'provider_login' }
    let(:provides_definition) do
      {
        'admin' => {
          'as' => provider_alias,
        },
      }
    end

    let(:consumes_definition) do
      {
        'login' => {
          'from' => provider_alias,
        },
      }
    end

    let(:new_provides_definition) do
      {
        'credentials' => {
          'as' => provider_alias,
        },
      }
    end

    def get_provider_instance_group(provides_definition)
      SharedSupport::DeploymentManifestHelper.simple_instance_group(
        name: 'provider_ig',
        jobs: [
          {
            'name' => 'provider_job',
            'provides' => provides_definition,
            'release' => releases.first['name'],
          },
        ],
        instances: 2,
      )
    end

    let(:consumer_instance_group) do
      instance_group_spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
        name: 'consumer_ig',
        jobs: [
          {
            'name' => 'consumer_job',
            'release' => releases.first['name'],
            'consumes' => consumes_definition,
          },
        ],
        instances: 1,
      )
      instance_group_spec
    end

    let(:releases) do
      [
        {
          'name' => 'changing_job_with_stable_links',
          'version' => 'latest',
        },
      ]
    end

    context 'but the alias is same' do
      let(:manifest) do
        manifest = SharedSupport::DeploymentManifestHelper.minimal_manifest
        manifest['releases'] = releases
        manifest['instance_groups'] = [get_provider_instance_group(provides_definition), consumer_instance_group]
        manifest
      end

      it 'should fail to create the link' do
        bosh_runner.run("upload-release #{asset_path('changing-release-0+dev.3.tgz')}")
        output = deploy_simple_manifest(manifest_hash: manifest, failure_expected: true)
        expect(output).to include(<<~OUTPUT.strip)
          Error: Failed to resolve links from deployment 'minimal'. See errors below:
            - Failed to resolve link 'login' with alias 'provider_login' and type 'usernamepassword' from job 'consumer_job' in instance group 'consumer_ig'. Details below:
              - No link providers found
        OUTPUT
      end

      context 'and the link is shared from another deployment' do
        let(:provider_manifest) do
          manifest = SharedSupport::DeploymentManifestHelper.minimal_manifest
          manifest['name'] = 'provider_deployment'
          manifest['releases'] = releases
          manifest['instance_groups'] = [get_provider_instance_group(provides_definition)]
          manifest
        end

        let(:consumer_manifest) do
          manifest = SharedSupport::DeploymentManifestHelper.minimal_manifest
          manifest['name'] = 'consumer_deployment'
          manifest['releases'] = releases
          manifest['instance_groups'] = [consumer_instance_group]
          manifest
        end

        let(:provides_definition) do
          {
            'admin' => {
              'shared' => true,
              'as' => provider_alias,
            },
          }
        end

        let(:consumes_definition) do
          {
            'login' => {
              'deployment' => provider_manifest['name'],
              'from' => provider_alias,
            },
          }
        end

        before do
          bosh_runner.run("upload-release #{asset_path('changing-release-0+dev.3.tgz')}")
          deploy_simple_manifest(manifest_hash: provider_manifest)
        end

        it 'should fail to create the link' do
          output = deploy_simple_manifest(manifest_hash: consumer_manifest, failure_expected: true)
          expect(output).to include(<<~OUTPUT.strip)
            Error: Failed to resolve links from deployment 'consumer_deployment'. See errors below:
              - Failed to resolve link 'login' with alias 'provider_login' and type 'usernamepassword' from job 'consumer_job' in instance group 'consumer_ig'. Details below:
                - No link providers found
          OUTPUT
        end
      end
    end
  end

  context 'when the consumer implicitly consumes a link' do
    context 'when there are multiple providers providing a link and one of the providers is set to nil' do
      let(:db_provider) do
        { 'as' => 'link_db_alias' }
      end
      let(:provider_instance_group_1) do
        spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
          name: 'provider_instance_group_1',
          jobs: [{
                   'name' => 'database',
                   'provides' => { 'db' => 'nil' },
                   'release' => 'bosh-release',
                   'properties' => {
                     'foo' => 'props_db_bar',
                   },
                 },
                 {
                   'name' => 'backup_database',
                   'release' => 'bosh-release',
                   'provides' => { 'backup_db' => { 'as' => 'link_backup_db_alias' } },
                   'properties' => {
                     'foo' => 'props_backup_db_bar',
                   },
                 }],
          instances: 1,
          )
        spec['azs'] = ['z1']
        spec
      end

      let(:provider_instance_group_2) do
        spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
          name: 'provider_instance_group_2',
          jobs: [{
                   'name' => 'database',
                   'release' => 'bosh-release',
                   'provides' => { 'db' => db_provider },
                   'properties' => {
                     'foo' => 'props_db_bar',
                   },
                 },
                 {
                   'name' => 'backup_database',
                   'provides' => { 'backup_db' => { 'as' => 'link_backup_db_alias2' } },
                   'release' => 'bosh-release',
                   'properties' => {
                     'foo' => 'props_backup_db_bar',
                   },
                 }],
          instances: 1,
          )
        spec['azs'] = ['z1']
        spec
      end

      let(:consumer_instance_group) do
        spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
          name: 'consumer_instance_group',
          jobs: [
            {
              'name' => 'api_server',
              'release' => 'bosh-release',
              'consumes' => {
                'db' => { 'from' => 'link_db_alias' },
                'backup_db' => { 'from' => 'link_backup_db_alias' },
              },
            },
          ],
          instances: 1,
          )
        spec['azs'] = ['z1']
        spec
      end

      let(:manifest) do
        manifest = SharedSupport::DeploymentManifestHelper.deployment_manifest
        manifest['instance_groups'] = [provider_instance_group_1, provider_instance_group_2, consumer_instance_group]
        manifest
      end

      it 'can resolve the links' do
        deploy_simple_manifest(manifest_hash: manifest)
        consumer_instance = director.instance('consumer_instance_group', '0')
        template = YAML.safe_load(consumer_instance.read_job_template('api_server', 'config.yml'))

        expect(template['databases']['main_properties']).to eq('props_db_bar')
        expect(template['databases']['backup_properties']).to eq('props_backup_db_bar')
      end
    end
  end
end
