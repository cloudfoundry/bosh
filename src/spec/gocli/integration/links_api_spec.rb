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

  let(:features) {{}}

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
      'provides' => { 'provider' => { 'as' => 'foo' } },
    }
  end

  let(:explicit_consumer) do
    {
      'name' => 'consumer',
      'consumes' => { 'provider' => { 'from' => 'foo' } },
    }
  end

  let(:implicit_provider_and_consumer) do
    [
      { 'name' => 'provider' },
      { 'name' => 'consumer' },
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
    deploy_simple_manifest(manifest_hash: manifest_hash)
  end

  context 'when requesting for a list of providers via link_providers endpoint' do
    context 'when deployment has an implicit link provider' do
      let(:jobs) { [{ 'name' => 'provider' }] }

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
          { 'name' => 'provider' },
          {
            'name' => 'alternate_provider',
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
    context 'when a job has a link consumer' do
      let(:jobs) { implicit_provider_and_consumer }

      it 'should return the correct number of consumers' do
        expected_response = [consumer_response]

        expect(get_link_consumers).to match_array(expected_response)
      end

      context 'and the consumer is optional' do
        let(:jobs) { [{ 'name' => 'api_server_with_optional_db_link' }] }

        it 'should still create a consumer' do
          expected_response = [consumer_response('api_server_with_optional_db_link', 'db').merge('optional' => true)]

          expect(get_link_consumers).to match_array(expected_response)
        end
      end

      context 'when the link is provided by a new provider' do
        let(:updated_manifest_hash) do
          manifest_hash.tap do |mh|
            mh['instance_groups'][0]['jobs'][0]['name'] = 'alternate_provider'
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
      let(:jobs) { explicit_provider_and_consumer }

      it 'should remove consumer data from link_consumer' do
        manifest_hash['instance_groups'][0]['jobs'].pop
        deploy_simple_manifest(manifest_hash: manifest_hash)

        expect(get_links).to be_empty
      end
    end
  end

  context 'when deployment which consumes and provides links already exist' do
    let(:jobs) { explicit_provider_and_consumer }

    before do
      @expected_providers = get_link_providers
      @expected_consumers = get_link_consumers
      @expected_links = get_links
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
            'provides' => { 'provider' => { 'as' => 'bar' } },
          },
          {
            'name' => 'consumer',
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
  end

  context 'when doing POST request to create link' do
    context 'when correct json is provided' do
      let(:provider_id) { '1' }
      let(:payload_json) do
        {
          'link_provider_id' => provider_id,
          'link_consumer' => {
            'owner_object_name' => 'external_consumer_1',
            'owner_object_type' => 'external',
          },
        }
      end
      let(:jobs) do
        [
          {
            'name' => 'provider',
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
        before do
          provider_response = get_link_providers
          provider_id = provider_response.first['id']
        end

        it 'provide link json output' do
          response = send_director_post_request('/links', '', JSON.generate(payload_json))
          link = JSON.parse(response.read_body)

          expect(link['name']).to eq(jobs[0]['name'])
          expect(link['link_provider_id']).to eq(provider_id)
        end

        it 'create consumer_intent' do
          send_director_post_request('/links', '', JSON.generate(payload_json))
          response = get_link_consumers

          expect(response.count).to_not eq(0)
          consumer = response[0]
          expect(consumer['deployment']).to eq('simple')
          expect(consumer['owner_object']['type']).to eq('external')
        end

        it 'keeps the consumer and link after redeploy' do
          send_director_post_request('/links', '', JSON.generate(payload_json))
          response = get_link_consumers

          deploy_simple_manifest(manifest_hash: manifest_hash)
          response2 = get_link_consumers

          expect(response.count).to eq(response2.count)
          consumer = response2[0]
          expect(consumer['deployment']).to eq('simple')
          expect(consumer['owner_object']['type']).to eq('external')
        end

        context 'when multiple request have same owner_object and provider_id' do
          before do
            first_response = send_director_post_request('/links', '', JSON.generate(payload_json))
            @link_1 = JSON.parse(first_response.read_body)
          end

          it 'should NOT create new links' do
            second_response = send_director_post_request('/links', '', JSON.generate(payload_json))
            link_2 = JSON.parse(second_response.read_body)

            expect(link_2).to eq(@link_1)
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

      context 'when owner_object_name is invalid' do
        let(:payload_json) do
          {
            'link_provider_id' => provider_id,
            'link_consumer' => {
              'owner_object_name' => '',
              'owner_object_type' => 'external',
            },
          }
        end

        it 'returns error' do
          response = send_director_post_request('/links', '', JSON.generate(payload_json))
          error_response = JSON.parse(response.read_body)
          expect(error_response['description']).to eq('Invalid request: `link_consumer.owner_object_name` must not be empty')
        end
      end

      context 'when network name is provided' do
        let(:network_name) { 'a' }
        let(:payload_json) do
          {
            'link_provider_id' => provider_id,
            'link_consumer' => {
              'owner_object_name' => 'external_consumer_1',
              'owner_object_type' => 'external',
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
            error_string = "Can't resolve network: `#{network_name}` in provider id: #{provider_id} for `#{payload_json['link_consumer']['owner_object_name']}`"

            expect(error_response['description']).to eq(error_string)
          end
        end
      end
    end

    # TODO: Links API
    context 'when user does not have sufficient permissions' do
      it 'should raise an error' do
        response = send_director_post_request('/links', '', JSON.generate({}), {})

        expect(response.read_body).to include("Not authorized: '/links'")
      end
    end
  end

  context 'when doing DELETE request to delete link' do
    let(:provider_id) { '1' }
    let(:payload_json) do
      {
        'link_provider_id' => provider_id,
        'link_consumer' => {
          'owner_object_name' => 'external_consumer_1',
          'owner_object_type' => 'external',
        },
        'network' => 'a',
      }
    end
    let(:jobs) do
      [
        {
          'name' => 'provider',
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
          'owner_object_name' => 'external_consumer_1',
          'owner_object_type' => 'external',
        },
      }
    end

    before do
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
  end
end
