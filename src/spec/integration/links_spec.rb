require 'spec_helper'

describe 'Links', type: :integration do
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

  context 'when job requires link' do
    let(:implied_instance_group_spec) do
      spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
        name: 'my_api',
        jobs: [{ 'name' => 'api_server', 'release' => 'bosh-release' }],
        instances: 1,
      )
      spec['azs'] = ['z1']
      spec
    end

    let(:api_instance_group_spec) do
      spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
        name: 'my_api',
        jobs: [{ 'name' => 'api_server', 'release' => 'bosh-release', 'consumes' => links }],
        instances: 1,
      )
      spec['azs'] = ['z1']
      spec
    end

    let(:mysql_instance_group_spec) do
      spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
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
      spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
        name: 'postgres',
        jobs: [{ 'name' => 'backup_database', 'release' => 'bosh-release' }],
        instances: 1,
        static_ips: ['192.168.1.12'],
      )
      spec['azs'] = ['z1']
      spec
    end

    let(:aliased_instance_group_spec) do
      spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
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

    let(:mongo_db_spec) do
      spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
        name: 'mongo',
        jobs: [{ 'name' => 'mongo_db', 'release' => 'bosh-release' }],
        instances: 1,
        static_ips: ['192.168.1.13'],
      )
      spec['azs'] = ['z1']
      spec
    end

    let(:manifest) do
      manifest = SharedSupport::DeploymentManifestHelper.deployment_manifest
      manifest['instance_groups'] = [api_instance_group_spec, mysql_instance_group_spec, postgres_instance_group_spec]
      manifest
    end

    let(:links) do
      {}
    end

    context 'when job consumes link with nested properties' do
      let(:link_instance_group_spec) do
        spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
          name: 'my_links',
          jobs: [
            {
              'name' => 'provider',
              'release' => 'bosh-release',
              'properties' => { 'b' => 'value_b', 'nested' => { 'three' => 'bar' } },
            },
            { 'name' => 'consumer', 'release' => 'bosh-release' },
          ],
          instances: 1,
        )
        spec['azs'] = ['z1']
        spec
      end

      it 'respects default properties' do
        manifest['instance_groups'] = [link_instance_group_spec]
        deploy_simple_manifest(manifest_hash: manifest)

        link_instance = director.find_instance(director.instances, 'my_links', '0')

        template = YAML.safe_load(link_instance.read_job_template('consumer', 'config.yml'))

        expect(template['a']).to eq('default_a')
        expect(template['b']).to eq('value_b')
        expect(template['c']).to eq('default_c')

        expect(template['nested'].size).to eq(3)
        expect(template['nested']).to eq(
          'one' => 'default_nested.one',
          'two' => 'default_nested.two',
          'three' => 'bar',
        )
      end
    end

    context 'when link is provided' do
      let(:links) do
        {
          'db' => { 'from' => 'db' },
          'backup_db' => { 'from' => 'backup_db' },
        }
      end

      it 'renders link data in job template' do
        deploy_simple_manifest(manifest_hash: manifest)

        instances = director.instances
        link_instance = director.find_instance(instances, 'my_api', '0')
        mysql_0_instance = director.find_instance(instances, 'mysql', '0')
        mysql_1_instance = director.find_instance(instances, 'mysql', '1')

        template = YAML.safe_load(link_instance.read_job_template('api_server', 'config.yml'))

        expect(template['databases']['main'].size).to eq(2)
        expect(template['databases']['main']).to contain_exactly(
          {
            'id' => mysql_0_instance.id.to_s,
            'name' => 'mysql',
            'index' => 0,
            'address' => "#{mysql_0_instance.id}.mysql.dynamic-network.simple.bosh",
          },
          {
            'id' => mysql_1_instance.id.to_s,
            'name' => 'mysql',
            'index' => 1,
            'address' => "#{mysql_1_instance.id}.mysql.dynamic-network.simple.bosh",
          },
        )

        expect(template['databases']['backup']).to contain_exactly(
          'name' => 'postgres',
          'az' => 'z1',
          'index' => 0,
          'address' => '192.168.1.12',
        )
      end
    end

    context 'when consumes link is renamed by `from` key' do
      let(:manifest) do
        manifest = SharedSupport::DeploymentManifestHelper.deployment_manifest
        manifest['instance_groups'] = [api_instance_group_spec, mongo_db_spec, mysql_instance_group_spec]
        manifest
      end

      let(:links) do
        {
          'db' => { 'from' => 'db' },
          'backup_db' => { 'from' => 'read_only_db' },
        }
      end

      it 'renders link data in job template' do
        deploy_simple_manifest(manifest_hash: manifest)

        link_instance = director.instance('my_api', '0')
        template = YAML.safe_load(link_instance.read_job_template('api_server', 'config.yml'))

        expect(template['databases']['backup'].size).to eq(1)
        expect(template['databases']['backup']).to contain_exactly(
          'name' => 'mongo',
          'index' => 0,
          'az' => 'z1',
          'address' => '192.168.1.13',
        )
      end
    end

    context 'when manifest has conflicting custom provider definitions' do
      it 'returns error when conflicting with release spec in same job' do
        custom_provider_job = {
          'name' => 'mongo_db',
          'release' => 'bosh-release',
          'custom_provider_definitions' => [
            {
              'name' => 'read_only_db',
              'type' => 'smurf',
            },
          ],
        }
        mongo_db_spec['jobs'] = [custom_provider_job]
        manifest = SharedSupport::DeploymentManifestHelper.deployment_manifest
        manifest['instance_groups'] = [mongo_db_spec]

        output = deploy_simple_manifest(manifest_hash: manifest, failure_expected: true)
        expect(output).to include("Custom provider 'read_only_db' in job 'mongo_db' in instance group 'mongo' is already defined in release 'bosh-release'")
      end

      it 'returns error when conflicting with another custom definition' do
        custom_provider_job = {
          'name' => 'mongo_db',
          'release' => 'bosh-release',
          'custom_provider_definitions' => [
            {
              'name' => 'gargamel',
              'type' => 'smurf'
            },
            {
              'name' => 'gargamel',
              'type' => 'person'
            }
          ],
        }
        mongo_db_spec['jobs'] = [custom_provider_job]
        manifest = SharedSupport::DeploymentManifestHelper.deployment_manifest
        manifest['instance_groups'] = [mongo_db_spec]

        output = deploy_simple_manifest(manifest_hash: manifest, failure_expected: true)
        expect(output).to include("Custom provider 'gargamel' in job 'mongo_db' in instance group 'mongo' is defined multiple times in manifest.")
      end
    end

    context 'when manifest has non-conflicting custom provider definitions' do
      let(:link_instance_group_spec) do
        spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
          name: 'my_links',
          jobs: [
            {
              'name' => 'provider_without_provides',
              'release' => 'bosh-release',
              'custom_provider_definitions' => [
                {
                  'name' => 'provider',
                  'type' => 'provider',
                  'properties' => [
                    'a',
                    'b',
                    'c',
                    'nested.one',
                    'nested.two',
                    'nested.three',
                  ]
                },
              ],
              'properties' => { 'b' => 'value_b', 'nested' => { 'three' => 'bar' } },
            },
            {
              'name' => 'consumer',
              'release' => 'bosh-release',
            },
          ],
          instances: 1,
        )
        spec['azs'] = ['z1']
        spec
      end

      it 'respects default properties and should create link successfully' do
        manifest['instance_groups'] = [link_instance_group_spec]
        deploy_simple_manifest(manifest_hash: manifest)

        link_instance = director.find_instance(director.instances, 'my_links', '0')

        template = YAML.safe_load(link_instance.read_job_template('consumer', 'config.yml'))

        expect(template['a']).to eq('default_a')
        expect(template['b']).to eq('value_b')
        expect(template['c']).to eq('default_c')

        expect(template['nested'].size).to eq(3)
        expect(template['nested']).to eq(
                                        'one' => 'default_nested.one',
                                        'two' => 'default_nested.two',
                                        'three' => 'bar',
                                        )
      end
    end

    context 'when release job requires and provides same link' do
      let(:first_node_instance_group_spec) do
        spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
          name: 'first_node',
          jobs: [{ 'name' => 'node', 'release' => 'bosh-release', 'consumes' => first_node_links }],
          instances: 1,
          static_ips: ['192.168.1.10'],
        )
        spec['azs'] = ['z1']
        spec
      end

      let(:first_node_links) do
        {
          'node1' => { 'from' => 'node1' },
          'node2' => { 'from' => 'node2' },
        }
      end

      let(:second_node_instance_group_spec) do
        spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
          name: 'second_node',
          jobs: [{ 'name' => 'node', 'release' => 'bosh-release', 'consumes' => second_node_links }],
          instances: 1,
          static_ips: ['192.168.1.11'],
        )
        spec['azs'] = ['z1']
        spec
      end
      let(:second_node_links) do
        {
          'node1' => { 'from' => 'node1' },
          'node2' => { 'from' => 'node2' },
        }
      end

      let(:manifest) do
        manifest = SharedSupport::DeploymentManifestHelper.deployment_manifest
        manifest['instance_groups'] = [first_node_instance_group_spec, second_node_instance_group_spec]
        manifest
      end

      it 'renders link data in job template' do
        _, exit_code = deploy_simple_manifest(manifest_hash: manifest, failure_expected: true, return_exit_code: true)
        expect(exit_code).not_to eq(0)
      end
    end

    context 'when provide and consume links are set in spec, but only implied by deployment manifest' do
      let(:manifest) do
        manifest = SharedSupport::DeploymentManifestHelper.deployment_manifest
        manifest['instance_groups'] = [implied_instance_group_spec, postgres_instance_group_spec]
        manifest
      end

      it 'renders link data in job template' do
        deploy_simple_manifest(manifest_hash: manifest)

        link_instance = director.instance('my_api', '0')
        template = YAML.safe_load(link_instance.read_job_template('api_server', 'config.yml'))

        postgres_instance = director.instance('postgres', '0')

        expect(template['databases']['main'].size).to eq(1)
        expect(template['databases']['main']).to contain_exactly(
          'id' => postgres_instance.id.to_s,
          'name' => 'postgres',
          'index' => 0,
          'address' => '192.168.1.12',
        )

        expect(template['databases']['backup'].size).to eq(1)
        expect(template['databases']['backup']).to contain_exactly(
          'name' => 'postgres',
          'index' => 0,
          'az' => 'z1',
          'address' => '192.168.1.12',
        )
      end
    end

    context 'multiple provide links with same type' do
      context 'when both provided links are on separate templates' do
        let(:manifest) do
          manifest = SharedSupport::DeploymentManifestHelper.deployment_manifest
          manifest['instance_groups'] = [implied_instance_group_spec, postgres_instance_group_spec, mysql_instance_group_spec]
          manifest
        end

        it 'raises error before deploying vms' do
          _, exit_code = deploy_simple_manifest(manifest_hash: manifest, failure_expected: true, return_exit_code: true)
          expect(exit_code).not_to eq(0)
          expect(director.instances).to be_empty
        end
      end

      context 'when both provided links are in same template' do
        let(:instance_group_with_same_type_links) do
          spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
            name: 'duplicate_link_type_job',
            jobs: [{ 'name' => 'database_with_two_provided_link_of_same_type', 'release' => 'bosh-release' }],
            instances: 1,
          )
          spec['azs'] = ['z1']
          spec
        end

        let(:manifest) do
          manifest = SharedSupport::DeploymentManifestHelper.deployment_manifest
          manifest['instance_groups'] = [implied_instance_group_spec, instance_group_with_same_type_links]
          manifest
        end

        it 'raises error' do
          _, exit_code = deploy_simple_manifest(manifest_hash: manifest, failure_expected: true, return_exit_code: true)
          expect(exit_code).not_to eq(0)
          expect(director.instances).to be_empty
        end
      end

      context 'when one link is manual' do
        let(:manual_api_server) do
          {
            'name' => 'api_server_with_optional_db_link',
            'release' => 'bosh-release',
            'consumes' => {
              'db' => {
                'address' => '192.168.1.254',
                'instances' => [{ 'address' => 'teswfbquts.cabsfabuo7yr.us-east-1.rds.amazonaws.com' }],
                'properties' => {},
              },
              'backup_db' => 'nil',
            },
          }
        end

        let(:manual_api_instance_group_spec) do
          spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
            name: 'my_manual_api',
            jobs: [manual_api_server],
            instances: 1,
          )
          spec['azs'] = ['z1']
          spec
        end

        let(:manifest) do
          manifest = SharedSupport::DeploymentManifestHelper.deployment_manifest
          manifest['instance_groups'] = [
            manual_api_instance_group_spec, implied_instance_group_spec, postgres_instance_group_spec
          ]
          manifest
        end

        it 'deploy without any error' do
          deploy_simple_manifest(manifest_hash: manifest)
        end

        context 'and it has the same name as the explicit link' do
          let(:manifest) do
            manifest = SharedSupport::DeploymentManifestHelper.deployment_manifest
            manifest['instance_groups'] = [
              manual_api_instance_group_spec, api_instance_group_spec, postgres_instance_group_spec, mysql_instance_group_spec
            ]
            manifest
          end

          let(:links) do
            {
              'db' => { 'from' => 'db' },
              'backup_db' => { 'from' => 'backup_db' },
            }
          end

          it 'deploy without any error' do
            deploy_simple_manifest(manifest_hash: manifest)
          end
        end
      end

      context 'when two links are manual' do
        let(:manual_api_server) do
          {
            'name' => 'api_server',
            'release' => 'bosh-release',
            'consumes' => {
              'db' => {
                'address' => '192.168.1.254',
                'instances' => [{ 'address' => 'teswfbquts.cabsfabuo7yr.us-east-1.rds.amazonaws.com' }],
                'properties' => { 'foo' => 4 },
              },
              'backup_db' => {
                'address' => '192.168.1.253',
                'instances' => [{ 'address' => 'jkhfasfdkj.cabsfabuo7yr.us-east-1.rds.amazonaws.com' }],
                'properties' => { 'foo' => 5 },
              },
            },
          }
        end

        let(:manual_api_instance_group_spec) do
          spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
            name: 'my_manual_api',
            jobs: [
              manual_api_server,
              {
                'name' => 'api_server_with_optional_db_link',
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
          manifest['instance_groups'] = [manual_api_instance_group_spec]
          manifest
        end

        it 'deploy without any error' do
          deploy_simple_manifest(manifest_hash: manifest)
        end
      end

      context 'when two idential links are manual in different instance groups' do
        let(:manual_api_server) do
          {
            'name' => 'api_server_with_optional_db_link',
            'release' => 'bosh-release',
            'consumes' => {
              'db' => {
                'address' => '192.168.1.254',
                'instances' => [{ 'address' => 'jkhfasfdkj.cabsfabuo7yr.us-east-1.rds.amazonaws.com' }],
                'properties' => {},
              },
            },
          }
        end

        let(:manual_api_instance_group_spec) do
          spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
            name: 'my_manual_api',
            jobs: [manual_api_server],
            instances: 1,
          )
          spec['azs'] = ['z1']
          spec
        end

        let(:manual_api_server2) do
          {
            'name' => 'api_server_with_optional_db_link',
            'release' => 'bosh-release',
            'consumes' => {
              'db' => {
                'address' => '192.168.1.253',
                'instances' => [{ 'address' => 'teswfbquts.cabsfabuo7yr.us-east-1.rds.amazonaws.com' }],
                'properties' => {},
              },
            },
          }
        end

        let(:manual_api_instance_group_spec2) do
          spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
            name: 'your_manual_api',
            jobs: [manual_api_server2],
            instances: 1,
          )
          spec['azs'] = ['z1']
          spec
        end

        let(:manifest) do
          manifest = SharedSupport::DeploymentManifestHelper.deployment_manifest
          manifest['instance_groups'] = [manual_api_instance_group_spec, manual_api_instance_group_spec2]
          manifest
        end

        it 'deploy without any error' do
          deploy_simple_manifest(manifest_hash: manifest)
        end
      end
    end

    context 'when link provider specifies properties from job spec' do
      let(:mysql_instance_group_spec) do
        spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
          name: 'mysql',
          jobs: [
            'name' => 'database',
            'release' => 'bosh-release',
            'properties' => { 'test' => 'test value' },
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

      let(:manifest) do
        manifest = SharedSupport::DeploymentManifestHelper.deployment_manifest
        manifest['instance_groups'] = [mysql_instance_group_spec]
        manifest
      end

      it 'allows to be deployed' do
        expect { deploy_simple_manifest(manifest_hash: manifest) }.to_not raise_error
      end
    end

    context 'when link provider specifies properties not listed in job spec properties' do
      let(:mysql_instance_group_spec) do
        spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
          name: 'mysql',
          jobs: [{ 'name' => 'provider_fail', 'release' => 'bosh-release' }],
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

      it 'fails if the property specified for links is not provided by job template' do
        expect do
          deploy_simple_manifest(manifest_hash: manifest)
        end.to raise_error(
          RuntimeError,
          /Link property b in template provider_fail is not defined in release spec/,
        )
      end
    end

    context 'when resurrector tries to resurrect an VM with jobs that consume links', hm: true do
      with_reset_hm_before_each

      let(:links) do
        {
          'db' => { 'from' => 'db' },
          'backup_db' => { 'from' => 'backup_db' },
        }
      end

      it 'resurrects the VM and resolves links correctly', hm: true do
        deploy_simple_manifest(manifest_hash: manifest)

        instances = director.instances
        api_instance = director.find_instance(instances, 'my_api', '0')
        mysql_0_instance = director.find_instance(instances, 'mysql', '0')
        mysql_1_instance = director.find_instance(instances, 'mysql', '1')

        template = YAML.safe_load(api_instance.read_job_template('api_server', 'config.yml'))

        expect(template['databases']['main'].size).to eq(2)
        expect(template['databases']['main']).to contain_exactly(
          {
            'id' => mysql_0_instance.id.to_s,
            'name' => 'mysql',
            'index' => 0,
            'address' => "#{mysql_0_instance.id}.mysql.dynamic-network.simple.bosh",
          },
          {
            'id' => mysql_1_instance.id.to_s,
            'name' => 'mysql',
            'index' => 1,
            'address' => "#{mysql_1_instance.id}.mysql.dynamic-network.simple.bosh",
          },
        )

        expect(template['databases']['backup']).to contain_exactly(
          'name' => 'postgres',
          'az' => 'z1',
          'index' => 0,
          'address' => '192.168.1.12',
        )

        # ===========================================
        # After resurrection
        new_api_instance = director.kill_vm_and_wait_for_resurrection(api_instance)
        new_template = YAML.safe_load(new_api_instance.read_job_template('api_server', 'config.yml'))
        expect(new_template['databases']['main'].size).to eq(2)
        expect(new_template['databases']['main']).to contain_exactly(
          {
            'id' => mysql_0_instance.id.to_s,
            'name' => 'mysql',
            'index' => 0,
            'address' => "#{mysql_0_instance.id}.mysql.dynamic-network.simple.bosh",
          },
          {
            'id' => mysql_1_instance.id.to_s,
            'name' => 'mysql',
            'index' => 1,
            'address' => "#{mysql_1_instance.id}.mysql.dynamic-network.simple.bosh",
          },
        )

        expect(new_template['databases']['backup']).to contain_exactly(
          'name' => 'postgres',
          'az' => 'z1',
          'index' => 0,
          'address' => '192.168.1.12',
        )
      end
    end
  end

  context 'when addon job requires link' do
    let(:mysql_instance_group_spec) do
      spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
        name: 'mysql',
        jobs: [{ 'name' => 'database', 'release' => 'bosh-release' }],
        instances: 1,
        static_ips: ['192.168.1.10'],
      )
      spec['azs'] = ['z1']
      spec['networks'] << {
        'name' => 'dynamic-network',
        'default' => %w[dns gateway],
      }
      spec
    end

    before do
      runtime_config_file = yaml_file('runtime_config.yml', SharedSupport::DeploymentManifestHelper.runtime_config_with_links)
      bosh_runner.run("update-runtime-config #{runtime_config_file.path}")
    end

    it 'should resolve links for addons' do
      manifest = SharedSupport::DeploymentManifestHelper.deployment_manifest
      manifest['releases'][0]['version'] = '0+dev.1'
      manifest['instance_groups'] = [mysql_instance_group_spec]

      deploy_simple_manifest(manifest_hash: manifest)

      my_sql_instance = director.instance('mysql', '0', deployment_name: 'simple')
      template = YAML.safe_load(my_sql_instance.read_job_template('addon', 'config.yml'))

      template['databases'].each_value do |database|
        database.each do |instance|
          expect(instance['address']).to match(/.dynamic-network./)
        end
      end
    end
  end

  context 'when link is not satisfied in deployment' do
    let(:bad_properties_instance_group_spec) do
      spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
        name: 'api_server_with_bad_link_types',
        jobs: [{ 'name' => 'api_server_with_bad_link_types', 'release' => 'bosh-release' }],
        instances: 1,
        static_ips: ['192.168.1.10'],
      )
      spec['azs'] = ['z1']
      spec['networks'] << {
        'name' => 'dynamic-network',
        'default' => %w[dns gateway],
      }
      spec
    end

    it 'should show all errors' do
      # Will be fixed with story #154604546
      manifest = SharedSupport::DeploymentManifestHelper.deployment_manifest
      manifest['releases'][0]['version'] = '0+dev.1'
      manifest['instance_groups'] = [bad_properties_instance_group_spec]

      out, exit_code = deploy_simple_manifest(manifest_hash: manifest, failure_expected: true, return_exit_code: true)

      expect(exit_code).not_to eq(0)

      expect(out).to include("No link providers found").at_least(3).times
      expect(out).to include("- Failed to resolve link 'db' with type 'bad_link' from job 'api_server_with_bad_link_types' in instance group 'api_server_with_bad_link_types'. Details below:")
      expect(out).to include("- Failed to resolve link 'backup_db' with type 'bad_link_2' from job 'api_server_with_bad_link_types' in instance group 'api_server_with_bad_link_types'. Details below:")
      expect(out).to include("- Failed to resolve link 'some_link_name' with type 'bad_link_3' from job 'api_server_with_bad_link_types' in instance group 'api_server_with_bad_link_types'. Details below:")

    end
  end
end
