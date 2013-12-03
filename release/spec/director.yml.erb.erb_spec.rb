require 'rspec'
require 'yaml'
require 'common/properties'
require 'json'

describe 'director.yml.erb.erb' do
  let(:deployment_manifest_fragment) do
    {
      'properties' => {
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
  end

  let(:erb_yaml) do
    erb_yaml_path = File.join(File.dirname(__FILE__), '../jobs/director/templates/director.yml.erb.erb')

    File.read(erb_yaml_path)
  end

  context 'when vcenter.address begins with a bang and contains quotes' do
    before do
      deployment_manifest_fragment['properties']['vcenter']['address'] = "!vcenter.address''"
    end

    it 'renders vcenter address correctly' do
      spec = deployment_manifest_fragment

      rendered_yaml = ERB.new(erb_yaml).result(Bosh::Common::TemplateEvaluationContext.new(spec).get_binding)

      parsed = YAML.load(rendered_yaml)

      expect(parsed['cloud']['properties']['vcenters'][0]['host']).to eq("!vcenter.address''")
    end
  end

  context 'when vcenter.user begins with a bang and contains quotes' do
    before do
      deployment_manifest_fragment['properties']['vcenter']['user'] = "!vcenter.user''"
    end

    it 'renders vcenter user correctly' do
      spec = deployment_manifest_fragment

      rendered_yaml = ERB.new(erb_yaml).result(Bosh::Common::TemplateEvaluationContext.new(spec).get_binding)

      parsed = YAML.load(rendered_yaml)

      expect(parsed['cloud']['properties']['vcenters'][0]['user']).to eq("!vcenter.user''")
    end
  end

  context 'when vcenter.password begins with a bang and contains quotes' do
    before do
      deployment_manifest_fragment['properties']['vcenter']['password'] = "!vcenter.password''"
    end

    it 'renders vcenter password correctly' do
      spec = deployment_manifest_fragment

      rendered_yaml = ERB.new(erb_yaml).result(Bosh::Common::TemplateEvaluationContext.new(spec).get_binding)

      parsed = YAML.load(rendered_yaml)

      expect(parsed['cloud']['properties']['vcenters'][0]['password']).to eq("!vcenter.password''")
    end
  end

  context 'provider: swift/openstack' do
    before do
      deployment_manifest_fragment['properties']['blobstore'] = {
        'provider' => 'swift',
        'swift_container_name' => 'my-container-name',
        'swift_provider' => 'openstack',
        'openstack' => {
          'openstack_auth_url' => 'http://1.2.3.4:5000/v2/tokens',
          'openstack_username' => 'username',
          'openstack_api_key' => 'password',
          'openstack_tenant' => 'test'
        }
      }
    end

    it 'renders blobstore correctly' do
      spec = deployment_manifest_fragment

      rendered_yaml = ERB.new(erb_yaml).result(Bosh::Common::TemplateEvaluationContext.new(spec).get_binding)

      parsed = YAML.load(rendered_yaml)

      expect(parsed['blobstore']).to eq({"provider"=>"swift",
       "options"=>
        {"swift_provider"=>"openstack",
         "container_name"=>"my-container-name",
         "openstack"=>
          {"openstack_auth_url"=>"http://1.2.3.4:5000/v2/tokens",
           "openstack_username"=>"username",
           "openstack_api_key"=>"password",
           "openstack_tenant"=>"test"}}
      })
    end

    it 'renders blobstore.openstack.openstack_region is correctly not defined' do
      spec = deployment_manifest_fragment

      rendered_yaml = ERB.new(erb_yaml).result(Bosh::Common::TemplateEvaluationContext.new(spec).get_binding)

      parsed = YAML.load(rendered_yaml)

      expect(parsed['blobstore']['options']['openstack']['openstack_region']).to be_nil
    end

    it 'renders blobstore.openstack.openstack_region is correctly defined if set' do
      spec = deployment_manifest_fragment
      spec['properties']['blobstore']['openstack']['openstack_region'] = 'wild-west'

      rendered_yaml = ERB.new(erb_yaml).result(Bosh::Common::TemplateEvaluationContext.new(spec).get_binding)

      parsed = YAML.load(rendered_yaml)

      expect(parsed['blobstore']['options']['openstack']['openstack_region']).to eq('wild-west')
    end

  end

  context 'provider: swift/hp' do
    before do
      deployment_manifest_fragment['properties']['blobstore'] = {
        'provider' => 'swift',
        'swift_container_name' => 'my-container-name',
        'swift_provider' => 'hp',
        'hp' => {
          'hp_access_key' => 'username',
          'hp_secret_key' => 'password',
          'hp_tenant_id' => 'test',
          'hp_avl_zone' => 'hp-happy-land'
        }
      }
    end

    it 'renders blobstore correctly' do
      spec = deployment_manifest_fragment

      rendered_yaml = ERB.new(erb_yaml).result(Bosh::Common::TemplateEvaluationContext.new(spec).get_binding)

      parsed = YAML.load(rendered_yaml)

      expect(parsed['blobstore']).to eq({"provider"=>"swift",
       "options"=>
        {"swift_provider"=>"hp",
         "container_name"=>"my-container-name",
         "hp"=>{
           'hp_access_key' => 'username',
           'hp_secret_key' => 'password',
           'hp_tenant_id' => 'test',
           'hp_avl_zone' => 'hp-happy-land'
          }
        }
      })
    end
  end
end
