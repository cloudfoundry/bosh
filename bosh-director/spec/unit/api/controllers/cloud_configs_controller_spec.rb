require 'spec_helper'
require 'rack/test'
require 'bosh/director/api/controllers/cloud_configs_controller'

module Bosh::Director
  describe Api::Controllers::CloudConfigsController do
    include Rack::Test::Methods

    subject(:app) { Api::Controllers::CloudConfigsController.new(Config.new({})) }

    describe 'POST', '/' do
      it 'creates a new cloud config' do
        authorize('admin', 'admin')

        properties = "---\nfoo: bar"
        expect {
          post '/', properties, { 'CONTENT_TYPE' => 'text/yaml' }
        }.to change(Bosh::Director::Models::CloudConfig, :count).from(0).to(1)

        expect(Bosh::Director::Models::CloudConfig.first.properties).to eq(properties)
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
    end
  end
end
