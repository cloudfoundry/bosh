
require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe PlacementPlanner::UnplacedExistingInstances do
    subject { PlacementPlanner::UnplacedExistingInstances.new([instance1, instance2, instance3]) }

    let(:instance1) { Bosh::Director::Models::Instance.make(availability_zone: '1') }
    let(:instance2) { Bosh::Director::Models::Instance.make(availability_zone: '2') }
    let(:instance3) { Bosh::Director::Models::Instance.make(availability_zone: '3') }

    describe 'azs' do
      it 'should return a list of azs' do
        expect(subject.azs).to eq(%w(1 2 3))
      end
    end
  end
end
