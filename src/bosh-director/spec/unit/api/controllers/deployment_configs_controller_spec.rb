require 'spec_helper'
require 'rack/test'
require 'bosh/director/api/controllers/configs_controller'

module Bosh::Director
  describe Api::Controllers::DeploymentConfigsController do
    include Rack::Test::Methods
    RSpec::Matchers.define :equal_deployment_config do |deployment, config|
      match do |actual|
        actual['deployment'] == deployment.name &&
          actual['id'] == deployment.id &&
          actual['config']['id'] == config.id &&
          actual['config']['type'] == config.type &&
          actual['config']['name'] == config.name
      end
    end

    subject(:app) { Api::Controllers::DeploymentConfigsController.new(config) }
    let(:config) do
      config = Config.load_hash(SpecHelper.spec_get_director_config)
      identity_provider = Support::TestIdentityProvider.new(config.get_uuid_provider)
      allow(config).to receive(:identity_provider).and_return(identity_provider)
      config
    end

    describe 'GET', '/' do
      let(:cloud_config) { Models::Config.make(:cloud) }
      let(:named_cloud_config) { Models::Config.make(:cloud, name: 'custom-name') }
      let(:cloud_configs) { [cloud_config, named_cloud_config] }
      let(:deployment_name) { 'fake-dep-name' }
      let(:other_deployment_name) { 'other-dep-name' }

      context 'with authenticated admin user' do
        let!(:deployment) do
          Models::Deployment.make(name: deployment_name).tap do |d|
            d.cloud_configs = cloud_configs
            d.runtime_configs = runtime_configs
          end
        end
        let(:runtime_configs) { [] }

        before(:each) do
          authorize('admin', 'admin')
        end

        context 'when no deployment name is given' do
          it 'returns empty list' do
            get '/'

            expect(last_response.status).to eq(200)
            deployment_configs = JSON.parse(last_response.body)
            expect(deployment_configs.count).to eq(0)
          end
        end

        context 'when one deployment name is given' do
          context 'when cloud configs exist' do
            it 'returns all active configs for that deployment' do
              get "/?deployment[]=#{deployment_name}"

              expect(last_response.status).to eq(200)
              deployment_configs = JSON.parse(last_response.body)
              expect(deployment_configs.count).to eq(2)
              expect(deployment_configs.first).to equal_deployment_config(deployment, cloud_config)
              expect(deployment_configs.last).to equal_deployment_config(deployment, named_cloud_config)
            end
          end

          context 'when cloud and runtime configs exist' do
            let(:runtime_config) { Models::Config.make(:runtime) }
            let(:runtime_configs) { [runtime_config] }

            it 'returns all configs for the deployment' do
              get "/?deployment[]=#{deployment_name}"

              expect(last_response.status).to eq(200)
              deployment_configs = JSON.parse(last_response.body)
              expect(deployment_configs.count).to eq(3)
              config = deployment_configs.find { |dc| dc['config']['id'] == runtime_config.id }
              expect(config).to equal_deployment_config(deployment, runtime_config)
            end
          end
        end

        context 'when multiple deployment names are given' do
          let!(:other_deployment) do
            Models::Deployment.make(name: other_deployment_name).tap do |d|
              d.cloud_configs = cloud_configs
              d.runtime_configs = runtime_configs
            end
          end

          it 'returns one result per config' do
            get "/?deployment[]=#{deployment_name}&deployment[]=#{other_deployment_name}"

            expect(last_response.status).to eq(200)
            deployment_configs = JSON.parse(last_response.body)
            expect(deployment_configs.count).to eq(4)
            expect(deployment_configs.map { |c| c['deployment'] }).to eq(
              [deployment_name, deployment_name, other_deployment_name, other_deployment_name],
            )
          end

          it 'does not error out if deployments are missing' do
            get "/?deployment[]=#{deployment_name}&deployment[]=unknown-name"
            expect(last_response.status).to eq(200)
            deployment_configs = JSON.parse(last_response.body)
            expect(deployment_configs.count).to eq(2)
          end

          it 'does not error out if no deployments are found' do
            get '/?deployment[]=unknown-name'
            expect(last_response.status).to eq(200)
            deployment_configs = JSON.parse(last_response.body)
            expect(deployment_configs.count).to eq(0)
          end
        end
      end

      context 'with authenticated team user' do
        before(:each) do
          authorize('dev-team-member', 'dev-team-member')
        end

        let!(:dev_team) { Models::Team.make(name: 'dev') }
        let!(:deployment) do
          Models::Deployment.make(name: deployment_name).tap do |d|
            d.teams = [dev_team]
            d.cloud_configs = cloud_configs
          end
        end
        let!(:other_deployment) do
          Models::Deployment.make(name: other_deployment_name).tap do |d|
            d.cloud_configs = cloud_configs
          end
        end

        it "lists only deployment configs that belong to the teams' deployments" do
          get "/?deployment[]=#{deployment_name}&deployment[]=#{other_deployment_name}"

          expect(last_response.status).to eq(200)
          deployment_configs = JSON.parse(last_response.body)
          expect(deployment_configs.count).to eq(2)
          expect(deployment_configs.map { |c| c['deployment'] }).to eq(
            [deployment_name, deployment_name],
          )
        end
      end
    end
  end
end
