require 'spec_helper'

describe 'optional links', type: :integration do
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

  let(:api_instance_group_with_optional_db_link) do
    spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
      name: 'my_api',
      jobs: [
        'name' => 'api_server_with_optional_db_link',
        'release' => 'bosh-release',
        'consumes' => links,
      ],
      instances: 1,
    )
    spec['azs'] = ['z1']
    spec
  end

  let(:api_instance_group_with_optional_links_spec_1) do
    spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
      name: 'my_api',
      jobs: [
        'name' => 'api_server_with_optional_links_1',
        'release' => 'bosh-release',
        'consumes' => links,
      ],
      instances: 1,
    )
    spec['azs'] = ['z1']
    spec
  end

  let(:api_instance_group_with_optional_links_spec_2) do
    spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
      name: 'my_api',
      jobs: [
        'name' => 'api_server_with_optional_links_2',
        'release' => 'bosh-release',
        'consumes' => links,
      ],
      instances: 1,
    )
    spec['azs'] = ['z1']
    spec
  end

  let(:mysql_instance_group_spec) do
    spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
      name: 'mysql',
      jobs: [
        'name' => 'database',
        'release' => 'bosh-release',
      ],
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
    spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
      name: 'postgres',
      jobs: [
        'name' => 'backup_database',
        'release' => 'bosh-release',
      ],
      instances: 1,
      static_ips: ['192.168.1.12'],
    )
    spec['azs'] = ['z1']
    spec
  end

  let(:manifest) do
    manifest = SharedSupport::DeploymentManifestHelper.deployment_manifest
    manifest['instance_groups'] = [
      api_instance_group_with_optional_links_spec_1,
      mysql_instance_group_spec,
      postgres_instance_group_spec,
    ]
    manifest
  end

  before do
    upload_links_release
    upload_stemcell

    upload_cloud_config(cloud_config_hash: cloud_config)
  end

  context 'when optional links are explicitly stated in deployment manifest' do
    let(:links) do
      {
        'db' => { 'from' => 'db' },
        'backup_db' => { 'from' => 'backup_db' },
        'optional_link_name' => { 'from' => 'backup_db' },
      }
    end

    it 'throws an error if the optional link was not found' do
      out, exit_code = deploy_simple_manifest(manifest_hash: manifest, failure_expected: true, return_exit_code: true)
      expect(exit_code).not_to eq(0)
      expect(out).to include(<<~OUTPUT.strip)
        Error: Failed to resolve links from deployment 'simple'. See errors below:
          - Failed to resolve link 'optional_link_name' with alias 'backup_db' and type 'optional_link_type' from job 'api_server_with_optional_links_1' in instance group 'my_api'. Details below:
            - No link providers found
      OUTPUT
    end
  end

  context 'when optional links are not explicitly stated in deployment manifest' do
    let(:links) do
      {
        'db' => { 'from' => 'db' },
        'backup_db' => { 'from' => 'backup_db' },
      }
    end

    it 'should not throw an error if the optional link was not found' do
      out, exit_code = deploy_simple_manifest(manifest_hash: manifest, return_exit_code: true)
      expect(exit_code).to eq(0)
      expect(out).to include('Succeeded')
    end
  end

  context 'when a job spec specifies an optional key in a provides link' do
    it 'should fail when uploading the release' do
      expect do
        bosh_runner.run("upload-release #{asset_path('links_releases/corrupted_release_optional_provides-0+dev.1.tgz')}")
      end.to raise_error(
        RuntimeError,
        /Error: Link 'node1' of type 'node1' is a provides link, not allowed to have 'optional' key/,
      )
    end
  end

  context 'when a consumed link is set to nil in the deployment manifest' do
    context 'when the link is optional and it does not exist' do
      let(:links) do
        {
          'db' => { 'from' => 'db' },
          'backup_db' => { 'from' => 'backup_db' },
          'optional_link_name' => 'nil',
        }
      end

      it 'should not render link data in job template' do
        deploy_simple_manifest(manifest_hash: manifest)

        link_instance = director.instance('my_api', '0')
        template = YAML.safe_load(link_instance.read_job_template('api_server_with_optional_links_1', 'config.yml'))

        expect(template['optional_key']).to eq(nil)
      end
    end

    context 'when the link is optional and transitions from implicit to blocked' do
      let(:manifest) do
        manifest = SharedSupport::DeploymentManifestHelper.deployment_manifest
        manifest['instance_groups'] = [
          api_instance_group_with_optional_links_spec_2,
          mysql_instance_group_spec,
        ]
        manifest
      end

      let(:links) do
        {
          'db' => { 'from' => 'db' },
        }
      end

      let(:links2) do
        {
          'db' => { 'from' => 'db' },
          'backup_db' => 'nil',
        }
      end

      it 'should not render link data in job template' do
        deploy_simple_manifest(manifest_hash: manifest)

        link_instance = director.instance('my_api', '0')
        template = YAML.safe_load(link_instance.read_job_template('api_server_with_optional_links_2', 'config.yml'))
        expect(template['databases']['backup']).to_not eq(nil)

        manifest['instance_groups'][0]['jobs'][0]['consumes'] = links2
        deploy_simple_manifest(manifest_hash: manifest)

        link_instance = director.instance('my_api', '0')
        template = YAML.safe_load(link_instance.read_job_template('api_server_with_optional_links_2', 'config.yml'))
        expect(template['databases']['backup']).to eq(nil)
      end
    end

    context 'when the link is optional and transitions from explicit to blocked' do
      let(:manifest) do
        manifest = SharedSupport::DeploymentManifestHelper.deployment_manifest
        manifest['instance_groups'] = [
          api_instance_group_with_optional_links_spec_2,
          mysql_instance_group_spec,
        ]
        manifest
      end

      let(:links) do
        {
          'db' => { 'from' => 'db' },
          'backup_db' => { 'from' => 'db' },
        }
      end

      let(:links2) do
        {
          'db' => { 'from' => 'db' },
          'backup_db' => 'nil',
        }
      end

      it 'should not render link data in job template' do
        deploy_simple_manifest(manifest_hash: manifest)

        link_instance = director.instance('my_api', '0')
        template = YAML.safe_load(link_instance.read_job_template('api_server_with_optional_links_2', 'config.yml'))
        expect(template['databases']['backup']).to_not eq(nil)

        manifest['instance_groups'][0]['jobs'][0]['consumes'] = links2
        deploy_simple_manifest(manifest_hash: manifest)

        link_instance = director.instance('my_api', '0')
        template = YAML.safe_load(link_instance.read_job_template('api_server_with_optional_links_2', 'config.yml'))
        expect(template['databases']['backup']).to eq(nil)
      end
    end

    context 'when the link is optional and transitions from implicit to not consumable' do
      let(:links) do
        {
        }
      end

      let(:manifest) do
        manifest = SharedSupport::DeploymentManifestHelper.deployment_manifest
        manifest['instance_groups'] = [
          api_instance_group_with_optional_db_link,
          mysql_instance_group_spec,
        ]
        manifest
      end

      it 'should not render link data in job template' do
        deploy_simple_manifest(manifest_hash: manifest)

        link_instance = director.instance('my_api', '0')
        template = YAML.safe_load(link_instance.read_job_template('api_server_with_optional_db_link', 'config.yml'))
        expect(template['databases']['optional_key']).to_not eq(nil)

        manifest['instance_groups'][1]['jobs'][0]['provides'] = { 'db' => 'nil' }
        deploy_simple_manifest(manifest_hash: manifest)

        link_instance = director.instance('my_api', '0')
        template = YAML.safe_load(link_instance.read_job_template('api_server_with_optional_db_link', 'config.yml'))
        expect(template['databases']['optional_key']).to eq(nil)
      end
    end

    context 'when the link is optional and transitions from explicit to not consumable and implicit' do
      let(:links) do
        {
          'db' => { 'from' => 'db' },
        }
      end

      let(:manifest) do
        manifest = SharedSupport::DeploymentManifestHelper.deployment_manifest
        manifest['instance_groups'] = [
          api_instance_group_with_optional_db_link,
          mysql_instance_group_spec,
        ]
        manifest
      end

      it 'should not render link data in job template' do
        deploy_simple_manifest(manifest_hash: manifest)

        link_instance = director.instance('my_api', '0')
        template = YAML.safe_load(link_instance.read_job_template('api_server_with_optional_db_link', 'config.yml'))
        expect(template['databases']['optional_key']).to_not eq(nil)

        manifest['instance_groups'][1]['jobs'][0]['provides'] = { 'db' => 'nil' }
        manifest['instance_groups'][0]['jobs'][0]['consumes'] = {}
        deploy_simple_manifest(manifest_hash: manifest)

        link_instance = director.instance('my_api', '0')
        template = YAML.safe_load(link_instance.read_job_template('api_server_with_optional_db_link', 'config.yml'))
        expect(template['databases']['optional_key']).to eq(nil)
      end
    end

    context 'when the link is optional and it exists' do
      let(:links) do
        {
          'db' => { 'from' => 'db' },
          'backup_db' => 'nil',
        }
      end

      let(:manifest) do
        manifest = SharedSupport::DeploymentManifestHelper.deployment_manifest
        manifest['instance_groups'] = [
          api_instance_group_with_optional_links_spec_2,
          mysql_instance_group_spec,
          postgres_instance_group_spec,
        ]
        manifest
      end

      it 'should not render link data in job template' do
        deploy_simple_manifest(manifest_hash: manifest)

        link_instance = director.instance('my_api', '0')
        template = YAML.safe_load(link_instance.read_job_template('api_server_with_optional_links_2', 'config.yml'))

        expect(template['databases']['backup']).to eq(nil)
      end
    end

    context 'when the link is not optional' do
      let(:links) do
        {
          'db' => 'nil',
          'backup_db' => { 'from' => 'backup_db' },
        }
      end

      it 'should throw an error' do
        out, exit_code = deploy_simple_manifest(manifest_hash: manifest, failure_expected: true, return_exit_code: true)
        expect(exit_code).not_to eq(0)
        expect(out).to include(<<~OUTPUT.strip)
          Error: Failed to resolve links from deployment 'simple'. See errors below:
            - Failed to resolve link 'db' with type 'db' from job 'api_server_with_optional_links_1' in instance group 'my_api'. Details below:
              - No link providers found
        OUTPUT
      end
    end
  end

  context 'when if_link and else_if_link are used in job templates' do
    let(:links) do
      {
        'db' => { 'from' => 'db' },
        'backup_db' => { 'from' => 'backup_db' },
      }
    end

    let(:manifest) do
      manifest = SharedSupport::DeploymentManifestHelper.deployment_manifest
      manifest['instance_groups'] = [
        api_instance_group_with_optional_links_spec_2,
        mysql_instance_group_spec,
        postgres_instance_group_spec,
      ]
      manifest
    end

    it 'should respect their behavior' do
      deploy_simple_manifest(manifest_hash: manifest)

      link_instance = director.instance('my_api', '0')
      template = YAML.safe_load(link_instance.read_job_template('api_server_with_optional_links_2', 'config.yml'))

      expect(template['databases']['backup2'][0]['name']).to eq('postgres')
      expect(template['databases']['backup2'][0]['az']).to eq('z1')
      expect(template['databases']['backup2'][0]['index']).to eq(0)
      expect(template['databases']['backup2'][0]['address']).to eq('192.168.1.12')
      expect(template['databases']['backup3']).to eq('happy')
    end
  end

  context 'when the optional link is used without if_link in templates' do
    let(:api_instance_group_with_bad_optional_links) do
      spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
        name: 'my_api',
        jobs: [
          'name' => 'api_server_with_bad_optional_links',
          'release' => 'bosh-release',
        ],
        instances: 1,
      )
      spec['azs'] = ['z1']
      spec
    end

    let(:manifest) do
      manifest = SharedSupport::DeploymentManifestHelper.deployment_manifest
      manifest['instance_groups'] = [api_instance_group_with_bad_optional_links]
      manifest
    end

    it 'should throw a legitimate error if link was not found' do
      out, = deploy_simple_manifest(manifest_hash: manifest, failure_expected: true, return_exit_code: true)
      expect(out).to include <<~OUTPUT
        Error: Unable to render instance groups for deployment. Errors are:
          - Unable to render jobs for instance group 'my_api'. Errors are:
            - Unable to render templates for job 'api_server_with_bad_optional_links'. Errors are:
              - Error filling in template 'config.yml.erb' (line 3: Can't find link 'optional_link_name')
      OUTPUT
    end
  end

  context 'when multiple links with same type being provided' do
    let(:api_server_with_optional_db_links) do
      spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
        name: 'optional_db',
        jobs: [
          'name' => 'api_server_with_optional_db_link',
          'release' => 'bosh-release',
        ],
        instances: 1,
        static_ips: ['192.168.1.13'],
      )
      spec['azs'] = ['z1']
      spec
    end

    let(:manifest) do
      manifest = SharedSupport::DeploymentManifestHelper.deployment_manifest
      manifest['instance_groups'] = [api_server_with_optional_db_links, mysql_instance_group_spec, postgres_instance_group_spec]
      manifest
    end

    it 'fails when the consumed optional link `from` key is not explicitly set in the deployment manifest' do
      output, exit_code = deploy_simple_manifest(manifest_hash: manifest, failure_expected: true, return_exit_code: true)

      expect(exit_code).not_to eq(0)
      expect(output).to include(<<~OUTPUT.strip)
        Error: Failed to resolve links from deployment 'simple'. See errors below:
          - Failed to resolve link 'db' with type 'db' from job 'api_server_with_optional_db_link' in instance group 'optional_db'. Multiple link providers found:
            - Link provider 'db' from job 'database' in instance group 'mysql' in deployment 'simple'
            - Link provider 'backup_db' from job 'backup_database' in instance group 'postgres' in deployment 'simple'
      OUTPUT
    end
  end
end
