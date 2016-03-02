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
      it 'creates a new cloud config' do
        authorize('admin', 'admin')

        properties = Psych.dump(Bosh::Spec::Deployments.simple_cloud_config)
        expect {
          post '/', properties, {'CONTENT_TYPE' => 'text/yaml'}
        }.to change(Bosh::Director::Models::CloudConfig, :count).from(0).to(1)

        expect(Bosh::Director::Models::CloudConfig.first.properties).to eq(properties)
      end

      it 'gives a nice error when request body is not a valid yml' do
        authorize('admin', 'admin')

        post '/', "}}}i'm not really yaml, hah!", {'CONTENT_TYPE' => 'text/yaml'}

        expect(last_response.status).to eq(400)
        expect(JSON.parse(last_response.body)['code']).to eq(440001)
        expect(JSON.parse(last_response.body)['description']).to include('Incorrect YAML structure of the uploaded manifest: ')
      end

      it 'gives a nice error when request body is empty' do
        authorize('admin', 'admin')

        post '/', '', {'CONTENT_TYPE' => 'text/yaml'}

        expect(last_response.status).to eq(400)
        expect(JSON.parse(last_response.body)).to eq(
            'code' => 440001,
            'description' => 'Manifest should not be empty',
        )
      end

      it 'denies access when read-only' do
        basic_authorize('reader', 'reader')

        expect(post('/', '', {'CONTENT_TYPE' => 'text/yaml'}).status).to eq(401)
      end

      it 'denies access when not authenticated' do
        expect(post('/').status).to eq(401)
      end
    end

    describe 'GET', '/' do
      it 'returns the number of cloud configs specified by ?limit' do
        authorize('admin', 'admin')

        oldest_cloud_config = Bosh::Director::Models::CloudConfig.new(
          properties: "config_from_time_immortal",
          created_at: Time.now - 3,
        ).save
        older_cloud_config = Bosh::Director::Models::CloudConfig.new(
          properties: "config_from_last_year",
          created_at: Time.now - 2,
        ).save
        newer_cloud_config_properties = "---\nsuper_shiny: new_config"
        newer_cloud_config = Bosh::Director::Models::CloudConfig.new(
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
