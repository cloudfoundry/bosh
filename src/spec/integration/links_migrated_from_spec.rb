require 'spec_helper'

describe 'Links', type: :integration do
  with_reset_sandbox_before_each

  def should_contain_network_for_job(job, template, pattern)
    my_api_instance = director.instance(job, '0', deployment_name: 'simple')
    template = YAML.load(my_api_instance.read_job_template(template, 'config.yml'))

    template['databases'].select {|key| key == 'main' || key == 'backup_db'}.each do |_, database|
      database.each do |instance|
        expect(instance['address']).to match(pattern)
      end
    end
  end

  let(:cloud_config) do
    cloud_config_hash = SharedSupport::DeploymentManifestHelper.simple_cloud_config
    cloud_config_hash['azs'] = [{'name' => 'z1'}]
    cloud_config_hash['networks'].first['subnets'].first['static'] = ['192.168.1.10', '192.168.1.11', '192.168.1.12', '192.168.1.13']
    cloud_config_hash['networks'].first['subnets'].first['az'] = 'z1'
    cloud_config_hash['compilation']['az'] = 'z1'
    cloud_config_hash['networks'] << {
      'name' => 'dynamic-network',
      'type' => 'dynamic',
      'subnets' => [{'az' => 'z1'}]
    }

    cloud_config_hash
  end

  before do
    upload_links_release(bosh_runner_options: {})
    upload_stemcell

    upload_cloud_config(cloud_config_hash: cloud_config)
  end

  context 'when job requires link' do
    let(:links) do
      {
        'db' => {'from' => 'link_alias'},
        'backup_db' => {'from' => 'link_alias'},
      }
    end

    let(:api_instance_group_spec) do
      spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
        name: 'my_api',
        jobs: [
          'name' => 'api_server',
          'release' => 'bosh-release',
          'consumes' => links,
        ],
        instances: 1,
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

    context 'when deployment includes a migrated job which also provides or consumes links' do
      let(:manifest) do
        manifest = SharedSupport::DeploymentManifestHelper.deployment_manifest
        manifest['instance_groups'] = [api_instance_group_spec, aliased_instance_group_spec]
        manifest
      end

      let(:new_api_instance_group_spec) do
        spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
          name: 'new_api_job',
          jobs: [
            'name' => 'api_server',
            'release' => 'bosh-release',
            'consumes' => links,
          ],
          instances: 1,
        )
        spec['migrated_from'] = ['name' => 'my_api']
        spec['azs'] = ['z1']
        spec
      end

      let(:new_aliased_instance_group_spec) do
        spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
          name: 'new_aliased_job',
          jobs: [
            'name' => 'backup_database',
            'release' => 'bosh-release',
            'provides' => { 'backup_db' => { 'as' => 'link_alias' } },
          ],
          instances: 1,
        )
        spec['migrated_from'] = [{ 'name' => 'aliased_postgres' }]
        spec['azs'] = ['z1']
        spec
      end

      let(:provided_link_migrated_response) do
        [{'id' => '1',
          'name' => 'link_alias',
          'shared' => false,
          'deployment' => 'simple',
          'link_provider_definition' => {'type' => 'db', 'name' => 'backup_db'},
          'owner_object' => {'type' => 'job',
                             'name' => 'backup_database',
                             'info' => {'instance_group' => 'new_aliased_job'}}
         }]
      end

      let(:consumed_link_migrated_response) do
        [{"id" => '1',
          "name" => "link_alias",
          "optional" => false,
          "deployment" => "simple",
          "owner_object" =>
            {"type" => "job", "name" => "api_server", "info" => {"instance_group" => "new_api_job"}},
          "link_consumer_definition" => {"name" => "db", "type" => "db"}},
         {"id" => '2',
          "name" => "link_alias",
          "optional" => false,
          "deployment" => "simple",
          "owner_object" =>
            {"type" => "job", "name" => "api_server", "info" => {"instance_group" => "new_api_job"}},
          "link_consumer_definition" => {"name" => "backup_db", "type" => "db"}}]
      end

      it 'deploys migrated_from jobs' do
        deploy_simple_manifest(manifest_hash: manifest)

        link_instance = director.instance('my_api', '0')
        template = YAML.load(link_instance.read_job_template('api_server', 'config.yml'))

        aliased_job_instance = director.instance('aliased_postgres', '0')

        expect(template['databases']['main'].size).to eq(1)
        expect(template['databases']['main']).to contain_exactly(
                                                   {
                                                     'id' => "#{aliased_job_instance.id}",
                                                     'name' => 'aliased_postgres',
                                                     'index' => 0,
                                                     'address' => '192.168.1.3'
                                                   }
                                                 )

        manifest['instance_groups'] = [new_api_instance_group_spec, new_aliased_instance_group_spec]
        deploy_simple_manifest(manifest_hash: manifest)

        link_instance = director.instance('new_api_job', '0')
        template = YAML.load(link_instance.read_job_template('api_server', 'config.yml'))

        new_aliased_job_instance = director.instance('new_aliased_job', '0')

        expect(template['databases']['main'].size).to eq(1)
        expect(template['databases']['main']).to contain_exactly(
                                                   {
                                                     'id' => "#{new_aliased_job_instance.id}",
                                                     'name' => 'new_aliased_job',
                                                     'index' => 0,
                                                     'address' => '192.168.1.3'
                                                   }
                                                 )

        response = get_link_providers
        expect(response).to eq(provided_link_migrated_response)
        consumer_response = get_link_consumers
        expect(consumer_response.count).to eq(2)
        expect(consumer_response).to include(consumed_link_migrated_response[0])
        expect(consumer_response).to include(consumed_link_migrated_response[1])
      end
    end

    context 'when deployment includes multiple migrated jobs with the same name and who both provide links' do
      let(:manifest) do
        manifest = SharedSupport::DeploymentManifestHelper.deployment_manifest
        manifest['instance_groups'] = [aliased_instance_group_spec, secondary_deployment_instance_group_spec,
                                       secondary_deployment_consumer_instance_group_spec, api_instance_group_spec]
        manifest
      end

      let(:secondary_deployment_instance_group_spec) do
        spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
          name: 'test_another_group',
          jobs: [
            {
              'name' => 'backup_database',
              'release' => 'bosh-release',
              'provides' => {
                'backup_db' => { 'as' => 'link_alias2' },
              },
            },
          ],
          instances: 1,
        )
        spec['azs'] = ['z1']
        spec
      end

      let(:secondary_deployment_consumer_instance_group_spec) do
        spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
          name: 'test_another_consumer_group',
          jobs: [
            {
              'name' => 'api_server',
              'release' => 'bosh-release',
              'consumes' => {
                'db' => { 'from' => 'link_alias2' },
                'backup_db' => { 'from' => 'link_alias2' },
              },
            },
          ],
          instances: 1,
        )
        spec['azs'] = ['z1']
        spec
      end

      let(:new_aliased_instance_group_spec) do
        spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
          name: 'new_aliased_job',
          jobs: [
            'name' => 'backup_database',
            'release' => 'bosh-release',
            'provides' => { 'backup_db' => { 'as' => 'link_alias' } },
          ],
          instances: 1,
        )
        spec['migrated_from'] = [{'name' => 'aliased_postgres'}, {'name' => 'test_another_group'}]
        spec['azs'] = ['z1']
        spec
      end

      let(:new_api_instance_group_spec) do
        spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
          name: 'new_api_job',
          jobs: [
            'name' => 'api_server',
            'release' => 'bosh-release',
            'consumes' => links,
          ],
          instances: 1,
        )
        spec['migrated_from'] = [{'name' => 'my_api'}, {'name' => 'test_another_consumer_group'}]
        spec['azs'] = ['z1']
        spec
      end

      it 'is still able to deploy and chooses the appropriate link property' do
        deploy_simple_manifest(manifest_hash: manifest)
        manifest['instance_groups'] = [new_api_instance_group_spec, new_aliased_instance_group_spec]
        expect { deploy_simple_manifest(manifest_hash: manifest) }.to_not raise_error
      end

      it 'is still able to deploy and chooses the appropriate link property in either order' do
        manifest['instance_groups'] = [secondary_deployment_instance_group_spec, aliased_instance_group_spec, api_instance_group_spec]
        deploy_simple_manifest(manifest_hash: manifest)
        manifest['instance_groups'] = [new_api_instance_group_spec, new_aliased_instance_group_spec]
        expect { deploy_simple_manifest(manifest_hash: manifest) }.to_not raise_error
      end
    end

    context 'when migrated from two jobs with the same name who use manual links' do
      let(:links) do
        {
          'db' => {
            'instances' => [
              { 'address' => 'something.aws.amazon.com' }
            ],
            'properties' => {'foo' => 'haha'}
          },
          'backup_db' => {
            'instances' => [
              { 'address' => 'something.aws.amazon.com' }
            ],
            'properties' => {'foo' => 'hehe'}
          }
        }
      end

      let(:second_api_instance_group_spec) do
        spec = Bosh::Common::DeepCopy.copy(api_instance_group_spec)
        spec['name'] = 'secondary_instance_group'
        spec
      end

      let(:merged_instance_group_spec) do
        spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
          name: 'merged_instance_group',
          jobs: [
            'name' => 'api_server',
            'release' => 'bosh-release',
            'consumes' => links,
          ],
          instances: 1,
        )
        spec['migrated_from'] = [{'name' => api_instance_group_spec['name']},
                                 {'name' => second_api_instance_group_spec['name']}]
        spec['azs'] = ['z1']
        spec
      end

      let(:manifest) do
        manifest = SharedSupport::DeploymentManifestHelper.deployment_manifest
        manifest['instance_groups'] = [api_instance_group_spec, second_api_instance_group_spec]
        manifest
      end

      it 'should choose the first job' do
        deploy_simple_manifest(manifest_hash: manifest)
        manifest['instance_groups'] = [merged_instance_group_spec]
        deploy_simple_manifest(manifest_hash: manifest)
      end
    end

    context 'when migrated_from but there is a new job with links added' do
      let(:secondary_aliased_instance_group_spec) do
        spec = Bosh::Common::DeepCopy.copy(aliased_instance_group_spec)
        spec['name'] = 'secondary_instance_group'
        spec
      end

      let(:merged_instance_group) do
        spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
          name: 'merged_group',
          jobs: [
            {
              'name' => 'backup_database',
              'release' => 'bosh-release',
              'provides' => { 'backup_db' => { 'as' => 'link_alias' } },
            },
            {
              'name' => 'database',
              'release' => 'bosh-release',
              'provides' => { 'db' => { 'as' => 'db2' } },
            },
          ],
          instances: 1,
        )
        spec['migrated_from'] = [{'name' => aliased_instance_group_spec['name']}, {'name' => secondary_aliased_instance_group_spec['name']}]
        spec['azs'] = ['z1']
        spec
      end

      let(:manifest) do
        manifest = SharedSupport::DeploymentManifestHelper.deployment_manifest
        manifest['instance_groups'] = [aliased_instance_group_spec, secondary_aliased_instance_group_spec]
        manifest
      end

      it 'still deploys successfully' do
        deploy_simple_manifest(manifest_hash: manifest)
        manifest['instance_groups'] = [merged_instance_group]
        deploy_simple_manifest(manifest_hash: manifest)
      end

      context 'if deploy fail cross-deployment should still work' do
        let(:secondary_aliased_instance_group_spec) do
          spec = Bosh::Common::DeepCopy.copy(aliased_instance_group_spec)
          spec['name'] = 'secondary_instance_group'
          spec['jobs'] << {
            'name' => 'provider_fail',
            'release' => 'bosh-release',
            'provides' => { 'provider_fail' => { 'shared' => true } },
            'properties' => { 'b' => 'adding_b' },
          }
          spec
        end

        let(:merged_instance_group) do
          spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
            name: 'merged_group',
            jobs: [
              {
                'name' => 'backup_database',
                'release' => 'bosh-release',
                'provides' => { 'backup_db' => { 'as' => 'link_alias' } },
              },
              {
                'name' => 'database',
                'release' => 'bosh-release',
                'provides' => { 'db' => { 'as' => 'db2' } },
              },
              {
                'name' => 'provider_fail',
                'release' => 'bosh-release',
                'provides' => { 'provider_fail' => { 'shared' => true } },
              },
            ],
            instances: 1,
          )
          spec['migrated_from'] = [
            { 'name' => aliased_instance_group_spec['name'] },
            { 'name' => secondary_aliased_instance_group_spec['name'] },
          ]
          spec['azs'] = ['z1']
          spec
        end

        let(:consuming_instance_group) do
          spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
            name: 'consuming_instance_group',
            jobs: [{
              'name' => 'consumer',
              'release' => 'bosh-release',
              'consumes' => { 'provider' => { 'from' => 'provider_fail', 'deployment' => 'simple' } },
            }],
            instances: 1,
          )
          spec['azs'] = ['z1']
          spec
        end

        let(:consuming_manifest) do
          manifest = SharedSupport::DeploymentManifestHelper.deployment_manifest(name: 'consuming')
          manifest['instance_groups'] = [consuming_instance_group]
          manifest
        end

        let(:deployment_error_string) { 'Link property b in template provider_fail is not defined in release spec' }

        before do
          deploy_simple_manifest(manifest_hash: manifest)
          deploy_simple_manifest(manifest_hash: consuming_manifest)
          manifest['instance_groups'] = [merged_instance_group]
          output, code = deploy_simple_manifest(manifest_hash: manifest, failure_expected: true, return_exit_code: true)

          expect(output).to include(deployment_error_string)
          expect(code).to_not eq(0)
        end

        it 'should fail to re-deploying a consumer with cross-deployment links' do
          output, code = deploy_simple_manifest(manifest_hash: consuming_manifest, failure_expected: true, return_exit_code: true)

          expect(output).to include(
            "Failed to resolve link 'provider' with alias 'provider_fail' and " \
            "type 'provider' from job 'consumer' in instance group 'consuming_instance_group'. Details below:",
          )
          expect(code).to_not eq(0)
        end

        context 'if provider deployment failed because of network config' do
          let(:merged_instance_group) do
            spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
              name: 'merged_group',
              jobs: [
                {
                  'name' => 'backup_database',
                  'release' => 'bosh-release',
                  'provides' => { 'backup_db' => { 'as' => 'link_alias' } },
                },
                {
                  'name' => 'database',
                  'release' => 'bosh-release',
                  'provides' => { 'db' => { 'as' => 'db2' } },
                },
                {
                  'name' => 'provider_fail',
                  'release' => 'bosh-release',
                  'provides' => { 'provider_fail' => { 'shared' => true } },
                  'properties' => { 'b' => 'important value' },
                },
              ],
              instances: 1,
            )
            spec['migrated_from'] = [
              { 'name' => aliased_instance_group_spec['name'] },
              { 'name' => secondary_aliased_instance_group_spec['name'] },
            ]
            spec['azs'] = ['invalid_network']
            spec
          end

          let(:deployment_error_string) do
            "Instance group 'merged_group' must specify availability zone that matches availability zones of network 'a'"
          end

          it 'should succeed to re-deploying a consumer with cross-deployment links' do
            _, code = deploy_simple_manifest(manifest_hash: consuming_manifest, return_exit_code: true)

            expect(code).to eq(0)
          end
        end
      end

      context 'if deploy is missing a property causing it to fail' do
        let(:secondary_aliased_instance_group_spec) do
          spec = Bosh::Common::DeepCopy.copy(aliased_instance_group_spec)
          spec['name'] = 'secondary_instance_group'
          spec['jobs'] << {
            'name' => 'provider_fail',
            'release' => 'bosh-release',
            'provides' => { 'provider_fail' => { 'shared' => true } },
            'properties' => { 'b' => 'adding_b' },
          }
          spec
        end

        let(:merged_instance_group) do
          spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
            name: 'merged_group',
            jobs: [
              {
                'name' => 'backup_database',
                'release' => 'bosh-release',
                'provides' => { 'backup_db' => { 'as' => 'link_alias' } },
              },
              {
                'name' => 'database',
                'release' => 'bosh-release',
                'provides' => { 'db' => { 'as' => 'db2' } },
              },
              {
                'name' => 'provider_fail',
                'release' => 'bosh-release',
                'provides' => { 'provider_fail' => { 'shared' => true } },
              },
            ],
            instances: 1,
          )
          spec['migrated_from'] = [
            { 'name' => aliased_instance_group_spec['name'] },
            { 'name' => secondary_aliased_instance_group_spec['name'] },
          ]
          spec['azs'] = ['z1']
          spec
        end

        before do
          deploy_simple_manifest(manifest_hash: manifest)
          manifest['instance_groups'] = [merged_instance_group]
          output, code = deploy_simple_manifest(manifest_hash: manifest, failure_expected: true, return_exit_code: true)

          expect(output).to include('Link property b in template provider_fail is not defined in release spec')
          expect(code).to_not eq(0)
        end

        it 'restart should not create new links' do
          bosh_runner.run('restart secondary_instance_group/0', deployment_name: 'simple')
        end

        it 'recreate should not create new links' do
          bosh_runner.run('recreate secondary_instance_group/0', deployment_name: 'simple')
        end

        it 'stop/start should not create new links' do
          bosh_runner.run('stop secondary_instance_group/0', deployment_name: 'simple')
          bosh_runner.run('start secondary_instance_group/0', deployment_name: 'simple')
        end

        it 'hard stop/start should not create new links' do
          bosh_runner.run('stop --hard secondary_instance_group/0', deployment_name: 'simple')
          bosh_runner.run('start secondary_instance_group/0', deployment_name: 'simple')
        end

        it 'should not create new links' do
          original_instance = director.instance('secondary_instance_group', '0')
          original_instance.kill_agent

          bosh_runner.run_interactively('cck', deployment_name: 'simple') do |runner|
            expect(runner).to have_output '3: Recreate VM without waiting for processes to start'
            runner.send_keys '3'
            expect(runner).to have_output 'Continue?'
            runner.send_keys 'yes'
            expect(runner).to have_output 'Succeeded'
          end

          recreated_instance = director.instance('secondary_instance_group', '0')
          expect(recreated_instance.vm_cid).to_not eq(original_instance.vm_cid)

          expect(original_instance.ips).to eq(recreated_instance.ips)
        end
      end

      context 'if deploy is has a bad az causing it to fail' do
        let(:secondary_aliased_instance_group_spec) do
          spec = Bosh::Common::DeepCopy.copy(aliased_instance_group_spec)
          spec['name'] = 'secondary_instance_group'
          spec['jobs'] << {
            'name' => 'provider_fail',
            'release' => 'bosh-release',
            'properties' => { 'b' => 'adding_b' },
          }
          spec
        end

        let(:merged_instance_group) do
          spec = SharedSupport::DeploymentManifestHelper.simple_instance_group(
            name: 'merged_group',
            jobs: [
              {
                'name' => 'backup_database',
                'release' => 'bosh-release',
                'provides' => { 'backup_db' => { 'as' => 'link_alias' } },
              },
              {
                'name' => 'database',
                'release' => 'bosh-release',
                'provides' => { 'db' => { 'as' => 'db2' } },
              },
              {
                'name' => 'provider_fail',
                'release' => 'bosh-release',
                'properties' => { 'b' => 'adding_b' },
              },
            ],
            instances: 1,
          )
          spec['migrated_from'] = [
            { 'name' => aliased_instance_group_spec['name'] },
            { 'name' => secondary_aliased_instance_group_spec['name'] },
          ]
          spec['azs'] = ['bad_az']
          spec
        end

        let(:deployment_error_string) do
          'Instance group \'merged_group\' must specify availability zone that matches availability zones of network'
        end

        before do
          deploy_simple_manifest(manifest_hash: manifest)
          manifest['instance_groups'] = [merged_instance_group]
          output, code = deploy_simple_manifest(manifest_hash: manifest, failure_expected: true, return_exit_code: true)
          error_string = "Instance group 'merged_group' must specify availability zone that matches availability zones of network"
          expect(output).to include(error_string)
          expect(code).to_not eq(0)
        end

        it 'restart should not create new links' do
          bosh_runner.run('restart secondary_instance_group', deployment_name: 'simple')
        end

        it 'recreate should not create new links' do
          bosh_runner.run('recreate secondary_instance_group', deployment_name: 'simple')
        end

        it 'stop/start should not create new links' do
          bosh_runner.run('stop secondary_instance_group', deployment_name: 'simple')
          bosh_runner.run('start secondary_instance_group', deployment_name: 'simple')
        end

        it 'hard stop/start should not create new links' do
          bosh_runner.run('stop --hard secondary_instance_group', deployment_name: 'simple')
          bosh_runner.run('start secondary_instance_group', deployment_name: 'simple')
        end

        it 'cck should not create new links' do
          bosh_runner.run('update-resurrection off')
          original_instance = director.instance('secondary_instance_group', '0')

          original_instance.kill_agent

          bosh_runner.run_interactively('cck', deployment_name: 'simple') do |runner|
            expect(runner).to have_output '3: Recreate VM without waiting for processes to start'
            runner.send_keys '3'
            expect(runner).to have_output 'Continue?'
            runner.send_keys 'yes'
            expect(runner).to have_output 'Succeeded'
          end

          recreated_instance = director.instance('secondary_instance_group', '0')
          expect(recreated_instance.vm_cid).to_not eq(original_instance.vm_cid)

          expect(original_instance.ips).to eq(recreated_instance.ips)
        end
      end
    end
  end
end
