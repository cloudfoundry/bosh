require 'spec_helper'
require 'rack/test'

module Bosh::Director
  module Api
    describe Controllers::LinksController do
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

      context 'when checking links' do
        let(:deployment) { Models::Deployment.create(:name => 'test_deployment', :manifest => YAML.dump({'foo' => 'bar'})) }

        it 'list links endpoint exists' do
          get "/?deployment=#{deployment.name}"
          expect(last_response.status).to eq(200)
        end

        context 'when teams are used' do
          let(:dev_team) { Models::Team.create(:name => 'dev') }
          let(:other_team) { Models::Team.create(:name => 'other') }

          let!(:owned_deployment) { Models::Deployment.create_with_teams(:name => 'owned_deployment', teams: [dev_team], manifest: YAML.dump({'foo' => 'bar'})) }
          let!(:other_deployment) { Models::Deployment.create_with_teams(:name => 'other_deployment', teams: [other_team], manifest: YAML.dump({'foo' => 'bar'})) }

          before do
            basic_authorize 'dev-team-read-member', 'dev-team-read-member'
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

        context 'and there are links in the database' do
          let!(:consumer_1) do
            Models::Links::LinkConsumer.create(
              :deployment => deployment,
              :instance_group => 'instance_group',
              :type => 'job',
              :name => 'job_name_1',
            )
            end
          let!(:consumer_intent_1) do
            Models::Links::LinkConsumerIntent.create(
              :link_consumer => consumer_1,
              :original_name => 'link_1',
              :type => 'link_type_1',
              :optional => false,
              :blocked => false,
            )
          end
          let!(:consumer_2) do
            Models::Links::LinkConsumer.create(
              :deployment => deployment,
              :instance_group => 'instance_group',
              :type => 'job',
              :name => 'job_name_2',
            )
          end
          let!(:consumer_intent_2) do
            Models::Links::LinkConsumerIntent.create(
              :link_consumer => consumer_2,
              :original_name => 'link_2',
              :type => 'link_type_2',
              :optional => false,
              :blocked => false,
              )
          end
          let!(:link_1) do
            Models::Links::Link.create(
              :name => 'link_1',
              :link_provider_intent_id => nil,
              :link_consumer_intent_id => consumer_intent_1.id,
              :link_content => "content 1",
              :created_at => Time.now
            )
          end
          let!(:link_2) do
            Models::Links::Link.create(
              :name => 'link_2',
              :link_provider_intent_id => nil,
              :link_consumer_intent_id => consumer_intent_2.id,
              :link_content => "content 2",
              :created_at => Time.now
            )
          end

          it 'should return a list of links for specified deployment' do
            get "/?deployment=#{consumer_1.deployment.name}"
            expect(last_response.status).to eq(200)
            expect(JSON.parse(last_response.body)).to eq([generate_link_hash(link_1), generate_link_hash(link_2)])
          end
        end
      end

      def generate_link_hash(model)
        {
          'id' => model.id,
          'name' => model.name,
          'link_consumer_id' => model[:link_consumer_intent_id],
          'link_provider_id' => model[:link_provider_intent_id],
          'created_at' => model.created_at.to_s,
        }
      end
    end
  end
end
