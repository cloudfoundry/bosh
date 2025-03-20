require 'spec_helper'

module Bosh::Director
  describe Jobs::CreateSnapshot do
    let(:instance) do
      is = FactoryBot.create(:models_instance)
      vm = FactoryBot.create(:models_vm, instance_id: is.id)
      is.active_vm = vm
      is
    end
    let(:options) do
      {}
    end
    let(:instance_manager) { instance_double('Bosh::Director::Api::InstanceManager') }
    let(:cids) { %w[snap0 snap1] }

    subject { described_class.new(instance.id, options) }

    describe 'DJ job class expectations' do
      let(:job_type) { :create_snapshot }
      let(:queue) { :normal }
      it_behaves_like 'a DelayedJob job'
    end

    it 'tells the snapshot manager to create a snapshot' do
      expect(Api::SnapshotManager).to receive(:take_snapshot).with(instance, options).and_return(cids)

      expect(subject.perform).to eq 'snapshot(s) snap0, snap1 created'
    end
  end
end
