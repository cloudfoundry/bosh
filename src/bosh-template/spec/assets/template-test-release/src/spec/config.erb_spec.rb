require 'rspec'
require 'bosh/template/test'
require 'yaml'
require 'json'


module Bosh::Template::Test
  describe 'config.erb' do
    describe 'template rendering' do
      let(:release_path) {File.join(File.dirname(__FILE__), '../..')}

      let(:deployment_manifest_properties_fragment) do
        {'properties' => {'cert' => '----- BEGIN ... -----'}}
      end

      let(:release) {ReleaseDir.new(release_path)}

      describe 'web-server job' do
        let(:job) {release.job('web-server')}

        describe 'config/config-with-nested' do
          let(:template) {job.template('config/config-with-nested')}
          describe 'manifest properties' do
            let(:deployment_manifest_properties_fragment) do
              {
                'properties' => {
                  'nested' => {
                    'properties' => {
                      'works' => {
                        'too' =>
                          'nested-works-too'
                      }
                    }
                  }
                }
              }
            end

            it 'parses out the values' do
              rendered_config = JSON.parse(template.render(deployment_manifest_properties_fragment))
              expect(rendered_config['works.too']).to eq('nested-works-too')
            end
          end
        end

        describe 'config/config' do
          let(:template) {job.template('config/config')}

          describe 'manifest properties' do
            context 'when the port is not specified' do
              let(:deployment_manifest_properties_fragment) do
                {'properties' => {'cert' => '----- BEGIN ... -----'}}
              end

              it 'defaults to the spec file default' do
                rendered_config = JSON.parse(template.render(deployment_manifest_properties_fragment))
                expect(rendered_config['port']).to eq(8080)
              end
            end

            context 'whet the port is specified' do
              let(:deployment_manifest_properties_fragment) do
                {
                  'properties' => {
                    'cert' => '----- BEGIN ... -----',
                    'port' => 42,
                  }
                }
              end

              it 'uses the value specified in the hash' do
                rendered_json = template.render(deployment_manifest_properties_fragment)
                rendered_config = JSON.parse(rendered_json)
                expect(rendered_config['port']).to eq(42)
              end
            end
          end

          describe 'instance spec info' do
            it 'has default spec values' do
              rendered_config = JSON.parse(template.render(deployment_manifest_properties_fragment))
              expect(rendered_config['address']).to eq('my.bosh.com')
              expect(rendered_config['az']).to eq('az1')
              expect(rendered_config['bootstrap']).to eq(false)
              expect(rendered_config['deployment']).to eq('my-deployment')
              expect(rendered_config['id']).to eq('xxxxxx-xxxxxxxx-xxxxx')
              expect(rendered_config['index']).to eq(0)
              expect(rendered_config['ip']).to eq('192.168.0.0')
              expect(rendered_config['name']).to eq('me')
              expect(rendered_config['network_data']).to eq('bar')
              expect(rendered_config['network_ip']).to eq('192.168.0.0')
            end

            context 'when the spec has special values' do
              it 'is overridden' do
                spec = InstanceSpec.new(bootstrap: true)
                rendered_config = JSON.parse(template.render(deployment_manifest_properties_fragment, spec: spec))
                expect(rendered_config['bootstrap']).to eq(true)
              end
            end
          end

          describe 'links' do
            it 'reads links' do
              links = [
                Link.new(
                  name: 'primary_db',
                  instances: [LinkInstance.new(address: 'my.database.com')],
                  properties: {
                    'adapter' => 'sqlite',
                    'username' => 'root',
                    'password' => 'asdf1234',
                    'port' => 4321,
                    'name' => 'webserverdb',
                  }
                )
              ]
              rendered_config = JSON.parse(template.render(deployment_manifest_properties_fragment, links: links))
              expect(rendered_config['db']['host']).to eq('my.database.com')
              expect(rendered_config['db']['adapter']).to eq('sqlite')
              expect(rendered_config['db']['username']).to eq('root')
              expect(rendered_config['db']['password']).to eq('asdf1234')
              expect(rendered_config['db']['port']).to eq(4321)
              expect(rendered_config['db']['database']).to eq('webserverdb')
            end
          end
        end
      end
    end
  end
end
