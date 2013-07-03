# Copyright (c) 2009-2013 VMware, Inc.

require 'spec_helper'

describe Bosh::Director::Jobs::DeleteDeploymentSnapshots do
  let(:deployment_manager) { double(BD::Api::DeploymentManager) }
  let(:deployment_name) { 'deployment' }
  let!(:deployment) { BDM::Deployment.make(name: deployment_name) }
  let!(:instance1) { BDM::Instance.make(deployment: deployment) }
  let!(:disk1) { BDM::PersistentDisk.make(:instance_id => instance1.id) }
  let!(:snap1a) { BDM::Snapshot.make(snapshot_cid: "snap1a", :persistent_disk_id => disk1.id) }
  let!(:snap1b) { BDM::Snapshot.make(snapshot_cid: "snap1b", :persistent_disk_id => disk1.id) }
  let!(:instance2) { BDM::Instance.make(deployment: deployment) }
  let!(:disk2) { BDM::PersistentDisk.make(:instance_id => instance2.id) }
  let!(:snap2a) { BDM::Snapshot.make(snapshot_cid: "snap2a", :persistent_disk_id => disk2.id) }
  let!(:instance3) { BDM::Instance.make(deployment: deployment) }
  let!(:disk3) { BDM::PersistentDisk.make(:instance_id => instance3.id) }
  let!(:instance4) { BDM::Instance.make }
  let!(:disk4) { BDM::PersistentDisk.make(:instance_id => instance4.id) }
  let!(:snap4a) { BDM::Snapshot.make(snapshot_cid: "snap4a", :persistent_disk_id => disk4.id) }

  subject { described_class.new(deployment_name) }

  describe 'described_class.job_type' do
    it 'returns a symbol representing job type' do
      expect(described_class.job_type).to eq(:delete_deployment_snapshots)
    end
  end

  it 'tells the snapshot manager to delete all snapshots of a deployment' do
    BD::Api::DeploymentManager.should_receive(:new).and_return(deployment_manager)
    deployment_manager.should_receive(:find_by_name).with(deployment_name).and_return(deployment)

    BD::Api::SnapshotManager.should_receive(:delete_snapshots).with([snap1a, snap1b])
    BD::Api::SnapshotManager.should_receive(:delete_snapshots).with([snap2a])
    BD::Api::SnapshotManager.should_not_receive(:delete_snapshots).with([])
    BD::Api::SnapshotManager.should_not_receive(:delete_snapshots).with([snap4a])

    expect(subject.perform).to eq "snapshots of deployment `deployment' deleted"
  end
end