require_relative '../spec_helper'

describe 'links api', type: :integration do
  with_reset_sandbox_before_each

  def upload_links_release
    FileUtils.cp_r(LINKS_RELEASE_TEMPLATE, ClientSandbox.links_release_dir, :preserve => true)
    bosh_runner.run_in_dir('create-release --force', ClientSandbox.links_release_dir)
    bosh_runner.run_in_dir('upload-release', ClientSandbox.links_release_dir)
  end

  let(:manifest_hash) do
    Bosh::Spec::NewDeployments.manifest_with_release.tap do |manifest|
      manifest['instance_groups'] = [instance_group]
    end
  end

  let(:instance_group) do
    {
      'name' => 'foobar',
      'jobs' => jobs,
      'vm_type' => 'a',
      'stemcell' => 'default',
      'instances' => 1,
      'networks' => [{'name' => 'a'}],
      'properties' => {},
      'persistent_disks' => persistent_disks
    }
  end

  let(:jobs) do
    []
  end

  let(:persistent_disks) do
    []
  end

  let(:cloud_config_hash) do
    hash = Bosh::Spec::NewDeployments.simple_cloud_config
    hash['disk_types'] = [
      {
        'name' => 'low-performance-disk-type',
        'disk_size' => 1024,
        'cloud_properties' => {'type' => 'gp2'}
      },
      {
        'name' => 'high-performance-disk-type',
        'disk_size' => 4076,
        'cloud_properties' => {'type' => 'io1'}
      },
    ]
    hash
  end

  before do
    upload_links_release
    upload_stemcell

    upload_cloud_config(cloud_config_hash: cloud_config_hash)
    deploy_simple_manifest(manifest_hash: manifest_hash)
  end

  context 'when requesting for a list of providers via link_providers endpoint' do
    context 'when deployment has an implicit link provider' do
      let(:jobs) do
        [{'name' => 'provider'}]
      end

      it 'should return the correct number of providers' do
        response = send_director_api_request("/link_providers", "deployment=simple", 'GET')
        response_body = JSON.parse(response.read_body)
        expected_response = [
          {
            "id" => 1,
            "name" => "provider",
            "shared" => false,
            "deployment" => "simple",
            "instance_group" => "foobar",
            "link_provider_definition" => {
              "type" => "provider", "name" => "provider"
            },
            "owner_object" => {
              "type" => "job", "name" => "provider"
            }
          }
        ]

        expect(response_body).to match_array(expected_response)
      end
    end

    context 'when deployment has an explicit link provider' do
      let(:jobs) do
        [
          {
            'name' => 'provider',
            'provides' => {'provider' => {'as' => 'foo'}}
          }
        ]
      end

      it 'should return the correct number of providers' do
        response = send_director_api_request("/link_providers", "deployment=simple", 'GET')
        response_body = JSON.parse(response.read_body)
        expected_response = [
          {
            "id" => 1,
            "name" => "foo",
            "shared" => false,
            "deployment" => "simple",
            "instance_group" => "foobar",
            "link_provider_definition" => {
              "name" => "provider",
              "type" => "provider",
            },
            "owner_object" => {
              "name" => "provider",
              "type" => "job",
            }
          }
        ]

        expect(response_body).to match_array(expected_response)
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
          response = send_director_api_request("/link_providers", "deployment=simple", 'GET')
          response_body = JSON.parse(response.read_body)
          expected_response = [
            {
              "id" => 1,
              "name" => "foo",
              "shared" => true,
              "deployment" => "simple",
              "instance_group" => "foobar",
              "link_provider_definition" => {
                "name" => "provider",
                "type" => "provider",
              },
              "owner_object" => {
                "name" => "provider",
                "type" => "job",
              }
            }
          ]

          expect(response_body).to match_array(expected_response)
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
          response = send_director_api_request("/link_providers", "deployment=simple", 'GET')
          response_body = JSON.parse(response.read_body)
          expected_response = [
            {
              "id" => 1,
              "name" => "bar",
              "shared" => false,
              "deployment" => "simple",
              "instance_group" => "foobar",
              "link_provider_definition" => {
                "type" => "provider",
                "name" => "provider"
              },
              "owner_object" => {
                "type" => "job",
                "name" => "provider"
              }
            }
          ]

          expect(response_body).to match_array(expected_response)
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
        response = send_director_api_request("/link_providers", "deployment=simple", 'GET')
        response_body = JSON.parse(response.read_body)
        expected_response = [
          {
            "id" => 1,
            "name" => "low-iops-persistent-disk-name",
            "shared" => false,
            "deployment" => "simple",
            "instance_group" => "foobar",
            "link_provider_definition" => {
              "type" => "disk", "name" => "low-iops-persistent-disk-name"
            },
            "owner_object" => {
              "type" => "instance_group", "name" => "foobar"
            }
          }, {
            "id" => 2,
            "name" => "high-iops-persistent-disk-name",
            "shared" => false,
            "deployment" => "simple",
            "instance_group" => "foobar",
            "link_provider_definition" => {
              "type" => "disk", "name" => "high-iops-persistent-disk-name"
            },
            "owner_object" => {
              "type" => "instance_group", "name" => "foobar"
            }
          }
        ]

        expect(response_body).to match_array(expected_response)
      end
    end

    context 'when deployment has multiple providers with the same name' do
      let(:persistent_disks) {
        [
          {
            'type' => 'low-performance-disk-type',
            'name' => 'provider'
          }
        ]
      }
      let(:jobs) {
        [
          {'name' => 'provider'},
          {
            'name' => 'alternate_provider',
            'provides' => {'provider' => {'as' => 'provider'}}
          }
        ]
      }

      it "should return all providers" do
        expected_response = [
          {
            "id" => Integer,
            "name" => "provider",
            "shared" => false,
            "deployment" => "simple",
            "instance_group" => "foobar",
            "link_provider_definition" => {
              "type" => "provider", "name" => "provider"
            },
            "owner_object" => {
              "type" => "job", "name" => "provider"
            }
          },
          {
            "id" => Integer,
            "name" => "provider",
            "shared" => false,
            "deployment" => "simple",
            "instance_group" => "foobar",
            "link_provider_definition" => {
              "type" => "provider", "name" => "provider"
            },
            "owner_object" => {
              "type" => "job", "name" => "alternate_provider"
            }
          },
          {
            "id" => Integer,
            "name" => "provider",
            "shared" => false,
            "deployment" => "simple",
            "instance_group" => "foobar",
            "link_provider_definition" => {
              "type" => "disk", "name" => "provider"
            },
            "owner_object" => {
              "type" => "instance_group", "name" => "foobar"
            }
          }
        ]

        response = send_director_api_request("/link_providers", "deployment=simple", 'GET')
        response_body = JSON.parse(response.read_body)
        expect(response_body).to match_array(expected_response)
      end
    end

    context 'when deployment does not have a link provider' do
      it 'should return an empty list of providers' do
        response = send_director_api_request("/link_providers", "deployment=simple", 'GET')
        response_body = JSON.parse(response.read_body)
        expected_response = []

        expect(response_body).to match_array(expected_response)
      end
    end

    context 'when deployment is not specified' do
      it 'should raise an error' do
        response = send_director_api_request("/link_providers", "", 'GET')
        response_body = JSON.parse(response.read_body)

        expected_error = Bosh::Director::DeploymentRequired.new("Deployment name is required")
        expected_response = {
          'code' => expected_error.error_code,
          'description' => expected_error.message,
        }

        expect(response_body).to match(expected_response)
      end
    end

    context 'when user does not have sufficient permissions' do
      it 'should raise an error' do
        response = send_director_api_request("/link_providers", "deployment=simple", 'GET', {})

        expect(response.read_body).to include("Not authorized: '/link_providers'")
      end
    end
  end

  context 'when requesting for a list of consumers via link_consumers endpoint' do
    context 'when a job has a link consumer' do
      let(:jobs) do
        [
          {'name' => 'provider'},
          {'name' => 'consumer'},
        ]
      end

      it 'should return the correct number of consumers' do
        response = send_director_api_request("/link_consumers", "deployment=simple", 'GET')
        response_body = JSON.parse(response.read_body)
        expected_response = [
          {
            "id" => 1,
            "deployment" => "simple",
            "instance_group" => "foobar",
            "owner_object" => {
              "type" => "job", "name" => "consumer"
            }
          }
        ]

        expect(response_body).to match_array(expected_response)
      end

      context 'and the consumer is optional' do
        let(:jobs) do
          [
            {'name' => 'api_server_with_optional_db_link'},
          ]
        end
        it 'should still create a consumer' do
          response = send_director_api_request("/link_consumers", "deployment=simple", 'GET')
          response_body = JSON.parse(response.read_body)
          expected_response = [
            {
              "id" => 1,
              "deployment" => "simple",
              "instance_group" => "foobar",
              "owner_object" => {
                "type" => "job", "name" => "api_server_with_optional_db_link"
              }
            }
          ]

          expect(response_body).to match_array(expected_response)
        end
      end

      context 'when the link is provided by a new provider' do
        let(:updated_manifest_hash) do
          manifest_hash.tap do |mh|
            mh['instance_groups'][0]['jobs'][0]['name'] = 'alternate_provider'
          end
        end

        it 'should reuse the same consumers' do
          expected_response = JSON.parse send_director_api_request("/link_consumers", "deployment=simple", 'GET').read_body

          deploy_simple_manifest(manifest_hash: updated_manifest_hash)

          response = send_director_api_request("/link_consumers", "deployment=simple", 'GET')
          response_body = JSON.parse(response.read_body)
          expect(response_body).to match_array(expected_response)
        end
      end
    end

    context 'when deployment does not have a link consumer' do
      it 'should return an empty list of consumers' do
        response = send_director_api_request("/link_consumers", "deployment=simple", 'GET')
        response_body = JSON.parse(response.read_body)
        expect(response_body).to be_empty
      end
    end

    context 'when deployment is not specified' do
      it 'should raise an error' do
        response = send_director_api_request("/link_consumers", "", 'GET')
        response_body = JSON.parse(response.read_body)

        expected_error = Bosh::Director::DeploymentRequired.new("Deployment name is required")
        expected_response = {
          'code' => expected_error.error_code,
          'description' => expected_error.message,
        }

        expect(response_body).to match(expected_response)
      end
    end

    context 'when user does not have sufficient permissions' do
      it 'should raise an error' do
        response = send_director_api_request("/link_consumers", "deployment=simple", 'GET', {})

        expect(response.read_body).to include("Not authorized: '/link_consumers'")
      end
    end
  end

  context 'when requesting for a list of links via links endpoint' do
    context 'when deployment has an implicit provider + consumer' do
      let(:jobs) do
        [
          {'name' => 'provider'},
          {'name' => 'consumer'},
        ]
      end

      it 'should return the correct number of links' do
        response = send_director_api_request("/links", "deployment=simple", 'GET')
        response_body = JSON.parse(response.read_body)
        expected_response = [
          {
            "id" => 1,
            "name" => "provider",
            "link_consumer_id" => 1,
            "link_provider_id" => 1,
            "created_at" => String
          }
        ]

        expect(response_body).to match_array(expected_response)
      end
    end

    context 'when deployment has an explicit provider + consumer' do
      let(:jobs) do
        [
          {
            'name' => 'provider',
            'provides' => {'provider' => {'as' => 'foo'}}
          },
          {
            'name' => 'consumer',
            'consumes' => {'provider' => {'from' => 'foo'}}
          },
        ]
      end

      it 'should return the correct number of links' do
        response = send_director_api_request("/links", "deployment=simple", 'GET')
        response_body = JSON.parse(response.read_body)
        expected_response = [
          {
            "id" => 1,
            "name" => "provider",
            "link_consumer_id" => 1,
            "link_provider_id" => 1,
            "created_at" => String
          }
        ]

        expect(response_body).to match_array(expected_response)
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
          manifest = Bosh::Spec::NewDeployments.manifest_with_release
          manifest['name'] = 'consumer-simple'
          manifest['instance_groups'] = [consumer_instance_group]
          manifest
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
            'networks' => [{'name' => 'a'}],
            'properties' => {}
          }
        end

        it 'should create a link for the cross deployment link' do
          deploy_simple_manifest(manifest_hash: consumer_manifest_hash)

          response = send_director_api_request("/links", "deployment=consumer-simple", 'GET')
          response_body = JSON.parse(response.read_body)
          expected_response = [
            {
              "id" => 1,
              "name" => "provider",
              "link_consumer_id" => 1,
              "link_provider_id" => 1,
              "created_at" => String
            }]

          expect(response_body).to match_array(expected_response)
        end
      end
    end

    context 'when deployment has an unmanaged persistent disk' do
      let(:instance_group) do
        {
          'name' => 'foobar',
          'jobs' => jobs,
          'vm_type' => 'a',
          'stemcell' => 'default',
          'instances' => 1,
          'networks' => [{'name' => 'a'}],
          'properties' => {},
          'persistent_disks' => [disk]
        }
      end

      let(:jobs) do
        [
          {
            'name' => 'disk_consumer',
            'consumes' => {'disk_provider' => {'from' => 'disk_name'}}
          },
        ]
      end

      let(:disk) do
        {
          'name' => 'disk_name',
          'type' => 'low-performance-disk-type',
        }
      end

      it 'should return the disk providers' do
        response = send_director_api_request("/links", "deployment=simple", 'GET')
        response_body = JSON.parse(response.read_body)
        expected_response = [
          {
            "id" => 1,
            "name" => "disk_provider",
            "link_consumer_id" => 1,
            "link_provider_id" => 1,
            "created_at" => String
          }
        ]

        expect(response_body).to match_array(expected_response)
      end
    end

    context 'when deployment consuming manual link' do
      let(:jobs) do
        [
          {
            'name' => 'consumer',
            'consumes' => {
              'provider' => {
                'instances' => [{'address' => 'teswfbquts.cabsfabuo7yr.us-east-1.rds.amazonaws.com'}],
                'properties' => {'a' => 'bar', 'c' => 'bazz'}
              }
            }
          },
        ]
      end

      it 'should return a single orphaned link' do
        response = send_director_api_request("/links", "deployment=simple", 'GET')
        response_body = JSON.parse(response.read_body)
        expected_response = [
          {
            "id" => 1,
            "name" => "provider",
            "link_consumer_id" => 1,
            "link_provider_id" => nil,
            "created_at" => String
          }
        ]

        expect(response_body).to match_array(expected_response)
      end
    end

    context 'when deployment is not specified' do
      it 'should raise an error' do
        response = send_director_api_request("/links", "", 'GET')
        response_body = JSON.parse(response.read_body)

        expected_error = Bosh::Director::DeploymentRequired.new("Deployment name is required")
        expected_response = {
          'code' => expected_error.error_code,
          'description' => expected_error.message,
        }

        expect(response_body).to match(expected_response)
      end
    end

    context 'when user does not have sufficient permissions' do
      it 'should raise an error' do
        response = send_director_api_request("/links", "deployment=simple", 'GET', {})

        expect(response.read_body).to include("Not authorized: '/links'")
      end
    end

    context 'when consumer is removed from deployment' do
      let(:jobs) do
        [
          {
            'name' => 'provider',
            'provides' => {'provider' => {'as' => 'foo'}}
          },
          {
            'name' => 'consumer',
            'consumes' => {'provider' => {'from' => 'foo'}}
          },
        ]
      end

      it 'should remove consumer data from link_consumer' do
        manifest_hash['instance_groups'][0]['jobs'].pop
        deploy_simple_manifest(manifest_hash: manifest_hash)

        response = send_director_api_request("/links", "deployment=simple", 'GET')
        response_body = JSON.parse(response.read_body)

        expect(response_body).to be_empty
      end
    end
  end

  context 'when deployment which consumes and provides links already exist' do
    let(:jobs) do
      [
        {
          'name' => 'provider',
          'provides' => {'provider' => {'as' => 'foo'}}
        },
        {
          'name' => 'consumer',
          'consumes' => {'provider' => {'from' => 'foo'}}
        },
      ]
    end

    before do
      providers_response = send_director_api_request("/link_providers", "deployment=simple", 'GET')
      @providers_response_body = JSON.parse(providers_response.read_body)

      consumers_response = send_director_api_request("/link_consumers", "deployment=simple", 'GET')
      @consumers_response_body = JSON.parse(consumers_response.read_body)

      links_response = send_director_api_request("/links", "deployment=simple", 'GET')
      @links_response_body = JSON.parse(links_response.read_body)
    end

    context 'redeploying no changes' do
      before do
        deploy_simple_manifest(manifest_hash: manifest_hash)
      end

      it 'should use the same provider' do
        response = send_director_api_request("/link_providers", "deployment=simple", 'GET')
        response_body = JSON.parse(response.read_body)
        expect(response_body).to match_array(@providers_response_body)
      end

      it 'should use the same consumer' do
        response = send_director_api_request("/link_consumers", "deployment=simple", 'GET')
        response_body = JSON.parse(response.read_body)
        expect(response_body).to match_array(@consumers_response_body)
      end

      it 'should not create a new link' do
        pending("To be done in a future story (#152942059)[https://www.pivotaltracker.com/story/show/152942059]")
        response = send_director_api_request("/links", "deployment=simple", 'GET')
        response_body = JSON.parse(response.read_body)
        expect(response_body).to match_array(@links_response_body)
      end
    end

    context 'recreating deployment' do
      before do
        bosh_runner.run('recreate', deployment_name: 'simple')
      end

      it 'should use the same provider' do
        response = send_director_api_request("/link_providers", "deployment=simple", 'GET')
        response_body = JSON.parse(response.read_body)
        expect(response_body).to match_array(@providers_response_body)
      end

      it 'should use the same consumer' do
        response = send_director_api_request("/link_consumers", "deployment=simple", 'GET')
        response_body = JSON.parse(response.read_body)
        expect(response_body).to match_array(@consumers_response_body)
      end

      it 'should not create a new link' do
        pending("To be done in a future story (#152942059)[https://www.pivotaltracker.com/story/show/152942059]")
        response = send_director_api_request("/links", "deployment=simple", 'GET')
        response_body = JSON.parse(response.read_body)
        expect(response_body).to match_array(@links_response_body)
      end
    end
  end
end