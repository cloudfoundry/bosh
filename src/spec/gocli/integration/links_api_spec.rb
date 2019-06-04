require_relative '../spec_helper'

describe 'links api', type: :integration do
  with_reset_sandbox_before_each

  def upload_links_release
    FileUtils.cp_r(LINKS_RELEASE_TEMPLATE, ClientSandbox.links_release_dir, preserve: true)
    bosh_runner.run_in_dir('create-release --force', ClientSandbox.links_release_dir)
    bosh_runner.run_in_dir('upload-release', ClientSandbox.links_release_dir)
  end

  let(:manifest_hash) do
    Bosh::Spec::NewDeployments.manifest_with_release.merge(
      'instance_groups' => [instance_group],
      'features' => features
    )
  end

  let(:features) do
    {}
  end

  let(:instance_group) do
    {
      'name' => 'foobar',
      'jobs' => jobs,
      'vm_type' => 'a',
      'stemcell' => 'default',
      'instances' => 1,
      'networks' => [{ 'name' => 'a' }],
      'properties' => {},
      'persistent_disks' => persistent_disks,
    }
  end

  let(:jobs) { [] }

  let(:persistent_disks) { [] }

  let(:cloud_config_hash) do
    Bosh::Spec::NewDeployments.simple_cloud_config.merge(
      'disk_types' => [
        {
          'name' => 'low-performance-disk-type',
          'disk_size' => 1024,
          'cloud_properties' => { 'type' => 'gp2' },
        },
        {
          'name' => 'high-performance-disk-type',
          'disk_size' => 4076,
          'cloud_properties' => { 'type' => 'io1' },
        },
      ],
    )
  end

  let(:explicit_provider_and_consumer) { [explicit_provider, explicit_consumer] }

  let(:explicit_provider) do
    {
      'name' => 'provider',
      'release' => 'bosh-release',
      'provides' => { 'provider' => { 'as' => 'foo' } },
    }
  end

  let(:explicit_consumer) do
    {
      'name' => 'consumer',
      'release' => 'bosh-release',
      'consumes' => { 'provider' => { 'from' => 'foo' } },
    }
  end

  let(:implicit_provider_and_consumer) do
    [
      { 'name' => 'provider', 'release' => 'bosh-release' },
      { 'name' => 'consumer', 'release' => 'bosh-release' },
    ]
  end

  let(:provider_response) do
    {
      'id' => String,
      'name' => 'provider',
      'shared' => false,
      'deployment' => 'simple',
      'link_provider_definition' => {
        'name' => 'provider',
        'type' => 'provider',
      },
      'owner_object' => {
        'name' => 'provider',
        'type' => 'job',
        'info' => {
          'instance_group' => 'foobar',
        },
      },
    }
  end

  def disk_provider_response(name)
    provider_response.merge(
      'name' => name,
      'link_provider_definition' => {
        'name' => name,
        'type' => 'disk',
      },
      'owner_object' => {
        'name' => 'foobar',
        'type' => 'disk',
        'info' => {
          'instance_group' => 'foobar',
        },
      },
    )
  end

  def consumer_response(job_name = 'consumer', link_name = 'provider')
    {
      'id' => String,
      'name' => link_name,
      'optional' => false,
      'deployment' => 'simple',
      'owner_object' => {
        'name' => job_name,
        'type' => 'job',
        'info' => {
          'instance_group' => 'foobar',
        },
      },
      'link_consumer_definition' => {
        'name' => link_name,
        'type' => link_name,
      },
    }
  end

  let(:links_response) do
    {
      'id' => '1',
      'name' => 'provider',
      'link_consumer_id' => '1',
      'link_provider_id' => '1',
      'created_at' => String,
    }
  end

  def get(path, params)
    send_director_get_request(path, params)
  end

  def get_json(*args)
    JSON.parse get(*args).read_body
  end

  def get_link_providers
    get_json('/link_providers', 'deployment=simple')
  end

  def get_link_consumers
    get_json('/link_consumers', 'deployment=simple')
  end

  def get_links
    get_json('/links', 'deployment=simple')
  end

  before do
    upload_links_release
    upload_stemcell

    upload_cloud_config(cloud_config_hash: cloud_config_hash)
  end

  def add_extra_networks_and_mark_default(cloud_config_hash, manifest_hash)
    new_network_b = {
      'name' => 'b',
      'subnets' => [{
                      'range' => '10.0.0.0/24',
                      'gateway' => '10.0.0.1',
                      'dns' => ['10.0.0.1', '10.0.0.2'],
                      'static' => ['10.0.0.10'],
                      'reserved' => [],
                      'cloud_properties' => {},
                    }]
    }
    cloud_config_hash['networks'].push(new_network_b)

    manifest_hash['instance_groups'][0]['networks'][0]['default'] = ['dns','gateway']
    manifest_hash['instance_groups'][0]['networks'].push({'name' => new_network_b['name']})
  end

  context 'when requesting for a list of providers via link_providers endpoint' do
    before do
      deploy_simple_manifest(manifest_hash: manifest_hash)
    end

    context 'when deployment has an implicit link provider' do
      let(:jobs) { [{ 'name' => 'provider', 'release' => 'bosh-release' }] }

      it 'should return the correct number of providers' do
        expected_response = [provider_response]

        expect(get_link_providers).to match_array(expected_response)
      end
    end

    context 'when deployment has an explicit link provider' do
      let(:jobs) { [explicit_provider] }

      it 'should return the correct number of providers' do
        expected_response = [provider_response.merge('name' => 'foo')]

        expect(get_link_providers).to match_array(expected_response)
      end

      context 'and the provider is shared' do
        let(:jobs) do
          [
            {
              'name' => 'provider',
              'release' => 'bosh-release',
              'provides' => {
                'provider' => {
                  'as' => 'foo',
                  'shared' => true,
                },
              },
            },
          ]
        end

        it 'should set the `shared` key to true' do
          expected_response = [provider_response.merge('name' => 'foo', 'shared' => true)]

          expect(get_link_providers).to match_array(expected_response)
        end
      end

      context 'then redeploying with a new alias' do
        let(:updated_manifest_hash) do
          manifest_hash.tap do |mh|
            mh['instance_groups'][0]['jobs'][0]['provides']['provider']['as'] = 'bar'
            mh['instance_groups'][0]['jobs'][0]['release'] = 'bosh-release'
          end
        end

        before do
          deploy_simple_manifest(manifest_hash: updated_manifest_hash)
        end

        it 'should return the original provider with updated information' do
          expected_response = [provider_response.merge('id' => '1', 'name' => 'bar')]

          expect(get_link_providers).to match_array(expected_response)
        end
      end
    end

    context 'when deployment has a custom provider definition' do
      let(:jobs) do
        [
          {
            'name' => 'api_server_with_optional_db_link',
            'release' => 'bosh-release',
            'provides' => {'smurf' => {'shared' => true}},
            'custom_provider_definitions' => [
              {
                'name' => 'smurf',
                'type' => 'gargamel',
              }
            ]
          },
        ]
      end

      it 'should create a provider' do
        expected_response = [
          {
            'id' => String,
            'name' => 'smurf',
            'shared' => true,
            'deployment' => 'simple',
            'link_provider_definition' => {
              'name' => 'smurf',
              'type' => 'gargamel',
            },
            'owner_object' => {
              'name' => 'api_server_with_optional_db_link',
              'type' => 'job',
              'info' => {
                'instance_group' => 'foobar',
              },
            },
          }
        ]

        expect(get_link_providers).to match_array(expected_response)
      end
    end

    context 'when deployment has a disk link provider' do
      let(:persistent_disks) do
        [low_iops_persistent_disk, high_iops_persistent_disk]
      end

      let(:low_iops_persistent_disk) do
        {
          'type' => 'low-performance-disk-type',
          'name' => 'low-iops-persistent-disk-name',
        }
      end

      let(:high_iops_persistent_disk) do
        {
          'type' => 'high-performance-disk-type',
          'name' => 'high-iops-persistent-disk-name',
        }
      end

      it 'should return the disk providers' do
        expected_response = [
          disk_provider_response('low-iops-persistent-disk-name'),
          disk_provider_response('high-iops-persistent-disk-name'),
        ]

        expect(get_link_providers).to match_array(expected_response)
      end
    end

    context 'when deployment has multiple providers with the same name' do
      let(:persistent_disks) do
        [
          {
            'type' => 'low-performance-disk-type',
            'name' => 'provider',
          },
        ]
      end

      let(:jobs) do
        [
          {
            'name' => 'provider',
            'release' => 'bosh-release',
          },
          {
            'name' => 'alternate_provider',
            'release' => 'bosh-release',
            'provides' => { 'provider' => { 'as' => 'provider' } },
          },
        ]
      end

      it 'should return all providers' do
        expected_response = [
          provider_response,
          provider_response.deep_merge(
            'owner_object' => {
              'name' => 'alternate_provider',
              'info' => {
                'instance_group' => 'foobar',
              },
            },
          ),
          disk_provider_response('provider'),
        ]

        expect(get_link_providers).to match_array(expected_response)
      end
    end

    context 'when deployment does not have a link provider' do
      it 'should return an empty list of providers' do
        expected_response = []

        expect(get_link_providers).to match_array(expected_response)
      end
    end

    context 'when deployment is not specified' do
      it 'should raise an error' do
        actual_response = get_json('/link_providers', '')

        expected_error = Bosh::Director::DeploymentRequired.new('Deployment name is required')
        expected_response = {
          'code' => expected_error.error_code,
          'description' => expected_error.message,
        }

        expect(actual_response).to match(expected_response)
      end
    end

    context 'when user does not have sufficient permissions' do
      it 'should raise an error' do
        response = send_director_get_request('/link_providers', 'deployment=simple', {})

        expect(response.read_body).to include("Not authorized: '/link_providers'")
      end
    end
  end

  context 'when requesting for a list of consumers via link_consumers endpoint' do
    before do
      deploy_simple_manifest(manifest_hash: manifest_hash)
    end

    context 'when a job has a link consumer' do
      let(:jobs) { implicit_provider_and_consumer }

      it 'should return the correct number of consumers' do
        expected_response = [consumer_response]

        expect(get_link_consumers).to match_array(expected_response)
      end

      context 'and the consumer is optional' do
        let(:jobs) { [{ 'name' => 'api_server_with_optional_db_link', 'release' => 'bosh-release' }] }

        it 'should still create a consumer' do
          expected_response = [consumer_response('api_server_with_optional_db_link', 'db').merge('optional' => true)]

          expect(get_link_consumers).to match_array(expected_response)
        end
      end

      context 'when the link is provided by a new provider' do
        let(:updated_manifest_hash) do
          manifest_hash.tap do |mh|
            mh['instance_groups'][0]['jobs'][0]['name'] = 'alternate_provider'
            mh['instance_groups'][0]['jobs'][0]['release'] = 'bosh-release'
          end
        end

        it 'should reuse the same consumers' do
          expected_response = get_link_consumers

          deploy_simple_manifest(manifest_hash: updated_manifest_hash)

          actual_response = get_link_consumers
          expect(actual_response).to match_array(expected_response)
        end
      end
    end

    context 'when deployment does not have a link consumer' do
      it 'should return an empty list of consumers' do
        expect(get_link_consumers).to be_empty
      end
    end

    context 'when deployment is not specified' do
      it 'should raise an error' do
        actual_response = get_json('/link_consumers', '')

        expected_error = Bosh::Director::DeploymentRequired.new('Deployment name is required')
        expected_response = {
          'code' => expected_error.error_code,
          'description' => expected_error.message,
        }

        expect(actual_response).to match(expected_response)
      end
    end

    context 'when user does not have sufficient permissions' do
      it 'should raise an error' do
        response = send_director_get_request('/link_consumers', 'deployment=simple', {})

        expect(response.read_body).to include("Not authorized: '/link_consumers'")
      end
    end
  end

  context 'when requesting for a list of links via links endpoint' do
    before do
      deploy_simple_manifest(manifest_hash: manifest_hash)
    end

    context 'when deployment has an implicit provider + consumer' do
      let(:jobs) { implicit_provider_and_consumer }

      it 'should return the correct number of links' do
        deploy_simple_manifest(manifest_hash: manifest_hash)

        expected_response = [links_response]

        expect(get_links).to match_array(expected_response)
      end
    end

    context 'when deployment has an explicit provider + consumer' do
      let(:jobs) { explicit_provider_and_consumer }

      it 'should return the correct number of links' do
        expected_response = [links_response]

        expect(get_links).to match_array(expected_response)
      end

      context 'and the provider is shared' do
        let(:jobs) do
          [
            {
              'name' => 'provider',
              'release' => 'bosh-release',
              'provides' => {
                'provider' => {
                  'as' => 'foo',
                  'shared' => true,
                },
              },
            },
          ]
        end

        let(:consumer_manifest_hash) do
          Bosh::Spec::NewDeployments.manifest_with_release.merge(
            'name' => 'consumer-simple',
            'instance_groups' => [consumer_instance_group],
          )
        end

        let(:consumer_instance_group) do
          {
            'name' => 'foobar',
            'jobs' => [
              {
                'name' => 'consumer',
                'release' => 'bosh-release',
                'consumes' => {
                  'provider' => {
                    'from' => 'foo',
                    'deployment' => 'simple',
                  },
                },
              },
            ],
            'vm_type' => 'a',
            'stemcell' => 'default',
            'instances' => 1,
            'networks' => [{ 'name' => 'a' }],
            'properties' => {},
          }
        end

        it 'should create a link for the cross deployment link' do
          deploy_simple_manifest(manifest_hash: consumer_manifest_hash)

          actual_response = get_json('/links', 'deployment=consumer-simple')
          expected_response = [links_response]

          expect(actual_response).to match_array(expected_response)
        end

        context 'when the shared provider is removed' do
          before do
            deploy_simple_manifest(manifest_hash: consumer_manifest_hash)

            manifest_hash['instance_groups'][0]['jobs'] = []
            deploy_simple_manifest(manifest_hash: manifest_hash)
            links_response['link_provider_id'] = nil
          end

          it 'should become an orphaned link (with no provider)' do
            actual_response = get_json('/links', 'deployment=consumer-simple')
            expected_response = [links_response]

            expect(actual_response).to match_array(expected_response)
          end
        end

        context 'when the shared provider deployment is removed' do
          before do
            deploy_simple_manifest(manifest_hash: consumer_manifest_hash)

            bosh_runner.run('delete-deployment', deployment_name: 'simple')
            links_response['link_provider_id'] = nil
          end

          it 'should become an orphaned link (with no provider)' do
            actual_response = get_json('/links', 'deployment=consumer-simple')
            expected_response = [links_response]

            expect(actual_response).to match_array(expected_response)
          end
        end

        context 'when the consumer is removed' do
          before do
            deploy_simple_manifest(manifest_hash: consumer_manifest_hash)

            consumer_manifest_hash['instance_groups'][0]['jobs'] = []
            deploy_simple_manifest(manifest_hash: consumer_manifest_hash)
          end

          it 'should remove the link' do
            actual_response = get_json('/links', 'deployment=consumer-simple')
            expected_response = []
            expect(actual_response).to match_array(expected_response)
          end
        end
      end
    end

    context 'when deployment consuming manual link' do
      let(:jobs) do
        [
          {
            'name' => 'consumer',
            'release' => 'bosh-release',
            'consumes' => {
              'provider' => {
                'instances' => [{ 'address' => 'teswfbquts.cabsfabuo7yr.us-east-1.rds.amazonaws.com' }],
                'properties' => { 'a' => 'bar', 'c' => 'bazz' },
              },
            },
          },
        ]
      end

      it 'should return a single orphaned link' do
        expected_response = [links_response.merge('link_provider_id' => String)]
        expect(get_links).to match_array(expected_response)
      end
    end

    context 'when the deployment consumes a disk provider' do
      let(:persistent_disks) do
        [low_iops_persistent_disk, high_iops_persistent_disk]
      end

      let(:low_iops_persistent_disk) do
        {
          'type' => 'low-performance-disk-type',
          'name' => 'low-iops-persistent-disk-name',
        }
      end

      let(:high_iops_persistent_disk) do
        {
          'type' => 'high-performance-disk-type',
          'name' => 'high-iops-persistent-disk-name',
        }
      end

      let(:jobs) do
        [
          {
            'name' => 'disk_consumer',
            'release' => 'bosh-release',
            'consumes' => {
              'disk_provider' => { 'from' => 'low-iops-persistent-disk-name' },
              'backup_disk_provider' => { 'from' => 'high-iops-persistent-disk-name' },
            },
          },
        ]
      end

      it 'should have one link for each disk being consumed' do
        expected_response = [
          links_response.merge(
            'id' => String,
            'name' => 'disk_provider',
            'link_provider_id' => '1',
          ),
          links_response.merge(
            'id' => String,
            'name' => 'backup_disk_provider',
            'link_consumer_id' => '2',
            'link_provider_id' => '2',
          ),
        ]
        expect(get_links).to match_array(expected_response)
      end
    end

    context 'when deployment is not specified' do
      it 'should raise an error' do
        actual_response = get_json('/links', '')

        expected_error = Bosh::Director::DeploymentRequired.new('Deployment name is required')
        expected_response = {
          'code' => expected_error.error_code,
          'description' => expected_error.message,
        }

        expect(actual_response).to match(expected_response)
      end
    end

    context 'when user does not have sufficient permissions' do
      it 'should raise an error' do
        response = send_director_get_request('/links', 'deployment=simple', {})

        expect(response.read_body).to include("Not authorized: '/links'")
      end
    end

    context 'when consumer is removed from deployment' do
      let(:jobs) { [explicit_provider] }

      it 'should remove consumer data from link_consumer' do
        deploy_simple_manifest(manifest_hash: manifest_hash)

        expect(get_links).to be_empty
      end
    end

    context 'when deployment has a custom provider definition' do
      context 'when definition satisfies a consumer' do
        let(:jobs) do
          [
            {
              'name' => 'api_server_with_optional_db_link',
              'release' => 'bosh-release',
              'custom_provider_definitions' => [
                {
                  'name' => 'smurf',
                  'type' => 'db',
                },
              ],
            },
          ]
        end

        it 'should create a link' do
          expected_response = [
            {
              'id' => '1',
              'name' => 'db',
              'link_consumer_id' => '1',
              'link_provider_id' => '1',
              'created_at' => String,
            },
          ]

          expect(get_links).to match_array(expected_response)
        end
      end
    end
  end

  context 'when deployment which consumes and provides links already exist' do
    let(:jobs) { explicit_provider_and_consumer }

    before do
      deploy_simple_manifest(manifest_hash: manifest_hash)
      @expected_providers = get_link_providers
      @expected_consumers = get_link_consumers
      @expected_links = get_links
      deploy_simple_manifest(manifest_hash: manifest_hash)
    end

    context 'redeploying no changes' do
      before do
        deploy_simple_manifest(manifest_hash: manifest_hash)
      end

      it 'should use the same provider' do
        expect(get_link_providers).to match_array(@expected_providers)
      end

      it 'should use the same consumer' do
        expect(get_link_consumers).to match_array(@expected_consumers)
      end

      it 'should not create a new link' do
        expect(get_links).to match_array(@expected_links)
      end
    end

    context 'recreating deployment' do
      before do
        bosh_runner.run('recreate', deployment_name: 'simple')
      end

      it 'should use the same provider' do
        expect(get_link_providers).to match_array(@expected_providers)
      end

      it 'should use the same consumer' do
        expect(get_link_consumers).to match_array(@expected_consumers)
      end

      it 'should not create a new link' do
        expect(get_links).to match_array(@expected_links)
      end
    end

    context 'when redeploying with change to provider' do
      let(:new_jobs) do
        [
          {
            'name' => 'provider',
            'release' => 'bosh-release',
            'provides' => { 'provider' => { 'as' => 'bar' } },
          },
          {
            'name' => 'consumer',
            'release' => 'bosh-release',
            'consumes' => { 'provider' => { 'from' => 'bar' } },
          },
        ]
      end

      it 'should reuse the old links' do
        manifest_hash['instance_groups'][0]['jobs'] = new_jobs

        deploy_simple_manifest(manifest_hash: manifest_hash)

        expected_response = [links_response]
        expect(get_links).to match_array(expected_response)
      end
    end

    context 'when redeploying with change to provider instances' do
      it 'should remove the old link and make a new one' do
        manifest_hash['instance_groups'][0]['instances'] = 2

        deploy_simple_manifest(manifest_hash: manifest_hash)

        links = get_links
        expect(links.count).to eq(1)
        expect(links.first['id']).to eq('2')
      end
    end

    context 'when the second deploy fails, so the deploy is rolled back' do
      let(:cloud_config_hash) do
        Bosh::Spec::NewDeployments.simple_cloud_config.tap do |cloud_config|
          cloud_config['networks'][0]['subnets'][0]['az'] = 'z1'
          cloud_config['compilation']['az'] = 'z1'
          cloud_config['azs'] = ['name' => 'z1']
        end
      end

      let(:instance_group) do
        spec = Bosh::Spec::NewDeployments.simple_instance_group(
          name: 'instance_group',
          jobs: [
            { 'name' => 'api_server_2_instances', 'release' => 'bosh-release' },
            { 'name' => 'database', 'release' => 'bosh-release' },
          ],
          instances: 2,
        )
        spec['networks'] = [{ 'name' => 'a' }]
        spec['azs'] = ['z1']
        spec
      end

      it 'should show the only the first links after redeploy' do
        manifest_hash['instance_groups'][0]['instances'] = 3

        out, exit_code = deploy_simple_manifest(manifest_hash: manifest_hash, failure_expected: true, return_exit_code: true)
        expect(exit_code).to eq(1)
        expect(out).to include('Error: Unable to render instance groups for deployment. Errors are:')
        expect(out).to include("- Error filling in template 'config.yml.erb' " \
          '(line 2: Expected exactly two instances of db in current deployment)')
        failed_links = get_links
        expect(failed_links.count).to eq(4)

        manifest_hash['instance_groups'][0]['instances'] = 2
        deploy_simple_manifest(manifest_hash: manifest_hash)
        final_links = get_links
        expect(final_links.count).to eq(2)
        expect(final_links).to include(@expected_links[0])
        expect(final_links).to include(@expected_links[1])
      end
    end

    context 'when a provider job is removed, so the implicit link should be cleared out' do
      let(:cloud_config_hash) do
        Bosh::Spec::NewDeployments.simple_cloud_config.tap do |cloud_config|
          cloud_config['networks'][0]['subnets'][0]['az'] = 'z1'
          cloud_config['compilation']['az'] = 'z1'
          cloud_config['azs'] = ['name' => 'z1']
        end
      end

      let(:instance_group) do
        spec = Bosh::Spec::NewDeployments.simple_instance_group(
          name: 'instance_group',
          jobs: [
            { 'name' => 'errand_with_optional_links', 'release' => 'bosh-release' },
            { 'name' => 'database', 'release' => 'bosh-release' },
            { 'name' => 'provider', 'release' => 'bosh-release' },
          ],
          instances: 2,
        )
        spec['networks'] = [{ 'name' => 'a' }]
        spec['azs'] = ['z1']
        spec
      end

      it 'should show the only the first links after redeploy' do
        out = run_errand('errand_with_optional_links', deployment_name: 'simple')
        expect(out).to include(/provider 192.168.1.2/)
        expect(@expected_links.count).to eq(2)

        manifest_hash['instance_groups'][0]['jobs'].delete_at(2)
        deploy_simple_manifest(manifest_hash: manifest_hash)
        out = run_errand('errand_with_optional_links', deployment_name: 'simple')
        expect(out).to include(/db 192.168.1.2/)
        final_links = get_links
        expect(final_links.count).to eq(1)
        persistent_link_index = @expected_links.index { |link| link['name'] == 'db' }

        expect(final_links).to include(@expected_links[persistent_link_index])
      end
    end
  end

  context 'when doing POST request to create link' do
    before do
      add_extra_networks_and_mark_default(cloud_config_hash, manifest_hash)
      upload_cloud_config(cloud_config_hash: cloud_config_hash)
      deploy_simple_manifest(manifest_hash: manifest_hash)
    end

    context 'when correct json is provided' do
      let(:provider_id) { '1' }
      let(:payload_json) do
        {
          'link_provider_id' => provider_id,
          'link_consumer' => {
            'owner_object' => {
              'name' => 'external_consumer_1',
              'type' => 'external',
            },
          },
        }
      end
      let(:jobs) do
        [
          {
            'name' => 'provider',
            'release' => 'bosh-release',
            'provides' => {
              'provider' => {
                'as' => 'foo',
                'shared' => true,
              },
            },
          },
        ]
      end

      context 'when provider already exists' do
        let(:jobs) do
          [
            {
              'name' => 'mongo_db',
              'release' => 'bosh-release',
              'provides' => {
                'read_only_db' => {
                  'as' => 'foo',
                  'shared' => true,
                },
              },
            },
          ]
        end

        before do
          provider_response = get_link_providers
          provider_id = provider_response.first['id']
        end

        it 'provide link json output' do
          response = send_director_post_request('/links', '', JSON.generate(payload_json))
          link = JSON.parse(response.read_body)

          provider_original_name = jobs[0]['provides'].keys[0]
          expect(link['name']).to eq(provider_original_name)
          expect(link['link_provider_id']).to eq(provider_id)
        end

        it 'create consumer_intent' do
          send_director_post_request('/links', '', JSON.generate(payload_json))
          response = get_link_consumers

          expect(response.count).to_not eq(0)
          consumer = response[0]

          provider_response = get_link_providers

          expect(provider_response.count).to_not eq(0)
          provider = provider_response[0]

          expect(consumer['deployment']).to eq('simple')
          expect(consumer['name']).to eq('foo')
          expect(consumer['owner_object']['type']).to eq('external')
          expect(consumer['owner_object']['info']).to be_nil

          expect(consumer['link_consumer_definition']['name']).to eq(provider['link_provider_definition']['name'])
        end

        it 'keeps the consumer and link after redeploy' do
          send_director_post_request('/links', '', JSON.generate(payload_json))
          provider_response = get_link_providers

          expect(provider_response.count).to_not eq(0)
          provider = provider_response[0]

          response = get_link_consumers

          deploy_simple_manifest(manifest_hash: manifest_hash)
          response2 = get_link_consumers

          expect(response.count).to eq(response2.count)
          consumer = response2[0]
          expect(consumer['deployment']).to eq('simple')
          expect(consumer['owner_object']['type']).to eq('external')
          expect(consumer['link_consumer_definition']['name']).to eq(provider['link_provider_definition']['name'])
        end

        context 'when provider does not change during re-deploy' do
          context 'when multiple requests have same owner_object and provider_id' do
            before do
              first_response = send_director_post_request('/links', '', JSON.generate(payload_json))
              @link_1 = JSON.parse(first_response.read_body)
            end

            context 'when requesting link with same request parameters again' do
              it 'should NOT create new link' do
                second_response = send_director_post_request("/links", '', JSON.generate(payload_json))
                link_2 = JSON.parse(second_response.read_body)

                expect(link_2).to eq(@link_1)
              end
            end

            context 'when requesting link with different request parameters' do
              before do
                payload_json['network'] = 'b'
              end

              it 'should create new link' do
                second_response = send_director_post_request("/links", '', JSON.generate(payload_json))
                link_2 = JSON.parse(second_response.read_body)

                expect(link_2['id']).to_not eq(@link_1['id'])
              end
            end
          end
        end

        context 'when provider content changes during re-deploy' do
          context 'when multiple request have same owner_object and provider_id before and after re-deploy' do
            before do
              first_response = send_director_post_request("/links", '', JSON.generate(payload_json))
              @link_1 = JSON.parse(first_response.read_body)
            end

            context 'when provider number of instances changes' do
              before do
                # re-deploy with provider content changes
                manifest_hash['instance_groups'][0]['instances'] = manifest_hash['instance_groups'][0]['instances'] + 1
                deploy_simple_manifest(manifest_hash: manifest_hash)
              end

              it 'should create new link' do
                second_response = send_director_post_request("/links", '', JSON.generate(payload_json))
                link_2 = JSON.parse(second_response.read_body)

                expect(link_2['id']).to_not eq(@link_1['id'])
              end
            end

            context 'when provider properties change' do
              before do
                updated_properties = {
                  'foo' => {
                    'one' => 'updated-nested-property',
                    'two' => 'another-updated-nested-property',
                  },
                }
                manifest_hash['instance_groups'][0]['properties'] = updated_properties
                # re-deploy with provider content changes
                deploy_simple_manifest(manifest_hash: manifest_hash)
              end

              it 'should create new link' do
                second_response = send_director_post_request("/links", '', JSON.generate(payload_json))
                link_2 = JSON.parse(second_response.read_body)

                expect(link_2['id']).to_not eq(@link_1['id'])
              end
            end

            context 'when provider networks change' do
              before do
                provider_response = get_link_providers
                provider_id = provider_response.first['id']

                response = send_director_post_request("/links", '', JSON.generate(payload_json))
                @before_deploy_link = JSON.parse(response.read_body)
              end

              context 'default network stays the same' do
                context 'new network added to cloud config and deployment' do
                  before do
                    new_network_c = {
                      'name' => 'c',
                      'subnets' => [{
                                      'range' => '10.1.0.0/24',
                                      'gateway' => '10.1.0.1',
                                      'dns' => ['10.1.0.1', '10.1.0.2'],
                                      'static' => ['10.1.0.10'],
                                      'reserved' => [],
                                      'cloud_properties' => {},
                                    }]
                    }
                    cloud_config_hash['networks'].push(new_network_c)
                    upload_cloud_config(cloud_config_hash: cloud_config_hash)

                    manifest_hash['instance_groups'][0]['networks'].push({'name' => new_network_c['name']})
                    # re-deploy with provider content changes
                    deploy_simple_manifest(manifest_hash: manifest_hash)
                  end

                  it 'creates new link using existing consumer for external link request for new network' do
                    payload_json['network'] = 'c'
                    response = send_director_post_request("/links", '', JSON.generate(payload_json))

                    expect(response.code).to eq('200')

                    after_deploy_link = JSON.parse(response.read_body)
                    expect(after_deploy_link['id']).to_not eq(@before_deploy_link['id'])
                    expect(after_deploy_link['link_consumer_id']).to eq(@before_deploy_link['link_consumer_id'])
                  end

                  it 'creates new link using existing consumer for external link request for existing network' do
                    payload_json['network'] = 'a'
                    response = send_director_post_request("/links", '', JSON.generate(payload_json))

                    expect(response.code).to eq('200')

                    after_deploy_link = JSON.parse(response.read_body)
                    expect(after_deploy_link['id']).to_not eq(@before_deploy_link['id'])
                    expect(after_deploy_link['link_consumer_id']).to eq(@before_deploy_link['link_consumer_id'])
                  end
                end
              end

              context 'default network changes' do
                before do
                  manifest_hash['instance_groups'][0]['networks'][0] = {'name' => 'a'}
                  manifest_hash['instance_groups'][0]['networks'][1] = {'name' => 'b', 'default' => ['dns','gateway']}
                  deploy_simple_manifest(manifest_hash: manifest_hash)
                end

                context 'requesting external link for new network' do
                  it 'creates new link and uses same consumer record' do
                    payload_json['network'] = 'b'
                    response = send_director_post_request("/links", '', JSON.generate(payload_json))

                    expect(response.code).to eq('200')

                    after_deploy_link = JSON.parse(response.read_body)
                    expect(after_deploy_link['id']).to_not eq(@before_deploy_link['id'])
                    expect(after_deploy_link['link_consumer_id']).to eq(@before_deploy_link['link_consumer_id'])
                  end
                end

                context 'requesting external link for old network' do
                  before do
                    # requesting for same network 'a', which id default network
                    payload_json['network']='a'
                    response = send_director_post_request("/links", '', JSON.generate(payload_json))

                    @old_network_link = JSON.parse(response.read_body)
                  end

                  it 'should not create new link with existing consumer' do
                    expect(@old_network_link['id']).to eq(@before_deploy_link['id'])
                    expect(@old_network_link['link_consumer_id']).to eq(@before_deploy_link['link_consumer_id'])
                  end

                  context 'requesting external link for old network again' do
                    it 'returns previously created link' do
                      payload_json['network']='a'
                      response = send_director_post_request("/links", '', JSON.generate(payload_json))

                      expect(response.code).to eq('200')

                      after_deploy_link = JSON.parse(response.read_body)
                      expect(after_deploy_link['id']).to eq(@old_network_link['id'])
                      expect(after_deploy_link['link_consumer_id']).to eq(@old_network_link['link_consumer_id'])
                    end
                  end
                end
              end
            end
          end
        end

        context 'when provider is NOT shared' do
          let(:jobs) do
            [
              {
                'name' => 'provider',
                'release' => 'bosh-release',
                'provides' => {
                  'provider' => {
                    'as' => 'foo',
                    'shared' => false,
                  },
                },
              },
            ]
          end
          it 'should returns error' do
            response = send_director_post_request('/links', '', JSON.generate(payload_json))
            error_response = JSON.parse(response.read_body)
            expect(error_response['code']).to eq(Bosh::Director::LinkProviderNotSharedError.new.error_code)
            expect(error_response['description']).to eq("Provider not `shared`")
          end
        end

        context 'when attempting to create the link a second time' do
          before do
            response = send_director_post_request('/links', '', JSON.generate(payload_json)).read_body
            @link1 = JSON.parse(response)
          end

          it 'should return the existing link' do
            response = send_director_post_request('/links', '', JSON.generate(payload_json)).read_body
            link2 = JSON.parse(response)
            expect(@link1).to eq(link2)
          end
        end

        context 'when multiple provider with same name and type exists' do
          before do
            new_instance_group = Bosh::Spec::NewDeployments.simple_instance_group(
              name: 'new-foobar',
              jobs: jobs,
            )
            manifest_hash['instance_groups'] << new_instance_group
            deploy_simple_manifest(manifest_hash: manifest_hash)
          end

          it 'should create link with correct provider' do
            all_providers = get_link_providers
            expect(all_providers.count).to eq(2)

            response = send_director_post_request('/links', '', JSON.generate(payload_json))
            link = JSON.parse(response.read_body)

            provider_original_name = jobs[0]['provides'].keys[0]
            expect(link['name']).to eq(provider_original_name)
            expect(link['link_provider_id']).to eq(provider_id)
          end
        end
      end

      context 'when link_provider_id do not exists' do
        let(:provider_id) { '42' }

        it 'returns error' do
          response = send_director_post_request('/links', '', JSON.generate(payload_json))
          error_response = JSON.parse(response.read_body)
          expect(error_response['description']).to eq("Invalid link_provider_id: #{provider_id}")
        end
      end

      context 'when link_provider_id is invalid' do
        let(:provider_id) { '' }
        it 'returns error' do
          response = send_director_post_request('/links', '', JSON.generate(payload_json))
          error_response = JSON.parse(response.read_body)
          expect(error_response['description']).to eq('Invalid request: `link_provider_id` must be provided')
        end
      end

      context 'when owner_object.name is invalid' do
        let(:payload_json) do
          {
            'link_provider_id' => provider_id,
            'link_consumer' => {
              'owner_object' => {
                'name' => '',
                'type' => 'external',
              },
            },
          }
        end

        it 'returns error' do
          response = send_director_post_request('/links', '', JSON.generate(payload_json))
          error_response = JSON.parse(response.read_body)
          expect(error_response['description']).to eq('Invalid request: `link_consumer.owner_object.name` must not be empty')
        end
      end

      context 'when network name is provided' do
        let(:network_name) { 'a' }
        let(:payload_json) do
          {
            'link_provider_id' => provider_id,
            'link_consumer' => {
              'owner_object' => {
                'name' => 'external_consumer_1',
                'type' => 'external',
              },
            },
            'network' => network_name,
          }
        end

        before do
          provider_response = get_link_providers
          provider_id = provider_response.first['id']
        end

        context 'when network name is valid' do
          it 'creates links' do
            response = send_director_post_request('/links', '', JSON.generate(payload_json))
            link = JSON.parse(response.read_body)

            expect(link).to match(links_response)
          end
        end

        context 'when network name is invalid' do
          let(:network_name) { 'invalid-network-name' }

          it 'return error' do
            response = send_director_post_request('/links', '', JSON.generate(payload_json))
            error_response = JSON.parse(response.read_body)
            error_string = "Can't resolve network: `#{network_name}` in provider id: #{provider_id} for `#{payload_json['link_consumer']['owner_object']['name']}`"

            expect(error_response['description']).to eq(error_string)
          end
        end
      end
    end

    context 'when user does not have sufficient permissions' do
      it 'should raise an error' do
        response = send_director_post_request('/links', '', JSON.generate({}), {})

        expect(response.read_body).to include("Not authorized: '/links'")
      end
    end
  end

  context 'when the provider deploy fails' do
    let(:provider_id) { '1' }
    let(:payload_json) do
      {
        'link_provider_id' => provider_id,
        'network' => 'a',
        'link_consumer' => {
          'owner_object' => {
            'name' => 'external_consumer_1',
            'type' => 'external',
          },
        },
      }
    end
    let(:jobs) do
      [
        {
          'name' => 'provider',
          'release' => 'bosh-release',
          'provides' => {
            'provider' => {
              'as' => 'foo',
              'shared' => true,
            },
          },
        },
      ]
    end

    before do
      manifest_hash['instance_groups'][0]['azs'] = ['unknown_az']

      _, exit_code = deploy_simple_manifest(manifest_hash: manifest_hash, failure_expected: true, return_exit_code: true)
      expect(exit_code).to_not eq(0)
    end

    it 'should fail to create the link gracefully' do
      response = send_director_post_request('/links', '', JSON.generate(payload_json))

      link = JSON.parse(response.read_body)
      expect(link['code']).to eq(810003)
      expect(link['description']).to eq("Can't resolve network: `a` in provider id: 1 for `external_consumer_1`")
    end
  end

  context 'when doing DELETE request to delete link' do
    let(:provider_id) { '1' }
    let(:payload_json) do
      {
        'link_provider_id' => provider_id,
        'link_consumer' => {
          'owner_object' => {
            'name' => 'external_consumer_1',
            'type' => 'external',
          },
        },
        'network' => 'a',
      }
    end
    let(:jobs) do
      [
        {
          'name' => 'provider',
          'release' => 'bosh-release',
          'provides' => {
            'provider' => {
              'as' => 'foo',
              'shared' => true,
            },
          },
        },
      ]
    end

    before do
      deploy_simple_manifest(manifest_hash: manifest_hash)
      provider_response = get_link_providers
      provider_id = provider_response.first['id']
      send_director_post_request('/links', '', JSON.generate(payload_json))
    end

    it 'performs a successful delete when link exists' do
      response = send_director_delete_request('/links/1', '')
      expect(response.body).to be_nil
      expect(response).to be_an_instance_of(Net::HTTPNoContent)
    end

    it 'raises error if link does not exist' do
      response = send_director_delete_request('/links/2', '')
      expect(response).to be_an_instance_of(Net::HTTPNotFound)
      parsed_body_hash = JSON.parse(response.body)
      expect(parsed_body_hash['code']).to eq(Bosh::Director::LinkLookupError.new.error_code)
      expect(parsed_body_hash['description']).to eq('Invalid link id: 2')
    end
  end

  context 'when doing GET for link_address' do
    let(:jobs) do
      [
        {
          'name' => 'provider',
          'release' => 'bosh-release',
          'provides' => {
            'provider' => {
              'as' => 'foo',
              'shared' => true,
            },
          },
        },
        explicit_consumer,
      ]
    end

    let(:instance_group) do
      Bosh::Spec::NewDeployments.simple_instance_group(jobs: jobs, azs: ['z2'])
    end

    let(:cloud_config_hash) do
      Bosh::Spec::NewDeployments.simple_cloud_config_with_multiple_azs
    end

    let(:payload_json) do
      {
        'link_consumer' => {
          'owner_object' => {
            'name' => 'external_consumer_1',
            'type' => 'external',
          },
        },
      }
    end

    before do
      deploy_simple_manifest(manifest_hash: manifest_hash)
      provider_response = get_link_providers
      provider_id = provider_response.first['id']
      payload_json['link_provider_id'] = provider_id
    end

    it 'returns link address' do
      external_link_response = JSON.parse(send_director_post_request('/links', '', JSON.generate(payload_json)).read_body)
      response = get_json('/link_address', "link_id=#{external_link_response['id']}")
      expect(response).to eq('address' => 'q-s0.foobar.a.simple.bosh')
    end

    context 'azs' do
      context 'when querying for a specific az' do
        it 'returns the link address' do
          external_link_response = JSON.parse(send_director_post_request('/links', '', JSON.generate(payload_json)).read_body)
          response = get_json('/link_address', "link_id=#{external_link_response['id']}&azs[]=z1")
          expect(response).to eq('address' => 'q-a1s0.foobar.a.simple.bosh')
        end
      end

      context 'when querying for multiple azs' do
        it 'returns the link address' do
          external_link_response = JSON.parse(send_director_post_request('/links', '', JSON.generate(payload_json)).read_body)
          response = get_json('/link_address', "link_id=#{external_link_response['id']}&azs[]=z2&azs[]=z1")
          expect(response).to eq('address' => 'q-a1a2s0.foobar.a.simple.bosh')
        end
      end
    end

    context 'healthiness' do
      context 'when querying for healthy address' do
        it 'returns the link address' do
          external_link_response = JSON.parse(send_director_post_request('/links', '', JSON.generate(payload_json)).read_body)
          response = get_json('/link_address', "link_id=#{external_link_response['id']}&status=healthy")
          expect(response).to eq('address' => 'q-s3.foobar.a.simple.bosh')
        end
      end

      context 'when querying for unhealthy address' do
        it 'returns the link address' do
          external_link_response = JSON.parse(send_director_post_request('/links', '', JSON.generate(payload_json)).read_body)
          response = get_json('/link_address', "link_id=#{external_link_response['id']}&status=unhealthy")
          expect(response).to eq('address' => 'q-s1.foobar.a.simple.bosh')
        end
      end

      context 'when querying for all address' do
        it 'returns the link address' do
          external_link_response = JSON.parse(send_director_post_request('/links', '', JSON.generate(payload_json)).read_body)
          response = get_json('/link_address', "link_id=#{external_link_response['id']}&status=all")
          expect(response).to eq('address' => 'q-s4.foobar.a.simple.bosh')
        end
      end

      context 'when querying for default address' do
        it 'returns the link address' do
          external_link_response = JSON.parse(send_director_post_request('/links', '', JSON.generate(payload_json)).read_body)
          response = get_json('/link_address', "link_id=#{external_link_response['id']}&status=default")
          expect(response).to eq('address' => 'q-s0.foobar.a.simple.bosh')
        end
      end

      context 'when querying for unknown address' do
        it 'returns the link address' do
          external_link_response = JSON.parse(send_director_post_request('/links', '', JSON.generate(payload_json)).read_body)
          response = send_director_get_request('/link_address', "link_id=#{external_link_response['id']}&status=foobar")
          expect(response).to be_an_instance_of(Net::HTTPBadRequest)
        end
      end

      context 'when querying for non-string address' do
        it 'returns the link address' do
          external_link_response = JSON.parse(send_director_post_request('/links', '', JSON.generate(payload_json)).read_body)
          response = send_director_get_request('/link_address', "link_id=#{external_link_response['id']}&status[]=default")
          expect(response).to be_an_instance_of(Net::HTTPBadRequest)
        end
      end
    end

    context 'when requesting for unknown link id' do
      it 'should raise an error' do
        response = send_director_get_request('/link_address', 'link_id=9999')
        expect(response).to be_an_instance_of(Net::HTTPNotFound)
      end
    end

    context 'when requesting for an internal link' do
      it 'should return ' do
        response = get_json('/link_address', 'link_id=1')
        expect(response).to eq('address' => 'q-s0.foobar.a.simple.bosh')
      end
    end

    context 'and the provider deployment has use_short_dns_addresses enabled' do
      let(:features) do
        { 'use_short_dns_addresses' => true }
      end

      it 'returns the address as a short dns entry' do
        external_link_response = JSON.parse(send_director_post_request('/links', '', JSON.generate(payload_json)).read_body)
        response = get_json('/link_address', "link_id=#{external_link_response['id']}")
        expect(response).to eq('address' => 'q-n1s0.q-g1.bosh')
      end
    end

    context 'and the provider deployment has use_link_dns_names enabled' do
      let(:features) do
        { 'use_link_dns_names' => true }
      end

      it 'returns the address as a link dns entry' do
        external_link_response = JSON.parse(send_director_post_request('/links', '', JSON.generate(payload_json)).read_body)
        response = get_json('/link_address', "link_id=#{external_link_response['id']}")

        expect(response).to eq('address' => 'q-n1s0.q-g2.bosh')
      end
    end

    context 'and the link is manual' do
      let(:explicit_consumer) do
        {
          'name' => 'consumer',
          'release' => 'bosh-release',
          'consumes' => {
            'provider' => {
              'address' => '192.168.1.254',
              'instances' => [{ 'address' => 'teswfbquts.cabsfabuo7yr.us-east-1.rds.amazonaws.com' }],
              'properties' => { 'a' => 'bar', 'c' => 'bazz' },
            },
          },
        }
      end

      it 'provides the address of the manual link' do
        response = get_json('/link_address', "link_id=1")
        expect(response).to eq('address' => '192.168.1.254')
      end
    end
  end
end
