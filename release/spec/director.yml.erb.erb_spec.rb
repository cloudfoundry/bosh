require 'rspec'
require 'yaml'
require 'bosh/template/evaluation_context'
require 'json'

describe 'director.yml.erb.erb' do
  let(:deployment_manifest_fragment) do
    {
      'properties' => {
        'ntp' => [
          '0.north-america.pool.ntp.org',
          '1.north-america.pool.ntp.org',
        ],
        'compiled_package_cache' => {},
        'blobstore' => {
          'address' => '10.10.0.7',
          'port' => 25251,
          'agent' => {'user' => 'agent', 'password' => '75d1605f59b60'},
          'director' => {
            'user' => 'user',
            'password' => 'password'
          },
          'provider' => 'dav',
        },
        'nats' => {
          'user' => 'nats',
          'password' => '1a0312a24c0a0',
          'address' => '10.10.0.7',
          'port' => 4222
        },
        'redis' => {
          'address' => '127.0.0.1', 'port' => 25255, 'password' => 'R3d!S',
          'loglevel' => 'info',
        },
        'director' => {
          'name' => 'vpc-bosh-idora',
          'backend_port' => 25556,
          'encryption' => false,
          'max_tasks' => 500,
          'max_threads' => 32,
          'enable_snapshots' => true,
          'db' => {
            'adapter' => 'mysql2',
            'user' => 'ub45391e00',
            'password' => 'p4cd567d84d0e012e9258d2da30',
            'host' => 'bosh.hamazonhws.com',
            'port' => 3306,
            'database' => 'bosh',
            'connection_options' => {},
          },
          'auto_fix_stateful_nodes' => true,
          'max_vm_create_tries' => 5,
        }
      }
    }
  end

  let(:erb_yaml) { File.read(File.join(File.dirname(__FILE__), '../jobs/director/templates/director.yml.erb.erb')) }

  subject(:parsed_yaml) do
    binding = Bosh::Template::EvaluationContext.new(deployment_manifest_fragment).get_binding
    YAML.load(ERB.new(erb_yaml).result(binding))
  end

  context 'vsphere' do
    before do
      deployment_manifest_fragment['properties']['vcenter'] = {
        'address' => 'vcenter.address',
        'user' => 'user',
        'password' => 'vcenter.password',
        'datacenters' => [
          {
            'name' => 'vcenter.datacenters.first.name',
            'clusters' => ['cluster1']
          },
        ]}
    end

    context 'when vcenter.address begins with a bang and contains quotes' do
      before do
        deployment_manifest_fragment['properties']['vcenter']['address'] = "!vcenter.address''"
      end

      it 'renders vcenter address correctly' do
        expect(parsed_yaml['cloud']['properties']['vcenters'][0]['host']).to eq("!vcenter.address''")
      end
    end

    context 'when vcenter.user begins with a bang and contains quotes' do
      before do
        deployment_manifest_fragment['properties']['vcenter']['user'] = "!vcenter.user''"
      end

      it 'renders vcenter user correctly' do
        expect(parsed_yaml['cloud']['properties']['vcenters'][0]['user']).to eq("!vcenter.user''")
      end
    end

    context 'when vcenter.password begins with a bang and contains quotes' do
      before do
        deployment_manifest_fragment['properties']['vcenter']['password'] = "!vcenter.password''"
      end

      it 'renders vcenter password correctly' do
        expect(parsed_yaml['cloud']['properties']['vcenters'][0]['password']).to eq("!vcenter.password''")
      end
    end
  end

  context 'vcloud' do
    before do
      deployment_manifest_fragment['properties']['vcd'] = {
        'url' => 'myvcdurl',
        'user' => 'myvcduser',
        'password' => 'myvcdpassword',
        'entities' => {
          'organization' => 'myorg',
          'virtual_datacenter' => 'myvdc',
          'vapp_catalog' => 'myvappcatalog',
          'media_catalog' => 'mymediacatalog',
          'vm_metadata_key' => 'mymetadatakey',
          'description' => 'mydescription'
        }
      }
    end

    context 'when control parameters do not exist' do
      it 'renders required parameters correctly' do
        parsed = parsed_yaml

        expect(parsed['cloud']['properties']['vcds'][0]['url']).to eq 'myvcdurl'
        expect(parsed['cloud']['properties']['vcds'][0]['user']).to eq 'myvcduser'
        expect(parsed['cloud']['properties']['vcds'][0]['password']).to eq 'myvcdpassword'
        expect(parsed['cloud']['properties']['vcds'][0]['entities']['organization']).to eq 'myorg'
        expect(parsed['cloud']['properties']['vcds'][0]['entities']['virtual_datacenter']).to eq 'myvdc'
        expect(parsed['cloud']['properties']['vcds'][0]['entities']['vapp_catalog']).to eq 'myvappcatalog'
        expect(parsed['cloud']['properties']['vcds'][0]['entities']['media_catalog']).to eq 'mymediacatalog'
        expect(parsed['cloud']['properties']['vcds'][0]['entities']['vm_metadata_key']).to eq 'mymetadatakey'
        expect(parsed['cloud']['properties']['vcds'][0]['entities']['description']).to eq 'mydescription'
        expect(parsed['cloud']['properties']['vcds'][0]['entities']['control']).to be_nil
      end
    end

    context 'when control parameters exist' do
      before do
        deployment_manifest_fragment['properties']['vcd']['entities']['control'] = {
          'wait_max' => '400',
          'wait_delay' => '10',
          'cookie_timeout' => '1200',
          'retry_max' => '5',
          'retry_delay' => '500'
        }
      end

      it 'renders all parameters correctly' do
        parsed = parsed_yaml

        expect(parsed['cloud']['properties']['vcds'][0]['url']).to eq 'myvcdurl'
        expect(parsed['cloud']['properties']['vcds'][0]['entities']['organization']).to eq 'myorg'

        expect(parsed['cloud']['properties']['vcds'][0]['entities']['control']['wait_max']).to eq 400
        expect(parsed['cloud']['properties']['vcds'][0]['entities']['control']['wait_delay']).to eq 10
        expect(parsed['cloud']['properties']['vcds'][0]['entities']['control']['cookie_timeout']).to eq 1200
        expect(parsed['cloud']['properties']['vcds'][0]['entities']['control']['retry_max']).to eq 5
        expect(parsed['cloud']['properties']['vcds'][0]['entities']['control']['retry_delay']).to eq 500
      end
    end
  end

  context 'openstack' do
    before do
      deployment_manifest_fragment['properties']['openstack'] = {
        'auth_url' => 'auth_url',
        'username' => 'username',
        'api_key' => 'api_key',
        'tenant' => 'tenant',
        'default_key_name' => 'default_key_name',
        'default_security_groups' => 'default_security_groups',
        'wait_resource_poll_interval' => 'wait_resource_poll_interval',
        'use_config_drive' => 'use-config-drive-value',
      }
      deployment_manifest_fragment['properties']['registry'] = {
        'address' => 'address',
        'http' => {
          'port' => 'port',
          'user' => 'user',
          'password' => 'password'
        }
      }
    end

    context 'when openstack connection options exist' do
      before do
        deployment_manifest_fragment['properties']['openstack']['connection_options'] = {
          'option1' => 'true', 'option2' => 'false'}
      end

      it 'renders openstack connection options correctly' do
        expect(parsed_yaml['cloud']['properties']['openstack']['connection_options']).to eq(
          {'option1' => 'true', 'option2' => 'false'})
      end
    end

    it 'renders openstack properties' do
      expect(parsed_yaml['cloud']['properties']['openstack']).to eq({
        'auth_url' => 'auth_url',
        'username' => 'username',
        'api_key' => 'api_key',
        'tenant' => 'tenant',
        'default_key_name' => 'default_key_name',
        'default_security_groups' => 'default_security_groups',
        'wait_resource_poll_interval' => 'wait_resource_poll_interval',
        'use_config_drive' => 'use-config-drive-value',
      })
    end
  end

  context 's3' do
    before do
      deployment_manifest_fragment['properties']['aws'] = {
        'access_key_id' => 'key',
        'secret_access_key' => 'secret',
        'default_key_name' => 'default_key_name',
        'default_security_groups' => 'default_security_groups',
        'region' => 'region'
      }

      deployment_manifest_fragment['properties']['registry'] = {
        'address' => 'aws-registry.example.com',
        'http' => {
          'port' => '1234',
          'user' => 'aws.user',
          'password' => 'aws.password'
        }
      }
    end

    context 'when the user specifies use_ssl, ssl_verify_peer, s3_multipart_threshold, port, s3_force_path_style and host' do
      before do
        blobstore_options = {
          'provider' => 's3',
          'bucket_name' => 'mybucket',
          'access_key_id' => 'key',
          'secret_access_key' => 'secret',
          'use_ssl' => false,
          'ssl_verify_peer' => false,
          's3_multipart_threshold' => 123,
          's3_port' => 5155,
          'host' => 'myhost.hostland.edu',
          's3_force_path_style' => true,
        }

        deployment_manifest_fragment['properties']['blobstore'] = blobstore_options
        deployment_manifest_fragment['properties']['compiled_package_cache']['options'] = blobstore_options
      end

      it 'sets the blobstore fields appropriately' do
        [ parsed_yaml['blobstore'], parsed_yaml['compiled_package_cache'] ].each do |blobstore|
          expect(blobstore['options']).to eq({
            'bucket_name' => 'mybucket',
            'access_key_id' => 'key',
            'secret_access_key' => 'secret',
            'use_ssl' => false,
            'ssl_verify_peer' => false,
            's3_multipart_threshold' => 123,
            'port' => 5155,
            'host' => 'myhost.hostland.edu',
            's3_force_path_style' => true,
          })
        end
      end

      it 'sets endpoint protocol appropriately when use_ssl is true' do
        deployment_manifest_fragment['properties']['blobstore']['use_ssl'] = true

        expect(parsed_yaml['blobstore']['options']).to eq({
          'bucket_name' => 'mybucket',
          'access_key_id' => 'key',
          'secret_access_key' => 'secret',
          'use_ssl' => true,
          'ssl_verify_peer' => false,
          's3_multipart_threshold' => 123,
          'port' => 5155,
          'host' => 'myhost.hostland.edu',
          's3_force_path_style' => true,
        })
      end

      describe 'the agent blobstore' do
        it 'has the same config as the toplevel blobstore' do
          expect(parsed_yaml['cloud']['properties']['agent']['blobstore']['options']).to eq({
            'bucket_name' => 'mybucket',
            'access_key_id' => 'key',
            'secret_access_key' => 'secret',
            'use_ssl' => false,
            'ssl_verify_peer' => false,
            's3_multipart_threshold' => 123,
            'port' => 5155,
            'host' => 'myhost.hostland.edu',
            's3_force_path_style' => true,
          })
        end

        context 'when there are override values for the agent' do
          before do
            deployment_manifest_fragment['properties']['agent'] = {
              'blobstore' => {
                'access_key_id' => 'agent-key',
                'secret_access_key' => 'agent-secret',
                'host' => 'fakehost.example.com',
                'use_ssl' => true,
                'ssl_verify_peer' => true,
                's3_force_path_style' => false,
                's3_multipart_threshold' => 456,
              }
            }
          end

          it 'uses the override values' do
            expect(parsed_yaml['cloud']['properties']['agent']['blobstore']['options']).to eq({
              'bucket_name' => 'mybucket',
              'access_key_id' => 'agent-key',
              'secret_access_key' => 'agent-secret',
              'use_ssl' => true,
              'ssl_verify_peer' => true,
              's3_force_path_style' => false,
              's3_multipart_threshold' => 456,
              'port' => 5155,
              'host' => 'fakehost.example.com',
            })
          end
        end
      end
    end

    context 'when the user specifies compiled_package_cache with a blobstore_path option' do
      before do
        deployment_manifest_fragment['properties']['compiled_package_cache']['options'] = {
          'blobstore_path' => '/some/path'
        }
      end

      it 'sets the compiled_package_cache fields appropriately' do
        expect(parsed_yaml['compiled_package_cache']).to eq({
          'provider' => 'local',
          'options' => {
            'blobstore_path' => '/some/path'
          }
        })
      end
    end

    context 'when the user only specifies bucket, access, and secret' do
      before do
        deployment_manifest_fragment['properties']['blobstore'] = {
          'provider' => 's3',
          'bucket_name' => 'mybucket',
          'access_key_id' => 'key',
          'secret_access_key' => 'secret',
        }
      end

      it 'sets the blobstore fields appropriately' do
        expect(parsed_yaml['blobstore']['options']).to eq({
          'bucket_name' => 'mybucket',
          'access_key_id' => 'key',
          'secret_access_key' => 'secret',
        })
      end

      describe 'the agent blobstore' do
        it 'has the same config as the toplevel blobstore' do
          expect(parsed_yaml['cloud']['properties']['agent']['blobstore']['options']).to eq({
            'bucket_name' => 'mybucket',
            'access_key_id' => 'key',
            'secret_access_key' => 'secret',
          })
        end

        context 'when there are override values for the agent' do
          before do
            deployment_manifest_fragment['properties']['agent'] = {
              'blobstore' => {
                'access_key_id' => 'agent-key',
                'secret_access_key' => 'agent-secret',
              }
            }
          end

          it 'uses the override values' do
            expect(parsed_yaml['cloud']['properties']['agent']['blobstore']['options']).to eq({
              'bucket_name' => 'mybucket',
              'access_key_id' => 'agent-key',
              'secret_access_key' => 'agent-secret',
            })
          end
        end
      end
    end
  end

  context 'when cloud plugin is not specified' do
    it 'raises an error' do
      expect{ parsed_yaml }.to raise_error('Could not find cloud plugin')
    end

    context 'when external cpi is specified' do
      before do
        deployment_manifest_fragment['properties']['external_cpi'] = {
          'enabled' => true,
          'name' => 'fake-external-cpi',
        }
      end

      it 'does not raise an error' do
        expect{ parsed_yaml }.to_not raise_error
      end
    end
  end

  describe 'external_cpi' do
    before do
      deployment_manifest_fragment['properties']['external_cpi'] = {
        'enabled' => true,
        'name' => 'fake-external-cpi',
      }
    end

    it 'sets external_cpi' do
      expect(parsed_yaml['cloud']['external_cpi']['enabled']).to eq(true)
      expect(parsed_yaml['cloud']['external_cpi']['cpi_path']).to eq('/var/vcap/jobs/fake-external-cpi/bin/cpi')
    end
  end
end
