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
      let(:link_serial_id) { 42 }
      let(:deployment) { Models::Deployment.create(:name => 'test_deployment', :manifest => YAML.dump({'foo' => 'bar'}), :links_serial_id => link_serial_id) }

      before do
        App.new(config)
        basic_authorize 'admin', 'admin'
      end

      context 'when checking links' do
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

      context 'when creating links' do
        context 'validate payload' do
          context 'when link_provider_id is invaid' do
            it 'raise error for missing link_provider_id' do
              post "/", JSON.generate('{}'), { 'CONTENT_TYPE' => 'application/json' }
              expect(last_response.status).to eq(400)
              expect(last_response.body).to eq('{"code":810001,"description":"Invalid json: provide valid `link_provider_id`"}')
            end
            it 'raise error for invalid link_provider_id' do
              # TODO Links: check if Integer validation is required or not?
              post "/", JSON.generate({"link_provider_id"=> "3"}), { 'CONTENT_TYPE' => 'application/json' }
              expect(last_response.status).to eq(400)
              expect(last_response.body).to eq('{"code":810001,"description":"Invalid json: provide valid `link_provider_id`"}')
            end
          end
          context 'when link_consumer is invalid' do
            it 'raise error for missing link_consumer' do
              post "/", JSON.generate({"link_provider_id"=> 3,}), { 'CONTENT_TYPE' => 'application/json' }
              expect(last_response.status).to eq(400)
              expect(last_response.body).to eq('{"code":810001,"description":"Invalid json: missing `link_consumer`"}')
            end
            it 'raise error for invalid owner_object_name' do
              post "/", JSON.generate({"link_provider_id"=> 3, "link_consumer"=> {"owner_object_name" => ""}}), { 'CONTENT_TYPE' => 'application/json' }
              expect(last_response.status).to eq(400)
              expect(last_response.body).to eq('{"code":810001,"description":"Invalid json: provide valid `owner_object_name`"}')
            end
          end

          context 'when link_provider_id and link_consumer are provided' do
            let(:provider_id) { 42 }
            let!(:payload_json) do
              {
                'link_provider_id'=> provider_id,
                'link_consumer' => {
                  'owner_object_name'=> 'external_consumer_1',
                  'owner_object_type'=> 'external',
                }
              }
            end

            it 'raise error for non-existing provider_id' do
              post "/", JSON.generate(payload_json), { 'CONTENT_TYPE' => 'application/json' }
              expect(last_response.status).to eq(400)
              expect(last_response.body).to eq('{"code":810001,"description":"Invalid link_provider_id: 42"}')
            end

            context "when a valid link_provider_id is provided" do
              let(:username) { 'LINK_CREATOR' }
              let(:provider_json_content) {'{"db_az_link":{"address":"q-a1s0.implicit-provider-ig.a.implicit-deployment.bosh"}}'}
              let(:provider_1) do
                Bosh::Director::Models::Links::LinkProvider.create(
                  deployment: deployment,
                  instance_group: 'instance_group',
                  name: 'provider_name_1',
                  type: 'job',
                  serial_id: link_serial_id,
                  )
              end
              let(:provider_1_intent_1) do
                Bosh::Director::Models::Links::LinkProviderIntent.create(
                  name: 'provider_intent_1_name_1',
                  link_provider: provider_1,
                  shared: true,
                  consumable: true,
                  type: 'link_type_1',
                  original_name: 'provider_name_1',
                  content: provider_json_content,
                  serial_id: link_serial_id,
                  )
              end
              let(:provider_id) { provider_1_intent_1.id }

              shared_examples 'creates consumer and link' do
                it 'returns links' do
                  post "/", JSON.generate(payload_json), { 'CONTENT_TYPE' => 'application/json' }
                  expect(last_response.status).to eq(200)

                  new_external_consumer = Bosh::Director::Models::Links::LinkConsumer.find(
                    deployment: deployment,
                    instance_group: 'instance_group',
                    name: "external_consumer_1",
                    type: "external"
                  )
                  expect(new_external_consumer).to_not be_nil
                  expect(new_external_consumer.name).to eq(payload_json["link_consumer"]["owner_object_name"])

                  new_external_link = Bosh::Director::Models::Links::Link.find(
                    link_provider_intent_id: provider_1_intent_1 && provider_1_intent_1[:id],
                    link_consumer_intent_id: new_external_consumer && new_external_consumer[:id],
                  )
                  expect(new_external_link).to_not be_nil
                  expect(JSON.parse(last_response.body)).to eq(generate_link_hash(new_external_link))
                end
              end


              context 'when NO network in provided' do
                include_examples 'creates consumer and link'
              end

              context 'when network in providerd' do
                let(:networks) { ['neta', 'netb'] }
                let(:provider_json_content) {   {
                  default_network: 'netb',
                  networks: networks,
                  instances: [
                    {
                      dns_addresses: {neta: 'dns1', netb: 'dns2'},
                      addresses: {neta: 'ip1', netb: 'ip2'}
                    }
                  ]
                  }.to_json
                }
                context 'when network is valid' do
                  let(:payload_json) do
                    {
                      'link_provider_id'=> provider_id,
                      'link_consumer' => {
                        'owner_object_name'=> 'external_consumer_1',
                        'owner_object_type'=> 'external',
                      },
                      'network' => networks[0]
                    }
                  end
                  include_examples 'creates consumer and link'
                end

                context 'when network in invalid' do
                  let(:payload_json) do
                    {
                      'link_provider_id'=> provider_id,
                      'link_consumer' => {
                        'owner_object_name'=> 'external_consumer_1',
                        'owner_object_type'=> 'external',
                      },
                      'network' => 'invalid-network-name'
                    }
                  end

                  it 'return error' do
                    post "/", JSON.generate(payload_json), { 'CONTENT_TYPE' => 'application/json' }
                    expect(last_response.status).to eq(400)

                    error_string = '{"code":810003,"description":"Can\'t resolve network: `invalid-network-name` in provider id: 1 for `external_consumer_1`"}'
                    expect(last_response.body).to eq(error_string)
                  end
                end
              end
            end
          end

          context 'when user is not authenticated' do
            before do
              basic_authorize 'invalid', 'invalid'
            end

            it 'should raise an error' do
              post '/', '{}', 'CONTENT_TYPE' => 'application/json'
              expect(last_response.status).to eq(401)
              expect(last_response.body).to start_with('Not authorized:')
            end
          end
        end
      end

      context 'when deleting links' do
        context 'when the user is not authenticated' do
          before do
            basic_authorize 'invalid', 'invalid'
          end

          it 'should raise an error' do
            delete '/3'
            expect(last_response.status).to eq(401)
            expect(last_response.body).to start_with('Not authorized:')
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
