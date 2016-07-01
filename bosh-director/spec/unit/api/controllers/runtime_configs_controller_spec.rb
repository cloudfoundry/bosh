require 'spec_helper'
require 'rack/test'
require 'bosh/director/api/controllers/runtime_configs_controller'

module Bosh::Director
  describe Api::Controllers::RuntimeConfigsController do
    include Rack::Test::Methods

    subject(:app) { Api::Controllers::RuntimeConfigsController.new(config) }
    let(:config) do
      config = Config.load_hash(SpecHelper.spec_get_director_config)
      identity_provider = Support::TestIdentityProvider.new(config.get_uuid_provider)
      allow(config).to receive(:identity_provider).and_return(identity_provider)
      config
    end

    describe 'POST', '/' do
      describe 'when user has admin access' do
        before { authorize('admin', 'admin') }

        it 'creates a new runtime config' do
          properties = YAML.dump(Bosh::Spec::Deployments.simple_runtime_config)
          expect {
            post '/', properties, {'CONTENT_TYPE' => 'text/yaml'}
          }.to change(Bosh::Director::Models::RuntimeConfig, :count).from(0).to(1)

          expect(Bosh::Director::Models::RuntimeConfig.first.properties).to eq(properties)
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
          expect(event.object_type).to eq("runtime-config")
          expect(event.action).to eq("update")
          expect(event.user).to eq("admin")
        end

        it 'creates a new event with error' do
          expect {
            post '/', {}, {'CONTENT_TYPE' => 'text/yaml'}
          }.to change(Bosh::Director::Models::Event, :count).from(0).to(1)
          event = Bosh::Director::Models::Event.first
          expect(event.object_type).to eq("runtime-config")
          expect(event.action).to eq("update")
          expect(event.user).to eq("admin")
          expect(event.error).to eq("Manifest should not be empty")

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

        it 'returns the number of runtime configs specified by ?limit' do
          oldest_runtime_config = Bosh::Director::Models::RuntimeConfig.new(
            properties: "config_from_time_immortal",
            created_at: Time.now - 3,
          ).save
          older_runtime_config = Bosh::Director::Models::RuntimeConfig.new(
            properties: "config_from_last_year",
            created_at: Time.now - 2,
          ).save
          newer_runtime_config_properties = "---\nsuper_shiny: new_config"
          newer_runtime_config = Bosh::Director::Models::RuntimeConfig.new(
            properties: newer_runtime_config_properties,
            created_at: Time.now - 1,
          ).save

          get '/?limit=2'

          expect(last_response.status).to eq(200)
          expect(JSON.parse(last_response.body).count).to eq(2)
          expect(JSON.parse(last_response.body).first["properties"]).to eq(newer_runtime_config_properties)
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
          Bosh::Director::Models::RuntimeConfig.make(:properties => '{}')
        }

        it 'allows access' do
          expect(get('/?limit=2').status).to eq(200)
        end
      end
    end
  end
end
