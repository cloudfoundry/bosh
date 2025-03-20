
require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe PlacementPlanner::UnplacedExistingInstances do
    subject { PlacementPlanner::UnplacedExistingInstances.new([instance1, instance2, instance3, instance4, instance5]) }

    let(:instance1) { FactoryBot.create(:models_instance, availability_zone: '1') }
    let(:instance2) { FactoryBot.create(:models_instance, availability_zone: '2') }
    let(:instance3) { FactoryBot.create(:models_instance, availability_zone: '3') }
    let(:instance4) { FactoryBot.create(:models_instance, availability_zone: '2') }
    let(:instance5) { FactoryBot.create(:models_instance, availability_zone: nil) }

    describe 'azs' do
      it 'should return an un-de-duped list of azs, decreasing when they are claimed, stripping nil azs' do
        expect(subject.azs).to eq(%w(1 2 2 3))
        subject.claim_instance_for_az(double(name: '2'))
        expect(subject.azs).to eq(%w(1 2 3))
      end
    end
  end
end
