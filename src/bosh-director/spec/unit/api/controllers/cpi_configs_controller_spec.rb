require 'spec_helper'
require 'rack/test'
require 'bosh/director/api/controllers/cpi_configs_controller'

module Bosh::Director
  describe Api::Controllers::CpiConfigsController do
    include Rack::Test::Methods

    subject(:app) { linted_rack_app(described_class.new(config)) }
    let(:config) do
      config = Config.load_hash(SpecHelper.spec_get_director_config)
      identity_provider = Support::TestIdentityProvider.new(config.get_uuid_provider)
      allow(config).to receive(:identity_provider).and_return(identity_provider)
      config
    end

    describe 'POST', '/' do
      describe 'when user has admin access' do
        before { authorize('admin', 'admin') }

        it 'creates a new cpi config' do
          cpi_config = YAML.dump(Bosh::Spec::Deployments.simple_cpi_config)
          expect {
            post '/', cpi_config, {'CONTENT_TYPE' => 'text/yaml'}
          }.to change(Bosh::Director::Models::Config, :count).from(0).to(1)

          expect(Bosh::Director::Models::Config.first.content).to eq(cpi_config)
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
          properties = YAML.dump(Bosh::Spec::Deployments.simple_cpi_config)
          expect {
            post '/', properties, {'CONTENT_TYPE' => 'text/yaml'}
          }.to change(Bosh::Director::Models::Event, :count).from(0).to(1)
          event = Bosh::Director::Models::Event.first
          expect(event.object_type).to eq('cpi-config')
          expect(event.action).to eq('update')
          expect(event.user).to eq('admin')
        end

        it 'creates a new event with error' do
          expect {
            post '/', {}, {'CONTENT_TYPE' => 'text/yaml'}
          }.to change(Bosh::Director::Models::Event, :count).from(0).to(1)
          event = Bosh::Director::Models::Event.first
          expect(event.object_type).to eq('cpi-config')
          expect(event.action).to eq('update')
          expect(event.user).to eq('admin')
          expect(event.error).to eq('Manifest should not be empty')

        end
      end

      describe 'when user has readonly access' do
        before { basic_authorize 'reader', 'reader' }

        it 'denies access' do
          expect(post('/', YAML.dump(Bosh::Spec::Deployments.simple_cpi_config), {'CONTENT_TYPE' => 'text/yaml'}).status).to eq(401)
        end
      end
    end

    describe 'POST', '/diff' do
      let(:cpi_config) { YAML.dump(Bosh::Spec::Deployments.simple_cpi_config) }
      let(:expected_diff) { '{"diff":[["cpis:","added"],["- name: cpi-name1","added"],["  type: cpi-type","added"],["  properties:","added"],["    somekey: \"<redacted>\"","added"],["- name: cpi-name2","added"],["  type: cpi-type2","added"],["  properties:","added"],["    somekey2: \"<redacted>\"","added"]]}' }


      describe 'when user has admin access' do
        before { authorize('admin', 'admin') }

        describe 'when redact=false' do
          let(:expected_diff) { '{"diff":[["cpis:","added"],["- name: cpi-name1","added"],["  type: cpi-type","added"],["  properties:","added"],["    somekey: someval","added"],["- name: cpi-name2","added"],["  type: cpi-type2","added"],["  properties:","added"],["    somekey2: someval2","added"]]}' }

          it 'shows property values in plain text' do
            post '/diff?redact=false', cpi_config, {'CONTENT_TYPE' => 'text/yaml'}

            expect(last_response.status).to eq(200)
            expect(last_response.body).to eq(expected_diff)
          end
        end

        describe 'when cpi config is new' do
          it "shows a full 'added' diff" do
            post '/diff', cpi_config, {'CONTENT_TYPE' => 'text/yaml'}

            expect(last_response.status).to eq(200)
            expect(last_response.body).to eq(expected_diff)
          end
        end

        describe 'when previous cpi config is nil' do
          before do
            cpi_config = Bosh::Director::Models::Config.make(:cpi, raw_manifest: nil)
          end

          it "shows a full 'added' diff" do
            post '/diff', cpi_config, {'CONTENT_TYPE' => 'text/yaml'}

            expect(last_response.status).to eq(200)
            expect(last_response.body).to eq(expected_diff)
          end
        end

        describe 'when new cpi config is empty' do
          before do
            Bosh::Director::Api::CpiConfigManager.new.update(cpi_config)
          end
          let(:expected_diff) { '{"diff":[["cpis:","removed"],["- name: cpi-name1","removed"],["  type: cpi-type","removed"],["  properties:","removed"],["    somekey: \"<redacted>\"","removed"],["- name: cpi-name2","removed"],["  type: cpi-type2","removed"],["  properties:","removed"],["    somekey2: \"<redacted>\"","removed"]]}' }

          it 'shows a full "removed" diff for nil' do
            post '/diff', '--- {}', { 'CONTENT_TYPE' => 'text/yaml' }

            expect(last_response.status).to eq(200)
            expect(last_response.body).to eq(expected_diff)
          end

          it 'shows a full "removed" diff for empty hash' do
            post '/diff', '--- {}', { 'CONTENT_TYPE' => 'text/yaml' }

            expect(last_response.status).to eq(200)
            expect(last_response.body).to eq(expected_diff)
          end
        end
      end

      describe 'when user has readonly access' do
        before { basic_authorize 'reader', 'reader' }

        it 'denies access' do
          expect(post('/diff', cpi_config, {'CONTENT_TYPE' => 'text/yaml'}).status).to eq(401)
        end
      end
    end

    describe 'GET', '/' do
      describe 'when user has admin access' do
        before { authorize('admin', 'admin') }

        it 'returns the number of cpi configs specified by ?limit' do
          Bosh::Director::Models::Config.make(:cpi,
              content: 'config_from_time_immortal',
              created_at: Time.now - 3,
          )
           Bosh::Director::Models::Config.make(:cpi,
              content: 'config_from_last_year',
              created_at: Time.now - 2,
          )
          newer_cpi_config_properties = "---\nsuper_shiny: new_config"
          Bosh::Director::Models::Config.make(:cpi,
              content: newer_cpi_config_properties,
              created_at: Time.now - 1,
          )

          get '/?limit=2'

          expect(last_response.status).to eq(200)
          expect(JSON.parse(last_response.body).count).to eq(2)
          expect(JSON.parse(last_response.body).first['properties']).to eq(newer_cpi_config_properties)
        end

        it 'returns STATUS 400 if limit was not specified or malformed' do
          get '/'
          expect(last_response.status).to eq(400)
          expect(last_response.body).to eq('limit is required')

          get '/?limit='
          expect(last_response.status).to eq(400)
          expect(last_response.body).to eq('limit is required')

          get '/?limit=foo'
          expect(last_response.status).to eq(400)
          expect(last_response.body).to eq("limit is invalid: 'foo' is not an integer")
        end
      end

      describe 'when user has readonly access' do
        before { basic_authorize 'reader', 'reader' }
        before {
          Bosh::Director::Models::Config.make(content: '{}')
        }

        it 'denies access' do
          expect(get('/?limit=2').status).to eq(401)
        end
      end
    end

    describe 'POST', '/diff' do
      let(:new_cpi_config) {
        {
          'cpis' => [
            {
              'name' => 'cpi-name',
              'type' => 'cpi-type',
              'properties' => {
                'somekey' => 'someotherval'
              }
            }
          ]
        }
      }

      context 'when user has admin access' do
        before { authorize('admin', 'admin') }

        context 'when YAML is valid' do

          context 'when cpi_config does not exist' do
            it 'returns the delta' do
              post '/diff', YAML.dump(new_cpi_config), {'CONTENT_TYPE' => 'text/yaml'}
              diff = JSON.parse(last_response.body)['diff']

              expect(last_response.status).to eq(200)
              expect(diff).to eq(
                [['cpis:', 'added'],
                  ['- name: cpi-name', 'added'],
                  ['  type: cpi-type', 'added'],
                  ['  properties:', 'added'],
                  ['    somekey: "<redacted>"', 'added']]
              )
            end

            context 'when `redact=false` option is given' do
              it 'returns the delta with actual values' do
                post '/diff?redact=false', YAML.dump(new_cpi_config), {'CONTENT_TYPE' => 'text/yaml'}
                diff = JSON.parse(last_response.body)['diff']

                expect(last_response.status).to eq(200)
                expect(diff).to eq(
                  [['cpis:', 'added'],
                    ['- name: cpi-name', 'added'],
                    ['  type: cpi-type', 'added'],
                    ['  properties:', 'added'],
                    ['    somekey: someotherval', 'added']]
                )
              end
            end
          end

          context 'when cpi_config exists' do

            let(:old_cpi_config) {
              {
                'cpis' => [
                  {
                    'name' => 'cpi-name',
                    'type' => 'cpi-type',
                    'properties' => {
                      'somekey' => 'someval'
                    }
                  }
                ]
              }
            }

            it 'returns the delta' do
              Bosh::Director::Models::Config.make(:cpi,
                content: YAML.dump(old_cpi_config),
                created_at: Time.now - 3,
              )

              post '/diff', YAML.dump(new_cpi_config), {'CONTENT_TYPE' => 'text/yaml'}
              diff = JSON.parse(last_response.body)['diff']

              expect(diff.size).to be > 0
              expect(diff[3]).to eq(['    somekey: "<redacted>"', 'removed'])
              expect(diff[4]).to eq(['    somekey: "<redacted>"', 'added'])
            end
          end

          context 'when changeset diff raises an error' do
            before do
              allow_any_instance_of(Changeset).to receive(:diff).and_raise StandardError, 'error'
            end

            it 'returns 200 with a body containing an empty diff and the error message' do
              post '/diff', YAML.dump(new_cpi_config), {'CONTENT_TYPE' => 'text/yaml'}

              expect(last_response.status).to eq(200)

              expect(JSON.parse(last_response.body)['diff']).to eq([])
              expect(JSON.parse(last_response.body)['error']).to include('Unable to diff cpi_config:')
            end

          end
        end

        context 'when invalid YAML is given' do
          it 'returns a nice error message' do
            post '/diff', "}}}i'm not really yaml, hah!", {'CONTENT_TYPE' => 'text/yaml'}

            expect(last_response.status).to eq(400)
            expect(JSON.parse(last_response.body)['code']).to eq(440001)
            expect(JSON.parse(last_response.body)['description']).to include('Incorrect YAML structure of the uploaded manifest: ')
          end
        end

        context 'when YAML is nil' do
          it 'returns a nice error message' do
            post '/diff', nil, {'CONTENT_TYPE' => 'text/yaml'}

            expect(last_response.status).to eq(400)
            expect(JSON.parse(last_response.body)['code']).to eq(440001)
            expect(JSON.parse(last_response.body)['description']).to include('Manifest should not be empty')
          end
        end
      end

      context 'when accessing with invalid credentials' do
        before { authorize 'invalid-user', 'invalid-password' }

        it 'returns 401' do
          post '/diff', YAML.dump({}), {'CONTENT_TYPE' => 'text/yaml'}

          expect(last_response.status).to eq(401)
        end
      end

    end

  end
end

