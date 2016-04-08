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
          'agent' => { 'user' => 'agent', 'password' => '75d1605f59b60' },
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
        'director' => {
          'name' => 'vpc-bosh-idora',
          'backend_port' => 25556,
          'encryption' => false,
          'max_tasks' => 100,
          'max_threads' => 32,
          'enable_snapshots' => true,
          'enable_post_deploy' => false,
          'generate_vm_passwords' => false,
          'remove_dev_tools' => false,
          'log_access_events_to_syslog' => false,
          'ignore_missing_gateway' => false,
          'disks' => {
            'max_orphaned_age_in_days' => 3,
            'cleanup_schedule' => '0 0,30 * * * * UTC',
          },
          'events' => {
            'record_events' => false,
            'max_events' => 10000,
            'cleanup_schedule' => '0 * * * * * UTC'
          },
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
          'user_management' => { 'provider' => 'local' },
          'trusted_certs' => "test_trusted_certs\nvalue",
        }
      }
    }
  end

  let(:erb_yaml) { File.read(File.join(File.dirname(__FILE__), '../jobs/director/templates/director.yml.erb.erb')) }

  subject(:parsed_yaml) do
    binding = Bosh::Template::EvaluationContext.new(deployment_manifest_fragment).get_binding
    YAML.load(ERB.new(erb_yaml).result(binding))
  end

  it 'raises an error when no cloud provider is configured' do
    expect { parsed_yaml }.to raise_error('Could not find cloud plugin')
  end

  context 'given a generally valid manifest' do
    before do
      deployment_manifest_fragment['properties']['aws'] = {
        'credentials_source' => 'static',
        'access_key_id' => 'key',
        'secret_access_key' => 'secret',
        'default_key_name' => 'default_key_name',
        'default_security_groups' => 'default_security_groups',
        'region' => 'region',
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

    it 'should contain the trusted_certs field' do
      expect(parsed_yaml['trusted_certs']).to eq("test_trusted_certs\nvalue")
    end

    it 'should keep dynamic, COMPONENT-based logging paths' do
      expect(parsed_yaml['logging']['file']).to eq("/var/vcap/sys/log/director/<%= ENV['COMPONENT'] %>.debug.log")
    end

    context 'when domain name specified without all other dns properties' do
      before do
        deployment_manifest_fragment['properties']['dns'] = {
          'domain_name' => 'domain.name'
        }
      end

      it 'does not set the domain_name field appropriately' do
        expect(parsed_yaml['dns']).to be_nil
      end
    end

    context 'and when configured with a blobstore_path' do
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

    it 'dumps the director.backup_destination at the top level' do
      deployment_manifest_fragment['properties']['director'].merge!('backup_destination' => {
        'some_backup_url' => 'http://foo.bar.com',
        'how_much_to_back_up' => {
          'all_the_things' => true
        }
      })

      expect(parsed_yaml['backup_destination']).to eq({
        'some_backup_url' => 'http://foo.bar.com',
        'how_much_to_back_up' => {
          'all_the_things' => true
        }
      })
    end

    context 'events configuration' do
      context 'when enabled' do
        before do
          deployment_manifest_fragment['properties']['director']['events']['record_events'] = true
        end

        it 'renders correctly' do
          expect(parsed_yaml['record_events']).to eq(true)
        end

        it 'is a scheduled task' do
          expect(parsed_yaml['scheduled_jobs'].map{ |v| v['command'] }).to include('ScheduledEventsCleanup')
        end
      end

      context 'when disabled' do
        it 'renders correctly' do
          expect(parsed_yaml['record_events']).to eq(false)
        end

        it 'is a scheduled task' do
          expect(parsed_yaml['scheduled_jobs'].map{ |v| v['command'] }).to_not include('ScheduledEventsCleanup')
        end
      end
    end
  end

  context 'when configured for vsphere' do
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
        ]
      }
    end

    it 'renders correctly' do
      expect(parsed_yaml['cloud']['properties']['vcenters'][0]['host']).to eq('vcenter.address')
      expect(parsed_yaml['cloud']['properties']['vcenters'][0]['user']).to eq('user')
      expect(parsed_yaml['cloud']['properties']['vcenters'][0]['password']).to eq('vcenter.password')
      expect(parsed_yaml['cloud']['properties']['vcenters'][0]['datacenters'][0]['name']).to eq('vcenter.datacenters.first.name')
      expect(parsed_yaml['cloud']['properties']['vcenters'][0]['datacenters'][0]['clusters'][0]).to eq('cluster1')
    end

    context 'when vcenter.address contains special characters' do
      before do
        deployment_manifest_fragment['properties']['vcenter']['address'] = "!vcenter.address''"
      end

      it 'renders correctly' do
        expect(parsed_yaml['cloud']['properties']['vcenters'][0]['host']).to eq("!vcenter.address''")
      end
    end

    context 'when vcenter.user contains special characters' do
      before do
        deployment_manifest_fragment['properties']['vcenter']['user'] = "!vcenter.user''"
      end

      it 'renders correctly' do
        expect(parsed_yaml['cloud']['properties']['vcenters'][0]['user']).to eq("!vcenter.user''")
      end
    end

    context 'when vcenter.password contains special characters' do
      before do
        deployment_manifest_fragment['properties']['vcenter']['password'] = "!vcenter.password''"
      end

      it 'renders correctly' do
        expect(parsed_yaml['cloud']['properties']['vcenters'][0]['password']).to eq("!vcenter.password''")
      end
    end

    context 'when datacenter cluster are provided as hash' do
      before do
        deployment_manifest_fragment['properties']['vcenter'] = {
          'address' => 'vcenter.address',
          'user' => 'user',
          'password' => 'vcenter.password',
          'datacenters' => [
            {
              'name' => 'vcenter.datacenters.first.name',
              'clusters' => [{'cluster-name' => {'resource_pool' => 'rp-name'}}]
            },
          ]
        }
      end

      it 'renders correctly' do
        expect(parsed_yaml['cloud']['properties']['vcenters'][0]['datacenters'][0]['clusters']).to eq([{'cluster-name' => {'resource_pool' => 'rp-name'}}])
      end
    end
  end

  context 'when configured for vcloud' do
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

      it 'escapes parameters correctly' do
        deployment_manifest_fragment['properties']['vcd'] = {
          'url' => "my\nvcdurl",
          'user' => "my\nvcduser",
          'password' => "my\nvcdpassword",
          'entities' => {
            'organization' => "my\norg",
            'virtual_datacenter' => "my\nvdc",
            'vapp_catalog' => "my\nvappcatalog",
            'media_catalog' => "my\nmediacatalog",
            'vm_metadata_key' => "my\nmetadatakey",
            'description' => "my\ndescription"
          }
        }

        parsed = parsed_yaml # doesn't blow up -- escapes the newlines correctly

        expect(parsed['cloud']['properties']['vcds'][0]['url']).to eq "my\nvcdurl"
        expect(parsed['cloud']['properties']['vcds'][0]['user']).to eq "my\nvcduser"
        expect(parsed['cloud']['properties']['vcds'][0]['password']).to eq "my\nvcdpassword"
        expect(parsed['cloud']['properties']['vcds'][0]['entities']['organization']).to eq "my\norg"
        expect(parsed['cloud']['properties']['vcds'][0]['entities']['virtual_datacenter']).to eq "my\nvdc"
        expect(parsed['cloud']['properties']['vcds'][0]['entities']['vapp_catalog']).to eq "my\nvappcatalog"
        expect(parsed['cloud']['properties']['vcds'][0]['entities']['media_catalog']).to eq "my\nmediacatalog"
        expect(parsed['cloud']['properties']['vcds'][0]['entities']['vm_metadata_key']).to eq "my\nmetadatakey"
        expect(parsed['cloud']['properties']['vcds'][0]['entities']['description']).to eq "my\ndescription"
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

  context 'when configured for openstack' do
    before do
      deployment_manifest_fragment['properties']['openstack'] = {
        'auth_url' => 'auth_url',
        'username' => 'username',
        'api_key' => 'api_key',
        'tenant' => 'tenant',
        'domain' => 'domain',
        'project' => 'project',
        'default_key_name' => 'default_key_name',
        'default_security_groups' => 'default_security_groups',
        'wait_resource_poll_interval' => 'wait_resource_poll_interval',
        'config_drive' => 'config-drive-value',
        'boot_volume_cloud_properties' => {
          'type' => 'SSD'
        },
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

    it 'renders openstack properties' do
      expect(parsed_yaml['cloud']['properties']['openstack']).to eq({
        'auth_url' => 'auth_url',
        'username' => 'username',
        'api_key' => 'api_key',
        'tenant' => 'tenant',
        'domain' => 'domain',
        'project' => 'project',
        'default_key_name' => 'default_key_name',
        'default_security_groups' => 'default_security_groups',
        'wait_resource_poll_interval' => 'wait_resource_poll_interval',
        'config_drive' => 'config-drive-value',
        'boot_volume_cloud_properties' => {
          'type' => 'SSD'
        },
      })
    end

    context 'when openstack connection options exist' do
      before do
        deployment_manifest_fragment['properties']['openstack']['connection_options'] = {
          'option1' => 'true', 'option2' => 'false' }
      end

      it 'renders openstack connection options correctly' do
        expect(parsed_yaml['cloud']['properties']['openstack']['connection_options']).to eq(
            { 'option1' => 'true', 'option2' => 'false' })
      end
    end

    context 'when openstack.auth_url contains special characters' do
      before do
        deployment_manifest_fragment['properties']['openstack']['auth_url'] = "!openstack.auth_url''"
      end

      it 'renders correctly' do
        expect(parsed_yaml['cloud']['properties']['openstack']['auth_url']).to eq("!openstack.auth_url''")
      end
    end

    context 'when openstack.username contains special characters' do
      before do
        deployment_manifest_fragment['properties']['openstack']['username'] = "!openstack.username''"
      end

      it 'renders correctly' do
        expect(parsed_yaml['cloud']['properties']['openstack']['username']).to eq("!openstack.username''")
      end
    end

    context 'when openstack.registry.user contains special characters' do
      before do
        deployment_manifest_fragment['properties']['registry']['http']['user'] = "!openstack.user"
      end

      it 'renders correctly' do
        expect(parsed_yaml['cloud']['properties']['registry']['user']).to eq("!openstack.user")
      end
    end

    context 'when openstack.registry.password contains special characters' do
      before do
        deployment_manifest_fragment['properties']['registry']['http']['password'] = "!openstack.password"
      end

      it 'renders correctly' do
        expect(parsed_yaml['cloud']['properties']['registry']['password']).to eq("!openstack.password")
      end
    end

    context 'when openstack.registry.endpoint contains special characters' do
      before do
        deployment_manifest_fragment['properties']['registry']['address'] = "!openstack.address"
        deployment_manifest_fragment['properties']['registry']['http']['port'] = "!4578"
      end

      it 'renders correctly' do
        expect(parsed_yaml['cloud']['properties']['registry']['endpoint']).to eq("http://!openstack.address:!4578")
      end
    end

    context 'when openstack.api_key contains special characters' do
      before do
        deployment_manifest_fragment['properties']['openstack']['api_key'] = "!openstack.api_key''"
      end

      it 'renders correctly' do
        expect(parsed_yaml['cloud']['properties']['openstack']['api_key']).to eq("!openstack.api_key''")
      end
    end

    context 'when openstack.tenant contains special characters' do
      before do
        deployment_manifest_fragment['properties']['openstack']['tenant'] = "!openstack.tenant''"
      end

      it 'renders correctly' do
        expect(parsed_yaml['cloud']['properties']['openstack']['tenant']).to eq("!openstack.tenant''")
      end
    end
  end

  context 'when configured for aws' do
    before do
      deployment_manifest_fragment['properties']['aws'] = {
        'credentials_source' => 'static',
        'access_key_id' => 'key',
        'secret_access_key' => 'secret',
        'default_key_name' => 'default_key_name',
        'default_security_groups' => 'default_security_groups',
        'region' => 'region',
        'ec2_endpoint' => 'some_ec2_endpoint',
        'elb_endpoint' => 'some_elb_endpoint',
        'max_retries' => 3,
        'http_read_timeout' => 300,
        'http_wire_trace' => true,
        'ssl_verify_peer' => false,
        'ssl_ca_file' => '/custom/cert/ca-certificates',
        'ssl_ca_path' => '/custom/cert/'
      }
      deployment_manifest_fragment['properties']['registry'] = {
        'address' => 'address',
        'http' => {
          'port' => 'port',
          'user' => 'user',
          'password' => 'password'
        }
      }
      deployment_manifest_fragment['properties']['director']['user_management'] = {
        'provider' => 'uaa',
        'uaa' => {
          'url' => 'fake-url',
          'symmetric_key' => 'fake-symmetric-key',
          'public_key' => 'fake-public-key',
        },
      }
    end

    context 'when credentials_source is not static' do
      before do
        deployment_manifest_fragment['properties']['aws']['credentials_source'] = 'env_or_profile'
        deployment_manifest_fragment['properties']['aws'].delete('access_key_id')
        deployment_manifest_fragment['properties']['aws'].delete('secret_access_key')
        deployment_manifest_fragment['properties']['aws']['default_iam_instance_profile'] = 'my_iam_profile'

      end

      it 'renders aws properties' do
        expect(parsed_yaml['cloud']['properties']['aws']).to eq({
          'credentials_source' => 'env_or_profile',
          'access_key_id' => nil,
          'secret_access_key' => nil,
          'default_iam_instance_profile' => 'my_iam_profile',
          'default_key_name' => 'default_key_name',
          'default_security_groups' => 'default_security_groups',
          'region' => 'region',
          'ec2_endpoint' => 'some_ec2_endpoint',
          'elb_endpoint' => 'some_elb_endpoint',
          'max_retries' => 3,
          'http_read_timeout' => 300,
          'http_wire_trace' => true,
          'ssl_verify_peer' => false,
          'ssl_ca_file' => '/custom/cert/ca-certificates',
          'ssl_ca_path' => '/custom/cert/'
        })
      end

    end

    it 'sets plugin to aws' do
      expect(parsed_yaml['cloud']).to include({
        'plugin' => 'aws'
      })
    end

    it 'sets the user_management provider' do
      expect(parsed_yaml['user_management']).to eq({
        'provider' => 'uaa',
        'uaa' => {
          'url' => 'fake-url',
          'symmetric_key' => 'fake-symmetric-key',
          'public_key' => 'fake-public-key',
        }
      })
    end

    context 'when user does not provide UAA key' do
      before do
        deployment_manifest_fragment['properties']['director']['user_management']['uaa'].delete('symmetric_key')
        deployment_manifest_fragment['properties']['director']['user_management']['uaa'].delete('public_key')
      end

      it 'raises' do
        expect { parsed_yaml }.to raise_error('UAA provider requires symmetric or public key')
      end
    end

    it 'renders aws properties' do
      expect(parsed_yaml['cloud']['properties']['aws']).to eq({
        'credentials_source' => 'static',
        'access_key_id' => 'key',
        'secret_access_key' => 'secret',
        'default_iam_instance_profile' => nil,
        'default_key_name' => 'default_key_name',
        'default_security_groups' => 'default_security_groups',
        'region' => 'region',
        'ec2_endpoint' => 'some_ec2_endpoint',
        'elb_endpoint' => 'some_elb_endpoint',
        'max_retries' => 3,
        'http_read_timeout' => 300,
        'http_wire_trace' => true,
        'ssl_verify_peer' => false,
        'ssl_ca_file' => '/custom/cert/ca-certificates',
        'ssl_ca_path' => '/custom/cert/'
      })
    end

    context 'when aws.registry.user contains special characters' do
      before do
        deployment_manifest_fragment['properties']['registry']['http']['user'] = "!aws.user"
      end

      it 'renders correctly' do
        expect(parsed_yaml['cloud']['properties']['registry']['user']).to eq("!aws.user")
      end
    end

    context 'when aws.registry.password contains special characters' do
      before do
        deployment_manifest_fragment['properties']['registry']['http']['password'] = "!aws.password"
      end

      it 'renders correctly' do
        expect(parsed_yaml['cloud']['properties']['registry']['password']).to eq("!aws.password")
      end
    end

    context 'when aws.registry.endpoint contains special characters' do
      before do
        deployment_manifest_fragment['properties']['registry']['address'] = "!aws.address"
        deployment_manifest_fragment['properties']['registry']['http']['port'] = "!4578"
      end

      it 'renders correctly' do
        expect(parsed_yaml['cloud']['properties']['registry']['endpoint']).to eq("http://!aws.address:!4578")
      end
    end

    context 'and using an s3 blobstore' do
      context 'when credentials_source is not static' do
        before do
          deployment_manifest_fragment['properties']['blobstore'] = {
            'provider' => 's3',
            'bucket_name' => 'mybucket',
            'credentials_source' => 'env_or_profile',
            'access_key_id' => nil,
            'secret_access_key' => nil,
            's3_region' => 'region'
          }
        end

        it 'sets the blobstore fields appropriately' do
          expect(parsed_yaml['blobstore']['options']).to include({
            'bucket_name' => 'mybucket',
            'credentials_source' => 'env_or_profile',
            'access_key_id' => nil,
            'secret_access_key' => nil,
            'region' => 'region'
          })
        end
      end

      context 'when credentials_source is static' do
        before do
          deployment_manifest_fragment['properties']['blobstore'] = {
            'provider' => 's3',
            'bucket_name' => 'mybucket',
            'credentials_source' => 'static',
            'access_key_id' => 'key',
            'secret_access_key' => 'secret',
            's3_region' => 'region'
          }
        end

        it 'set provider as s3cli' do
          expect(parsed_yaml['blobstore']['provider']).to eq("s3cli")
        end

        it 'sets the blobstore fields appropriately' do
          expect(parsed_yaml['blobstore']['options']).to eq({
            'bucket_name' => 'mybucket',
            'credentials_source' => 'static',
            'access_key_id' => 'key',
            'secret_access_key' => 'secret',
            'region' => 'region',
            's3cli_config_path' => '/var/vcap/data/tmp/director',
            's3cli_path' => '/var/vcap/packages/s3cli/bin/s3cli'
          })
        end

        describe 'the agent blobstore' do
          it 'has the same config as the toplevel blobstore' do
            expect(parsed_yaml['cloud']['properties']['agent']['blobstore']['options']).to eq({
              'bucket_name' => 'mybucket',
              'credentials_source' => 'static',
              'access_key_id' => 'key',
              'secret_access_key' => 'secret',
              'region' => 'region'
            })
          end

          context 'when credentials_source is not static' do
            before do
              deployment_manifest_fragment['properties']['agent'] = {
                'blobstore' => {
                  'credentials_source' => 'env_or_profile',
                  'access_key_id' => nil,
                  'secret_access_key' => nil,
                }
              }
            end

            it 'falls back to blobstore credential' do
              expect(parsed_yaml['cloud']['properties']['agent']['blobstore']['options']).to eq({
                'bucket_name' => 'mybucket',
                'credentials_source' => 'env_or_profile',
                'access_key_id' => 'key',
                'secret_access_key' => 'secret',
                'region' => 'region'
              })
            end

            context 'when blobstore does not have credentials' do
              before do
                deployment_manifest_fragment['properties']['blobstore'].delete('access_key_id')
                deployment_manifest_fragment['properties']['blobstore'].delete('secret_access_key')
              end

              it 'access key and secret key to nil' do
                expect(parsed_yaml['cloud']['properties']['agent']['blobstore']['options']).to eq({
                  'bucket_name' => 'mybucket',
                  'credentials_source' => 'env_or_profile',
                  'access_key_id' => nil,
                  'secret_access_key' => nil,
                  'region' => 'region'
                })
              end
            end
          end

          context 'when there are override values for the agent' do
            before do
              deployment_manifest_fragment['properties']['agent'] = {
                'blobstore' => {
                  'credentials_source' => 'static',
                  'access_key_id' => 'agent-key',
                  'secret_access_key' => 'agent-secret',
                }
              }
            end

            it 'uses the override values' do
              expect(parsed_yaml['cloud']['properties']['agent']['blobstore']['options']).to eq({
                'bucket_name' => 'mybucket',
                'credentials_source' => 'static',
                'access_key_id' => 'agent-key',
                'secret_access_key' => 'agent-secret',
                'region' => 'region'

              })
            end
          end
        end

        context 'when the user specifies use_ssl, ssl_verify_peer, s3_multipart_threshold, port, s3_force_path_style and host' do
          before do
            deployment_manifest_fragment['properties']['blobstore'].merge!({
              'use_ssl' => false,
              'ssl_verify_peer' => false,
              's3_multipart_threshold' => 123,
              's3_signature_version' => 52,
              's3_port' => 5155,
              'host' => 'myhost.hostland.edu',
              's3_force_path_style' => true,
              's3_region' => 'region'
            })
            deployment_manifest_fragment['properties']['compiled_package_cache']['options'] = deployment_manifest_fragment['properties']['blobstore']
          end

          it 'sets the blobstore fields appropriately' do
            expect(parsed_yaml['blobstore']['options']).to include({
              'bucket_name' => 'mybucket',
              'credentials_source' => 'static',
              'access_key_id' => 'key',
              'secret_access_key' => 'secret',
              'use_ssl' => false,
              'ssl_verify_peer' => false,
              's3_multipart_threshold' => 123,
              's3_signature_version' => 52,
              'port' => 5155,
              'host' => 'myhost.hostland.edu',
              's3_force_path_style' => true,
              'region' => 'region'
            })

            expect(parsed_yaml['compiled_package_cache']['options']).to include({
              'bucket_name' => 'mybucket',
              'credentials_source' => 'static',
              'access_key_id' => 'key',
              'secret_access_key' => 'secret',
              'use_ssl' => false,
              'ssl_verify_peer' => false,
              's3_multipart_threshold' => 123,
              's3_signature_version' => 52,
              'port' => 5155,
              'host' => 'myhost.hostland.edu',
              's3_force_path_style' => true,
              'region' => 'region'
            })
          end

          it 'sets endpoint protocol appropriately when use_ssl is true' do
            deployment_manifest_fragment['properties']['blobstore']['use_ssl'] = true

            expect(parsed_yaml['blobstore']['options']).to include({
              'bucket_name' => 'mybucket',
              'credentials_source' => 'static',
              'access_key_id' => 'key',
              'secret_access_key' => 'secret',
              'use_ssl' => true,
              'ssl_verify_peer' => false,
              's3_multipart_threshold' => 123,
              's3_signature_version' => 52,
              'port' => 5155,
              'host' => 'myhost.hostland.edu',
              's3_force_path_style' => true,
              'region' => 'region'
            })
          end

          describe 'the agent blobstore' do
            it 'has the same config as the toplevel blobstore' do
              expect(parsed_yaml['cloud']['properties']['agent']['blobstore']['options']).to eq({
                'bucket_name' => 'mybucket',
                'credentials_source' => 'static',
                'access_key_id' => 'key',
                'secret_access_key' => 'secret',
                'use_ssl' => false,
                'ssl_verify_peer' => false,
                's3_multipart_threshold' => 123,
                's3_signature_version' => 52,
                'port' => 5155,
                'host' => 'myhost.hostland.edu',
                's3_force_path_style' => true,
                'region' => 'region'
              })
            end

            context 'when there are override values for the agent' do
              before do
                deployment_manifest_fragment['properties']['agent'] = {
                  'blobstore' => {
                    'credentials_source' => 'static',
                    'access_key_id' => 'agent-key',
                    'secret_access_key' => 'agent-secret',
                    'host' => 'fakehost.example.com',
                    'use_ssl' => true,
                    'ssl_verify_peer' => true,
                    's3_force_path_style' => false,
                    's3_signature_version' => 51,
                    's3_multipart_threshold' => 456,
                  }
                }
              end

              it 'uses the override values' do
                expect(parsed_yaml['cloud']['properties']['agent']['blobstore']['options']).to eq({
                  'bucket_name' => 'mybucket',
                  'credentials_source' => 'static',
                  'access_key_id' => 'agent-key',
                  'secret_access_key' => 'agent-secret',
                  'use_ssl' => true,
                  'ssl_verify_peer' => true,
                  's3_force_path_style' => false,
                  's3_multipart_threshold' => 456,
                  's3_signature_version' => 51,
                  'port' => 5155,
                  'host' => 'fakehost.example.com',
                  'region' => 'region'
                })
              end
            end
          end
        end
      end
    end
  end

  describe 'ignore_missing_gateway property' do
    before do
      deployment_manifest_fragment['properties']['director']['cpi_job'] = 'test-cpi'
    end

    context 'when false' do
      it 'renders false' do
        expect(parsed_yaml['ignore_missing_gateway']).to be(false)
      end
    end

    context 'when true' do
      before do
        deployment_manifest_fragment['properties']['director']['ignore_missing_gateway'] = true
      end

      it 'renders true' do
        expect(parsed_yaml['ignore_missing_gateway']).to be(true)
      end
    end
  end

  context 'when configured to use a cpi_job' do
    before do
      deployment_manifest_fragment['properties']['director']['cpi_job'] = 'test-cpi'
    end

    it 'configures the cpi correctly' do
      expect(parsed_yaml['cloud']['provider']['name']).to eq('test-cpi')
      expect(parsed_yaml['cloud']['provider']['path']).to eq('/var/vcap/jobs/test-cpi/bin/cpi')
    end
  end

  context 'when ntp is provided' do
    before do
      deployment_manifest_fragment['properties']['director']['cpi_job'] = 'test-cpi'
      deployment_manifest_fragment['properties']['ntp'] = ['1.1.1.1', '2.2.2.2']
    end

    it 'configures the cpi correctly' do
      expect(parsed_yaml['cloud']['properties']['agent']['ntp']).to eq(['1.1.1.1', '2.2.2.2'])
    end
  end
end
