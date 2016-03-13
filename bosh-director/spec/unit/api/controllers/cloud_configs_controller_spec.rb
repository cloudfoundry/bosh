require 'spec_helper'
require 'rack/test'
require 'bosh/director/api/controllers/cloud_configs_controller'

module Bosh::Director
  describe Api::Controllers::CloudConfigsController do
    include Rack::Test::Methods

    subject(:app) { Api::Controllers::CloudConfigsController.new(config) }
    let(:config) do
      config = Config.load_hash(Psych.load(spec_asset('test-director-config.yml')))
      identity_provider = Support::TestIdentityProvider.new(config.get_uuid_provider)
      allow(config).to receive(:identity_provider).and_return(identity_provider)
      config
    end

    describe 'POST', '/' do
      context 'user has admin permissions' do
        before { authorize 'admin', 'admin' }

        it 'creates a new cloud config' do
          properties = Psych.dump(Bosh::Spec::Deployments.simple_cloud_config)
          expect {
            post '/', properties, {'CONTENT_TYPE' => 'text/yaml'}
          }.to change(Models::CloudConfig, :count).from(0).to(1)

          expect(Models::CloudConfig.first.properties).to eq(properties)
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

        properties = Psych.dump(Bosh::Spec::Deployments.simple_cloud_config)
        expect {
          post '/', properties, {'CONTENT_TYPE' => 'text/yaml'}
        }.to change(Bosh::Director::Models::Event, :count).from(0).to(1)
        event = Bosh::Director::Models::Event.first
        expect(event.object_type).to eq("cloud-config")
        expect(event.action).to eq("update")
        expect(event.user).to eq("admin")
      end

      it 'creates a new event with error' do
        authorize('admin', 'admin')
        expect {
          post '/', {}, {'CONTENT_TYPE' => 'text/yaml'}
        }.to change(Bosh::Director::Models::Event, :count).from(0).to(1)
        event = Bosh::Director::Models::Event.first
        expect(event.object_type).to eq("cloud-config")
        expect(event.action).to eq("update")
        expect(event.user).to eq("admin")
        expect(event.error).to eq("Manifest should not be empty")
      end
    end

    describe 'GET', '/' do
      it 'returns the number of cloud configs specified by ?limit' do
        authorize('admin', 'admin')

        Models::CloudConfig.new(
          properties: 'config_from_time_immortal',
          created_at: Time.now - 3,
        ).save
        Models::CloudConfig.new(
          properties: 'config_from_last_year',
          created_at: Time.now - 2,
        ).save
        newer_cloud_config_properties = "---\nsuper_shiny: new_config"
        Models::CloudConfig.new(
          properties: newer_cloud_config_properties,
          created_at: Time.now - 1,
        ).save


        get '/?limit=2'

        expect(last_response.status).to eq(200)
        expect(JSON.parse(last_response.body).count).to eq(2)
        expect(JSON.parse(last_response.body).first["properties"]).to eq(newer_cloud_config_properties)
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
    end
  end
end
