require 'spec_helper'

describe Bosh::Director::Api::SnapshotManager do
  let(:cloud) { double(Bosh::Cloud) }
  let(:manager) { described_class.new }

  before(:each) do
    BD::Config.stub(cloud: cloud)

    deployment = BD::Models::Deployment.make(name: 'deployment')

    # instance 1: two disks
    vm = BD::Models::Vm.make(cid: 'vm-cid1', agent_id: 'agent1', deployment: deployment)
    instance = BD::Models::Instance.make(vm: vm, deployment: deployment, job: 'job', index: 0)

    disk = BD::Models::PersistentDisk.make(disk_cid: 'cid1', instance: instance, active: true)
    BD::Models::Snapshot.make(persistent_disk: disk, snapshot_cid: 'snap1')
    BD::Models::Snapshot.make(persistent_disk: disk, snapshot_cid: 'snap2')

    # instance 2: 1 disk
    vm = BD::Models::Vm.make(cid: 'vm-cid2', agent_id: 'agent2', deployment: deployment)
    instance = BD::Models::Instance.make(vm: vm, deployment: deployment, job: 'job', index: 1)

    disk = BD::Models::PersistentDisk.make(disk_cid: 'cid2', instance: instance, active: true)
    BD::Models::Snapshot.make(persistent_disk: disk, snapshot_cid: 'snap3')

    # instance 3: no disks
    vm = BD::Models::Vm.make(cid: 'vm-cid3', agent_id: 'agent3', deployment: deployment)
    instance = BD::Models::Instance.make(vm: vm, deployment: deployment, job: 'job2', index: 0)

    # snapshot from another deployment
    BD::Models::Snapshot.make
  end

  describe '#snapshot_instance' do
    context 'instance with a persistent_disk' do
      it 'should take a snapshot of the persistent disk' do
        cloud.should_receive(:snapshot_disk).with('cid1').and_return('snap-xxxxxxxx')

        manager.snapshot_instance('deployment', 'job', 0)

        snapshot = BDM::Snapshot[snapshot_cid: 'snap-xxxxxxxx']
        snapshot.should_not be_nil
        snapshot.clean.should be_false
      end

    end

    context 'instance without a persistent_disk' do
      it 'should not take a snapshot' do
        cloud.should_not_receive(:snapshot_disk)
        count = BDM::Snapshot.all.count

        manager.snapshot_instance('deployment', 'job2', 0)

        BDM::Snapshot.all.count.should == count
      end
    end
  end

  describe '#delete_snapshot' do
    it 'should delete a existing snapshot' do
      cloud.should_receive(:delete_snapshot).with('snap1')

      BDM::Snapshot.all.count.should == 4

      manager.delete_snapshot('snap1')

      BDM::Snapshot.all.count.should == 3
    end

    it 'should raise an error when deleting a non existent snapshot' do
      cloud.should_not_receive(:delete_snapshot)

      expect {
        manager.delete_snapshot('snap4')
      }.to raise_error Bosh::Director::SnapshotNotFound, 'snapshot snap4 not found'
    end
  end

  describe '#delete_all_snapshots' do
    it 'should delete all snapshots for a given instance' do
      cloud.should_receive(:delete_snapshot).with('snap1')
      cloud.should_receive(:delete_snapshot).with('snap2')

      manager.delete_all_snapshots('deployment', 'job', 0)

      #@disk.snapshots.size.should == 0
      BDM::Snapshot.all.count.should == 2
    end
  end

  describe '#snapshots' do
    it 'should list all snapshots for a given deployment' do
      response = {
          'job' => {
              0 => %w[snap1 snap2],
              1 => %w[snap3]
          }
      }
      manager.snapshots('deployment').should == response
    end

    it 'should list all snapshots for a given instance' do
      response = {
          'job' => {
              0 => %w[snap1 snap2]
          }
      }
      manager.snapshots('deployment', 'job', 0).should == response
    end
  end
end
