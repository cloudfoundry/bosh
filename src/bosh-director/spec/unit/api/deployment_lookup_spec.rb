require 'spec_helper'
require 'bosh/director/api/deployment_lookup'

module Bosh::Director
  module Api
    describe DeploymentLookup do
      let(:deployment) { instance_double('Bosh::Director::Models::Deployment') }
      subject(:deployment_lookup) { DeploymentLookup.new }

      describe '.by_name' do
        let(:deployment_name) { 'bob' }

        before do
          allow(Models::Deployment).to receive(:[]).with(name: deployment_name).and_return(deployment)
        end

        it 'finds deployment for name' do
          expect(deployment_lookup.by_name(deployment_name)).to eq deployment
        end

        context 'no deployment exists for name' do
          let(:deployment) { nil }

          it 'raises' do
            expect {
              deployment_lookup.by_name(deployment_name)
            }.to raise_error(DeploymentNotFound, "Deployment 'bob' doesn't exist")
          end
        end
      end
    end
  end
end
