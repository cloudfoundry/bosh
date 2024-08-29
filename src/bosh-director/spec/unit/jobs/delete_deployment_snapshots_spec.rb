require 'spec_helper'

module Bosh::Director
  describe Jobs::DeleteDeploymentSnapshots do
    let(:deployment_manager) { instance_double('Bosh::Director::Api::DeploymentManager') }
    let(:deployment_name) { 'deployment' }
    let(:deployment) { FactoryBot.create(:models_deployment, name: deployment_name) }
    let!(:vm1) { FactoryBot.create(:models_vm, instance_id: instance1.id) }
    let!(:instance1) { FactoryBot.create(:models_instance, deployment: deployment) }
    let!(:disk1) { FactoryBot.create(:models_persistent_disk, :instance_id => instance1.id) }
    let!(:snap1a) { FactoryBot.create(:models_snapshot, snapshot_cid: "snap1a", persistent_disk_id: disk1.id) }
    let!(:snap1b) { FactoryBot.create(:models_snapshot, snapshot_cid: "snap1b", persistent_disk_id: disk1.id) }
    let!(:vm2) { FactoryBot.create(:models_vm, instance_id: instance2.id) }
    let!(:instance2) { FactoryBot.create(:models_instance, deployment: deployment) }
    let!(:disk2) { FactoryBot.create(:models_persistent_disk, :instance_id => instance2.id) }
    let!(:snap2a) { FactoryBot.create(:models_snapshot, snapshot_cid: "snap2a", persistent_disk_id: disk2.id) }
    let!(:vm3) { FactoryBot.create(:models_vm, instance_id: instance3.id) }
    let!(:instance3) { FactoryBot.create(:models_instance, deployment: deployment) }
    let!(:disk3) { FactoryBot.create(:models_persistent_disk, :instance_id => instance3.id) }
    let!(:vm4) { FactoryBot.create(:models_vm, instance_id: instance4.id) }
    let!(:instance4) { FactoryBot.create(:models_instance) }
    let!(:disk4) { FactoryBot.create(:models_persistent_disk, :instance_id => instance4.id) }
    let!(:snap4a) { FactoryBot.create(:models_snapshot, snapshot_cid: "snap4a", persistent_disk_id: disk4.id) }

    subject { described_class.new(deployment_name) }

    before do
      instance1.active_vm = vm1
      instance2.active_vm = vm2
      instance3.active_vm = vm3
      instance4.active_vm = vm4
    end

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
