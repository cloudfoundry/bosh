require 'spec_helper'

module Bosh::Director
  describe Jobs::DeleteDeploymentSnapshots do
    let(:deployment_manager) { instance_double('Bosh::Director::Api::DeploymentManager') }
    let(:deployment_name) { 'deployment' }
    let(:deployment) { Models::Deployment.make(name: deployment_name) }
    let!(:vm1) { Models::Vm.make }
    let!(:instance1) do
      is = Models::Instance.make(deployment: deployment)
      is.add_vm vm1
      is.update(active_vm: vm1)
    end
    let!(:disk1) { Models::PersistentDisk.make(:instance_id => instance1.id) }
    let!(:snap1a) { Models::Snapshot.make(snapshot_cid: "snap1a", persistent_disk_id: disk1.id) }
    let!(:snap1b) { Models::Snapshot.make(snapshot_cid: "snap1b", persistent_disk_id: disk1.id) }
    let!(:vm2) { Models::Vm.make }
    let!(:instance2) do
      is = Models::Instance.make(deployment: deployment)
      is.add_vm vm2
      is.update(active_vm: vm2)
    end
    let!(:disk2) { Models::PersistentDisk.make(:instance_id => instance2.id) }
    let!(:snap2a) { Models::Snapshot.make(snapshot_cid: "snap2a", persistent_disk_id: disk2.id) }
    let!(:vm3) { Models::Vm.make }
    let!(:instance3) do
      is = Models::Instance.make(deployment: deployment)
      is.add_vm vm3
      is.update(active_vm: vm3)
    end
    let!(:disk3) { Models::PersistentDisk.make(:instance_id => instance3.id) }
    let!(:vm4) { Models::Vm.make }
    let!(:instance4) do
      is = Models::Instance.make
      is.add_vm vm4
      is.update(active_vm: vm4)
    end
    let!(:disk4) { Models::PersistentDisk.make(:instance_id => instance4.id) }
    let!(:snap4a) { Models::Snapshot.make(snapshot_cid: "snap4a", persistent_disk_id: disk4.id) }

    subject { described_class.new(deployment_name) }

    describe 'DJ job class expectations' do
      let(:job_type) { :delete_deployment_snapshots }
      let(:queue) { :normal }
      it_behaves_like 'a DJ job'
    end

    it 'tells the snapshot manager to delete all snapshots of a deployment' do
      expect(Api::DeploymentManager).to receive(:new).and_return(deployment_manager)
      expect(deployment_manager).to receive(:find_by_name).with(deployment_name).and_return(deployment)

      expect(Api::SnapshotManager).to receive(:delete_snapshots).with([snap1a, snap1b])
      expect(Api::SnapshotManager).to receive(:delete_snapshots).with([snap2a])
      expect(Api::SnapshotManager).not_to receive(:delete_snapshots).with([])
      expect(Api::SnapshotManager).not_to receive(:delete_snapshots).with([snap4a])

      expect(subject.perform).to eq "snapshots of deployment 'deployment' deleted"
    end
  end
end
