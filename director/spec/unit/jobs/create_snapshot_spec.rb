require 'spec_helper'

module Bosh::Director
  describe Jobs::CreateSnapshot do
    let(:instance) { Models::Instance.make }
    let(:options) { {} }
    let(:instance_manager) { instance_double('Bosh::Director::Api::InstanceManager') }
    let(:cids) { %w[snap0 snap1] }

    subject { described_class.new(instance.id, options) }

    describe 'Resque job class expectations' do
      let(:job_type) { :create_snapshot }
      it_behaves_like 'a Resque job'
    end

    it 'tells the snapshot manager to create a snapshot' do
      Api::SnapshotManager.should_receive(:take_snapshot).with(instance, options).and_return(cids)

      expect(subject.perform).to eq 'snapshot(s) snap0, snap1 created'
    end
  end
end
