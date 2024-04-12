require 'rspec'
require 'yaml'
require 'json'
require 'bosh/template/test'
require 'bosh/template/evaluation_context'
require_relative './template_example_group'

describe 'director.yml.erb' do
  let(:merged_manifest_properties) do
    {
      'agent' => {
        'env' => {
          'bosh' => {
            'foo' => 'bar'
          }
        },
        'agent_wait_timeout' => 600,
      },
      'blobstore' => {
        'address' => '10.10.0.7',
        'port' => 25251,
        'agent' => { 'user' => 'agent', 'password' => '75d1605f59b60' },
        'director' => {
          'user' => 'user',
          'password' => 'password'
        },
        'provider' => 'dav',
        'tls' => {
          'cert' => {
            'ca' => '-----BEGIN CERTIFICATE-----'
          }
        },
        'enable_signed_urls' => false,
      },
      'hm' => {
        'http' => {
          'port' => 12345,
        },
      },
      'nats' => {
        'address' => '10.10.0.7',
        'port' => 4222
      },
      'director' => {
        'name' => 'vpc-bosh-idora',
        'backend_port' => 25556,
        'max_tasks' => 100,
        'max_threads' => 32,
        'puma_workers' => 3,
        'enable_snapshots' => true,
        'enable_nats_delivered_templates' => false,
        'enable_cpi_resize_disk' => false,
        'enable_pre_ruby_3_2_equal_tilde_behavior' => false,
        'allow_errands_on_stopped_instances' => false,
        'generate_vm_passwords' => false,
        'remove_dev_tools' => false,
        'log_level' => 'debug',
        'log_access_events' => false,
        'flush_arp' => false,
        'local_dns' => {
          'enabled' => true,
          'include_index' => false,
          'use_dns_addresses' => true,
        },
        'ignore_missing_gateway' => false,
        'disks' => {
          'max_orphaned_age_in_days' => 3,
          'cleanup_schedule' => '0 0,30 * * * * UTC',
        },
        'networks' => {
          'enable_cpi_management' => false,
          'max_orphaned_age_in_days' => 3,
          'cleanup_schedule' => '0 0,30 * * * * UTC',
        },
        'vms' => {
          'cleanup_schedule' => '0 0,30 * * * * UTC',
        },
        'events' => {
          'record_events' => false,
          'max_events' => 10000,
          'cleanup_schedule' => '0 * * * * * UTC'
        },
        'tasks_cleanup_schedule' => '0 0 */7 * * * UTC',
        'db' => {
          'adapter' => 'mysql2',
          'user' => 'ub45391e00',
          'password' => 'p4cd567d84d0e012e9258d2da30',
          'host' => 'bosh.hamazonhws.com',
          'port' => 3306,
          'database' => 'bosh',
          'connection_options' => {},
          'tls' => {
            'enabled' => false,
            'cert' => {
              'ca' => 'config/db/ca.pem'
            }
          },
        },
        'config_server' => {
          'enabled' => false
        },
        'auto_fix_stateful_nodes' => true,
        'max_vm_create_tries' => 5,
        'user_management' => { 'provider' => 'local' },
        'trusted_certs' => "test_trusted_certs\nvalue",
        'cpi_api_test_max_version' => 2,
        'metrics_server' => {
          'enabled' => false,
          'port' => 9091,
        },
      }
    }
  end

  shared_examples 'template rendering' do
    context 'given a generally valid manifest' do
      before do
        merged_manifest_properties['director']['cpi_job'] = 'vsphere'
      end

      context 'when using web dav blobstore' do
        before do
          expect(merged_manifest_properties['blobstore']['provider']).to eq('dav')
        end

        it 'should configure the paths' do
          expect(parsed_yaml['blobstore']['provider']).to eq('davcli')
          expect(parsed_yaml['blobstore']['options']['davcli_config_path']).to eq('/var/vcap/data/director/tmp')
          expect(parsed_yaml['blobstore']['options']['davcli_path']).to eq('/var/vcap/packages/davcli/bin/davcli')
          expect(parsed_yaml['blobstore']['options']['tls']['cert']['ca']).to eq('-----BEGIN CERTIFICATE-----')
        end
      end

      context 'when using s3 blobstore' do
        before do
          merged_manifest_properties['blobstore']['provider'] = 's3'
          merged_manifest_properties['blobstore']['bucket_name'] = 'bucket'
        end

        it 'should configure the paths' do
          expect(parsed_yaml['blobstore']['provider']).to eq('s3cli')
          expect(parsed_yaml['blobstore']['options']['s3cli_config_path']).to eq('/var/vcap/data/director/tmp')
          expect(parsed_yaml['blobstore']['options']['s3cli_path']).to eq('/var/vcap/packages/s3cli/bin/s3cli')
        end
      end

      context 'when using the verify-multidigest binary' do
        it 'should configure the paths' do
          expect(parsed_yaml['verify_multidigest_path']).to eq('/var/vcap/packages/verify_multidigest/bin/verify-multidigest')
        end
      end

      describe 'local_dns' do
        it 'configures local dns values' do
          expect(parsed_yaml['local_dns']['enabled']).to eq(true)
          expect(parsed_yaml['local_dns']['include_index']).to eq(false)
          expect(parsed_yaml['local_dns']['use_dns_addresses']).to eq(true)
        end
      end

      context 'nats' do
        it 'should have the path to server ca certificate' do
          expect(parsed_yaml['nats']['server_ca_path']).to eq('/var/vcap/jobs/director/config/nats_server_ca.pem')
        end

        context 'director' do
          it 'should have the path to director certificate' do
            expect(parsed_yaml['nats']['client_certificate_path']).to eq('/var/vcap/jobs/director/config/nats_client_certificate.pem')
          end
          it 'should have the path to director private key' do
            expect(parsed_yaml['nats']['client_private_key_path']).to eq('/var/vcap/jobs/director/config/nats_client_private_key')
          end
        end

        context 'agent' do
          it 'should have the path to agent certificate' do
            expect(parsed_yaml['nats']['client_ca_certificate_path']).to eq('/var/vcap/jobs/director/config/nats_client_ca_certificate.pem')
          end

          it 'should have the path to agent private key' do
            expect(parsed_yaml['nats']['client_ca_private_key_path']).to eq('/var/vcap/jobs/director/config/nats_client_ca_private_key')
          end
        end
      end

      context 'when dns.domain_name specified' do
        before do
          merged_manifest_properties['dns'] = {
            'domain_name' => 'fake.domain.name'
          }
        end

        it 'set the domain_name field appropriately' do
          expect(parsed_yaml['dns']).to_not be_nil
        end
      end

      context 'events configuration' do
        context 'when enabled' do
          before do
            merged_manifest_properties['director']['events']['record_events'] = true
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

          it 'is not a scheduled task' do
            expect(parsed_yaml['scheduled_jobs'].map{ |v| v['command'] }).to_not include('ScheduledEventsCleanup')
          end
        end
      end

      context 'dns blob cleanup' do
        it 'is a scheduled task with correct params' do
          expect(parsed_yaml['scheduled_jobs']).to include({
            'command' => 'ScheduledDnsBlobsCleanup',
            'schedule' => '0 0,30 * * * * UTC',
            'params' => [{'max_blob_age' => 3600, 'num_dns_blobs_to_keep' => 10}]
          })
        end
      end

      context 'orphaned network cleanup' do
        it 'is a scheduled task with correct params' do
          expect(parsed_yaml['scheduled_jobs']).to include(
            'command' => 'ScheduledOrphanedNetworkCleanup',
            'schedule' => '0 0,30 * * * * UTC',
            'params' => [{ 'max_orphaned_age_in_days' => 3 }],
          )
        end
      end

      describe 'config server' do
        context 'when turned on' do
          before do
            merged_manifest_properties['director']['config_server'] = {
              'enabled' => true,
              'url' => 'https://config-server-host',
              'uaa' => {
                'url' => 'fake-uaa-url',
                'client_id' => 'fake-client-id',
                'client_secret' => 'fake-client-secret',
                'ca_cert' => 'fake-ca-cert'
              },
            }
          end

          it 'parses correctly' do
            expect(parsed_yaml['config_server']['enabled']).to eq(true)

            expect(parsed_yaml['config_server']['url']).to eq('https://config-server-host')
            expect(parsed_yaml['config_server']['ca_cert_path']).to eq('/var/vcap/jobs/director/config/config_server_ca.cert')

            expect(parsed_yaml['config_server']['uaa']['url']).to eq('fake-uaa-url')
            expect(parsed_yaml['config_server']['uaa']['client_id']).to eq('fake-client-id')
            expect(parsed_yaml['config_server']['uaa']['client_secret']).to eq('fake-client-secret')
            expect(parsed_yaml['config_server']['uaa']['ca_cert_path']).to eq('/var/vcap/jobs/director/config/uaa_server_ca.cert')
          end

          describe 'UAA properties' do
            it 'throws an error when uaa properties are not defined' do
              merged_manifest_properties['director']['config_server'] = {
                'enabled' => true,
                'url' => 'https://config-server-host',
              }
              expect { parsed_yaml['config_server'] }.to raise_error(/Can't find property '\["director.config_server.uaa.url"\]'/)
            end

            it 'throws an error when uaa url is not defined' do
              merged_manifest_properties['director']['config_server'] = {
                'enabled' => true,
                'url' => 'https://config-server-host',
                'uaa' => {}
              }

              expect { parsed_yaml['config_server'] }.to raise_error(Bosh::Template::UnknownProperty, "Can't find property '[\"director.config_server.uaa.url\"]'")
            end

            it 'throws an error when uaa client id is not defined' do
              merged_manifest_properties['director']['config_server'] = {
                'enabled' => true,
                'url' => 'https://config-server-host',
                'uaa' => {
                  'url' => 'https://something.com',
                  'client_secret' => 'secret',
                  'ca_cert_path' => '/var/vcap/blah/to/go'
                }
              }

              expect { parsed_yaml['config_server'] }.to raise_error(Bosh::Template::UnknownProperty, "Can't find property '[\"director.config_server.uaa.client_id\"]'")
            end

            it 'throws an error when uaa client secret is not defined' do
              merged_manifest_properties['director']['config_server'] = {
                'enabled' => true,
                'url' => 'https://config-server-host',
                'uaa' => {
                  'url' => 'https://something.com',
                  'client_id' => 'id',
                  'ca_cert_path' => '/var/vcap/blah/to/go'
                }
              }

              expect { parsed_yaml['config_server'] }.to raise_error(Bosh::Template::UnknownProperty, "Can't find property '[\"director.config_server.uaa.client_secret\"]'")
            end

            it 'does not throw any error when all the uaa properties are defined' do
              merged_manifest_properties['director']['config_server'] = {
                'enabled' => true,
                'url' => 'https://config-server-host',
                'uaa' => {
                  'url' => 'https://something.com',
                  'client_id' => 'id',
                  'client_secret' => 'secret',
                  'ca_cert_path' => '/var/some/path'
                }
              }

              expect { parsed_yaml['config_server'] }.to_not raise_error
            end
          end
        end

        context 'when turned off' do
          before do
            merged_manifest_properties['director']['config_server']['enabled'] = false
          end

          it 'parses correctly' do
            expect(parsed_yaml['config_server']).to eq({"enabled"=>false})
          end
        end
      end

      describe 'allow_errands_on_stopped_instances' do
        it 'defaults to false' do
          expect(parsed_yaml['allow_errands_on_stopped_instances']).to be_falsey
        end

        context 'when set to true' do
          before do
            merged_manifest_properties['director']['allow_errands_on_stopped_instances'] = true
          end

          it 'parses correctly' do
            expect(parsed_yaml['allow_errands_on_stopped_instances']).to be_truthy
          end
        end
      end

      describe 'enable_nats_delivered_templates' do
        context 'when set to true' do
          before do
            merged_manifest_properties['director']['enable_nats_delivered_templates'] = true
          end

          it 'parses correctly' do
            expect(parsed_yaml['enable_nats_delivered_templates']).to be_truthy
          end
        end

        context 'when set to false' do
          before do
            merged_manifest_properties['director']['enable_nats_delivered_templates'] = false
          end

          it 'parses correctly' do
            expect(parsed_yaml['enable_nats_delivered_templates']).to be_falsey
          end
        end
      end

      describe 'director.db.tls properties' do
        it 'passes correct path for database ca cert, client cert, and client private key' do
          expect(parsed_yaml['db']['tls']['cert']['ca']).to eq('/var/vcap/jobs/director/config/db/ca.pem')
          expect(parsed_yaml['db']['tls']['cert']['certificate']).to eq('/var/vcap/jobs/director/config/db/client_certificate.pem')
          expect(parsed_yaml['db']['tls']['cert']['private_key']).to eq('/var/vcap/jobs/director/config/db/client_private_key.key')
        end

        context 'when director.db.tls.enabled is true' do
          before do
            merged_manifest_properties['director']['db']['tls']['enabled'] = true
          end

          it 'configures enabled TLS for database property' do
            expect(parsed_yaml['db']['tls']['enabled']).to be_truthy
          end
        end

        context 'when director.db.tls.enabled is false' do
          before do
            merged_manifest_properties['director']['db']['tls']['enabled'] = false
          end

          it 'configures disables TLS for database property' do
            expect(parsed_yaml['db']['tls']['enabled']).to be_falsey
          end
        end

        context 'when director.db.tls.enabled is not defined' do
          before do
            merged_manifest_properties['director']['db']['tls'].delete('enabled')
          end

          it 'configures disables TLS for database property' do
            expect(parsed_yaml['db']['tls']['enabled']).to be_falsey
          end
        end

        context 'when director.db.tls.skip_host_verify is true' do
          before do
            merged_manifest_properties['director']['db']['tls']['skip_host_verify'] = true
          end

          it 'configures enabled TLS for database property' do
            expect(parsed_yaml['db']['tls']['skip_host_verify']).to be_truthy
          end
        end

        context 'when director.db.tls.skip_host_verify is false' do
          before do
            merged_manifest_properties['director']['db']['tls']['skip_host_verify'] = false
          end

          it 'configures disables TLS for database property' do
            expect(parsed_yaml['db']['tls']['skip_host_verify']).to be_falsey
          end
        end

        context 'when director.db.tls.skip_host_verify is not defined' do
          before do
            merged_manifest_properties['director']['db']['tls'].delete('skip_host_verify')
          end

          it 'configures disables TLS for database property' do
            expect(parsed_yaml['db']['tls']['skip_host_verify']).to be_falsey
          end
        end

        context 'when director.db.tls.cert.ca is provided' do
          it 'set bosh_internal ca_provided to true' do
            expect(parsed_yaml['db']['tls']['bosh_internal']['ca_provided']).to be_truthy
          end
        end

        context 'when director.db.tls.cert.ca is NOT provided' do
          before do
            merged_manifest_properties['director']['db']['tls']['cert']['ca'] = nil
          end

          it 'set bosh_internal ca_provided to false' do
            expect(parsed_yaml['db']['tls']['bosh_internal']['ca_provided']).to be_falsey
          end
        end

        context 'when director.db.tls.cert.certificate and director.db.tls.cert.private_key are provided' do
          before do
            merged_manifest_properties['director']['db']['tls']['cert']['certificate'] = 'something'
            merged_manifest_properties['director']['db']['tls']['cert']['private_key'] = 'something secret'
          end

          it 'configures mutual TLS for database' do
            expect(parsed_yaml['db']['tls']['bosh_internal']['mutual_tls_enabled']).to be_truthy
          end
        end

        context 'when director.db.tls.cert.certificate is NOT provided' do
          before do
            merged_manifest_properties['director']['db']['tls']['cert']['private_key'] = 'something secret'
          end

          it 'does NOT configure mutual TLS for database' do
            expect(parsed_yaml['db']['tls']['bosh_internal']['mutual_tls_enabled']).to be_falsey
          end
        end

        context 'when director.db.tls.cert.private_key is NOT provided' do
          before do
            merged_manifest_properties['director']['db']['tls']['cert']['certificate'] = 'something'
          end

          it 'does NOT configure mutual TLS for database' do
            expect(parsed_yaml['db']['tls']['bosh_internal']['mutual_tls_enabled']).to be_falsey
          end
        end
      end

      describe 'puma_workers' do
        it 'configures default puma_workers correctly' do
          expect(parsed_yaml['puma_workers']).to eq(3)
        end
      end

      it 'should contain the trusted_certs field' do
        expect(parsed_yaml['trusted_certs']).to eq("test_trusted_certs\nvalue")
      end

      it 'should contain the version' do
        expect(parsed_yaml['version']).to eq('280.0.22')
      end

      it 'should contain the audit log path' do
        expect(parsed_yaml['audit_log_path']).to eq('/var/vcap/sys/log/director')
      end

      it 'should contain the director certificate expiry path' do
        expect(parsed_yaml['director_certificate_expiry_json_path']).to(
          eq('/var/vcap/jobs/director/config/certificate_expiry.json'),
        )
      end
    end

    describe 'ignore_missing_gateway property' do
      before do
        merged_manifest_properties['director']['cpi_job'] = 'test-cpi'
      end

      context 'when false' do
        it 'renders false' do
          expect(parsed_yaml['ignore_missing_gateway']).to be(false)
        end
      end

      context 'when true' do
        before do
          merged_manifest_properties['director']['ignore_missing_gateway'] = true
        end

        it 'renders true' do
          expect(parsed_yaml['ignore_missing_gateway']).to be(true)
        end
      end
    end

    context 'when agent env properties are provided' do
      before do
        merged_manifest_properties['director']['cpi_job'] = 'test-cpi'
        merged_manifest_properties['agent']['env']['bosh'] = {'foo' => 'bar'}
        merged_manifest_properties['agent']['env']['abc'] = {'foo' => 'bar'}
        merged_manifest_properties['agent']['agent_wait_timeout'] = 'some-timeout'
      end

      it 'configures the cpi correctly with agent.env.bosh properties' do
        expect(parsed_yaml['agent']['env']['bosh']).to eq({'foo' => 'bar'})
      end

      it 'ignores non-supported agent.env properties' do
        expect(parsed_yaml['agent']['env']['abc']).to eq(nil)
      end

      it 'outputs the agent_wait_timeout' do
        expect(parsed_yaml['agent']['agent_wait_timeout']).to eq('some-timeout')
      end
    end

    context 'when configured to use a cpi_job' do
      before do
        merged_manifest_properties['director']['cpi_job'] = 'test-cpi'
      end

      it 'configures the cpi correctly' do
        expect(parsed_yaml['cloud']['provider']['name']).to eq('test-cpi')
        expect(parsed_yaml['cloud']['provider']['path']).to eq('/var/vcap/jobs/test-cpi/bin/cpi')
      end

      it 'configures agent env correctly' do
        expect(parsed_yaml['agent']['env']['bosh']).to_not eq(nil)
        expect(parsed_yaml['agent']['env']['bosh']).to eq({'foo' => 'bar'})
      end
    end

    describe 'parallel_problem_resolution property' do
      before do
        merged_manifest_properties['director']['cpi_job'] = 'test-cpi'
      end

      context 'when parallel_problem_resolution not specified' do
        it 'should be the default value' do
          expect(parsed_yaml['parallel_problem_resolution']).to eq(true)
        end
      end
      context 'when parallel_problem_resolution specified' do
        before do
          merged_manifest_properties['director']['parallel_problem_resolution'] = false
        end
        it 'should be the specified value' do
          expect(parsed_yaml['parallel_problem_resolution']).to eq(false)
        end
      end
    end
  end

  describe Bosh::Template::Test do
    subject(:parsed_yaml) do
      release = Bosh::Template::Test::ReleaseDir.new(File.join(File.dirname(__FILE__), '../'))
      job = release.job('director')
      template = job.template('config/director.yml')
      YAML.load(template.render(merged_manifest_properties))
    end

    it_behaves_like 'template rendering'
  end

  describe Bosh::Template::EvaluationContext do
    let(:erb_yaml) { File.read(File.join(File.dirname(__FILE__), '../jobs/director/templates/director.yml.erb')) }

    subject(:parsed_yaml) do
      binding = Bosh::Template::EvaluationContext.new(
        {
          'job' => {'name' => 'i_like_bosh'},
          'properties' => merged_manifest_properties
        }, nil).get_binding
      YAML.load(ERB.new(erb_yaml).result(binding))
    end

    it_behaves_like 'template rendering'
  end

  describe 'director' do
    describe 'nats_client_certificate.pem.erb' do
      it_should_behave_like 'a rendered file' do
        let(:file_name) { '../jobs/director/templates/nats_client_certificate.pem.erb' }
        let(:properties) do
          {
            'properties' => {
              'nats' => {
                'tls' => {
                  'director' => {
                    'certificate' => content
                  }
                }
              }
            }
          }
        end
      end
    end

    describe 'nats_client_private_key.erb' do
      it_should_behave_like 'a rendered file' do
        let(:file_name) { '../jobs/director/templates/nats_client_private_key.erb' }
        let(:properties) do
          {
            'properties' => {
              'nats' => {
                'tls' => {
                  'director' => {
                    'private_key' => content
                  }
                }
              }
            }
          }
        end
      end
    end

    describe 'db_ca.pem.erb' do
      it_should_behave_like 'a rendered file' do
        let(:file_name) { '../jobs/director/templates/db_ca.pem.erb' }
        let(:properties) do
          {
            'properties' => {
              'director' => {
                'db' => {
                  'tls' => {
                    'cert' => {
                      'ca' => content
                    }
                  }
                }
              }
            }
          }
        end
      end
    end

    context 'director.cpi.preferred_api_version' do
      subject(:parsed_yaml) do
        release = Bosh::Template::Test::ReleaseDir.new(File.join(File.dirname(__FILE__), '../'))
        job = release.job('director')
        template = job.template('config/director.yml')
        YAML.load(template.render(merged_manifest_properties))
      end

      let(:max_cpi_api_version) { 2 }

      before do
        merged_manifest_properties['director']['cpi_job'] = 'test-cpi'
      end

      it 'should have a max_cpi_api_version' do
        expect(parsed_yaml['cpi']['max_supported_api_version']).to eq(max_cpi_api_version)
      end

      context 'when preferred_api_version not specified' do
        it 'should be the default value' do
          expect(parsed_yaml['cpi']['preferred_api_version']).to eq(max_cpi_api_version)
        end
      end

      context 'when set to a specified version' do
        let(:preferred_api_version) { 1 }

        let(:cpi_config) do
          {
            'preferred_api_version' => preferred_api_version,
          }
        end

        before do
          merged_manifest_properties['director']['cpi'] = cpi_config
        end

        it 'should be the specified version' do
          expect(parsed_yaml['cpi']['preferred_api_version']).to eq(preferred_api_version)
        end

        context 'when preferred_api_version is greater than max_cpi_api_version' do
          let(:preferred_api_version) { max_cpi_api_version + 1 }
          it 'should raise an error' do
            expect do
              parsed_yaml
            end.to raise_error "Max supported api version is #{max_cpi_api_version} but got #{preferred_api_version}"
          end
        end

        context 'when preferred_api_version is less than 1' do
          let(:preferred_api_version) { 0 }
          it 'should raise an error' do
            expect do
              parsed_yaml
            end.to raise_error "Min supported api version is 1 but got #{preferred_api_version}"
          end
        end
      end
    end
  end

  describe 'client ca' do
    describe 'nats_client_ca_certificate.pem.erb' do
      it_should_behave_like 'a rendered file' do
        let(:file_name) { '../jobs/director/templates/nats_client_ca_certificate.pem.erb' }
        let(:properties) do
          {
            'properties' => {
              'nats' => {
                'tls' => {
                  'client_ca' => {
                    'certificate' => content
                  }
                }
              }
            }
          }
        end
      end
    end

    describe 'nats_client_ca_private_key.erb' do
      it_should_behave_like 'a rendered file' do
        let(:file_name) { '../jobs/director/templates/nats_client_ca_private_key.erb' }
        let(:properties) do
          {
            'properties' => {
              'nats' => {
                'tls' => {
                  'client_ca' => {
                    'private_key' => content
                  }
                }
              }
            }
          }
        end
      end
    end
  end
end
