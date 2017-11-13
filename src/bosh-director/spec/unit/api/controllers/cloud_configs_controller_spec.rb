require 'spec_helper'
require 'rack/test'
require 'bosh/director/api/controllers/cloud_configs_controller'

module Bosh::Director
  describe Api::Controllers::CloudConfigsController do
    include Rack::Test::Methods

    subject(:app) { linted_rack_app(described_class.new(config)) }
    let(:config) do
      config = Config.load_hash(SpecHelper.spec_get_director_config)
      identity_provider = Support::TestIdentityProvider.new(config.get_uuid_provider)
      allow(config).to receive(:identity_provider).and_return(identity_provider)
      config
    end

    describe 'POST', '/' do
      context 'user has admin permissions' do
        before { authorize 'admin', 'admin' }

        it 'creates a new cloud config' do
          content = YAML.dump(Bosh::Spec::Deployments.simple_cloud_config)
          expect {
            post '/', content, {'CONTENT_TYPE' => 'text/yaml'}
          }.to change(Models::Config, :count).from(0).to(1)

          expect(Models::Config.first.content).to eq(content)
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
      end

      context 'when user is reader' do
        before { basic_authorize('reader', 'reader') }

        it 'forbids access' do
          expect(post('/', '', {'CONTENT_TYPE' => 'text/yaml'}).status).to eq(401)
        end
      end

      context 'when user is team-admin' do
        before { basic_authorize('dev-team-member', 'dev-team-member') }

        it 'forbid access' do
          expect(post('/', '', {'CONTENT_TYPE' => 'text/yaml'}).status).to eq(401)
        end
      end

      context 'user is not authorized' do
        it 'denies access when not authenticated' do
          expect(post('/').status).to eq(401)
        end
      end

      it 'creates a new event' do
        authorize('admin', 'admin')

        content = YAML.dump(Bosh::Spec::Deployments.simple_cloud_config)
        expect {
          post '/', content, {'CONTENT_TYPE' => 'text/yaml'}
        }.to change(Bosh::Director::Models::Event, :count).from(0).to(1)
        event = Bosh::Director::Models::Event.first
        expect(event.object_type).to eq('cloud-config')
        expect(event.object_name).to eq('default')
        expect(event.action).to eq('update')
        expect(event.user).to eq('admin')
      end

      it 'creates a new event with error' do
        authorize('admin', 'admin')
        expect {
          post '/', {}, {'CONTENT_TYPE' => 'text/yaml'}
        }.to change(Bosh::Director::Models::Event, :count).from(0).to(1)
        event = Bosh::Director::Models::Event.first
        expect(event.object_type).to eq('cloud-config')
        expect(event.object_name).to eq('default')
        expect(event.action).to eq('update')
        expect(event.user).to eq('admin')
        expect(event.error).to eq('Manifest should not be empty')
      end
    end

    describe 'GET', '/' do
      it 'returns the number of cloud configs specified by ?limit' do
        authorize('admin', 'admin')

        Models::Config.make(
          :cloud,
          content: 'config_from_time_immortal',
          created_at: Time.now - 3,
        )
        Models::Config.make(
          :cloud,
          content: 'config_from_last_year',
          created_at: Time.now - 2,
        )
        newer_cloud_config_content = "---\nsuper_shiny: new_config"
        Models::Config.make(
          :cloud,
          content: newer_cloud_config_content,
          created_at: Time.now - 1,
        )

        get '/?limit=2'

        expect(last_response.status).to eq(200)
        expect(JSON.parse(last_response.body).count).to eq(2)
        expect(JSON.parse(last_response.body).first['properties']).to eq(newer_cloud_config_content)
      end

      it 'returns STATUS 400 if limit was not specified or malformed' do
        authorize('admin', 'admin')

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

      it 'denies access when not authenticated' do
        expect(get('/').status).to eq(401)
      end

      context 'when user is reader' do
        before { basic_authorize('reader', 'reader') }

        it 'permits access' do
          expect(get('/?limit=1').status).to eq(200)
        end
      end
    end

    describe 'diff' do

      let(:cloud_config_hash_with_one_az) {
        {
          'azs' => [
            {
              'name' => 'az1',
              'cloud_properties' => {}
            }
          ]
        }
      }

      let(:cloud_config_hash_with_two_azs) {
        {
          'azs' => [
            {
              'name' => 'az1',
              'cloud_properties' => {}
            },
            {
              'name' => 'az2',
              'cloud_properties' => {}
            }
          ]
        }
      }

      context 'authenticated access' do

        before { authorize 'admin', 'admin' }

        context 'when there is a previous cloud config' do
          before do
            Models::Config.make(:cloud, content: YAML.dump(cloud_config_hash_with_two_azs))
          end

          context 'when uploading an empty cloud config' do
            it 'returns the diff' do
              post(
                '/diff',
                "--- \n {}",
                { 'CONTENT_TYPE' => 'text/yaml' }
              )
              expect(last_response.status).to eq(200)
              expect(last_response.body).to eq('{"diff":[["azs:","removed"],["- name: az1","removed"],["  cloud_properties: {}","removed"],["- name: az2","removed"],["  cloud_properties: {}","removed"]]}')
            end
          end

          context 'when there is no diff' do
            it 'returns empty diff' do
              post(
                  '/diff',
                  YAML.dump(cloud_config_hash_with_two_azs),
                  {'CONTENT_TYPE' => 'text/yaml'}
              )
              expect(last_response.body).to eq('{"diff":[]}')
            end
          end

          context 'when there is a diff' do
            it 'returns the diff' do
              post(
                  '/diff',
                  YAML.dump(cloud_config_hash_with_one_az),
                  {'CONTENT_TYPE' => 'text/yaml'}
              )
              expect(last_response.status).to eq(200)
              expect(last_response.body).to eq('{"diff":[["azs:",null],["- name: az2","removed"],["  cloud_properties: {}","removed"]]}')
            end
          end

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

          it 'returns 200 with an empty diff and an error message if the diffing fails' do
            allow_any_instance_of(Bosh::Director::Changeset).to receive(:diff).and_raise('Oooooh crap')

            post '/diff', {}.to_yaml, {'CONTENT_TYPE' => 'text/yaml'}

            expect(last_response.status).to eq(200)
            expect(JSON.parse(last_response.body)['diff']).to eq([])
            expect(JSON.parse(last_response.body)['error']).to include('Unable to diff cloud-config')
          end

        end

        context 'when there are two previous cloud config ' do
          before do
            Models::Config.make(:cloud, name: 'foo',content: YAML.dump(cloud_config_hash_with_one_az))
            Models::Config.make(:cloud, content: YAML.dump(cloud_config_hash_with_two_azs))
          end
          it 'always diffs against the default-named cloud config' do
            post(
                '/diff',
                YAML.dump(cloud_config_hash_with_two_azs),
                {'CONTENT_TYPE' => 'text/yaml'}
            )
            expect(last_response.body).to eq('{"diff":[]}')
          end
        end

        context 'when there is no previous cloud config' do
          it 'returns the diff' do
            post(
                '/diff',
                YAML.dump(cloud_config_hash_with_one_az),
                {'CONTENT_TYPE' => 'text/yaml'}
            )
            expect(last_response.status).to eq(200)
            expect(last_response.body).to eq('{"diff":[["azs:","added"],["- name: az1","added"],["  cloud_properties: {}","added"]]}')
          end

          context 'when previous cloud config is nil' do
            before do
              Models::Config.make(:cloud)
            end

            it 'returns the diff' do
              post(
                '/diff',
                YAML.dump(cloud_config_hash_with_one_az),
                {'CONTENT_TYPE' => 'text/yaml'}
              )
              expect(last_response.status).to eq(200)
              expect(last_response.body).to eq('{"diff":[["azs:","added"],["- name: az1","added"],["  cloud_properties: {}","added"]]}')
            end
          end
        end
      end

      context 'accessing with invalid credentials' do
        before { authorize 'invalid-user', 'invalid-password' }

        it 'returns 401' do
          post '/diff', {}.to_yaml, {'CONTENT_TYPE' => 'text/yaml'}
          expect(last_response.status).to eq(401)
        end
      end
    end
  end
end
