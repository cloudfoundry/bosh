require 'spec_helper'

RSpec.describe 'director templates' do
  let(:release) { Bosh::Common::Template::Test::ReleaseDir.new(RELEASE_ROOT) }
  let(:job) { release.job('director') }
  let(:properties) { default_properties }
  let(:default_properties) do
    {
      'blobstore' => {
        'address' => '127.0.0.1',
        'director' => {
          'user' => 'fake-director',
          'password' => 'fake-director-password',
        },
        'tls' => {
          'cert' => {
            'ca' => 'fake-ca',
          },
        },
      },
      'director' => {
        'cpi_job' => 'fake-cpi',
        'db' => {
          'password' => 'fake-password',
        },
        'name' => 'test',
      },
      'nats' => {
        'address' => '127.0.0.1',
      },
    }
  end

  describe 'director' do
    describe 'nats related templates' do
      describe 'nats_client_certificate.pem.erb' do
        it_should_behave_like 'a rendered file' do
          let(:file_name) { 'jobs/director/templates/nats_client_certificate.pem.erb' }
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
          let(:file_name) { 'jobs/director/templates/nats_client_private_key.erb' }
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

      describe 'nats_client_ca_certificate.pem.erb' do
        it_should_behave_like 'a rendered file' do
          let(:file_name) { 'jobs/director/templates/nats_client_ca_certificate.pem.erb' }
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
          let(:file_name) { 'jobs/director/templates/nats_client_ca_private_key.erb' }
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

    describe 'database related templates' do
      describe 'db_ca.pem.erb' do
        it_should_behave_like 'a rendered file' do
          let(:file_name) { 'jobs/director/templates/db_ca.pem.erb' }
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

        context 'when cert property is not provided' do
          it_should_behave_like 'a rendered file' do
            let(:file_name) { 'jobs/director/templates/db_ca.pem.erb' }
            let(:expected_content) { "\n" }
            let(:properties) do
              {
                'properties' => {
                  'director' => {
                    'db' => {
                      'tls' => {
                        'cert' => {}
                      }
                    }
                  }
                }
              }
            end
          end
        end
      end

      describe 'db_client_certificate.pem.erb' do
        it_should_behave_like 'a rendered file' do
          let(:file_name) { 'jobs/director/templates/db_client_certificate.pem.erb' }
          let(:properties) do
            {
              'properties' => {
                'director' => {
                  'db' => {
                    'tls' => {
                      'cert' => {
                        'certificate' => content
                      }
                    }
                  }
                }
              }
            }
          end
        end

        context 'when certificate property is not provided' do
          it_should_behave_like 'a rendered file' do
            let(:file_name) { 'jobs/director/templates/db_client_certificate.pem.erb' }
            let(:expected_content) { "\n" }
            let(:properties) do
              {
                'properties' => {
                  'director' => {
                    'db' => {
                      'tls' => {
                        'cert' => {}
                      }
                    }
                  }
                }
              }
            end
          end
        end
      end

      describe 'db_client_private_key.pem.erb' do
        it_should_behave_like 'a rendered file' do
          let(:file_name) { 'jobs/director/templates/db_client_private_key.key.erb' }
          let(:properties) do
            {
              'properties' => {
                'director' => {
                  'db' => {
                    'tls' => {
                      'cert' => {
                        'private_key' => content
                      }
                    }
                  }
                }
              }
            }
          end
        end

        context 'when private_key property is not provided' do
          it_should_behave_like 'a rendered file' do
            let(:file_name) { 'jobs/director/templates/db_client_private_key.key.erb' }
            let(:expected_content) { "\n" }
            let(:properties) do
              {
                'properties' => {
                  'director' => {
                    'db' => {
                      'tls' => {
                        'cert' => {}
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

    describe 'scheduled jobs' do
      let(:template) { job.template('config/director.yml') }
      let(:rendered) { YAML.safe_load(template.render(properties)) }

      context 'scheduled orphan VM job' do
        it 'defaults to 5 min' do
          expect(rendered['scheduled_jobs']).to include(
            'command' => 'ScheduledOrphanedVMCleanup',
            'schedule' => '*/5 * * * * UTC',
          )
        end

        context 'given a configured schedule' do
          let(:properties) do
            properties = default_properties
            properties['director']['vms'] = {
              'cleanup_schedule' => '*/15 * * * *',
            }
            properties
          end

          it 'respects the configured schedule' do
            expect(rendered['scheduled_jobs']).to include(
              'command' => 'ScheduledOrphanedVMCleanup',
              'schedule' => '*/15 * * * *',
            )
          end
        end
      end
    end

    describe 'bin/drain' do
      let(:template) { job.template('bin/drain') }
      let(:rendered_template) { template.render(properties) }

      let(:enable_dedicated_status_worker) { false }
      let(:dynamic_disks_workers) { 0 }
      let(:properties) do
        properties = default_properties.dup
        properties['director']['enable_dedicated_status_worker'] = enable_dedicated_status_worker
        properties['director']['dynamic_disks_workers'] = dynamic_disks_workers
        properties
      end

      it 'renders to drain all jobs' do
        expect(rendered_template).to match(/.+stop_worker worker_1.+stop_worker worker_2.+stop_worker worker_3/m)
        expect(rendered_template).to include('bosh-director-drain-workers -c /var/vcap/jobs/director/config/director.yml')
        expect(rendered_template).to_not include('--queue normal')
        expect(rendered_template).to_not include('--queue dynamic_disks')
      end

      context 'dynamic disks workers' do
        let(:dynamic_disks_workers) { 2 }

        it 'renders to drain all jobs' do
          expect(rendered_template).to match(/.+stop_worker worker_2.+stop_worker worker_3.+.+stop_worker dynamic_disks_worker_1.+stop_worker dynamic_disks_worker_2/m)

          expect(rendered_template).to include('bosh-director-drain-workers -c /var/vcap/jobs/director/config/director.yml')
          expect(rendered_template).to_not include('--queue normal')
          expect(rendered_template).to_not include('--queue dynamic_disks')
        end
      end

      context 'dedicated status workers' do
        let(:enable_dedicated_status_worker) { true }

        it 'renders to drain normal jobs and then the rest' do
          expect(rendered_template).to match(/.+stop_worker worker_2.+stop_worker worker_3.+stop_dedicated_worker worker_1/m)

          expect(rendered_template).to include('bosh-director-drain-workers -c /var/vcap/jobs/director/config/director.yml --queue normal')
          expect(rendered_template).to_not include('bosh-director-drain-workers -c /var/vcap/jobs/director/config/director.yml --queue dynamic_disks')
        end

        context 'dynamic disks workers' do
          let(:dynamic_disks_workers) { 2 }

          it 'renders to drain normal jobs, then dynamic_disks jobs and then the rest' do
            expect(rendered_template).to match(/.+stop_worker worker_2.+stop_worker worker_3.+.+stop_worker dynamic_disks_worker_1.+stop_worker dynamic_disks_worker_2.+stop_dedicated_worker worker_1/m)

            expect(rendered_template).to include('bosh-director-drain-workers -c /var/vcap/jobs/director/config/director.yml --queue normal')
            expect(rendered_template).to include('bosh-director-drain-workers -c /var/vcap/jobs/director/config/director.yml --queue dynamic_disks')
          end
        end
      end
    end

    describe 'bbr_config.json' do
      let(:template) { job.template('config/bbr.json') }

      it 'renders' do
        bbr_config = JSON.parse(template.render(properties))
        expect(bbr_config['adapter']).to eq('postgres')
        expect(bbr_config['username']).to eq('bosh')
        expect(bbr_config['password']).to eq('fake-password')
        expect(bbr_config['host']).to eq('127.0.0.1')
        expect(bbr_config['port']).to eq(5432)
        expect(bbr_config['database']).to eq('bosh')
        expect(bbr_config.key?('tls')).to eq(false)
      end

      context 'with the mysql2 adapter' do
        let(:properties) do
          default_properties.merge(
            'director' => {
              'db' => {
                'adapter' => 'mysql2',
                'user' => 'bosh',
                'password' => 'fake-password',
                'host' => '127.0.0.1',
                'port' => 1234,
                'database' => 'bosh',
              },
            },
          )
        end

        it 'converts the adapter to `mysql`' do
          bbr_config = JSON.parse(template.render(properties))
          expect(bbr_config['adapter']).to eq('mysql')
        end
      end

      context 'with tls enabled' do
        let(:properties) do
          default_properties.merge(
            'director' => {
              'db' => {
                'user' => 'bosh',
                'password' => 'fake-password',
                'host' => '127.0.0.1',
                'port' => 1234,
                'database' => 'bosh',
                'tls' => {
                  'enabled' => true,
                  'skip_host_verify' => true,
                  'cert' => {
                    'ca' => 'ca-certificate',
                    'certificate' => 'certificate',
                    'private_key' => 'private_key',
                  },
                },
              },
            },
          )
        end

        it 'correctly renders tls configuration' do
          bbr_config = JSON.parse(template.render(properties))
          expect(bbr_config['adapter']).to eq('postgres')
          expect(bbr_config['username']).to eq('bosh')
          expect(bbr_config['password']).to eq('fake-password')
          expect(bbr_config['host']).to eq('127.0.0.1')
          expect(bbr_config['port']).to eq(1234)
          expect(bbr_config['database']).to eq('bosh')
          expect(bbr_config['tls']['cert']['ca']).to eq('ca-certificate')
          expect(bbr_config['tls']['cert']['certificate']).to eq('certificate')
          expect(bbr_config['tls']['cert']['private_key']).to eq('private_key')
          expect(bbr_config['tls']['skip_host_verify']).to eq(true)
        end
      end
    end

    describe 'certificate expiry template' do
      before do
        @key, @cert, @expiry = create_key_and_csr_cert
      end

      it_should_behave_like 'a rendered file' do
        let(:file_name) { 'jobs/director/templates/certificate_expiry.json.erb' }
        let(:properties) do
          {
            'properties' => {
              'director' => {
                'ssl' => {
                  'cert' => @cert,
                },
                'db' => {
                  'tls' => {
                    'cert' => {
                      'ca' => @cert,
                      'certificate' => nil,
                    },
                  },
                },
                'config_server' => {
                  'ca_cert' => nil,
                  'uaa' => {
                    'ca_cert' => @cert,
                  },
                },
              },
              'nats' => {
                'tls' => {
                  'ca' => nil,
                  'client_ca' => {
                    'certificate' => @cert,
                  },
                  'director' => {
                    'certificate' => @cert,
                  },
                },
              },
              'blobstore' => {
                'tls' => {
                  'cert' => {
                    'ca' => @cert,
                  },
                },
              },
            },
          }
        end

        let(:expected_content) do
          <<~JSON
            {
              "director.ssl.cert": "#{@expiry.utc.iso8601}",
              "blobstore.tls.cert.ca": "#{@expiry.utc.iso8601}",
              "director.config_server.ca_cert": "0",
              "director.config_server.uaa.ca_cert": "#{@expiry.utc.iso8601}",
              "nats.tls.ca": "0",
              "nats.tls.client_ca.certificate": "#{@expiry.utc.iso8601}",
              "nats.tls.director.certificate": "#{@expiry.utc.iso8601}",
              "director.db.tls.cert.ca": "#{@expiry.utc.iso8601}",
              "director.db.tls.cert.certificate": "0"
            }
          JSON
        end
      end
    end

    describe 'worker_ctl' do
      let(:template) { job.template('bin/worker_ctl') }
      let(:rendered_template) { template.render(properties) }

      let(:enable_dedicated_status_worker) { false }
      let(:properties) do
        properties = default_properties.dup
        properties['director']['enable_dedicated_status_worker'] = enable_dedicated_status_worker
        properties
      end

      it 'renders' do
        expect(rendered_template).to include('export QUEUE="${3:-normal,urgent}"')
      end

      context 'dedicated status workers' do
        let(:enable_dedicated_status_worker) { true }

        it 'renders' do
          expect(rendered_template).to include('export QUEUE="urgent"')
        end
      end
    end
  end
end

def create_key_and_csr_cert
  subject = OpenSSL::X509::Name.parse('/O=Cloud Foundry/CN=Sample Certificate')
  key = OpenSSL::PKey::RSA.new(2048)
  csr = new_csr(key, subject)
  csr_cert = new_csr_certificate(key, csr)

  [key.to_pem, csr_cert.to_pem, csr_cert.not_after]
end

def new_csr(key, subject)
  csr = OpenSSL::X509::Request.new
  csr.version = 0
  csr.subject = subject
  csr.public_key = key.public_key
  csr.sign key, OpenSSL::Digest.new('SHA1')

  csr
end

def new_csr_certificate(key, csr)
  csr_cert = OpenSSL::X509::Certificate.new
  csr_cert.serial = 0
  csr_cert.version = 2
  csr_cert.not_before = Time.now - 60 * 60 * 24
  csr_cert.not_after = Time.now + 94_608_000

  csr_cert.subject = csr.subject
  csr_cert.public_key = csr.public_key
  csr_cert.issuer = csr.subject

  csr_cert.sign key, OpenSSL::Digest.new('SHA1')

  csr_cert
end
