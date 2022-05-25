# frozen_string_literal: true

require 'rspec'
require 'yaml'
require 'json'
require 'bosh/template/evaluation_context'
require_relative './template_example_group'

describe 'bosh_nats_sync_config.yml.erb' do
  it_should_behave_like 'a rendered file' do
    let(:file_name) { '../jobs/nats/templates/bosh_nats_sync_config.yml.erb' }
    let(:properties) do
      {
        'properties' => {
          'director' => {
            'address' => '10.9.9.20',
            'port' => '25555'
          },
          'nats' => {
            'director_account' => {
              'client_id' => 'my-client',
              'client_secret' => 'my-client-secret',
              'user' => 'my-user',
              'password' => 'my-password'
            },
          },
          'nats-sync' => {
            'intervals' => {
              'poll_user_sync' => "sync-me",
            }
          }
        }
      }
    end
    let(:expected_content) do
      <<~HEREDOC
        ---
        director:
          url: https://10.9.9.20:25555
          user: my-user
          password: my-password
          client_id: my-client
          client_secret: my-client-secret
          ca_cert: "/var/vcap/jobs/nats/config/uaa.pem"
          director_subject_file: "/var/vcap/data/nats/director-subject"
          hm_subject_file: "/var/vcap/data/nats/hm-subject"
        intervals:
          poll_user_sync: sync-me
        nats:
          config_file_path: "/var/vcap/data/nats/auth.json"
        logfile: "/var/vcap/sys/log/nats/bosh-nats-sync.log"


      HEREDOC
    end
  end
end

describe 'nats.cfg.erb' do
  it_should_behave_like 'a rendered file' do
    let(:file_name) { '../jobs/nats/templates/nats.cfg.erb' }
    let(:properties) do
      {
        'properties' => {
          'nats' => {
            'listen_address' => '1.2.3.4',
            'port' => 4222,
            'enable_metrics_endpoint' => true,
            'ping_interval' => 7,
            'ping_max_outstanding' => 10,
            'auth_timeout' => 10,
            'tls' => {
              'timeout' => 10,
            },
            'max_payload_mb' => '1.5',
          }
        }
      }
    end
    let(:expected_content) do
      <<~HEREDOC
        net: 1.2.3.4
        port: 4222

        http: localhost:8222

        logtime: true

        log_file: /var/vcap/sys/log/nats/nats.log

        authorization {
          users = [
            {
              user: "C=USA, O=Cloud Foundry, CN=default.director.bosh-internal"
              permissions: {
                publish: [ "agent.*", "hm.director.alert" ]
                subscribe: [ "director.>" ]
              }
            },
            {
              user: "C=USA, O=Cloud Foundry, CN=default.hm.bosh-internal"
              permissions: {
                publish: []
                subscribe: [
                  "hm.agent.heartbeat.*",
                  "hm.agent.alert.*",
                  "hm.agent.shutdown.*",
                  "hm.director.alert"
               ]
              }
            }
          ]
        }

        tls {
          cert_file:          "/var/vcap/jobs/nats/config/nats_server_certificate.pem"
          key_file:           "/var/vcap/jobs/nats/config/nats_server_private_key"
          ca_file:            "/var/vcap/jobs/nats/config/nats_client_ca.pem"
          verify_and_map:     true
          timeout:            10
        }

        ping_interval: 7
        ping_max: 10
        max_payload: 1572864

        include ../../../data/nats/auth.json
      HEREDOC
    end
  end
end

describe 'nats_client_ca.pem.erb' do
  it_should_behave_like 'a rendered file' do
    let(:file_name) { '../jobs/nats/templates/nats_client_ca.pem.erb' }
    let(:properties) do
      {
        'properties' => {
          'nats' => {
            'tls' => {
              'ca' => content
            }
          }
        }
      }
    end
  end
end

describe 'nats_director_client_certificate.pem.erb' do
  it_should_behave_like 'a rendered file' do
    let(:file_name) { '../jobs/nats/templates/nats_director_client_certificate.pem.erb' }
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

describe 'nats_hm_client_certificate.pem.erb' do
  it_should_behave_like 'a rendered file' do
    let(:file_name) { '../jobs/nats/templates/nats_hm_client_certificate.pem.erb' }
    let(:properties) do
      {
        'properties' => {
          'nats' => {
            'tls' => {
              'health_monitor' => {
                'certificate' => content
              }
            }
          }
        }
      }
    end
  end
end

describe 'nats_server_certificate.pem.erb' do
  it_should_behave_like 'a rendered file' do
    let(:file_name) { '../jobs/nats/templates/nats_server_certificate.pem.erb' }
    let(:properties) do
      {
        'properties' => {
          'nats' => {
            'tls' => {
              'server' => {
                'certificate' => content
              }
            }
          }
        }
      }
    end
  end
end

describe 'nats_server_private_key.erb' do
  it_should_behave_like 'a rendered file' do
    let(:file_name) { '../jobs/nats/templates/nats_server_private_key.erb' }
    let(:properties) do
      {
        'properties' => {
          'nats' => {
            'tls' => {
              'server' => {
                'private_key' => content
              }
            }
          }
        }
      }
    end
  end
end
