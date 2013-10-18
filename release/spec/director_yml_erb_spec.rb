require 'rspec'
require 'yaml'
require 'common/properties'
require 'json'

describe 'director.yml.erb' do
  context 'when vcenter.password is alphanumeric' do
    it 'renders vcenter password correctly' do
      erb_yaml_path = File.join(File.dirname(__FILE__), '../jobs/director/templates/director.yml.erb')

      erb_yaml = File.read(erb_yaml_path)

      gigantic_hash = {
        'properties' =>
          {
            'ntp' => [
              '0.north-america.pool.ntp.org',
              '1.north-america.pool.ntp.org',
            ],
            'blobstore' => {
              'address' => '10.10.0.7',
              'port' => 25251,
              'agent' => { 'user' => 'agent', 'password' => '75d1605f59b60' },
              'director' => {
                'user' => 'user',
                'password' => 'password'
              },
              'provider' => 'dav',
            },
            'nats' => {
              'user' => 'nats',
              'password' => '1a0312a24c0a0',
              'address' => '10.10.0.7',
              'port' => 4222
            },
            'redis' => {
              'address' => '127.0.0.1', 'port' => 25255, 'password' => 'R3d!S',
              'loglevel' => 'info',
            },
            'director' => {
              'name' => 'vpc-bosh-idora',
              'backend_port' => 25556,
              'encryption' => false,
              'max_tasks' => 500,
              'max_threads' => 32,
              'enable_snapshots' => true,
              'db' => {
                'adapter' => 'mysql2',
                'user' => 'ub45391e00',
                'password' => 'p4cd567d84d0e012e9258d2da30',
                'host' => 'bosh.hamazonhws.com',
                'port' => 3306,
                'database' => 'bosh',
                'connection_options' => {},
              },
              'auto_fix_stateful_nodes' => true
            },
            'vcenter' => {
              'address' => 'vcenter.address',
              'user' => 'user',
              'password' => 'vcenter.password',
              'datacenters' => [
                {
                  'name' => 'vcenter.datacenters.first.name',
                  'clusters' => ['cluster1']
                },
              ],
            },
          }

      }

      rendered_yaml = ERB.new(erb_yaml).result(Bosh::Common::TemplateEvaluationContext.new(gigantic_hash).get_binding)

      parsed = YAML.load(rendered_yaml)

      expect(parsed['cloud']['properties']['vcenters'][0]['password']).to eq('vcenter.password')
    end
  end

  context 'when vcenter.password begins with a bang' do
    it 'renders vcenter password correctly' do
      erb_yaml_path = File.join(File.dirname(__FILE__), '../jobs/director/templates/director.yml.erb')

      erb_yaml = File.read(erb_yaml_path)

      gigantic_hash = {
        'properties' =>
          {
            'ntp' => [
              '0.north-america.pool.ntp.org',
              '1.north-america.pool.ntp.org',
            ],
            'blobstore' => {
              'address' => '10.10.0.7',
              'port' => 25251,
              'agent' => { 'user' => 'agent', 'password' => '75d1605f59b60' },
              'director' => {
                'user' => 'user',
                'password' => 'password'
              },
              'provider' => 'dav',
            },
            'nats' => {
              'user' => 'nats',
              'password' => '1a0312a24c0a0',
              'address' => '10.10.0.7',
              'port' => 4222
            },
            'redis' => {
              'address' => '127.0.0.1', 'port' => 25255, 'password' => 'R3d!S',
              'loglevel' => 'info',
            },
            'director' => {
              'name' => 'vpc-bosh-idora',
              'backend_port' => 25556,
              'encryption' => false,
              'max_tasks' => 500,
              'max_threads' => 32,
              'enable_snapshots' => true,
              'db' => {
                'adapter' => 'mysql2',
                'user' => 'ub45391e00',
                'password' => 'p4cd567d84d0e012e9258d2da30',
                'host' => 'bosh.hamazonhws.com',
                'port' => 3306,
                'database' => 'bosh',
                'connection_options' => {},
              },
              'auto_fix_stateful_nodes' => true
            },
            'vcenter' => {
              'address' => 'vcenter.address',
              'user' => 'user',
              'password' => '!vcenter.password',
              'datacenters' => [
                {
                  'name' => 'vcenter.datacenters.first.name',
                  'clusters' => ['cluster1']
                },
              ],
            },
          }

      }

      rendered_yaml = ERB.new(erb_yaml).result(Bosh::Common::TemplateEvaluationContext.new(gigantic_hash).get_binding)

      parsed = YAML.load(rendered_yaml)

      expect(parsed['cloud']['properties']['vcenters'][0]['password']).to eq('!vcenter.password')
    end
  end

end
