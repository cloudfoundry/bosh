require 'spec_helper'
require 'bosh/director/models/deployment'

module Bosh::Director::Models
  describe Deployment do

    subject(:deployment) { described_class.make }

    describe '#tainted_instances' do
      context 'when there are no tainted instances' do
        it 'returns an empty array' do
          expect(deployment.tainted_instances).to eq([])
        end
      end

      context 'when there are tainted instances' do
        it 'includes only the tainted instances from the current deployment' do
          tainted_instance = Instance.make(tainted: true, deployment: deployment)
          Instance.make(tainted: false, deployment: deployment)
          foreign_deployment = Deployment.make(name: 'different')
          Instance.make(tainted: false, deployment: foreign_deployment)

          expect(deployment.tainted_instances).to eq([tainted_instance])
        end
      end
    end
  end
end
