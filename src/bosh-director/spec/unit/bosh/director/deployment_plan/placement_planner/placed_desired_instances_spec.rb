
require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe PlacementPlanner::PlacedDesiredInstances do
    subject { PlacementPlanner::PlacedDesiredInstances.new([az1, az2, az3]) }

    let(:az1) { AvailabilityZone.new('1', {}) }
    let(:az2) { AvailabilityZone.new('2', {}) }
    let(:az3) { AvailabilityZone.new('3', {}) }

    describe 'az_placement_count' do
      it 'should give us an az placement count' do
        expect(subject.az_placement_count).to eq({az1 => 0, az2 => 0, az3 => 0})
      end

      context 'with nil az' do
        let(:az3) { nil }

        it 'should give us az placement count, excluding nil azs' do
          expect(subject.az_placement_count).to eq({az1 => 0, az2 => 0})
        end
      end
    end
  end
end
