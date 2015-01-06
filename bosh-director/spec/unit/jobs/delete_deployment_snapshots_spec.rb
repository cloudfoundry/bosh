# Copyright (c) 2009-2013 VMware, Inc.

require 'spec_helper'

module Bosh::Director
  describe Jobs::DeleteDeploymentSnapshots do
    let(:deployment_manager) { instance_double('Bosh::Director::Api::DeploymentManager') }
    let(:deployment_name) { 'deployment' }
    let!(:deployment) { Models::Deployment.make(name: deployment_name) }
    let!(:instance1) { Models::Instance.make(deployment: deployment) }
    let!(:disk1) { Models::PersistentDisk.make(:instance_id => instance1.id) }
    let!(:snap1a) { Models::Snapshot.make(snapshot_cid: "snap1a", persistent_disk_id: disk1.id) }
    let!(:snap1b) { Models::Snapshot.make(snapshot_cid: "snap1b", persistent_disk_id: disk1.id) }
    let!(:instance2) { Models::Instance.make(deployment: deployment) }
    let!(:disk2) { Models::PersistentDisk.make(:instance_id => instance2.id) }
    let!(:snap2a) { Models::Snapshot.make(snapshot_cid: "snap2a", persistent_disk_id: disk2.id) }
    let!(:instance3) { Models::Instance.make(deployment: deployment) }
    let!(:disk3) { Models::PersistentDisk.make(:instance_id => instance3.id) }
    let!(:instance4) { Models::Instance.make }
    let!(:disk4) { Models::PersistentDisk.make(:instance_id => instance4.id) }
    let!(:snap4a) { Models::Snapshot.make(snapshot_cid: "snap4a", persistent_disk_id: disk4.id) }

    subject { described_class.new(deployment_name) }

    describe 'Resque job class expectations' do
      let(:job_type) { :delete_deployment_snapshots }
      it_behaves_like 'a Resque job'
    end

    it 'tells the snapshot manager to delete all snapshots of a deployment' do
      expect(Api::DeploymentManager).to receive(:new).and_return(deployment_manager)
      expect(deployment_manager).to receive(:find_by_name).with(deployment_name).and_return(deployment)

      expect(Api::SnapshotManager).to receive(:delete_snapshots).with([snap1a, snap1b])
      expect(Api::SnapshotManager).to receive(:delete_snapshots).with([snap2a])
      expect(Api::SnapshotManager).not_to receive(:delete_snapshots).with([])
      expect(Api::SnapshotManager).not_to receive(:delete_snapshots).with([snap4a])

      expect(subject.perform).to eq "snapshots of deployment `deployment' deleted"
    end
  end
end
