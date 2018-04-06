require 'spec_helper'
require 'rack/test'

module Bosh::Director
  module Api
    describe Controllers::LinkAddressController do
      include Rack::Test::Methods

      subject(:app) { described_class.new(config) }
      let(:config) do
        config = Config.load_hash(SpecHelper.spec_get_director_config)
        identity_provider = Support::TestIdentityProvider.new(config.get_uuid_provider)
        allow(config).to receive(:identity_provider).and_return(identity_provider)
        config
      end

      let!(:consumer_1) do
        Models::Links::LinkConsumer.create(
          deployment: deployment,
          instance_group: 'instance_group',
          type: 'job',
          name: 'job_name_1',
          )
      end
      let!(:consumer_intent_1) do
        Models::Links::LinkConsumerIntent.create(
          link_consumer: consumer_1,
          original_name: 'link_1',
          type: 'link_type_1',
          optional: false,
          blocked: false,
          )
      end
      let(:deployment) { Models::Deployment.create(:name => 'test_deployment', :manifest => YAML.dump({'foo' => 'bar'})) }


      before do
        App.new(config)
        basic_authorize 'admin', 'admin'

        link_content = {
          'instances' => [
            {
              'az' => 'az1',
              'address' => '127.0.0.1'
            },
            {
              'az' => 'az2',
              'address' => '127.0.0.2'
            },
            {
              'az' => 'az3',
              'address' => '127.0.0.3'
            }
          ]
        }

        Models::Links::Link.create(
          name: 'link_1',
          link_provider_intent_id: nil,
          link_consumer_intent_id: consumer_intent_1.id,
          link_content: link_content.to_json,
          created_at: Time.now,
          )
      end

      context 'when checking link address' do
        it 'should raise an error if the link id is not specified' do
          get "/"
          expect(last_response.status).to eq(400)
          expect(JSON.parse(last_response.body)['description']).to eq("Link id is required")
        end

        context 'when link does not exist' do
          it 'should return link not found' do
            get "/?link_id=1337"
            expect(last_response.status).to eq(404)
            expect(JSON.parse(last_response.body)['description']).to eq("Could not find the link id 1337")
          end
        end

        context 'when link exists' do
          it 'should find all link addresses for no az specified' do
            get '/?link_id=1'
            expect(last_response.status).to eq(200)
            response = JSON.parse(last_response.body)
            expect(response.count).to eq(3)
            expect(response).to include({'az' => 'az1', 'address' => '127.0.0.1'})
            expect(response).to include({'az' => 'az2', 'address' => '127.0.0.2'})
            expect(response).to include({'az' => 'az3', 'address' => '127.0.0.3'})
          end

          it 'should find the address for a specific az' do
            get '/?link_id=1&az=az1'
            expect(last_response.status).to eq(200)
            response = JSON.parse(last_response.body)
            expect(response.count).to eq(1)
            expect(response.first).to eq({'az' => 'az1', 'address' => '127.0.0.1'})
          end

          it 'should find the address for multiple azs' do
            get '/?link_id=1&az[]=az1&az[]=az2'
            expect(last_response.status).to eq(200)
            response = JSON.parse(last_response.body)
            expect(response.count).to eq(2)
            expect(response).to include({'az' => 'az1', 'address' => '127.0.0.1'})
            expect(response).to include({'az' => 'az2', 'address' => '127.0.0.2'})
          end
        end
      end

      context 'when user has read access' do
        before do
          basic_authorize 'reader', 'reader'
        end

        it 'returns the links' do
          get "/?link_id=1"
          expect(last_response.status).to eq(200)
        end
      end

      context 'when user has dev-team-member access' do
        before do
          basic_authorize 'dev-team-member', 'dev-team-member'
        end

        it 'does not return the links' do
          get "/?link_id=1"
          expect(last_response.status).to eq(401)
        end
      end

    end
  end
end
