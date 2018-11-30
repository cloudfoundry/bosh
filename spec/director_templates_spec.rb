require 'rspec'
require 'json'
require 'bosh/template/test'
require 'bosh/template/evaluation_context'
require 'openssl'
require_relative './template_example_group'

describe 'director templates' do
  describe 'director' do
    describe 'nats related templates' do
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

    describe 'database related templates' do
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

        context 'when cert property is not provided' do
          it_should_behave_like 'a rendered file' do
            let(:file_name) { '../jobs/director/templates/db_ca.pem.erb' }
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
          let(:file_name) { '../jobs/director/templates/db_client_certificate.pem.erb' }
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
            let(:file_name) { '../jobs/director/templates/db_client_certificate.pem.erb' }
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
          let(:file_name) { '../jobs/director/templates/db_client_private_key.key.erb' }
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
            let(:file_name) { '../jobs/director/templates/db_client_private_key.key.erb' }
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
      let(:release) { Bosh::Template::Test::ReleaseDir.new(File.join(File.dirname(__FILE__), '..')) }
      let(:job) { release.job('director') }
      let(:template) { job.template('config/director.yml') }
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

    # rubocop:disable Metrics/MethodLength
    describe 'certificate expiry template' do
      before do
        @key, @cert, @expiry = create_key_and_csr_cert
      end
      # rubocop:disable Metrics/BlockLength
      it_should_behave_like 'a rendered file' do
        let(:file_name) { '../jobs/director/templates/certificate_expiry.json.erb' }
        # rubocop:disable Metrics/BlockLength
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
      # rubocop:enable Metrics/BlockLength
      # rubocop:enable Metrics/MethodLength
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
  csr.sign key, OpenSSL::Digest::SHA1.new

  csr
end

def new_csr_certificate(key, csr)
  csr_cert = OpenSSL::X509::Certificate.new
  csr_cert.serial = 0
  csr_cert.version = 2
  csr_cert.not_before = Time.now - 60 * 60 * 24
  csr_cert.not_after = Time.now + 94608000

  csr_cert.subject = csr.subject
  csr_cert.public_key = csr.public_key
  csr_cert.issuer = csr.subject

  csr_cert.sign key, OpenSSL::Digest::SHA1.new

  csr_cert
end
