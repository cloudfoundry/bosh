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

    describe 'config/bpm.yml' do
      let(:template) { job.template('config/bpm.yml') }
      let(:rendered) { YAML.safe_load(template.render(properties)) }

      let(:enable_dedicated_status_worker) { false }
      let(:workers) { 3 }
      let(:dynamic_disks_workers) { 0 }
      let(:properties) do
        properties = default_properties.dup
        properties['director']['workers'] = workers
        properties['director']['enable_dedicated_status_worker'] = enable_dedicated_status_worker
        properties['director']['dynamic_disks_workers'] = dynamic_disks_workers
        properties
      end

      def worker_process(rendered, name)
        rendered['processes'].find { |p| p['name'] == name }
      end

      it 'generates no worker processes by default' do
        worker_names = rendered['processes'].map { |p| p['name'] }.grep(/\Aworker_\d+\z/)
        expect(worker_names).to be_empty
        dd_names = rendered['processes'].map { |p| p['name'] }.grep(/\Adynamic_disks_worker_/)
        expect(dd_names).to be_empty
      end

      context 'when use_bpm_for_workers is true' do
        let(:properties) do
          properties = default_properties.dup
          properties['director']['workers'] = workers
          properties['director']['enable_dedicated_status_worker'] = enable_dedicated_status_worker
          properties['director']['dynamic_disks_workers'] = dynamic_disks_workers
          properties['director']['use_bpm_for_workers'] = true
          properties
        end

        it 'generates one BPM worker process per director.workers' do
          worker_names = rendered['processes'].map { |p| p['name'] }.grep(/\Aworker_\d+\z/)
          expect(worker_names).to eq(%w[worker_1 worker_2 worker_3])
        end

        it 'assigns QUEUE=normal,urgent to all workers by default' do
          (1..3).each do |i|
            expect(worker_process(rendered, "worker_#{i}")['env']['QUEUE']).to eq('normal,urgent')
          end
        end

        context 'with enable_dedicated_status_worker' do
          let(:enable_dedicated_status_worker) { true }

          it 'assigns QUEUE=urgent to worker_1' do
            expect(worker_process(rendered, 'worker_1')['env']['QUEUE']).to eq('urgent')
          end

          it 'assigns QUEUE=normal,urgent to remaining workers' do
            (2..3).each do |i|
              expect(worker_process(rendered, "worker_#{i}")['env']['QUEUE']).to eq('normal,urgent')
            end
          end
        end

        it 'runs workers via bin/worker with worker name as argument' do
          proc = worker_process(rendered, 'worker_1')
          expect(proc['executable']).to eq('/var/vcap/jobs/director/bin/worker')
          expect(proc['args']).to eq(['worker_1'])
        end

        it 'mounts ephemeral and persistent disk for workers' do
          proc = worker_process(rendered, 'worker_1')
          expect(proc['ephemeral_disk']).to eq(true)
          expect(proc['persistent_disk']).to eq(true)
        end

        it 'generates no dynamic_disks_worker processes when dynamic_disks_workers is 0' do
          dd_names = rendered['processes'].map { |p| p['name'] }.grep(/\Adynamic_disks_worker_/)
          expect(dd_names).to be_empty
        end

        context 'with dynamic_disks_workers' do
          let(:dynamic_disks_workers) { 2 }

          it 'generates dynamic_disks_worker processes' do
            dd_names = rendered['processes'].map { |p| p['name'] }.grep(/\Adynamic_disks_worker_/)
            expect(dd_names).to eq(%w[dynamic_disks_worker_1 dynamic_disks_worker_2])
          end

          it 'assigns QUEUE=dynamic_disks to dynamic_disks_worker processes' do
            [1, 2].each do |i|
              expect(worker_process(rendered, "dynamic_disks_worker_#{i}")['env']['QUEUE']).to eq('dynamic_disks')
            end
          end

          it 'runs dynamic_disks_workers via bin/worker with worker name as argument' do
            proc = worker_process(rendered, 'dynamic_disks_worker_1')
            expect(proc['executable']).to eq('/var/vcap/jobs/director/bin/worker')
            expect(proc['args']).to eq(['dynamic_disks_worker_1'])
          end
        end

        context 'with a cpi_job configured' do
          it 'mounts the CPI job directory with allow_executions in worker processes' do
            (1..3).each do |i|
              vols = worker_process(rendered, "worker_#{i}").dig('unsafe', 'unrestricted_volumes')
              expect(vols).to include({'path' => '/var/vcap/jobs/fake-cpi', 'allow_executions' => true})
            end
          end

          it 'does not mount the CPI job directory in the director process' do
            director_proc = rendered['processes'].find { |p| p['name'] == 'director' }
            vols = director_proc.dig('unsafe', 'unrestricted_volumes') || []
            expect(vols).not_to include(include('path' => '/var/vcap/jobs/fake-cpi'))
          end

          context 'with cpi_additional_volumes' do
            let(:properties) do
              props = default_properties.dup
              props['director'] = default_properties['director'].merge(
                'workers' => workers,
                'enable_dedicated_status_worker' => enable_dedicated_status_worker,
                'dynamic_disks_workers' => dynamic_disks_workers,
                'use_bpm_for_workers' => true,
                'cpi_additional_volumes' => [{'path' => '/var/run/docker.sock', 'mount_only' => true}],
              )
              props
            end

            it 'appends cpi_additional_volumes to worker unrestricted_volumes' do
              (1..3).each do |i|
                vols = worker_process(rendered, "worker_#{i}").dig('unsafe', 'unrestricted_volumes')
                expect(vols).to include({'path' => '/var/vcap/jobs/fake-cpi', 'allow_executions' => true})
                expect(vols).to include({'path' => '/var/run/docker.sock', 'mount_only' => true})
              end
            end

            it 'does not add cpi_additional_volumes to the director process' do
              director_proc = rendered['processes'].find { |p| p['name'] == 'director' }
              vols = director_proc.dig('unsafe', 'unrestricted_volumes') || []
              expect(vols).not_to include(include('path' => '/var/run/docker.sock'))
            end
          end
        end

        context 'without a cpi_job configured' do
          let(:properties) do
            props = default_properties.dup
            props['director'] = default_properties['director'].merge(
              'workers' => workers,
              'enable_dedicated_status_worker' => enable_dedicated_status_worker,
              'dynamic_disks_workers' => dynamic_disks_workers,
              'use_bpm_for_workers' => true,
              'cpi_job' => '',
            )
            props
          end

          it 'does not add unrestricted_volumes to worker processes' do
            (1..3).each do |i|
              proc = worker_process(rendered, "worker_#{i}")
              expect(proc['unsafe']).to be_nil
            end
          end
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
