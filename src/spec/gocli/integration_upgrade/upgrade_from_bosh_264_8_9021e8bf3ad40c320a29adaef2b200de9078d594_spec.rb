require_relative '../spec_helper'

describe 'director upgrade after refactoring links into separate database tables', type: :upgrade do
  with_reset_sandbox_before_each(test_initial_state: 'bosh-v264.8-c2b5bf268ea6420e4a3f1f657dc45b7db3720216', drop_database: true)

  describe '#bosh start' do
    it 'can start the hard stopped implicit link deployment' do
      expected_template = {
        'databases' => {
          'main' => [{ 'id' => String, 'name' => 'implicit_provider_ig', 'index' => 0, 'address' => '192.168.1.5' }],
          'main_properties' => 'backup_bar',
          'backup' => [{ 'name' => 'implicit_provider_ig', 'az' => 'z1', 'index' => 0, 'address' => '192.168.1.5' }],
          'backup_properties' => 'backup_bar',
        },
        'db_az_link' => { 'address' => 'q-a1s0.implicit-provider-ig.a.implicit-deployment.bosh' },
        'optional_backup_link' => [{ 'address' => 'q-s0.implicit-provider-ig.a.implicit-deployment.bosh' }],
      }

      output = scrub_random_ids(parse_blocks(bosh_runner.run('-d implicit_deployment start', json: true)))
      expect(output).to include('Creating missing vms: implicit_provider_ig/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0)')
      expect(output).to include('Creating missing vms: implicit_consumer_ig/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0)')
      expect(output).to include('Updating instance implicit_provider_ig: implicit_provider_ig/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0) (canary)')
      expect(output).to include('Updating instance implicit_consumer_ig: implicit_consumer_ig/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0) (canary)')

      new_instance = director.instance('implicit_consumer_ig', '0', deployment_name: 'implicit_deployment')
      new_template = YAML.safe_load(new_instance.read_job_template('api_server', 'config.yml'))
      expect(new_template).to match(expected_template)
    end

    it 'can start the hard stopped explicit link deployment' do
      expected_template = {
        'databases' => {
          'main' => [{ 'id' => String, 'name' => 'explicit_provider_ig', 'index' => 0, 'address' => '192.168.1.7' }],
          'main_properties' => 'backup_bar',
          'backup' => [{ 'name' => 'explicit_provider_ig', 'az' => 'z1', 'index' => 0, 'address' => '192.168.1.7' }],
          'backup_properties' => 'backup_bar',
        },
        'db_az_link' => { 'address' => 'q-a1s0.explicit-provider-ig.a.explicit-deployment.bosh' },
        'optional_backup_link' => [{ 'address' => 'q-s0.explicit-provider-ig.a.explicit-deployment.bosh' }],
      }

      output = scrub_random_ids(parse_blocks(bosh_runner.run('-d explicit_deployment start', json: true)))
      expect(output).to include('Creating missing vms: explicit_provider_ig/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0)')
      expect(output).to include('Creating missing vms: explicit_consumer_ig/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0)')
      expect(output).to include('Updating instance explicit_provider_ig: explicit_provider_ig/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0) (canary)')
      expect(output).to include('Updating instance explicit_consumer_ig: explicit_consumer_ig/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0) (canary)')

      new_instance = director.instance('explicit_consumer_ig', '0', deployment_name: 'explicit_deployment')
      new_template = YAML.safe_load(new_instance.read_job_template('api_server', 'config.yml'))
      expect(new_template).to match(expected_template)
    end

    it 'can start the hard stopped shared link provider deployment' do
      output = scrub_random_ids(parse_blocks(bosh_runner.run('-d shared_provider_deployment start', json: true)))
      expect(output).to include('Creating missing vms: shared_provider_ig/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0)')
      expect(output).to include('Updating instance shared_provider_ig: shared_provider_ig/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0) (canary)')
    end

    it 'can start the hard stopped consumer of shared deployment' do
      expected_template = {
        'databases' => {
          'main' => [{ 'id' => String, 'name' => 'shared_provider_ig', 'index' => 0, 'address' => '192.168.1.3' }],
          'main_properties' => 'normal_bar',
          'backup' => [{ 'name' => 'shared_provider_ig', 'az' => 'z1', 'index' => 0, 'address' => '192.168.1.3' }],
          'backup_properties' => 'normal_bar',
        },
        'db_az_link' => { 'address' => 'q-a1s0.shared-provider-ig.a.shared-provider-deployment.bosh' },
        'optional_backup_link' => [{ 'address' => 'q-s0.shared-provider-ig.a.shared-provider-deployment.bosh' }],
      }

      output = scrub_random_ids(parse_blocks(bosh_runner.run('-d shared_consumer_deployment start', json: true)))
      expect(output).to include('Creating missing vms: shared_consumer_ig/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0)')
      expect(output).to include('Updating instance shared_consumer_ig: shared_consumer_ig/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0) (canary)')

      new_instance = director.instance('shared_consumer_ig', '0', deployment_name: 'shared_consumer_deployment')
      new_template = YAML.safe_load(new_instance.read_job_template('api_server', 'config.yml'))
      expect(new_template).to match(expected_template)
    end
  end

  describe '#bosh recreate' do
    it 'can start the hard stopped implicit link deployment' do
      expected_template = {
        'databases' => {
          'main' => [{ 'id' => String, 'name' => 'implicit_provider_ig', 'index' => 0, 'address' => '192.168.1.5' }],
          'main_properties' => 'backup_bar',
          'backup' => [{ 'name' => 'implicit_provider_ig', 'az' => 'z1', 'index' => 0, 'address' => '192.168.1.5' }],
          'backup_properties' => 'backup_bar',
        },
        'db_az_link' => { 'address' => 'q-a1s0.implicit-provider-ig.a.implicit-deployment.bosh' },
        'optional_backup_link' => [{ 'address' => 'q-s0.implicit-provider-ig.a.implicit-deployment.bosh' }],
      }

      output = scrub_random_ids(parse_blocks(bosh_runner.run('-d implicit_deployment recreate', json: true)))
      expect(output).to include('Creating missing vms: implicit_provider_ig/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0)')
      expect(output).to include('Creating missing vms: implicit_consumer_ig/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0)')
      expect(output).to include('Updating instance implicit_provider_ig: implicit_provider_ig/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0) (canary)')
      expect(output).to include('Updating instance implicit_consumer_ig: implicit_consumer_ig/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0) (canary)')

      new_instance = director.instance('implicit_consumer_ig', '0', deployment_name: 'implicit_deployment')
      new_template = YAML.safe_load(new_instance.read_job_template('api_server', 'config.yml'))
      expect(new_template).to match(expected_template)
    end

    it 'can start the hard stopped explicit link deployment' do
      expected_template = {
        'databases' => {
          'main' => [{ 'id' => String, 'name' => 'explicit_provider_ig', 'index' => 0, 'address' => '192.168.1.7' }],
          'main_properties' => 'backup_bar',
          'backup' => [{ 'name' => 'explicit_provider_ig', 'az' => 'z1', 'index' => 0, 'address' => '192.168.1.7' }],
          'backup_properties' => 'backup_bar',
        },
        'db_az_link' => { 'address' => 'q-a1s0.explicit-provider-ig.a.explicit-deployment.bosh' },
        'optional_backup_link' => [{ 'address' => 'q-s0.explicit-provider-ig.a.explicit-deployment.bosh' }],
      }

      output = scrub_random_ids(parse_blocks(bosh_runner.run('-d explicit_deployment recreate', json: true)))
      expect(output).to include('Creating missing vms: explicit_provider_ig/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0)')
      expect(output).to include('Creating missing vms: explicit_consumer_ig/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0)')
      expect(output).to include('Updating instance explicit_provider_ig: explicit_provider_ig/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0) (canary)')
      expect(output).to include('Updating instance explicit_consumer_ig: explicit_consumer_ig/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0) (canary)')

      new_instance = director.instance('explicit_consumer_ig', '0', deployment_name: 'explicit_deployment')
      new_template = YAML.safe_load(new_instance.read_job_template('api_server', 'config.yml'))
      expect(new_template).to match(expected_template)
    end

    it 'can start the hard stopped shared link provider deployment' do
      output = scrub_random_ids(parse_blocks(bosh_runner.run('-d shared_provider_deployment recreate', json: true)))
      expect(output).to include('Creating missing vms: shared_provider_ig/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0)')
      expect(output).to include('Updating instance shared_provider_ig: shared_provider_ig/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0) (canary)')
    end

    it 'can start the hard stopped consumer of shared deployment' do
      expected_template = {
        'databases' => {
          'main' => [{ 'id' => String, 'name' => 'shared_provider_ig', 'index' => 0, 'address' => '192.168.1.3' }],
          'main_properties' => 'normal_bar',
          'backup' => [{ 'name' => 'shared_provider_ig', 'az' => 'z1', 'index' => 0, 'address' => '192.168.1.3' }],
          'backup_properties' => 'normal_bar',
        },
        'db_az_link' => { 'address' => 'q-a1s0.shared-provider-ig.a.shared-provider-deployment.bosh' },
        'optional_backup_link' => [{ 'address' => 'q-s0.shared-provider-ig.a.shared-provider-deployment.bosh' }],
      }

      output = scrub_random_ids(parse_blocks(bosh_runner.run('-d shared_consumer_deployment recreate', json: true)))
      expect(output).to include('Creating missing vms: shared_consumer_ig/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0)')
      expect(output).to include('Updating instance shared_consumer_ig: shared_consumer_ig/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0) (canary)')

      new_instance = director.instance('shared_consumer_ig', '0', deployment_name: 'shared_consumer_deployment')
      new_template = YAML.safe_load(new_instance.read_job_template('api_server', 'config.yml'))
      expect(new_template).to match(expected_template)
    end
  end

  describe '#bosh deploy (redeploy)' do
    context 'When redeploying implicit consumer deployment' do
      let(:implicit_provider_instance_group) do
        Bosh::Spec::NewDeployments.simple_instance_group(
          name: 'implicit_provider_ig',
          jobs: [{ 'name' => 'backup_database', 'properties' => { 'foo' => 'a_diff_foo' } }],
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

      it 'should use the updated provider for rendering templates' do
        expected_template = {
          'databases' => {
            'main' => [{ 'id' => String, 'name' => 'implicit_provider_ig', 'index' => 0, 'address' => '192.168.1.5' }],
            'main_properties' => 'a_diff_foo',
            'backup' => [{ 'name' => 'implicit_provider_ig', 'az' => 'z1', 'index' => 0, 'address' => '192.168.1.5' }],
            'backup_properties' => 'a_diff_foo',
          },
          'db_az_link' => { 'address' => 'q-a1s0.implicit-provider-ig.a.implicit-deployment.bosh' },
          'optional_backup_link' => [{ 'address' => 'q-s0.implicit-provider-ig.a.implicit-deployment.bosh' }],
        }
        expect do
          deploy_simple_manifest(manifest_hash: implicit_manifest)
          bosh_runner.run('-d implicit_deployment start')
        end.to_not raise_error

        new_instance = director.instance('implicit_consumer_ig', '0', deployment_name: 'implicit_deployment')
        new_template = YAML.safe_load(new_instance.read_job_template('api_server', 'config.yml'))
        expect(new_template).to match(expected_template)
      end
    end

    context 'When redeploying explicit consumer deployment' do
      let(:explicit_provider_instance_group) do
        Bosh::Spec::NewDeployments.simple_instance_group(
          name: 'explicit_provider_ig',
          jobs: [
            {
              'name' => 'backup_database',
              'provides' => {
                'backup_db' => { 'as' => 'explicit_db' },
              },
              'properties' => { 'foo' => 'a_diff_foo' },
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

      it 'should use the updated provider for rendering templates' do
        expected_template = {
          'databases' => {
            'main' => [{ 'id' => String, 'name' => 'explicit_provider_ig', 'index' => 0, 'address' => '192.168.1.7' }],
            'main_properties' => 'a_diff_foo',
            'backup' => [{ 'name' => 'explicit_provider_ig', 'az' => 'z1', 'index' => 0, 'address' => '192.168.1.7' }],
            'backup_properties' => 'a_diff_foo',
          },
          'db_az_link' => { 'address' => 'q-a1s0.explicit-provider-ig.a.explicit-deployment.bosh' },
          'optional_backup_link' => [{ 'address' => 'q-s0.explicit-provider-ig.a.explicit-deployment.bosh' }],
        }

        expect do
          deploy_simple_manifest(manifest_hash: explicit_manifest)
          bosh_runner.run('-d explicit_deployment start')
        end.to_not raise_error

        new_instance = director.instance('explicit_consumer_ig', '0', deployment_name: 'explicit_deployment')
        new_template = YAML.safe_load(new_instance.read_job_template('api_server', 'config.yml'))
        expect(new_template).to match(expected_template)
      end
    end

    context 'when redeploying the consumer of shared provider' do
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

      let(:shared_consumer_deployment_manifest) do
        Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups.tap do |manifest|
          manifest['name'] = 'shared_consumer_deployment'
          manifest['instance_groups'] = [shared_consumer_instance_group]
        end
      end

      it 'should render the templates using the values from before migration' do
        expected_template = {
          'databases' => {
            'main' => [{ 'id' => String, 'name' => 'shared_provider_ig', 'index' => 0, 'address' => '192.168.1.3' }],
            'main_properties' => 'normal_bar',
            'backup' => [{ 'name' => 'shared_provider_ig', 'az' => 'z1', 'index' => 0, 'address' => '192.168.1.3' }],
            'backup_properties' => 'normal_bar',
          },
          'db_az_link' => { 'address' => 'q-a1s0.shared-provider-ig.a.shared-provider-deployment.bosh' },
          'optional_backup_link' => [{ 'address' => 'q-s0.shared-provider-ig.a.shared-provider-deployment.bosh' }],
        }

        expect do
          deploy_simple_manifest(manifest_hash: shared_consumer_deployment_manifest)
          bosh_runner.run('-d shared_consumer_deployment start')
        end.to_not raise_error

        new_instance = director.instance('shared_consumer_ig', '0', deployment_name: 'shared_consumer_deployment')
        new_template = YAML.safe_load(new_instance.read_job_template('api_server', 'config.yml'))
        expect(new_template).to match(expected_template)
      end

      context 'and the shared provider is started' do
        before do
          bosh_runner.run('-d shared_provider_deployment start')
        end

        it 'should render the templates using the values from before migration' do
          expected_template = {
            'databases' => {
              'main' => [{ 'id' => String, 'name' => 'shared_provider_ig', 'index' => 0, 'address' => '192.168.1.3' }],
              'main_properties' => 'normal_bar',
              'backup' => [{ 'name' => 'shared_provider_ig', 'az' => 'z1', 'index' => 0, 'address' => '192.168.1.3' }],
              'backup_properties' => 'normal_bar',
            },
            'db_az_link' => { 'address' => 'q-a1s0.shared-provider-ig.a.shared-provider-deployment.bosh' },
            'optional_backup_link' => [{ 'address' => 'q-s0.shared-provider-ig.a.shared-provider-deployment.bosh' }],
          }

          expect do
            deploy_simple_manifest(manifest_hash: shared_consumer_deployment_manifest)
            bosh_runner.run('-d shared_consumer_deployment start')
          end.to_not raise_error

          new_instance = director.instance('shared_consumer_ig', '0', deployment_name: 'shared_consumer_deployment')
          new_template = YAML.safe_load(new_instance.read_job_template('api_server', 'config.yml'))
          expect(new_template).to match(expected_template)
        end
      end

      context 'and the shared provider is recreated' do
        before do
          bosh_runner.run('-d shared_provider_deployment recreate')
        end

        it 'should render the templates using the values from before migration' do
          expected_template = {
            'databases' => {
              'main' => [{ 'id' => String, 'name' => 'shared_provider_ig', 'index' => 0, 'address' => '192.168.1.3' }],
              'main_properties' => 'normal_bar',
              'backup' => [{ 'name' => 'shared_provider_ig', 'az' => 'z1', 'index' => 0, 'address' => '192.168.1.3' }],
              'backup_properties' => 'normal_bar',
            },
            'db_az_link' => { 'address' => 'q-a1s0.shared-provider-ig.a.shared-provider-deployment.bosh' },
            'optional_backup_link' => [{ 'address' => 'q-s0.shared-provider-ig.a.shared-provider-deployment.bosh' }],
          }

          expect do
            deploy_simple_manifest(manifest_hash: shared_consumer_deployment_manifest)
            bosh_runner.run('-d shared_consumer_deployment start')
          end.to_not raise_error

          new_instance = director.instance('shared_consumer_ig', '0', deployment_name: 'shared_consumer_deployment')
          new_template = YAML.safe_load(new_instance.read_job_template('api_server', 'config.yml'))
          expect(new_template).to match(expected_template)
        end
      end

      context 'and the shared provider is redeployed' do
        let(:properties) do
          {}
        end

        let(:provider_ig_name) do
          'shared_provider_ig'
        end

        let(:shared_provider_instance_group) do
          Bosh::Spec::NewDeployments.simple_instance_group(
            name: provider_ig_name,
            jobs: [
              {
                'name' => 'database',
                'provides' => {
                  'db' => { 'shared' => true, 'as' => 'my_shared_db' },
                },
                'properties' => properties,
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

        before do
          deploy_simple_manifest(manifest_hash: shared_provider_manifest)
        end

        it 'should render the templates using the values from the newly deployed provider' do
          expected_template = {
            'databases' => {
              'main' => [{ 'id' => String, 'name' => 'shared_provider_ig', 'index' => 0, 'address' => '192.168.1.3' }],
              'main_properties' => 'normal_bar',
              'backup' => [{ 'name' => 'shared_provider_ig', 'az' => 'z1', 'index' => 0, 'address' => '192.168.1.3' }],
              'backup_properties' => 'normal_bar',
            },
            'db_az_link' => { 'address' => 'q-a1s0.shared-provider-ig.a.shared-provider-deployment.bosh' },
            'optional_backup_link' => [{ 'address' => 'q-s0.shared-provider-ig.a.shared-provider-deployment.bosh' }],
          }

          expect do
            deploy_simple_manifest(manifest_hash: shared_consumer_deployment_manifest)
            bosh_runner.run('-d shared_consumer_deployment start')
          end.to_not raise_error

          new_instance = director.instance('shared_consumer_ig', '0', deployment_name: 'shared_consumer_deployment')
          new_template = YAML.safe_load(new_instance.read_job_template('api_server', 'config.yml'))
          expect(new_template).to match(expected_template)
        end

        context 'and the properties have changed' do
          let(:properties) do
            { 'foo' => 'a_diff_foo' }
          end

          it 'should render the templates using the values from the newly deployed provider' do
            expected_template = {
              'databases' => {
                'main' => [{ 'id' => String, 'name' => 'shared_provider_ig', 'index' => 0, 'address' => '192.168.1.3' }],
                'main_properties' => 'a_diff_foo',
                'backup' => [{ 'name' => 'shared_provider_ig', 'az' => 'z1', 'index' => 0, 'address' => '192.168.1.3' }],
                'backup_properties' => 'a_diff_foo',
              },
              'db_az_link' => { 'address' => 'q-a1s0.shared-provider-ig.a.shared-provider-deployment.bosh' },
              'optional_backup_link' => [{ 'address' => 'q-s0.shared-provider-ig.a.shared-provider-deployment.bosh' }],
            }

            expect do
              deploy_simple_manifest(manifest_hash: shared_consumer_deployment_manifest)
              bosh_runner.run('-d shared_consumer_deployment start')
            end.to_not raise_error

            new_instance = director.instance('shared_consumer_ig', '0', deployment_name: 'shared_consumer_deployment')
            new_template = YAML.safe_load(new_instance.read_job_template('api_server', 'config.yml'))
            expect(new_template).to match(expected_template)
          end
        end

        context 'and the instance group name has changed' do
          let(:provider_ig_name) do
            'new_shared_provider_ig'
          end

          it 'should render the templates using the values from the newly deployed provider' do
            expected_template = {
              'databases' => {
                'main' => [{ 'id' => String, 'name' => 'new_shared_provider_ig', 'index' => 0, 'address' => /192\.168\.1\./ }],
                'main_properties' => 'normal_bar',
                'backup' => [{ 'name' => 'new_shared_provider_ig', 'az' => 'z1', 'index' => 0, 'address' => /192\.168\.1\./ }],
                'backup_properties' => 'normal_bar',
              },
              'db_az_link' => { 'address' => 'q-a1s0.new-shared-provider-ig.a.shared-provider-deployment.bosh' },
              'optional_backup_link' => [{ 'address' => 'q-s0.new-shared-provider-ig.a.shared-provider-deployment.bosh' }],
            }

            expect do
              deploy_simple_manifest(manifest_hash: shared_consumer_deployment_manifest)
              bosh_runner.run('-d shared_consumer_deployment start')
            end.to_not raise_error

            new_instance = director.instance('shared_consumer_ig', '0', deployment_name: 'shared_consumer_deployment')
            new_template = YAML.safe_load(new_instance.read_job_template('api_server', 'config.yml'))
            expect(new_template).to match(expected_template)
          end
        end
      end

      context 'and the shared provider is redeployed with --recreate flag' do
        let(:properties) do
          {}
        end

        let(:provider_ig_name) do
          'shared_provider_ig'
        end

        let(:shared_provider_instance_group) do
          Bosh::Spec::NewDeployments.simple_instance_group(
            name: provider_ig_name,
            jobs: [
              {
                'name' => 'database',
                'provides' => {
                  'db' => { 'shared' => true, 'as' => 'my_shared_db' },
                },
                'properties' => properties,
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

        before do
          deploy_simple_manifest(manifest_hash: shared_provider_manifest, recreate: true)
        end

        it 'should render the templates using the values from the newly deployed provider' do
          expected_template = {
            'databases' => {
              'main' => [{ 'id' => String, 'name' => 'shared_provider_ig', 'index' => 0, 'address' => '192.168.1.3' }],
              'main_properties' => 'normal_bar',
              'backup' => [{ 'name' => 'shared_provider_ig', 'az' => 'z1', 'index' => 0, 'address' => '192.168.1.3' }],
              'backup_properties' => 'normal_bar',
            },
            'db_az_link' => { 'address' => 'q-a1s0.shared-provider-ig.a.shared-provider-deployment.bosh' },
            'optional_backup_link' => [{ 'address' => 'q-s0.shared-provider-ig.a.shared-provider-deployment.bosh' }],
          }

          expect do
            deploy_simple_manifest(manifest_hash: shared_consumer_deployment_manifest)
            bosh_runner.run('-d shared_consumer_deployment start')
          end.to_not raise_error

          new_instance = director.instance('shared_consumer_ig', '0', deployment_name: 'shared_consumer_deployment')
          new_template = YAML.safe_load(new_instance.read_job_template('api_server', 'config.yml'))
          expect(new_template).to match(expected_template)
        end

        context 'and the properties have changed' do
          let(:properties) do
            { 'foo' => 'a_diff_foo' }
          end

          it 'should render the templates using the values from the newly deployed provider' do
            expected_template = {
              'databases' => {
                'main' => [{ 'id' => String, 'name' => 'shared_provider_ig', 'index' => 0, 'address' => '192.168.1.3' }],
                'main_properties' => 'a_diff_foo',
                'backup' => [{ 'name' => 'shared_provider_ig', 'az' => 'z1', 'index' => 0, 'address' => '192.168.1.3' }],
                'backup_properties' => 'a_diff_foo',
              },
              'db_az_link' => { 'address' => 'q-a1s0.shared-provider-ig.a.shared-provider-deployment.bosh' },
              'optional_backup_link' => [{ 'address' => 'q-s0.shared-provider-ig.a.shared-provider-deployment.bosh' }],
            }

            expect do
              deploy_simple_manifest(manifest_hash: shared_consumer_deployment_manifest)
              bosh_runner.run('-d shared_consumer_deployment start')
            end.to_not raise_error

            new_instance = director.instance('shared_consumer_ig', '0', deployment_name: 'shared_consumer_deployment')
            new_template = YAML.safe_load(new_instance.read_job_template('api_server', 'config.yml'))
            expect(new_template).to match(expected_template)
          end
        end

        context 'and the instance group name has changed' do
          let(:provider_ig_name) do
            'new_shared_provider_ig'
          end

          it 'should render the templates using the values from the newly deployed provider' do
            expected_template = {
              'databases' => {
                'main' => [{ 'id' => String, 'name' => 'new_shared_provider_ig', 'index' => 0, 'address' => /192\.168\.1\./ }],
                'main_properties' => 'normal_bar',
                'backup' => [{ 'name' => 'new_shared_provider_ig', 'az' => 'z1', 'index' => 0, 'address' => /192\.168\.1\./ }],
                'backup_properties' => 'normal_bar',
              },
              'db_az_link' => { 'address' => 'q-a1s0.new-shared-provider-ig.a.shared-provider-deployment.bosh' },
              'optional_backup_link' => [{ 'address' => 'q-s0.new-shared-provider-ig.a.shared-provider-deployment.bosh' }],
            }

            expect do
              deploy_simple_manifest(manifest_hash: shared_consumer_deployment_manifest)
              bosh_runner.run('-d shared_consumer_deployment start')
            end.to_not raise_error

            new_instance = director.instance('shared_consumer_ig', '0', deployment_name: 'shared_consumer_deployment')
            new_template = YAML.safe_load(new_instance.read_job_template('api_server', 'config.yml'))
            expect(new_template).to match(expected_template)
          end
        end
      end
    end
  end

  describe '#bosh deploy --recreate' do
    context 'When redeploying implicit consumer deployment' do
      let(:implicit_provider_instance_group) do
        Bosh::Spec::NewDeployments.simple_instance_group(
          name: 'implicit_provider_ig',
          jobs: [{ 'name' => 'backup_database', 'properties' => { 'foo' => 'a_diff_foo' } }],
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

      it 'should use the new provider data for rendering templates' do
        expected_template = {
          'databases' => {
            'main' => [{ 'id' => String, 'name' => 'implicit_provider_ig', 'index' => 0, 'address' => '192.168.1.5' }],
            'main_properties' => 'a_diff_foo',
            'backup' => [{ 'name' => 'implicit_provider_ig', 'az' => 'z1', 'index' => 0, 'address' => '192.168.1.5' }],
            'backup_properties' => 'a_diff_foo',
          },
          'db_az_link' => { 'address' => 'q-a1s0.implicit-provider-ig.a.implicit-deployment.bosh' },
          'optional_backup_link' => [{ 'address' => 'q-s0.implicit-provider-ig.a.implicit-deployment.bosh' }],
        }
        expect do
          deploy_simple_manifest(manifest_hash: implicit_manifest, recreate: true)
          bosh_runner.run('-d implicit_deployment start')
        end.to_not raise_error

        new_instance = director.instance('implicit_consumer_ig', '0', deployment_name: 'implicit_deployment')
        new_template = YAML.safe_load(new_instance.read_job_template('api_server', 'config.yml'))
        expect(new_template).to match(expected_template)
      end
    end

    context 'When redeploying explicit consumer deployment' do
      let(:explicit_provider_instance_group) do
        Bosh::Spec::NewDeployments.simple_instance_group(
          name: 'explicit_provider_ig',
          jobs: [
            {
              'name' => 'backup_database',
              'provides' => {
                'backup_db' => { 'as' => 'explicit_db' },
              },
              'properties' => { 'foo' => 'a_diff_foo' },
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

      it 'should use the updated provider for rendering templates' do
        expected_template = {
          'databases' => {
            'main' => [{ 'id' => String, 'name' => 'explicit_provider_ig', 'index' => 0, 'address' => '192.168.1.7' }],
            'main_properties' => 'a_diff_foo',
            'backup' => [{ 'name' => 'explicit_provider_ig', 'az' => 'z1', 'index' => 0, 'address' => '192.168.1.7' }],
            'backup_properties' => 'a_diff_foo',
          },
          'db_az_link' => { 'address' => 'q-a1s0.explicit-provider-ig.a.explicit-deployment.bosh' },
          'optional_backup_link' => [{ 'address' => 'q-s0.explicit-provider-ig.a.explicit-deployment.bosh' }],
        }

        expect do
          deploy_simple_manifest(manifest_hash: explicit_manifest, recreate: true)
          bosh_runner.run('-d explicit_deployment start')
        end.to_not raise_error

        new_instance = director.instance('explicit_consumer_ig', '0', deployment_name: 'explicit_deployment')
        new_template = YAML.safe_load(new_instance.read_job_template('api_server', 'config.yml'))
        expect(new_template).to match(expected_template)
      end
    end

    context 'when redeploying the consumer of shared provider' do
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

      let(:shared_consumer_deployment_manifest) do
        Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups.tap do |manifest|
          manifest['name'] = 'shared_consumer_deployment'
          manifest['instance_groups'] = [shared_consumer_instance_group]
        end
      end

      it 'should render the templates using the values from before migration' do
        expected_template = {
          'databases' => {
            'main' => [{ 'id' => String, 'name' => 'shared_provider_ig', 'index' => 0, 'address' => '192.168.1.3' }],
            'main_properties' => 'normal_bar',
            'backup' => [{ 'name' => 'shared_provider_ig', 'az' => 'z1', 'index' => 0, 'address' => '192.168.1.3' }],
            'backup_properties' => 'normal_bar',
          },
          'db_az_link' => { 'address' => 'q-a1s0.shared-provider-ig.a.shared-provider-deployment.bosh' },
          'optional_backup_link' => [{ 'address' => 'q-s0.shared-provider-ig.a.shared-provider-deployment.bosh' }],
        }

        expect do
          deploy_simple_manifest(manifest_hash: shared_consumer_deployment_manifest, recreate: true)
          bosh_runner.run('-d shared_consumer_deployment start')
        end.to_not raise_error

        new_instance = director.instance('shared_consumer_ig', '0', deployment_name: 'shared_consumer_deployment')
        new_template = YAML.safe_load(new_instance.read_job_template('api_server', 'config.yml'))
        expect(new_template).to match(expected_template)
      end

      context 'and the shared provider is started' do
        before do
          bosh_runner.run('-d shared_provider_deployment start')
        end

        it 'should render the templates using the values from before migration' do
          expected_template = {
            'databases' => {
              'main' => [{ 'id' => String, 'name' => 'shared_provider_ig', 'index' => 0, 'address' => '192.168.1.3' }],
              'main_properties' => 'normal_bar',
              'backup' => [{ 'name' => 'shared_provider_ig', 'az' => 'z1', 'index' => 0, 'address' => '192.168.1.3' }],
              'backup_properties' => 'normal_bar',
            },
            'db_az_link' => { 'address' => 'q-a1s0.shared-provider-ig.a.shared-provider-deployment.bosh' },
            'optional_backup_link' => [{ 'address' => 'q-s0.shared-provider-ig.a.shared-provider-deployment.bosh' }],
          }

          expect do
            deploy_simple_manifest(manifest_hash: shared_consumer_deployment_manifest, recreate: true)
            bosh_runner.run('-d shared_consumer_deployment start')
          end.to_not raise_error

          new_instance = director.instance('shared_consumer_ig', '0', deployment_name: 'shared_consumer_deployment')
          new_template = YAML.safe_load(new_instance.read_job_template('api_server', 'config.yml'))
          expect(new_template).to match(expected_template)
        end
      end

      context 'and the shared provider is recreated' do
        before do
          bosh_runner.run('-d shared_provider_deployment recreate')
        end

        it 'should render the templates using the values from before migration' do
          expected_template = {
            'databases' => {
              'main' => [{ 'id' => String, 'name' => 'shared_provider_ig', 'index' => 0, 'address' => '192.168.1.3' }],
              'main_properties' => 'normal_bar',
              'backup' => [{ 'name' => 'shared_provider_ig', 'az' => 'z1', 'index' => 0, 'address' => '192.168.1.3' }],
              'backup_properties' => 'normal_bar',
            },
            'db_az_link' => { 'address' => 'q-a1s0.shared-provider-ig.a.shared-provider-deployment.bosh' },
            'optional_backup_link' => [{ 'address' => 'q-s0.shared-provider-ig.a.shared-provider-deployment.bosh' }],
          }

          expect do
            deploy_simple_manifest(manifest_hash: shared_consumer_deployment_manifest, recreate: true)
            bosh_runner.run('-d shared_consumer_deployment start')
          end.to_not raise_error

          new_instance = director.instance('shared_consumer_ig', '0', deployment_name: 'shared_consumer_deployment')
          new_template = YAML.safe_load(new_instance.read_job_template('api_server', 'config.yml'))
          expect(new_template).to match(expected_template)
        end
      end

      context 'and the shared provider is redeployed' do
        let(:properties) do
          {}
        end

        let(:provider_ig_name) do
          'shared_provider_ig'
        end

        let(:shared_provider_instance_group) do
          Bosh::Spec::NewDeployments.simple_instance_group(
            name: provider_ig_name,
            jobs: [
              {
                'name' => 'database',
                'provides' => {
                  'db' => { 'shared' => true, 'as' => 'my_shared_db' },
                },
                'properties' => properties,
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

        before do
          deploy_simple_manifest(manifest_hash: shared_provider_manifest)
        end

        it 'should render the templates using the values from the newly deployed provider' do
          expected_template = {
            'databases' => {
              'main' => [{ 'id' => String, 'name' => 'shared_provider_ig', 'index' => 0, 'address' => '192.168.1.3' }],
              'main_properties' => 'normal_bar',
              'backup' => [{ 'name' => 'shared_provider_ig', 'az' => 'z1', 'index' => 0, 'address' => '192.168.1.3' }],
              'backup_properties' => 'normal_bar',
            },
            'db_az_link' => { 'address' => 'q-a1s0.shared-provider-ig.a.shared-provider-deployment.bosh' },
            'optional_backup_link' => [{ 'address' => 'q-s0.shared-provider-ig.a.shared-provider-deployment.bosh' }],
          }

          expect do
            deploy_simple_manifest(manifest_hash: shared_consumer_deployment_manifest, recreate: true)
            bosh_runner.run('-d shared_consumer_deployment start')
          end.to_not raise_error

          new_instance = director.instance('shared_consumer_ig', '0', deployment_name: 'shared_consumer_deployment')
          new_template = YAML.safe_load(new_instance.read_job_template('api_server', 'config.yml'))
          expect(new_template).to match(expected_template)
        end

        context 'and the properties have changed' do
          let(:properties) do
            { 'foo' => 'a_diff_foo' }
          end

          it 'should render the templates using the values from the newly deployed provider' do
            expected_template = {
              'databases' => {
                'main' => [{ 'id' => String, 'name' => 'shared_provider_ig', 'index' => 0, 'address' => '192.168.1.3' }],
                'main_properties' => 'a_diff_foo',
                'backup' => [{ 'name' => 'shared_provider_ig', 'az' => 'z1', 'index' => 0, 'address' => '192.168.1.3' }],
                'backup_properties' => 'a_diff_foo',
              },
              'db_az_link' => { 'address' => 'q-a1s0.shared-provider-ig.a.shared-provider-deployment.bosh' },
              'optional_backup_link' => [{ 'address' => 'q-s0.shared-provider-ig.a.shared-provider-deployment.bosh' }],
            }

            expect do
              deploy_simple_manifest(manifest_hash: shared_consumer_deployment_manifest, recreate: true)
              bosh_runner.run('-d shared_consumer_deployment start')
            end.to_not raise_error

            new_instance = director.instance('shared_consumer_ig', '0', deployment_name: 'shared_consumer_deployment')
            new_template = YAML.safe_load(new_instance.read_job_template('api_server', 'config.yml'))
            expect(new_template).to match(expected_template)
          end
        end

        context 'and the instance group name has changed' do
          let(:provider_ig_name) do
            'new_shared_provider_ig'
          end

          it 'should render the templates using the values from the newly deployed provider' do
            expected_template = {
              'databases' => {
                'main' => [{ 'id' => String, 'name' => 'new_shared_provider_ig', 'index' => 0, 'address' => /192\.168\.1\./ }],
                'main_properties' => 'normal_bar',
                'backup' => [{ 'name' => 'new_shared_provider_ig', 'az' => 'z1', 'index' => 0, 'address' => /192\.168\.1\./ }],
                'backup_properties' => 'normal_bar',
              },
              'db_az_link' => { 'address' => 'q-a1s0.new-shared-provider-ig.a.shared-provider-deployment.bosh' },
              'optional_backup_link' => [{ 'address' => 'q-s0.new-shared-provider-ig.a.shared-provider-deployment.bosh' }],
            }

            expect do
              deploy_simple_manifest(manifest_hash: shared_consumer_deployment_manifest, recreate: true)
              bosh_runner.run('-d shared_consumer_deployment start')
            end.to_not raise_error

            new_instance = director.instance('shared_consumer_ig', '0', deployment_name: 'shared_consumer_deployment')
            new_template = YAML.safe_load(new_instance.read_job_template('api_server', 'config.yml'))
            expect(new_template).to match(expected_template)
          end
        end
      end

      context 'and the shared provider is redeployed with --recreate flag' do
        let(:properties) do
          {}
        end

        let(:provider_ig_name) do
          'shared_provider_ig'
        end

        let(:shared_provider_instance_group) do
          Bosh::Spec::NewDeployments.simple_instance_group(
            name: provider_ig_name,
            jobs: [
              {
                'name' => 'database',
                'provides' => {
                  'db' => { 'shared' => true, 'as' => 'my_shared_db' },
                },
                'properties' => properties,
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

        before do
          deploy_simple_manifest(manifest_hash: shared_provider_manifest, recreate: true)
        end

        it 'should render the templates using the values from the newly deployed provider' do
          expected_template = {
            'databases' => {
              'main' => [{ 'id' => String, 'name' => 'shared_provider_ig', 'index' => 0, 'address' => '192.168.1.3' }],
              'main_properties' => 'normal_bar',
              'backup' => [{ 'name' => 'shared_provider_ig', 'az' => 'z1', 'index' => 0, 'address' => '192.168.1.3' }],
              'backup_properties' => 'normal_bar',
            },
            'db_az_link' => { 'address' => 'q-a1s0.shared-provider-ig.a.shared-provider-deployment.bosh' },
            'optional_backup_link' => [{ 'address' => 'q-s0.shared-provider-ig.a.shared-provider-deployment.bosh' }],
          }

          expect do
            deploy_simple_manifest(manifest_hash: shared_consumer_deployment_manifest, recreate: true)
            bosh_runner.run('-d shared_consumer_deployment start')
          end.to_not raise_error

          new_instance = director.instance('shared_consumer_ig', '0', deployment_name: 'shared_consumer_deployment')
          new_template = YAML.safe_load(new_instance.read_job_template('api_server', 'config.yml'))
          expect(new_template).to match(expected_template)
        end

        context 'and the properties have changed' do
          let(:properties) do
            { 'foo' => 'a_diff_foo' }
          end

          it 'should render the templates using the values from the newly deployed provider' do
            expected_template = {
              'databases' => {
                'main' => [{ 'id' => String, 'name' => 'shared_provider_ig', 'index' => 0, 'address' => '192.168.1.3' }],
                'main_properties' => 'a_diff_foo',
                'backup' => [{ 'name' => 'shared_provider_ig', 'az' => 'z1', 'index' => 0, 'address' => '192.168.1.3' }],
                'backup_properties' => 'a_diff_foo',
              },
              'db_az_link' => { 'address' => 'q-a1s0.shared-provider-ig.a.shared-provider-deployment.bosh' },
              'optional_backup_link' => [{ 'address' => 'q-s0.shared-provider-ig.a.shared-provider-deployment.bosh' }],
            }

            expect do
              deploy_simple_manifest(manifest_hash: shared_consumer_deployment_manifest, recreate: true)
              bosh_runner.run('-d shared_consumer_deployment start')
            end.to_not raise_error

            new_instance = director.instance('shared_consumer_ig', '0', deployment_name: 'shared_consumer_deployment')
            new_template = YAML.safe_load(new_instance.read_job_template('api_server', 'config.yml'))
            expect(new_template).to match(expected_template)
          end
        end

        context 'and the instance group name has changed' do
          let(:provider_ig_name) do
            'new_shared_provider_ig'
          end

          it 'should render the templates using the values from the newly deployed provider' do
            expected_template = {
              'databases' => {
                'main' => [{ 'id' => String, 'name' => 'new_shared_provider_ig', 'index' => 0, 'address' => /192\.168\.1\./ }],
                'main_properties' => 'normal_bar',
                'backup' => [{ 'name' => 'new_shared_provider_ig', 'az' => 'z1', 'index' => 0, 'address' => /192\.168\.1\./ }],
                'backup_properties' => 'normal_bar',
              },
              'db_az_link' => { 'address' => 'q-a1s0.new-shared-provider-ig.a.shared-provider-deployment.bosh' },
              'optional_backup_link' => [{ 'address' => 'q-s0.new-shared-provider-ig.a.shared-provider-deployment.bosh' }],
            }

            expect do
              deploy_simple_manifest(manifest_hash: shared_consumer_deployment_manifest, recreate: true)
              bosh_runner.run('-d shared_consumer_deployment start')
            end.to_not raise_error

            new_instance = director.instance('shared_consumer_ig', '0', deployment_name: 'shared_consumer_deployment')
            new_template = YAML.safe_load(new_instance.read_job_template('api_server', 'config.yml'))
            expect(new_template).to match(expected_template)
          end
        end
      end
    end
  end

  describe '#bosh deploy new_shared_consumer_deployment' do
    let(:shared_consumer_instance_group) do
      Bosh::Spec::NewDeployments.simple_instance_group(
        name: 'new_shared_consumer_ig',
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

    let(:new_shared_consumer_deployment_manifest) do
      Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups.tap do |manifest|
        manifest['name'] = 'new_shared_consumer_deployment'
        manifest['instance_groups'] = [shared_consumer_instance_group]
      end
    end

    it 'should render the templates using the values from before migration' do
      expected_template = {
        'databases' => {
          'main' => [{ 'id' => String, 'name' => 'shared_provider_ig', 'index' => 0, 'address' => '192.168.1.3' }],
          'main_properties' => 'normal_bar',
          'backup' => [{ 'name' => 'shared_provider_ig', 'az' => 'z1', 'index' => 0, 'address' => '192.168.1.3' }],
          'backup_properties' => 'normal_bar',
        },
        'db_az_link' => { 'address' => 'q-a1s0.shared-provider-ig.a.shared-provider-deployment.bosh' },
        'optional_backup_link' => [{ 'address' => 'q-s0.shared-provider-ig.a.shared-provider-deployment.bosh' }],
      }

      expect do
        deploy_simple_manifest(manifest_hash: new_shared_consumer_deployment_manifest)
      end.to_not raise_error

      new_instance = director.instance('new_shared_consumer_ig', '0', deployment_name: 'new_shared_consumer_deployment')
      new_template = YAML.safe_load(new_instance.read_job_template('api_server', 'config.yml'))
      expect(new_template).to match(expected_template)
    end

    context 'and the shared provider is started' do
      before do
        bosh_runner.run('-d shared_provider_deployment start', json: true)
      end

      it 'should render the templates using the values from before migration' do
        expected_template = {
          'databases' => {
            'main' => [{ 'id' => String, 'name' => 'shared_provider_ig', 'index' => 0, 'address' => '192.168.1.3' }],
            'main_properties' => 'normal_bar',
            'backup' => [{ 'name' => 'shared_provider_ig', 'az' => 'z1', 'index' => 0, 'address' => '192.168.1.3' }],
            'backup_properties' => 'normal_bar',
          },
          'db_az_link' => { 'address' => 'q-a1s0.shared-provider-ig.a.shared-provider-deployment.bosh' },
          'optional_backup_link' => [{ 'address' => 'q-s0.shared-provider-ig.a.shared-provider-deployment.bosh' }],
        }

        expect do
          deploy_simple_manifest(manifest_hash: new_shared_consumer_deployment_manifest)
        end.to_not raise_error

        new_instance = director.instance('new_shared_consumer_ig', '0', deployment_name: 'new_shared_consumer_deployment')
        new_template = YAML.safe_load(new_instance.read_job_template('api_server', 'config.yml'))
        expect(new_template).to match(expected_template)
      end
    end

    context 'and the shared provider is recreated' do
      before do
        bosh_runner.run('-d shared_provider_deployment recreate', json: true)
      end

      it 'should render the templates using the values from before migration' do
        expected_template = {
          'databases' => {
            'main' => [{ 'id' => String, 'name' => 'shared_provider_ig', 'index' => 0, 'address' => '192.168.1.3' }],
            'main_properties' => 'normal_bar',
            'backup' => [{ 'name' => 'shared_provider_ig', 'az' => 'z1', 'index' => 0, 'address' => '192.168.1.3' }],
            'backup_properties' => 'normal_bar',
          },
          'db_az_link' => { 'address' => 'q-a1s0.shared-provider-ig.a.shared-provider-deployment.bosh' },
          'optional_backup_link' => [{ 'address' => 'q-s0.shared-provider-ig.a.shared-provider-deployment.bosh' }],
        }

        expect do
          deploy_simple_manifest(manifest_hash: new_shared_consumer_deployment_manifest)
        end.to_not raise_error

        new_instance = director.instance('new_shared_consumer_ig', '0', deployment_name: 'new_shared_consumer_deployment')
        new_template = YAML.safe_load(new_instance.read_job_template('api_server', 'config.yml'))
        expect(new_template).to match(expected_template)
      end
    end

    context 'and the shared provider is redeployed' do
      let(:properties) do
        {}
      end

      let(:provider_ig_name) do
        'shared_provider_ig'
      end

      let(:shared_provider_instance_group) do
        Bosh::Spec::NewDeployments.simple_instance_group(
          name: provider_ig_name,
          jobs: [
            {
              'name' => 'database',
              'provides' => {
                'db' => { 'shared' => true, 'as' => 'my_shared_db' },
              },
              'properties' => properties,
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

      before do
        deploy_simple_manifest(manifest_hash: shared_provider_manifest)
      end

      it 'should render the templates using the values from the newly deployed provider' do
        expected_template = {
          'databases' => {
            'main' => [{ 'id' => String, 'name' => 'shared_provider_ig', 'index' => 0, 'address' => '192.168.1.3' }],
            'main_properties' => 'normal_bar',
            'backup' => [{ 'name' => 'shared_provider_ig', 'az' => 'z1', 'index' => 0, 'address' => '192.168.1.3' }],
            'backup_properties' => 'normal_bar',
          },
          'db_az_link' => { 'address' => 'q-a1s0.shared-provider-ig.a.shared-provider-deployment.bosh' },
          'optional_backup_link' => [{ 'address' => 'q-s0.shared-provider-ig.a.shared-provider-deployment.bosh' }],
        }

        expect do
          deploy_simple_manifest(manifest_hash: new_shared_consumer_deployment_manifest)
        end.to_not raise_error

        new_instance = director.instance('new_shared_consumer_ig', '0', deployment_name: 'new_shared_consumer_deployment')
        new_template = YAML.safe_load(new_instance.read_job_template('api_server', 'config.yml'))
        expect(new_template).to match(expected_template)
      end

      context 'and the properties have changed' do
        let(:properties) do
          { 'foo' => 'a_diff_foo' }
        end

        it 'should render the templates using the values from the newly deployed provider' do
          expected_template = {
            'databases' => {
              'main' => [{ 'id' => String, 'name' => 'shared_provider_ig', 'index' => 0, 'address' => '192.168.1.3' }],
              'main_properties' => 'a_diff_foo',
              'backup' => [{ 'name' => 'shared_provider_ig', 'az' => 'z1', 'index' => 0, 'address' => '192.168.1.3' }],
              'backup_properties' => 'a_diff_foo',
            },
            'db_az_link' => { 'address' => 'q-a1s0.shared-provider-ig.a.shared-provider-deployment.bosh' },
            'optional_backup_link' => [{ 'address' => 'q-s0.shared-provider-ig.a.shared-provider-deployment.bosh' }],
          }

          expect do
            deploy_simple_manifest(manifest_hash: new_shared_consumer_deployment_manifest)
          end.to_not raise_error

          new_instance = director.instance('new_shared_consumer_ig', '0', deployment_name: 'new_shared_consumer_deployment')
          new_template = YAML.safe_load(new_instance.read_job_template('api_server', 'config.yml'))
          expect(new_template).to match(expected_template)
        end
      end

      context 'and the instance group name has changed' do
        let(:provider_ig_name) do
          'new_shared_provider_ig'
        end

        it 'should render the templates using the values from the newly deployed provider' do
          expected_template = {
            'databases' => {
              'main' => [{ 'id' => String, 'name' => 'new_shared_provider_ig', 'index' => 0, 'address' => /192\.168\.1\./ }],
              'main_properties' => 'normal_bar',
              'backup' => [{ 'name' => 'new_shared_provider_ig', 'az' => 'z1', 'index' => 0, 'address' => /192\.168\.1\./ }],
              'backup_properties' => 'normal_bar',
            },
            'db_az_link' => { 'address' => 'q-a1s0.new-shared-provider-ig.a.shared-provider-deployment.bosh' },
            'optional_backup_link' => [{ 'address' => 'q-s0.new-shared-provider-ig.a.shared-provider-deployment.bosh' }],
          }

          expect do
            deploy_simple_manifest(manifest_hash: new_shared_consumer_deployment_manifest)
          end.to_not raise_error

          new_instance = director.instance('new_shared_consumer_ig', '0', deployment_name: 'new_shared_consumer_deployment')
          new_template = YAML.safe_load(new_instance.read_job_template('api_server', 'config.yml'))
          expect(new_template).to match(expected_template)
        end
      end
    end

    context 'and the shared provider is redeployed with --recreate flag' do
      let(:properties) do
        {}
      end

      let(:provider_ig_name) do
        'shared_provider_ig'
      end

      let(:shared_provider_instance_group) do
        Bosh::Spec::NewDeployments.simple_instance_group(
          name: provider_ig_name,
          jobs: [
            {
              'name' => 'database',
              'provides' => {
                'db' => { 'shared' => true, 'as' => 'my_shared_db' },
              },
              'properties' => properties,
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

      before do
        deploy_simple_manifest(manifest_hash: shared_provider_manifest, recreate: true)
      end

      it 'should render the templates using the values from the newly deployed provider' do
        expected_template = {
          'databases' => {
            'main' => [{ 'id' => String, 'name' => 'shared_provider_ig', 'index' => 0, 'address' => '192.168.1.3' }],
            'main_properties' => 'normal_bar',
            'backup' => [{ 'name' => 'shared_provider_ig', 'az' => 'z1', 'index' => 0, 'address' => '192.168.1.3' }],
            'backup_properties' => 'normal_bar',
          },
          'db_az_link' => { 'address' => 'q-a1s0.shared-provider-ig.a.shared-provider-deployment.bosh' },
          'optional_backup_link' => [{ 'address' => 'q-s0.shared-provider-ig.a.shared-provider-deployment.bosh' }],
        }

        expect do
          deploy_simple_manifest(manifest_hash: new_shared_consumer_deployment_manifest)
        end.to_not raise_error

        new_instance = director.instance('new_shared_consumer_ig', '0', deployment_name: 'new_shared_consumer_deployment')
        new_template = YAML.safe_load(new_instance.read_job_template('api_server', 'config.yml'))
        expect(new_template).to match(expected_template)
      end

      context 'and the properties have changed' do
        let(:properties) do
          { 'foo' => 'a_diff_foo' }
        end

        it 'should render the templates using the values from the newly deployed provider' do
          expected_template = {
            'databases' => {
              'main' => [{ 'id' => String, 'name' => 'shared_provider_ig', 'index' => 0, 'address' => '192.168.1.3' }],
              'main_properties' => 'a_diff_foo',
              'backup' => [{ 'name' => 'shared_provider_ig', 'az' => 'z1', 'index' => 0, 'address' => '192.168.1.3' }],
              'backup_properties' => 'a_diff_foo',
            },
            'db_az_link' => { 'address' => 'q-a1s0.shared-provider-ig.a.shared-provider-deployment.bosh' },
            'optional_backup_link' => [{ 'address' => 'q-s0.shared-provider-ig.a.shared-provider-deployment.bosh' }],
          }

          expect do
            deploy_simple_manifest(manifest_hash: new_shared_consumer_deployment_manifest)
          end.to_not raise_error

          new_instance = director.instance('new_shared_consumer_ig', '0', deployment_name: 'new_shared_consumer_deployment')
          new_template = YAML.safe_load(new_instance.read_job_template('api_server', 'config.yml'))
          expect(new_template).to match(expected_template)
        end
      end

      context 'and the instance group name has changed' do
        let(:provider_ig_name) do
          'new_shared_provider_ig'
        end

        it 'should render the templates using the values from the newly deployed provider' do
          expected_template = {
            'databases' => {
              'main' => [{ 'id' => String, 'name' => 'new_shared_provider_ig', 'index' => 0, 'address' => /192\.168\.1\./ }],
              'main_properties' => 'normal_bar',
              'backup' => [{ 'name' => 'new_shared_provider_ig', 'az' => 'z1', 'index' => 0, 'address' => /192\.168\.1\./ }],
              'backup_properties' => 'normal_bar',
            },
            'db_az_link' => { 'address' => 'q-a1s0.new-shared-provider-ig.a.shared-provider-deployment.bosh' },
            'optional_backup_link' => [{ 'address' => 'q-s0.new-shared-provider-ig.a.shared-provider-deployment.bosh' }],
          }

          expect do
            deploy_simple_manifest(manifest_hash: new_shared_consumer_deployment_manifest)
          end.to_not raise_error

          new_instance = director.instance('new_shared_consumer_ig', '0', deployment_name: 'new_shared_consumer_deployment')
          new_template = YAML.safe_load(new_instance.read_job_template('api_server', 'config.yml'))
          expect(new_template).to match(expected_template)
        end
      end
    end
  end

  it 'runs the errand with links' do
    output, exit_code = bosh_runner.run('-d errand_deployment run-errand errand_with_links', return_exit_code: true)
    expect(exit_code).to eq(0)

    expect(output).to include('Creating missing vms: errand_consumer_ig')
    expect(output).to include('Updating instance errand_consumer_ig: errand_consumer_ig')
    expect(output).to include('Stdout     normal_bar')
  end

  it 'runs the colocated errand with links' do
    output, exit_code = bosh_runner.run('-d colocated_errand_deployment start', return_exit_code: true)
    expect(exit_code).to eq(0)

    output, exit_code = bosh_runner.run('-d colocated_errand_deployment run-errand errand_with_links', return_exit_code: true)
    expect(exit_code).to eq(0)

    expect(output).to include('Running errand: errand_ig')
    expect(output).to include('Stdout     normal_bar')
  end
end
