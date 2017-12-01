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
      'instance_groups' => [instance_group]
    )
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
      'persistent_disks' => persistent_disks
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
          'cloud_properties' => { 'type' => 'gp2' }
        },
        {
          'name' => 'high-performance-disk-type',
          'disk_size' => 4076,
          'cloud_properties' => { 'type' => 'io1' }
        }
      ]
    )
  end

  let(:explicit_provider_and_consumer) { [explicit_provider, explicit_consumer] }

  let(:explicit_provider) do
    {
      'name' => 'provider',
      'provides' => { 'provider' => { 'as' => 'foo' } }
    }
  end

  let(:explicit_consumer) do
    {
      'name' => 'consumer',
      'consumes' => { 'provider' => { 'from' => 'foo' } }
    }
  end

  let(:implicit_provider_and_consumer) do
    [
      { 'name' => 'provider' },
      { 'name' => 'consumer' }
    ]
  end

  let(:provider_response) do
    {
      'id' => Integer,
      'name' => 'provider',
      'shared' => false,
      'deployment' => 'simple',
      'link_provider_definition' => {
        'name' => 'provider',
        'type' => 'provider'
      },
      'owner_object' => {
        'name' => 'provider',
        'type' => 'job',
        'info' => {
          'instance_group' => 'foobar',
        }
      }
    }
  end

  def disk_provider_response(name)
    provider_response.merge(
      'name' => name,
      'link_provider_definition' => {
        'name' => name,
        'type' => 'disk'
      },
      'owner_object' => {
        'name' => 'foobar',
        'type' => 'instance_group',
        'info' => {
          'instance_group' => 'foobar',
        }
      }
    )
  end

  def consumer_response(name='consumer')
    {
      'id' => Integer,
      'deployment' => 'simple',
      'instance_group' => 'foobar',
      'owner_object' => {
        'type' => 'job', 'name' => name
      }
    }
  end

  let(:links_response) do
    {
      'id' => 1,
      'name' => 'provider',
      'link_consumer_id' => 1,
      'link_provider_id' => 1,
      'created_at' => String
    }
  end

  def get(path, params)
    send_director_api_request(path, params, 'GET')
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
                  'shared' => true
                }
              }
            }
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
          puts updated_manifest_hash
          deploy_simple_manifest(manifest_hash: updated_manifest_hash)
        end

        it 'should return the original provider with updated information' do
          expected_response = [provider_response.merge('id' => 1, 'name' => 'bar')]

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
          'name' => 'low-iops-persistent-disk-name'
        }
      end

      let(:high_iops_persistent_disk) do
        {
          'type' => 'high-performance-disk-type',
          'name' => 'high-iops-persistent-disk-name'
        }
      end

      it 'should return the disk providers' do
        expected_response = [
          disk_provider_response('low-iops-persistent-disk-name'),
          disk_provider_response('high-iops-persistent-disk-name')
        ]

        expect(get_link_providers).to match_array(expected_response)
      end
    end

    context 'when deployment has multiple providers with the same name' do
      let(:persistent_disks) do
        [
          {
            'type' => 'low-performance-disk-type',
            'name' => 'provider'
          }
        ]
      end

      let(:jobs) do
        [
          { 'name' => 'provider' },
          {
            'name' => 'alternate_provider',
            'provides' => { 'provider' => { 'as' => 'provider' } }
          }
        ]
      end

      it 'should return all providers' do
        expected_response = [
          provider_response,
          provider_response.deep_merge(
            'owner_object' => {
              'name' => 'alternate_provider',
              'info' => {
                'instance_group' => 'foobar'
              }
            }
          ),
          disk_provider_response('provider')
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
          'description' => expected_error.message
        }

        expect(actual_response).to match(expected_response)
      end
    end

    context 'when user does not have sufficient permissions' do
      it 'should raise an error' do
        response = send_director_api_request('/link_providers', 'deployment=simple', 'GET', {})

        expect(response.read_body).to include("Not authorized: '/link_providers'")
      end
    end
  end

  context 'when requesting for a list of consumers via link_consumers endpoint' do
    context 'when a job has a link consumer' do
      let(:jobs) { implicit_provider_and_consumer }

      it 'should return the correct number of consumers' do
        expected_response = [ consumer_response ]

        expect(get_link_consumers).to match_array(expected_response)
      end

      context 'and the consumer is optional' do
        let(:jobs) { [{ 'name' => 'api_server_with_optional_db_link' }] }

        it 'should still create a consumer' do
          expected_response = [ consumer_response('api_server_with_optional_db_link') ]

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
          'description' => expected_error.message
        }

        expect(actual_response).to match(expected_response)
      end
    end

    context 'when user does not have sufficient permissions' do
      it 'should raise an error' do
        response = send_director_api_request('/link_consumers', 'deployment=simple', 'GET', {})

        expect(response.read_body).to include("Not authorized: '/link_consumers'")
      end
    end
  end

  context 'when requesting for a list of links via links endpoint' do
    context 'when deployment has an implicit provider + consumer' do
      let(:jobs) { implicit_provider_and_consumer }

      it 'should return the correct number of links' do
        expected_response = [ links_response ]

        expect(get_links).to match_array(expected_response)
      end
    end

    context 'when deployment has an explicit provider + consumer' do
      let(:jobs) { explicit_provider_and_consumer }

      it 'should return the correct number of links' do
        expected_response = [ links_response ]

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
                  'shared' => true
                }
              }
            }
          ]
        end

        let(:consumer_manifest_hash) do
          Bosh::Spec::NewDeployments.manifest_with_release.merge(
            'name' => 'consumer-simple',
            'instance_groups' => [consumer_instance_group]
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
                    'deployment' => 'simple'
                  }
                }
              }
            ],
            'vm_type' => 'a',
            'stemcell' => 'default',
            'instances' => 1,
            'networks' => [{ 'name' => 'a' }],
            'properties' => {}
          }
        end

        it 'should create a link for the cross deployment link' do
          deploy_simple_manifest(manifest_hash: consumer_manifest_hash)

          actual_response = get_json('/links', 'deployment=consumer-simple')
          expected_response = [ links_response ]

          expect(actual_response).to match_array(expected_response)
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
                'properties' => { 'a' => 'bar', 'c' => 'bazz' }
              }
            }
          }
        ]
      end

      it 'should return a single orphaned link' do
        expected_response = [ links_response.merge('link_provider_id' => nil) ]
        expect(get_links).to match_array(expected_response)
      end
    end

    context 'when deployment is not specified' do
      it 'should raise an error' do
        actual_response = get_json('/links', '')

        expected_error = Bosh::Director::DeploymentRequired.new('Deployment name is required')
        expected_response = {
          'code' => expected_error.error_code,
          'description' => expected_error.message
        }

        expect(actual_response).to match(expected_response)
      end
    end

    context 'when user does not have sufficient permissions' do
      it 'should raise an error' do
        response = send_director_api_request('/links', 'deployment=simple', 'GET', {})

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
        pending('To be done in a future story (#152942059)[https://www.pivotaltracker.com/story/show/152942059]')
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
        pending('To be done in a future story (#152942059)[https://www.pivotaltracker.com/story/show/152942059]')
        expect(get_links).to match_array(@expected_links)
      end
    end
  end
end
