require 'spec_helper'

describe Bosh::Director::Api::SnapshotManager do
  let(:cloud) { double(Bosh::Cloud) }
  let(:manager) { described_class.new }

  let(:deployment) { BD::Models::Deployment.make(name: 'deployment') }
  before(:each) do
    BD::Config.stub(cloud: cloud)

    # instance 1: two disks
    vm = BD::Models::Vm.make(cid: 'vm-cid0', agent_id: 'agent0', deployment: deployment)
    instance = BD::Models::Instance.make(vm: vm, deployment: deployment, job: 'job', index: 0)

    disk = BD::Models::PersistentDisk.make(disk_cid: 'disk0', instance: instance, active: true)
    BD::Models::Snapshot.make(persistent_disk: disk, snapshot_cid: 'snap0a')
    BD::Models::Snapshot.make(persistent_disk: disk, snapshot_cid: 'snap0b')

    # instance 2: 1 disk
    vm = BD::Models::Vm.make(cid: 'vm-cid1', agent_id: 'agent1', deployment: deployment)
    instance = BD::Models::Instance.make(vm: vm, deployment: deployment, job: 'job', index: 1)

    disk = BD::Models::PersistentDisk.make(disk_cid: 'disk1', instance: instance, active: true)
    BD::Models::Snapshot.make(persistent_disk: disk, snapshot_cid: 'snap1a')

    # instance 3: no disks
    vm = BD::Models::Vm.make(cid: 'vm-cid2', agent_id: 'agent2', deployment: deployment)
    instance = BD::Models::Instance.make(vm: vm, deployment: deployment, job: 'job2', index: 0)

    # snapshot from another deployment
    BD::Models::Snapshot.make
  end

  describe '#create_snapshot' do

  end

  describe '#delete_snapshot' do

  end

  describe '#find_by_id' do
    it 'should return the snapshot with the given id' do
      manager.find_by_id(deployment, 'snap0a').snapshot_cid.should == 'snap0a'
    end
  end

  describe '#snapshot_instance' do
    context 'instance with a persistent_disk' do
      let(:instance) { BDM::Instance.find(job: 'job', index: 1) }

      it 'should take a snapshot of the persistent disk' do
        cloud.should_receive(:snapshot_disk).with('disk1').and_return('snap-xxxxxxxx')

        manager.snapshot(instance)

        snapshot = BDM::Snapshot[snapshot_cid: 'snap-xxxxxxxx']
        snapshot.should_not be_nil
        snapshot.clean.should be_false
      end

    end

    context 'instance without a persistent_disk' do
      let(:instance) { BDM::Instance.find(job: 'job2', index: 0) }

      it 'should not take a snapshot' do
        cloud.should_not_receive(:snapshot_disk)
        count = BDM::Snapshot.all.count

        manager.snapshot(instance)

        BDM::Snapshot.all.count.should == count
      end
    end
  end

  describe '#delete_snapshot_by_id' do
    it 'should delete a existing snapshot' do
      cloud.should_receive(:delete_snapshot).with('snap0a')

      BDM::Snapshot.all.count.should == 4

      manager.delete_snapshot_by_id(deployment, 'snap0a')

      BDM::Snapshot.all.count.should == 3
    end

    it 'should raise an error when deleting a non existent snapshot' do
      cloud.should_not_receive(:delete_snapshot)

      expect {
        manager.delete_snapshot_by_id(deployment, 'snap4')
      }.to raise_error Bosh::Director::SnapshotNotFound, 'snapshot snap4 not found'
    end

    it 'should raise an error when deleting a snapshot belonging to a different deployment' do
      snapshot = BD::Models::Snapshot.make(snapshot_cid: 'snap_cid')
      cloud.should_not_receive(:delete_snapshot)

      expect {
        manager.delete_snapshot_by_id(deployment, snapshot.snapshot_cid)
      }.to raise_error Bosh::Director::SnapshotNotFound, 'snapshot snap_cid not found in deployment deployment'
    end
  end

  describe '#delete_all_snapshots' do
    it 'should delete all snapshots for a given instance' do
      cloud.should_receive(:delete_snapshot).with('snap0a')
      cloud.should_receive(:delete_snapshot).with('snap0b')

      manager.delete_snapshots('deployment', 'job', 0)

      BDM::Snapshot.all.count.should == 2
    end
  end

  describe '#snapshots' do
    it 'should list all snapshots for a given deployment' do
      response = {
          'job' => {
              0 => %w[snap0a snap0b],
              1 => %w[snap1a]
          }
      }
      manager.snapshots(deployment).should == response
    end

    it 'should list all snapshots for a given instance' do
      response = {
          'job' => {
              0 => %w[snap0a snap0b]
          }
      }
      manager.snapshots(deployment, 'job', 0).should == response
    end
  end
end
