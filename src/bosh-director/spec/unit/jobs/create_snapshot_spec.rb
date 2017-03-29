require 'spec_helper'

module Bosh::Director
  describe Jobs::CreateSnapshot do
    let(:vm) { Models::Vm.make }
    let(:instance) do
      is = Models::Instance.make
      is.add_vm vm
      is.update(active_vm: vm)
    end
    let(:options) { {} }
    let(:instance_manager) { instance_double('Bosh::Director::Api::InstanceManager') }
    let(:cids) { %w[snap0 snap1] }

    subject { described_class.new(instance.id, options) }

    describe 'DJ job class expectations' do
      let(:job_type) { :create_snapshot }
      let(:queue) { :normal }
      it_behaves_like 'a DJ job'
    end

    it 'tells the snapshot manager to create a snapshot' do
      expect(Api::SnapshotManager).to receive(:take_snapshot).with(instance, options).and_return(cids)

      expect(subject.perform).to eq 'snapshot(s) snap0, snap1 created'
    end
  end
end
