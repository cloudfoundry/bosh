require 'rspec'
require 'yaml'
require 'bosh/template/evaluation_context'
require 'json'

describe 'nats.yml.erb' do
  let(:deployment_manifest_fragment) do
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
          'certificate' => 'some-cert-value',
          'private_key' => 'some-private-key'
        }
      }
    }
  end

  let(:erb_cfg) { File.read(File.join(File.dirname(__FILE__), '../jobs/nats/templates/nats.cfg.erb')) }

  subject(:parsed_cfg) do
    binding = Bosh::Template::EvaluationContext.new(deployment_manifest_fragment, nil).get_binding
    ERB.new(erb_cfg).result(binding)
  end

  let(:expected_cfg) do
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
        cert_file:  "/var/vcap/jobs/nats/config/nats_cert.pem"
        key_file:   "/var/vcap/jobs/nats/config/nats_key.key"
        ca_file:    "/var/vcap/jobs/nats/config/nats_ca.pem"
        verify:     true
        timeout:    2
      }

      ping_interval: 7
      ping_max: 10
    HEREDOC
  end

  context 'given a generally valid manifest' do
    it "should contain NATS's bare minimum" do
      expect(parsed_cfg).to eq(expected_cfg)
    end

  end
end
