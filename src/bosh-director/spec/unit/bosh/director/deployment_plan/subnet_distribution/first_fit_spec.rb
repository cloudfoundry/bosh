require 'spec_helper'

module Bosh::Director::DeploymentPlan
  module SubnetDistribution
    describe FirstFit do
      subject(:strategy) { described_class.new }

      it 'returns candidate subnets unchanged (manifest order)' do
        candidates = [double('subnet-a'), double('subnet-b'), double('subnet-c')]

        expect(strategy.order(candidates, double('reservation'))).to eq(candidates)
      end

      it 'ignores allocation and release notifications' do
        candidates = [double('subnet-a'), double('subnet-b')]

        expect { strategy.record_allocation(double('network'), candidates.first) }.not_to raise_error
        expect { strategy.record_release(double('network'), candidates.first) }.not_to raise_error
        expect(strategy.order(candidates, double('reservation'))).to eq(candidates)
      end
    end
  end
end
