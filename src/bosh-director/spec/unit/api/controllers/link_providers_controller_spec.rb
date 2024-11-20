require 'spec_helper'
require 'rack/test'

module Bosh::Director
  module Api
    describe Controllers::LinkProvidersController do
      include Rack::Test::Methods

      subject(:app) { described_class.new(config) }
      let(:config) do
        config = Config.load_hash(SpecHelper.director_config_hash)
        identity_provider = Support::TestIdentityProvider.new(config.get_uuid_provider)
        allow(config).to receive(:identity_provider).and_return(identity_provider)
        config
      end

      before do
        App.new(config)
        basic_authorize 'admin', 'admin'
      end

      context 'when checking link provider' do
        let(:deployment) { Models::Deployment.create(:name => 'test_deployment', :manifest => YAML.dump({'foo' => 'bar'})) }

        it 'list providers endpoint exists' do
          get "/?deployment=#{deployment.name}"
          expect(last_response.status).to eq(200)
        end

        context 'when teams are used' do
          let(:dev_team) { Models::Team.create(:name => 'dev') }
          let(:other_team) { Models::Team.create(:name => 'other') }

          let!(:owned_deployment) { Models::Deployment.create_with_teams(:name => 'owned_deployment', teams: [dev_team], manifest: YAML.dump({'foo' => 'bar'})) }
          let!(:other_deployment) { Models::Deployment.create_with_teams(:name => 'other_deployment', teams: [other_team], manifest: YAML.dump({'foo' => 'bar'})) }

          before do
            basic_authorize 'dev-team-member', 'dev-team-member'
          end

          it 'allows access to owned deployment' do
            expect(get("/?deployment=#{owned_deployment.name}").status).to eq(200)
          end

          it 'denies access to other deployment' do
            expect(get("/?deployment=#{other_deployment.name}").status).to eq(401)
          end
        end

        context 'when user has read access' do
          before do
            basic_authorize 'reader', 'reader'
          end

          it 'returns the links' do
            get "/?deployment=#{deployment.name}"
            expect(last_response.status).to eq(200)
          end
        end

        it 'with invalid link deployment name' do
          get '/?deployment=invalid_deployment_name'
          expect(last_response.status).to eq(404)
          expect(last_response.body).to eq("{\"code\":70000,\"description\":\"Deployment 'invalid_deployment_name' doesn't exist\"}")
        end

        it 'returns 400 if deployment name is not provided' do
          get '/'
          expect(last_response.status).to eq(400)
          expect(last_response.body).to eq('{"code":190024,"description":"Deployment name is required"}')
        end

        context 'and there are providers in the database' do
          let!(:provider_1) do
            Models::Links::LinkProvider.create(
              :deployment => deployment,
              :instance_group => 'instance_group',
              :type => 'job',
              :name => 'job_name_1',
            )
            end
          let!(:provider_intent_1a) do
            Models::Links::LinkProviderIntent.create(
              :name => 'link_name_1a',
              :link_provider => provider_1,
              :shared => true,
              :consumable => true,
              :type => 'link_type_1a',
              :original_name => 'link_original_name_1a',
              :content => 'some link content',
            )
            end
          let!(:provider_intent_1b) do
            Models::Links::LinkProviderIntent.create(
              :name => 'link_name_1b',
              :link_provider => provider_1,
              :shared => true,
              :consumable => true,
              :type => 'link_type_1b',
              :original_name => 'link_original_name_1b',
              :content => 'some link content',
            )
          end
          let!(:provider_2) do
            Models::Links::LinkProvider.create(
              :deployment => deployment,
              :instance_group => 'instance_group',
              :type => 'job',
              :name => 'job_name_2',
            )
            end
          let!(:provider_intent_2) do
            Models::Links::LinkProviderIntent.create(
              :name => 'link_name_2',
              :link_provider => provider_2,
              :shared => false,
              :consumable => true,
              :type => 'link_type_2',
              :original_name => 'link_original_name_2',
              :content => 'I have content',
            )
          end

          it 'should return a list of providers for specified deployment' do
            get "/?deployment=#{provider_1.deployment.name}"
            expect(last_response.status).to eq(200)
            expect(JSON.parse(last_response.body)).to eq([generate_provider_hash(provider_intent_1a),generate_provider_hash(provider_intent_1b),generate_provider_hash(provider_intent_2)])
          end
        end
      end

      def generate_provider_hash(model)
        provider = model.link_provider
        {
          'id' => model.id.to_s,
          'name' => model.name,
          'shared' => model.shared,
          'deployment' => provider.deployment.name,
          'link_provider_definition' =>
            {
              'type' => model.type,
              'name' => model.original_name,
            },
          'owner_object' => {
            'type' => provider.type,
            'name' => provider.name,
            'info' => {
              'instance_group' => provider.instance_group,
            }
          }
        }
      end
    end
  end
end
