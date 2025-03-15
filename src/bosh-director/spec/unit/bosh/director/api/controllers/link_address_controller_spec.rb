require 'spec_helper'
require 'rack/test'

module Bosh::Director
  module Api
    describe Controllers::LinkAddressController do
      include Rack::Test::Methods

      subject(:app) { described_class.new(config) }
      let(:config) do
        config = Config.load_hash(SpecHelper.director_config_hash)
        identity_provider = Support::TestIdentityProvider.new(config.get_uuid_provider)
        allow(config).to receive(:identity_provider).and_return(identity_provider)
        config
      end

      let(:deployment) { FactoryBot.create(:models_deployment) }

      let(:external_consumer) do
        Bosh::Director::Models::Links::LinkConsumer.create(
          deployment: deployment,
          instance_group: '',
          name: 'external_consumer_1',
          type: 'external',
        )
      end

      let(:external_consumer_intent) do
        Bosh::Director::Models::Links::LinkConsumerIntent.create(
          link_consumer: external_consumer,
          original_name: 'link_name',
          type: 'link_type',
        )
      end

      let!(:link) do
        Bosh::Director::Models::Links::Link.create(
          link_consumer_intent: external_consumer_intent,
          link_content: '{"deployment_name": "dep_foo", "instance_group": "ig_bar", "default_network": "baz", "domain": "bosh"}',
          name: 'external_consumer_link',
        )
      end

      before do
        App.new(config)
      end

      context 'when the user has director read permissions' do
        before do
          basic_authorize 'reader', 'reader'
        end

        context 'when the link id is not specified' do
          it 'should return a "bad request" response' do
            get '/'
            expect(last_response.status).to eq(400)
            expect(JSON.parse(last_response.body)['description']).to eq('Link id is required')
          end
        end

        context 'when link does not exist' do
          it 'should return link not found' do
            get '/?link_id=1337'
            expect(last_response.status).to eq(404)
            expect(JSON.parse(last_response.body)['description']).to eq('Could not find a link with id 1337')
          end
        end

        context 'when link exists' do
          it 'should return the address in a hash' do
            get "/?link_id=#{link.id}"
            expect(last_response.status).to eq(200)
            response = JSON.parse(last_response.body)
            expect(response).to eq('address' => 'q-s0.ig-bar.baz.dep-foo.bosh')
          end

          context 'when a single az is specified' do
            let!(:az1) { Models::LocalDnsEncodedAz.create(name: 'z1') }
            let!(:az2) { Models::LocalDnsEncodedAz.create(name: 'z2') }

            it 'should return the address with the az information' do
              get "/?link_id=#{link.id}&azs[]=z1"
              expect(last_response.status).to eq(200)
              response = JSON.parse(last_response.body)
              expect(response).to eq('address' => "q-a#{az1.id}s0.ig-bar.baz.dep-foo.bosh")
            end

            context 'when the az is specified as not an array' do
              it 'should raise an error' do
                get "/?link_id=#{link.id}&azs=z1"
                expect(last_response.status).to eq(400)
                response = JSON.parse(last_response.body)
                expect(response["description"]).to eq('`azs` param must be array type: `azs[]=`')
              end
            end
          end

          context 'when multiple azs are specified' do
            let!(:az1) { Models::LocalDnsEncodedAz.create(name: 'z1') }
            let!(:az2) { Models::LocalDnsEncodedAz.create(name: 'z2') }

            it 'should return the address with the az information' do
              get "/?link_id=#{link.id}&azs[]=z1&azs[]=z2"
              expect(last_response.status).to eq(200)
              response = JSON.parse(last_response.body)
              expect(response).to eq('address' => "q-a#{az1.id}a#{az2.id}s0.ig-bar.baz.dep-foo.bosh")
            end
          end

          context 'when "healthy" status is specified' do
            it 'should return the query address with the status information' do
              get "/?link_id=#{link.id}&status=healthy"
              expect(last_response.status).to eq(200)
              response = JSON.parse(last_response.body)
              expect(response).to eq('address' => 'q-s3.ig-bar.baz.dep-foo.bosh')
            end
          end

          context 'when "unhealthy" status is specified' do
            it 'should return the query address with the status information' do
              get "/?link_id=#{link.id}&status=unhealthy"
              expect(last_response.status).to eq(200)
              response = JSON.parse(last_response.body)
              expect(response).to eq('address' => 'q-s1.ig-bar.baz.dep-foo.bosh')
            end
          end

          context 'when "all" status is specified' do
            it 'should return the query address with the status information' do
              get "/?link_id=#{link.id}&status=all"
              expect(last_response.status).to eq(200)
              response = JSON.parse(last_response.body)
              expect(response).to eq('address' => 'q-s4.ig-bar.baz.dep-foo.bosh')
            end
          end

          context 'when "default" status is specified' do
            it 'should return the query address with the status information' do
              get "/?link_id=#{link.id}&status=default"
              expect(last_response.status).to eq(200)
              response = JSON.parse(last_response.body)
              expect(response).to eq('address' => 'q-s0.ig-bar.baz.dep-foo.bosh')
            end
          end

          context 'when an invalid status is specified' do
            it 'should return a 400 bad request' do
              get "/?link_id=#{link.id}&status=foobar"
              expect(last_response.status).to eq(400)
              response = JSON.parse(last_response.body)
              expect(response["description"]).to eq('status must be a one of: ["healthy", "unhealthy", "all", "default"]')
            end
          end

          context 'when an invalid status is specified (array)' do
            it 'should return a 400 bad request' do
              get "/?link_id=#{link.id}&status[]=healthy"
              expect(last_response.status).to eq(400)
              response = JSON.parse(last_response.body)
              expect(response["description"]).to eq('status must be a one of: ["healthy", "unhealthy", "all", "default"]')
            end
          end

          context 'and the link is manual' do
            let(:provider) do
              Bosh::Director::Models::Links::LinkProvider.create(
                deployment: deployment,
                instance_group: 'instance_group',
                name: 'manual_provider_name',
                type: 'manual',
                )
            end

            let(:provider_intent) do
              Models::Links::LinkProviderIntent.create(
                name: 'manual_link_name',
                link_provider: provider,
                shared: true,
                consumable: true,
                type: 'spaghetti',
                original_name: 'napolean',
                content: {}.to_json,
                )
            end

            let!(:link) do
              Bosh::Director::Models::Links::Link.create(
                link_provider_intent: provider_intent,
                link_consumer_intent: external_consumer_intent,
                link_content: link_content.to_json,
                name: 'napolean',
                )
            end

            let(:link_content) do
              {
                'address' => '192.168.1.254'
              }
            end

            it 'returns the manual link address content' do
              get "/?link_id=#{link.id}"
              expect(last_response.status).to eq(200)
              response = JSON.parse(last_response.body)
              expect(response).to eq('address' => '192.168.1.254')
            end
          end
        end
      end

      context 'when the user has admin permissions' do
        before do
          basic_authorize 'admin', 'admin'
        end

        context 'when the link id is not specified' do
          it 'should return a "bad request" response' do
            get '/'
            expect(last_response.status).to eq(400)
            expect(JSON.parse(last_response.body)['description']).to eq('Link id is required')
          end
        end

        context 'when link does not exist' do
          it 'should return link not found' do
            get '/?link_id=1337'
            expect(last_response.status).to eq(404)
            expect(JSON.parse(last_response.body)['description']).to eq('Could not find a link with id 1337')
          end
        end

        context 'when link exists' do
          it 'should return the address in a hash' do
            get "/?link_id=#{link.id}"
            expect(last_response.status).to eq(200)
            response = JSON.parse(last_response.body)
            expect(response).to eq('address' => 'q-s0.ig-bar.baz.dep-foo.bosh')
          end
        end
      end

      context 'when the deployment is created with teams' do
        let(:dev_team) { Models::Team.create(name: 'dev') }
        let(:other_team) { Models::Team.create(name: 'other') }

        let!(:deployment) do
          Models::Deployment.create_with_teams(name: 'owned_deployment', teams: [dev_team], manifest: YAML.dump('foo' => 'bar'))
        end
        let!(:other_deployment) do
          Models::Deployment.create_with_teams(name: 'other_deployment', teams: [other_team], manifest: YAML.dump('foo' => 'bar'))
        end

        let(:other_consumer) do
          Bosh::Director::Models::Links::LinkConsumer.create(
            deployment: other_deployment,
            instance_group: '',
            name: 'other_consumer_1',
            type: 'external',
            )
        end

        let(:other_consumer_intent) do
          Bosh::Director::Models::Links::LinkConsumerIntent.create(
            link_consumer: other_consumer,
            original_name: 'other_link_name',
            type: 'other_link_type',
            )
        end

        let!(:other_link) do
          Bosh::Director::Models::Links::Link.create(
            link_consumer_intent: other_consumer_intent,
            link_content:
              '{"deployment_name": "other_deployment", "instance_group": "other_ig_bar", ' \
              '"default_network": "other_baz", "domain": "bosh"}',
            name: 'other_consumer_link',
            )
        end

        before do
          basic_authorize 'dev-team-read-member', 'dev-team-read-member'
        end

        context 'when the user has team read permissions' do
          before do
            basic_authorize 'dev-team-read-member', 'dev-team-read-member'
          end

          context 'when the link id is not specified' do
            it 'should return a "bad request" response' do
              get '/'
              expect(last_response.status).to eq(400)
              expect(JSON.parse(last_response.body)['description']).to eq('Link id is required')
            end
          end

          context 'when link does not exist' do
            it 'should return link not found' do
              get '/?link_id=1337'
              expect(last_response.status).to eq(404)
              expect(JSON.parse(last_response.body)['description']).to eq('Could not find a link with id 1337')
            end
          end

          context 'when link exists' do
            it 'should return the address in a hash' do
              get "/?link_id=#{link.id}"
              expect(last_response.status).to eq(200)
              response = JSON.parse(last_response.body)
              expect(response).to eq('address' => 'q-s0.ig-bar.baz.dep-foo.bosh')
            end
          end
        end

        context 'when the user has team admin permissions' do
          before do
            basic_authorize 'dev-team-member', 'dev-team-member'
          end

          context 'when the link id is not specified' do
            it 'should return a "bad request" response' do
              get '/'
              expect(last_response.status).to eq(400)
              expect(JSON.parse(last_response.body)['description']).to eq('Link id is required')
            end
          end

          context 'when link does not exist' do
            it 'should return link not found' do
              get '/?link_id=1337'
              expect(last_response.status).to eq(404)
              expect(JSON.parse(last_response.body)['description']).to eq('Could not find a link with id 1337')
            end
          end

          context 'when link exists' do
            it 'should return the address in a hash' do
              get "/?link_id=#{link.id}"
              expect(last_response.status).to eq(200)
              response = JSON.parse(last_response.body)
              expect(response).to eq('address' => 'q-s0.ig-bar.baz.dep-foo.bosh')
            end
          end
        end

        context 'when the user does not have read/admin permissions' do
          before do
            basic_authorize 'outsider', 'outsider'
          end

          it 'should return with unauthorized error' do
            get "/?link_id=#{other_link.id}"
            expect(last_response.status).to eq(401)
            response = JSON.parse(last_response.body)
            expect(response['description']).to match(
              'Require one of the scopes: bosh.admin, bosh\..*\.admin, ' \
              'bosh.read, bosh\..*\.read',
            )
          end
        end
      end
    end
  end
end
