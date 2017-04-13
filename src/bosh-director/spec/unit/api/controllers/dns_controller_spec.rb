require 'spec_helper'
require 'rack/test'

module Bosh::Director
  module Api
    describe Controllers::DnsController do
      include Rack::Test::Methods

      subject(:app) { described_class.new(config) }
      let(:config) do
        config = Config.load_hash(SpecHelper.spec_get_director_config.merge({'dns' => {'domain_name' => root_domain}}))
        identity_provider = Support::TestIdentityProvider.new(config.get_uuid_provider)
        allow(config).to receive(:identity_provider).and_return(identity_provider)
        config
      end

      let(:dev_team) { Models::Team.create(:name => 'dev') }
      let(:other_team) { Models::Team.create(:name => 'other') }
      let!(:deployment_model) { Models::Deployment.create_with_teams(:name => 'deployment1', teams: [dev_team]) }
      let!(:other_deployment) { Models::Deployment.create_with_teams(:name => 'some-other-deployment', teams: [other_team]) }

      let(:root_domain) { 'bosh1.tld' }

      let(:instance_model) do
        Models::Instance.make(
          uuid: 'instance-uuid1',
          index: 1,
          deployment: deployment_model,
          job: 'group1',
          availability_zone: 'az1',
          spec_json: JSON.dump(spec_json),
        )
      end

      let!(:active_vm) do
        Models::Vm.make(
          agent_id: 'some-agent-id',
          instance: instance_model,
          active: true
        )
      end

      let(:spec_json) { {'networks' => {'network1' => {'ip' => '1234'}}} }

      before do
        App.new(config)
        basic_authorize 'admin', 'admin'
      end

      it 'returns a dns record for a specific instance' do
        response = get '/?deployment=deployment1&instance_group=group1&instance=instance-uuid1&network=network1'

        expect(response.status).to eq(200)
        expect(response.headers['Content-type']).to eq('application/json')
        expect(JSON.parse(response.body)).to eq([{'name' => 'instance-uuid1.group1.network1.deployment1.bosh1.tld'}])
      end

      it 'errors when network is not configured' do
        response = get '/?deployment=deployment1&instance_group=group1&instance=instance-uuid1&network=network27'

        expect(response.status).to eq(400)
        expect(response.body).to eq('network not found')
      end

      context 'missing parameters' do
        it '400 errors without deployment' do
          response = get '/'

          expect(response.status).to eq(400)
          expect(response.body).to eq('missing parameter deployment')
        end

        it '400 errors without instance_group' do
          response = get '/?deployment=deployment1'

          expect(response.status).to eq(400)
          expect(response.body).to eq('missing parameter instance_group')
        end

        it '400 errors without instance' do
          response = get '/?deployment=deployment1&instance_group=group1'

          expect(response.status).to eq(400)
          expect(response.body).to eq('missing parameter instance')
        end

        it '400 errors without network' do
          response = get '/?deployment=deployment1&instance_group=group1&instance=instance-uuid1'

          expect(response.status).to eq(400)
          expect(response.body).to eq('missing parameter network')
        end
      end

      context 'authorization' do
        context 'non-team member accessing' do
          before { basic_authorize 'dev-team-member', 'dev-team-member' }

          it 'allows access to owned deployment' do
            response = get '/?deployment=deployment1&instance_group=group1&instance=instance-uuid1&network=network1'

            expect(response.status).to eq(200)
          end

          it 'denies access to other deployment' do
            response = get '/?deployment=some-other-deployment&instance_group=group1&instance=instance-uuid1&network=network1'

            expect(response.status).to eq(401)
          end
        end
      end
    end
  end
end
