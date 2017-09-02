require 'rspec'
require 'yaml'
require 'bosh/template/evaluation_context'
require 'json'

describe 'nats.yml.erb' do
  let(:deployment_manifest_fragment) do
    {
      'properties' => {
        'nats' => {
          'listen_address' => '0.0.0.0',
          'port' => 4222,
          'no_epoll' => false,
          'no_kqueue' => false,
          'ping_interval' => 5,
          'ping_max_outstanding' => 10,
          'user' => 'my-user',
          'password' => 'my-password',
          'auth_timeout' => 10,
        }
      }
    }
  end

  let(:erb_yaml) { File.read(File.join(File.dirname(__FILE__), '../jobs/nats/templates/nats.yml.erb')) }

  subject(:parsed_yaml) do
    binding = Bosh::Template::EvaluationContext.new(deployment_manifest_fragment, nil).get_binding
    YAML.load(ERB.new(erb_yaml).result(binding))
  end

  context 'given a generally valid manifest' do
    it "should contain NATS's bare minimum" do
      expect(parsed_yaml['net']).to eq('0.0.0.0')
      expect(parsed_yaml['port']).to eq(4222)
      expect(parsed_yaml['logtime']).to satisfy { |v| v == true || v == false }
      expect(parsed_yaml['no_epoll']).to eq(false)
      expect(parsed_yaml['no_kqueue']).to eq(false)
      expect(parsed_yaml['ping']['interval']).to eq(5)
      expect(parsed_yaml['ping']['max_outstanding']).to eq(10)
      expect(parsed_yaml['pid_file']).to be_a(String)
      expect(parsed_yaml['log_file']).to be_a(String)
      expect(parsed_yaml['authorization']['user']).to eq('my-user')
      expect(parsed_yaml['authorization']['password']).to eq('my-password')
      expect(parsed_yaml['authorization']['timeout']).to eq(10)
      expect(parsed_yaml.has_key?('http')).to eq(false)
    end

    context "When NATS's HTTP interface is specified" do
      before do
        deployment_manifest_fragment['properties']['nats']['http'] = {
          'port' => 8081,
          'user' => 'http-user',
          'password' => 'http-password',
        }
      end

      it 'should template the appropriate parameters' do
        expect(parsed_yaml['http']['port']).to eq(8081)
        expect(parsed_yaml['http']['user']).to eq('http-user')
        expect(parsed_yaml['http']['password']).to eq('http-password')
      end
    end
  end
end
