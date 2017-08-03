require 'rspec'
require 'yaml'
require 'bosh/template/evaluation_context'
require 'json'

describe 'nats.cfg.erb' do
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
          user: "my-user"
          password: "my-password"
          timeout: 10
        }

        tls {
          cert_file:  "/var/vcap/jobs/nats/config/nats_server_certificate.pem"
          key_file:   "/var/vcap/jobs/nats/config/nats_server_private_key"
          ca_file:    "/var/vcap/jobs/nats/config/nats_client_ca.pem"
          verify:     true
          timeout:    2
        }

        ping_interval: 7
        ping_max: 10
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