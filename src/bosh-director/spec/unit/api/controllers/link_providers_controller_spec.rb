require 'spec_helper'
require 'rack/test'

module Bosh::Director
  module Api
    describe Controllers::LinkProvidersController do
      include Rack::Test::Methods

      subject(:app) { described_class.new(config) }
      let(:config) do
        config = Config.load_hash(SpecHelper.spec_get_director_config)
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
            Models::LinkProvider.create(
              :name => 'link_name_1',
              :deployment => deployment,
              :instance_group => 'instance_group',
              :shared => true,
              :consumable => true,
              :link_provider_definition_type => 'link_type_1',
              :link_provider_definition_name => 'link_original_name_1',
              :owner_object_type => 'job',
              :content => 'some link content',
              :owner_object_name => 'job_name_1',
            )
          end
          let!(:provider_2) do
            Models::LinkProvider.create(
              :name => 'link_name_2',
              :deployment => deployment,
              :instance_group => 'instance_group',
              :shared => false,
              :consumable => true,
              :link_provider_definition_type => 'link_type_2',
              :link_provider_definition_name => 'link_original_name_2',
              :owner_object_type => 'job',
              :content => 'I have content',
              :owner_object_name => 'job_name_2',
            )
          end

          it 'should return a list of providers for specified deployment' do
            get "/?deployment=#{provider_1.deployment.name}"
            expect(last_response.status).to eq(200)
            expect(JSON.parse(last_response.body)).to eq([generate_provider_hash(provider_1),generate_provider_hash(provider_2)])
          end
        end
      end

      def generate_provider_hash(model)
        {
          'id' => model.id,
          'name' => model.name,
          'shared' => model.shared,
          'deployment' => model.deployment.name,
          'instance_group' => model.instance_group,
          'link_provider_definition' => {
            'type' => model.link_provider_definition_type,
            'name' => model.link_provider_definition_name
          },
          'owner_object' => {
            'type' => model.owner_object_type,
            'name' => model.owner_object_name,
          },
          'content' => model.content
        }
      end
    end
  end
end
