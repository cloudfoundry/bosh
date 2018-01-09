require 'rspec'
require 'bosh/template/evaluation_context'
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
  end
end
