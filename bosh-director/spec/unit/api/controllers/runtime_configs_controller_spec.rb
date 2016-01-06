require 'spec_helper'
require 'rack/test'
require 'bosh/director/api/controllers/runtime_configs_controller'

module Bosh::Director
  describe Api::Controllers::RuntimeConfigsController do
    include Rack::Test::Methods

    let(:config) { Config.load_hash(Psych.load(spec_asset('test-director-config.yml'))) }
    subject(:app) { Api::Controllers::RuntimeConfigsController.new(config) }

    describe 'POST', '/' do
      it 'creates a new runtime config' do
        authorize('admin', 'admin')

        properties = Psych.dump(Bosh::Spec::Deployments.simple_runtime_config)
        expect {
          post '/', properties, {'CONTENT_TYPE' => 'text/yaml'}
        }.to change(Bosh::Director::Models::RuntimeConfig, :count).from(0).to(1)

        expect(Bosh::Director::Models::RuntimeConfig.first.properties).to eq(properties)
      end
    end

    describe 'GET', '/' do
      it 'returns the number of runtime configs specified by ?limit' do
        authorize('admin', 'admin')

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
    end

    describe 'scope' do
      let(:identity_provider) { Support::TestIdentityProvider.new }
      before { allow(config).to receive(:identity_provider).and_return(identity_provider) }

      it 'accepts read scope for routes allowing read access' do
        authorize 'admin', 'admin'

        get '/'
        expect(identity_provider.scope).to eq(:read)

        header 'Content-Type', 'text/yaml'
        post '/'
        expect(identity_provider.scope).to eq(:write)
      end
    end
  end
end
