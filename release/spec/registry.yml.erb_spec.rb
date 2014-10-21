require 'rspec'
require 'yaml'
require 'bosh/template/evaluation_context'
require 'json'

describe 'registry.yml.erb' do
  let(:deployment_manifest_fragment) do
    {
      'properties' => {
        'registry' => {
          'http' => {
              'port' => 80,
              'user' => 'user',
              'password' => 'password'
          },

          'db' => {
            'adapter' => 'mysql2',
            'user' => 'ub45391e00',
            'password' => 'p4cd567d84d0e012e9258d2da30',
            'host' => 'bosh.hamazonhws.com',
            'port' => 3306,
            'database' => 'bosh',
            'connection_options' => {},
          },
        }
      }
    }
  end

  let(:erb_yaml) { File.read(File.join(File.dirname(__FILE__), '../jobs/registry/templates/registry.yml.erb')) }

  subject(:parsed_yaml) do
    binding = Bosh::Template::EvaluationContext.new(deployment_manifest_fragment).get_binding
    YAML.load(ERB.new(erb_yaml).result(binding))
  end

  context 'aws' do
    before do
      deployment_manifest_fragment['properties']['aws'] = {
        'access_key_id' => 'key',
        'secret_access_key' => 'secret',
        'region' => 'region',
        'ec2_endpoint' => 'some_ec2_endpoint',
        'elb_endpoint' => 'some_elb_endpoint',
        'max_retries' => 10
      }
    end

    it 'sets plugin to aws' do
      expect(parsed_yaml['cloud']).to include({
        'plugin' => 'aws'
      })
    end

    it 'renders aws properties' do
      expect(parsed_yaml['cloud']['aws']).to eq({
        'access_key_id' => 'key',
        'secret_access_key' => 'secret',
        'region' => 'region',
        'ec2_endpoint' => 'some_ec2_endpoint',
        'elb_endpoint' => 'some_elb_endpoint',
        'max_retries' => 10
      })
    end
  end

end