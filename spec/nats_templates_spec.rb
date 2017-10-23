require 'rspec'
require 'yaml'
require 'json'
require 'bosh/template/evaluation_context'
require_relative './template_example_group'

describe 'nats.cfg.erb' do
  context 'allow_legacy_agents is true' do
    it_should_behave_like 'a rendered file' do
      let(:file_name) { '../jobs/nats/templates/nats.cfg.erb' }
      let(:properties) do
        {
          'properties' => {
            'nats' => {
              'listen_address' => '1.2.3.4',
              'port' => 4222,
              'ping_interval' => 7,
              'ping_max_outstanding' => 10,
              'user' => 'my-user',
              'password' => 'my-password',
              'auth_timeout' => 10,
              'allow_legacy_agents' => true,
              'tls' => {
                'timeout' => 10
              }
            }
          }
        }
      end
      let(:expected_content) do
        <<~HEREDOC
          net: 1.2.3.4
          port: 4222

          logtime: true

          pid_file: /var/vcap/sys/run/nats/nats.pid
          log_file: /var/vcap/sys/log/nats/nats.log

          authorization {
            username: "my-user"
            password: "my-password"

            DIRECTOR_PERMISSIONS: {
              publish: [
                "agent.*",
                "hm.director.alert"
              ]
              subscribe: ["director.>"]
            }

            AGENT_PERMISSIONS: {
              publish: [
                "hm.agent.heartbeat._CLIENT_ID",
                "hm.agent.alert._CLIENT_ID",
                "hm.agent.shutdown._CLIENT_ID",
                "director.*._CLIENT_ID.*"
              ]
              subscribe: ["agent._CLIENT_ID"]
            }

            HM_PERMISSIONS: {
              publish: []
              subscribe: [
                "hm.agent.heartbeat.*",
                "hm.agent.alert.*",
                "hm.agent.shutdown.*",
                "hm.director.alert"
              ]
            }

            certificate_clients: [
              {client_name: director.bosh-internal, permissions: $DIRECTOR_PERMISSIONS},
              {client_name: agent.bosh-internal, permissions: $AGENT_PERMISSIONS},
              {client_name: hm.bosh-internal, permissions: $HM_PERMISSIONS},
            ]

            timeout: 10
          }

          tls {
            cert_file:  "/var/vcap/jobs/nats/config/nats_server_certificate.pem"
            key_file:   "/var/vcap/jobs/nats/config/nats_server_private_key"
            ca_file:    "/var/vcap/jobs/nats/config/nats_client_ca.pem"
            verify:     true
            timeout:    10
            enable_cert_authorization: true
            allow_legacy_clients: true
          }

          ping_interval: 7
          ping_max: 10
        HEREDOC
      end
    end
  end

  context 'allow_legacy_agents is false' do
    it_should_behave_like 'a rendered file' do
      let(:file_name) { '../jobs/nats/templates/nats.cfg.erb' }
      let(:properties) do
        {
          'properties' => {
            'nats' => {
              'listen_address' => '1.2.3.4',
              'port' => 4222,
              'ping_interval' => 7,
              'ping_max_outstanding' => 10,
              'auth_timeout' => 10,
              'allow_legacy_agents' => false,
              'tls' => {
                'timeout' => 10
              }
            }
          }
        }
      end
      let(:expected_content) do
        <<~HEREDOC
          net: 1.2.3.4
          port: 4222

          logtime: true

          pid_file: /var/vcap/sys/run/nats/nats.pid
          log_file: /var/vcap/sys/log/nats/nats.log

          authorization {

            DIRECTOR_PERMISSIONS: {
              publish: [
                "agent.*",
                "hm.director.alert"
              ]
              subscribe: ["director.>"]
            }

            AGENT_PERMISSIONS: {
              publish: [
                "hm.agent.heartbeat._CLIENT_ID",
                "hm.agent.alert._CLIENT_ID",
                "hm.agent.shutdown._CLIENT_ID",
                "director.*._CLIENT_ID.*"
              ]
              subscribe: ["agent._CLIENT_ID"]
            }

            HM_PERMISSIONS: {
              publish: []
              subscribe: [
                "hm.agent.heartbeat.*",
                "hm.agent.alert.*",
                "hm.agent.shutdown.*",
                "hm.director.alert"
              ]
            }

            certificate_clients: [
              {client_name: director.bosh-internal, permissions: $DIRECTOR_PERMISSIONS},
              {client_name: agent.bosh-internal, permissions: $AGENT_PERMISSIONS},
              {client_name: hm.bosh-internal, permissions: $HM_PERMISSIONS},
            ]

            timeout: 10
          }

          tls {
            cert_file:  "/var/vcap/jobs/nats/config/nats_server_certificate.pem"
            key_file:   "/var/vcap/jobs/nats/config/nats_server_private_key"
            ca_file:    "/var/vcap/jobs/nats/config/nats_client_ca.pem"
            verify:     true
            timeout:    10
            enable_cert_authorization: true
            allow_legacy_clients: false
          }

          ping_interval: 7
          ping_max: 10
        HEREDOC
      end
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
