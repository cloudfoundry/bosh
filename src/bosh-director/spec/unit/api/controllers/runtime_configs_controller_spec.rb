require 'spec_helper'
require 'rack/test'
require 'bosh/director/api/controllers/runtime_configs_controller'

module Bosh::Director
  describe Api::Controllers::RuntimeConfigsController do
    include Rack::Test::Methods

    subject(:app) { linted_rack_app(described_class.new(config)) }
    let(:config) do
      config = Config.load_hash(SpecHelper.spec_get_director_config)
      identity_provider = Support::TestIdentityProvider.new(config.get_uuid_provider)
      allow(config).to receive(:identity_provider).and_return(identity_provider)
      config
    end

    describe 'POST', '/diff' do
      let(:runtime_config) {
        {
            'release' => {
                'name' => 'some-release',
                'version' => '0.0.1'
            },
            'addons' => {
                'name' => 'some-addon',
                'jobs' => {
                    'name' => 'some-job',
                    'release' => 'some-release',
                    'properties' => {
                        'some-key' => 'some-value'
                    }
                }
            }
        }
      }

      let(:dns_runtime_config) {
        {
          'dns' => {
            'version' => '0.0.1'
          }
        }
      }

      describe 'when user has admin access' do

        before { authorize('admin', 'admin') }

        it 'gives a nice error when request body is not a valid yml' do
          post '/diff', "}}}i'm not really yaml, hah!", {'CONTENT_TYPE' => 'text/yaml'}

          expect(last_response.status).to eq(400)
          expect(JSON.parse(last_response.body)['code']).to eq(440001)
          expect(JSON.parse(last_response.body)['description']).to include('Incorrect YAML structure of the uploaded manifest: ')
        end

        it 'gives a nice error when request body is empty' do
          post '/diff', '', {'CONTENT_TYPE' => 'text/yaml'}

          expect(last_response.status).to eq(400)
          expect(JSON.parse(last_response.body)).to eq(
              'code' => 440001,
              'description' => 'Manifest should not be empty',
          )
        end

        describe 'when diffing raises an error' do
          before do
            allow(Changeset).to receive(:new).and_raise StandardError, 'BOOM!'
          end

          it 'returns 200 with an empty diff and an error message if the diffing fails' do
            post '/diff', {}.to_yaml, {'CONTENT_TYPE' => 'text/yaml'}

            expect(last_response.status).to eq(200)
            expect(JSON.parse(last_response.body)['diff']).to eq([])
            expect(JSON.parse(last_response.body)['error']).to include('Unable to diff runtime-config')
          end
        end

        describe 'when runtime config is already set' do
          before do
            Bosh::Director::Api::RuntimeConfigManager.new.update(YAML.dump(dns_runtime_config))
            Bosh::Director::Api::RuntimeConfigManager.new.update(YAML.dump(runtime_config))
          end

          describe 'when runtime config already exists' do
            it 'shows an empty diff' do
              post '/diff', YAML.dump(runtime_config), {'CONTENT_TYPE' => 'text/yaml'}

              expect(last_response.status).to eq(200)
              expect(last_response.body).to eq('{"diff":[]}')
            end
          end

          describe 'when single line modified' do
            it 'shows a single line modified' do
              runtime_config['release']['version'] = '0.0.2'
              post '/diff', YAML.dump(runtime_config), {'CONTENT_TYPE' => 'text/yaml'}

              expect(last_response.status).to eq(200)
              expect(last_response.body).to eq('{"diff":[["release:",null],["  version: 0.0.1","removed"],["  version: 0.0.2","added"]]}')
            end
          end

          describe 'when single line added' do
            it 'shows a single line added' do
              runtime_config['addons']['jobs']['properties']['new-key'] = 'new-value'
              post '/diff', YAML.dump(runtime_config), {'CONTENT_TYPE' => 'text/yaml'}

              expect(last_response.status).to eq(200)
              expect(last_response.body).to eq('{"diff":[["addons:",null],["  jobs:",null],["    properties:",null],["      new-key: \"<redacted>\"","added"]]}')
            end
          end

          describe 'when redact=false' do
            it 'shows property values in plain text' do
              runtime_config['addons']['jobs']['properties']['new-key'] = 'new-value'
              post '/diff?redact=false', YAML.dump(runtime_config), {'CONTENT_TYPE' => 'text/yaml'}

              expect(last_response.status).to eq(200)
              expect(last_response.body).to eq('{"diff":[["addons:",null],["  jobs:",null],["    properties:",null],["      new-key: new-value","added"]]}')
            end
          end

          describe 'when diffing against empty yaml' do
            it "shows a full 'removed' diff" do
              post '/diff', YAML.dump({}), {'CONTENT_TYPE' => 'text/yaml'}

              expect(last_response.status).to eq(200)
              expect(last_response.body).to eq(
                  '{"diff":[' +
                      '["release:","removed"],' +
                      '["  name: some-release","removed"],' +
                      '["  version: 0.0.1","removed"],' +
                      '["",null],' +
                      '["addons:","removed"],' +
                      '["  name: some-addon","removed"],' +
                      '["  jobs:","removed"],' +
                      '["    name: some-job","removed"],' +
                      '["    release: some-release","removed"],' +
                      '["    properties:","removed"],' +
                      '["      some-key: \"<redacted>\"","removed"]]}')
            end
          end
        end

        describe 'when multiple named runtime configs exist' do

          let (:addons_runtime_config) do
            { addons: runtime_config['addons'] }
          end
          before do
            Bosh::Director::Api::RuntimeConfigManager.new.update(YAML.dump(runtime_config))
            Bosh::Director::Api::RuntimeConfigManager.new.update(YAML.dump(dns_runtime_config), 'dns')
            Bosh::Director::Api::RuntimeConfigManager.new.update(YAML.dump(addons_runtime_config), 'addons')
          end

          describe 'when no runtime config name provided' do
            it 'shows diff for default runtime config' do
              runtime_config['release']['version'] = '0.0.2'

              post '/diff?name=', YAML.dump(runtime_config), {'CONTENT_TYPE' => 'text/yaml'}

              expect(last_response.status).to eq(200)
              expect(last_response.body).to eq('{"diff":[["release:",null],["  version: 0.0.1","removed"],["  version: 0.0.2","added"]]}')
            end
          end

          describe 'when runtime config name provided' do
            it 'shows diff for named runtime config' do
              dns_runtime_config['dns']['version'] = '0.0.2'

              post '/diff?name=dns', YAML.dump(dns_runtime_config), {'CONTENT_TYPE' => 'text/yaml'}

              expect(last_response.status).to eq(200)
              expect(last_response.body).to eq('{"diff":[["dns:",null],["  version: 0.0.1","removed"],["  version: 0.0.2","added"]]}')
            end
          end
        end

        describe 'when runtime config is new' do
          it "shows a full 'added' diff" do
            post '/diff', YAML.dump(runtime_config), {'CONTENT_TYPE' => 'text/yaml'}

            expect(last_response.status).to eq(200)
            expect(last_response.body).to eq(
                '{"diff":[' +
                    '["release:","added"],' +
                    '["  name: some-release","added"],' +
                    '["  version: 0.0.1","added"],' +
                    '["",null],' +
                    '["addons:","added"],' +
                    '["  name: some-addon","added"],' +
                    '["  jobs:","added"],' +
                    '["    name: some-job","added"],' +
                    '["    release: some-release","added"],' +
                    '["    properties:","added"],' +
                    '["      some-key: \"<redacted>\"","added"]]}')
          end
        end

        describe 'when previous runtime config is nil' do

          before do
            Bosh::Director::Api::RuntimeConfigManager.new.update('---')
          end

          it "shows a full 'added' diff" do
            post '/diff', YAML.dump(runtime_config), {'CONTENT_TYPE' => 'text/yaml'}

            expect(last_response.status).to eq(200)
            expect(last_response.body).to eq(
              '{"diff":[' +
                '["release:","added"],' +
                '["  name: some-release","added"],' +
                '["  version: 0.0.1","added"],' +
                '["",null],' +
                '["addons:","added"],' +
                '["  name: some-addon","added"],' +
                '["  jobs:","added"],' +
                '["    name: some-job","added"],' +
                '["    release: some-release","added"],' +
                '["    properties:","added"],' +
                '["      some-key: \"<redacted>\"","added"]]}')
          end
        end

        describe 'when new manifest is nil' do
          before do
            Bosh::Director::Api::RuntimeConfigManager.new.update(YAML.dump(runtime_config))
          end

          it 'shows a full "removed" diff' do
            post '/diff', '--- {}', { 'CONTENT_TYPE' => 'text/yaml' }

            expect(last_response.status).to eq(200)
            expect(last_response.body).to eq(
              '{"diff":[' +
                '["release:","removed"],' +
                '["  name: some-release","removed"],' +
                '["  version: 0.0.1","removed"],' +
                '["",null],' +
                '["addons:","removed"],' +
                '["  name: some-addon","removed"],' +
                '["  jobs:","removed"],' +
                '["    name: some-job","removed"],' +
                '["    release: some-release","removed"],' +
                '["    properties:","removed"],' +
                '["      some-key: \"<redacted>\"","removed"]]}')
          end
        end
      end

      describe 'when user has no admin access' do
        it 'get unauthorized' do
          post '/diff', '', {'CONTENT_TYPE' => 'text/yaml'}
          expect(last_response.status).to eq(401)
        end
      end
    end

    describe 'POST', '/' do
      describe 'when user has admin access' do
        before { authorize('admin', 'admin') }

        it 'creates a new runtime config' do
          properties = YAML.dump(Bosh::Spec::Deployments.simple_runtime_config)
          expect {
            post '/', properties, {'CONTENT_TYPE' => 'text/yaml'}
          }.to change(Bosh::Director::Models::Config, :count).from(0).to(1)

          expect(last_response.status).to eq(201)
          expect(Bosh::Director::Models::Config.first.content).to eq(properties)
          expect(Bosh::Director::Models::Config.first.type).to eq('runtime')
          expect(Bosh::Director::Models::Config.first.name).to eq('default')
        end

        it 'gives a nice error when request body is not a valid yml' do
          post '/', "}}}i'm not really yaml, hah!", {'CONTENT_TYPE' => 'text/yaml'}

          expect(last_response.status).to eq(400)
          expect(JSON.parse(last_response.body)['code']).to eq(440001)
          expect(JSON.parse(last_response.body)['description']).to include('Incorrect YAML structure of the uploaded manifest: ')
        end

        it 'gives a nice error when request body is empty' do
          post '/', '', {'CONTENT_TYPE' => 'text/yaml'}

          expect(last_response.status).to eq(400)
          expect(JSON.parse(last_response.body)).to eq(
              'code' => 440001,
              'description' => 'Manifest should not be empty',
          )
        end

        it 'creates a new event' do
          properties = YAML.dump(Bosh::Spec::Deployments.simple_runtime_config)
          expect {
            post '/', properties, {'CONTENT_TYPE' => 'text/yaml'}
          }.to change(Bosh::Director::Models::Event, :count).from(0).to(1)
          event = Bosh::Director::Models::Event.first
          expect(event.object_type).to eq('runtime-config')
          expect(event.object_name).to eq('default')
          expect(event.action).to eq('update')
          expect(event.user).to eq('admin')
        end

        it 'creates a new event with error' do
          expect {
            post '/', {}, {'CONTENT_TYPE' => 'text/yaml'}
          }.to change(Bosh::Director::Models::Event, :count).from(0).to(1)
          event = Bosh::Director::Models::Event.first
          expect(event.object_type).to eq('runtime-config')
          expect(event.object_name).to eq('default')
          expect(event.action).to eq('update')
          expect(event.user).to eq('admin')
          expect(event.error).to eq('Manifest should not be empty')
        end

        context 'when name is the empty string' do
          let(:path) { '/?name=' }

          it "creates a new runtime config with name 'default'" do
            properties = YAML.dump(Bosh::Spec::Deployments.simple_runtime_config)

            post path, properties, {'CONTENT_TYPE' => 'text/yaml'}

            expect(last_response.status).to eq(201)
            expect(Bosh::Director::Models::Config.first.name).to eq('default')
          end
        end

        context 'when a name is passed in via a query param' do
          let(:path) { '/?name=smurf' }

          it 'creates a new named runtime config' do
            properties = YAML.dump(Bosh::Spec::Deployments.simple_runtime_config)

            post path, properties, {'CONTENT_TYPE' => 'text/yaml'}

            expect(last_response.status).to eq(201)
            expect(Bosh::Director::Models::Config.first.name).to eq('smurf')
          end

          it 'creates a new event and add name to event context' do
            properties = YAML.dump(Bosh::Spec::Deployments.simple_runtime_config)
            expect {
              post path, properties, {'CONTENT_TYPE' => 'text/yaml'}
            }.to change(Bosh::Director::Models::Event, :count).from(0).to(1)

            event = Bosh::Director::Models::Event.first
            expect(event.object_type).to eq('runtime-config')
            expect(event.object_name).to eq('smurf')
            expect(event.action).to eq('update')
            expect(event.user).to eq('admin')
          end
        end
      end

      describe 'when user has readonly access' do
        before { basic_authorize 'reader', 'reader' }

        it 'denies access' do
          expect(post('/', YAML.dump(Bosh::Spec::Deployments.simple_runtime_config), {'CONTENT_TYPE' => 'text/yaml'}).status).to eq(401)
        end
      end
    end

    describe 'GET', '/' do
      describe 'when user has admin access' do
        before { authorize('admin', 'admin') }

        it "returns the number of runtime configs specified by ?limit and only considers 'default' names" do
          Bosh::Director::Models::Config.new(type: 'runtime', content: 'config_value_1', name: 'default').save
          Bosh::Director::Models::Config.new(type: 'runtime', content: 'config_value_2', name: 'non-default').save

          newer_runtime_config_properties = "---\nsuper_shiny: new_config"
          Bosh::Director::Models::Config.new(type: 'runtime', content: newer_runtime_config_properties, name: 'default').save

          get '/?limit=2'

          expect(last_response.status).to eq(200)
          expect(JSON.parse(last_response.body).count).to eq(2)
          expect(JSON.parse(last_response.body)[0]['properties']).to eq(newer_runtime_config_properties)
          expect(JSON.parse(last_response.body)[1]['properties']).to eq('config_value_1')
        end

        it 'returns the config with the specified name' do
          Bosh::Director::Models::Config.new(type: 'runtime', content: 'named_config', name: 'smurf').save
          Bosh::Director::Models::Config.new(type: 'runtime', content: 'unnamed_config', name: 'default').save

          get '/?name=smurf&limit=1'

          expect(last_response.status).to eq(200)
          expect(JSON.parse(last_response.body).count).to eq(1)
          expect(JSON.parse(last_response.body).first['properties']).to eq('named_config')
        end

        it 'returns STATUS 400 if limit was not specified or malformed' do
          get '/'
          expect(last_response.status).to eq(400)
          expect(last_response.body).to eq("limit is required")

          get "/?limit="
          expect(last_response.status).to eq(400)
          expect(last_response.body).to eq("limit is required")

          get "/?limit=foo"
          expect(last_response.status).to eq(400)
          expect(last_response.body).to eq("limit is invalid: 'foo' is not an integer")
        end
      end

      describe 'when user has readonly access' do
        before { basic_authorize 'reader', 'reader' }
        before {
          Bosh::Director::Models::Config.make(:content => '{}')
        }

        it 'allows access' do
          expect(get('/?limit=2').status).to eq(200)
        end
      end
    end
  end
end
