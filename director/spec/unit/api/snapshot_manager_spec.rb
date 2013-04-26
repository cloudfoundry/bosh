require 'spec_helper'

describe Bosh::Director::Api::SnapshotManager do
  let(:cloud) { double(Bosh::Cloud) }
  let(:manager) { described_class.new }
  let(:user) { BD::Models::User.make }

  let(:deployment) { BD::Models::Deployment.make(name: 'deployment') }
  before(:each) do
    BD::Config.stub(cloud: cloud)

    # instance 1: one disk with two snapshots
    vm = BD::Models::Vm.make(cid: 'vm-cid0', agent_id: 'agent0', deployment: deployment)
    @instance = BD::Models::Instance.make(vm: vm, deployment: deployment, job: 'job', index: 0)

    @disk = BD::Models::PersistentDisk.make(disk_cid: 'disk0', instance: @instance, active: true)
    BD::Models::Snapshot.make(persistent_disk: @disk, snapshot_cid: 'snap0a')
    BD::Models::Snapshot.make(persistent_disk: @disk, snapshot_cid: 'snap0b')

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

  let(:task) { double(BDM::Task, id: 'task_id') }

  describe '#create_snapshot' do
    let(:instance) { double(BDM::Instance) }
    let(:options) { {} }

    it 'should enqueue a CreateSnapshot job' do
      manager.should_receive(:create_task).with(user.username, :create_snapshot, "create snapshot").and_return(task)
      Resque.should_receive(:enqueue).with(BD::Jobs::CreateSnapshot, task.id, instance, options)

      expect(manager.create_snapshot(user.username, instance, options)).to eq task
    end
  end

  describe '#delete_snapshots' do
    let(:snapshots) { [] }

    it 'should enqueue a DeleteSnapshot job' do
      manager.should_receive(:create_task).with(user.username, :delete_snapshot, "delete snapshot").and_return(task)
      Resque.should_receive(:enqueue).with(BD::Jobs::DeleteSnapshot, task.id, snapshots)

      expect(manager.delete_snapshots(user.username, snapshots)).to eq task
    end
  end

  describe '#find_by_id' do
    it 'should return the snapshot with the given id' do
      expect(manager.find_by_id(deployment, 'snap0a').snapshot_cid).to eq 'snap0a'
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
      expect(manager.snapshots(deployment)).to eq response
    end

    it 'should list all snapshots for a given instance' do
      response = {
          'job' => {
              0 => %w[snap0a snap0b]
          }
      }
      expect(manager.snapshots(deployment, 'job', 0)).to eq response
    end
  end

  describe 'class methods' do
    let(:config) { Psych.load_file(asset('test-director-config.yml')) }

    before do
      BD::Config.configure(config)
    end

    describe '#delete_snapshots' do

      it 'deletes the snapshots' do
        BD::Config.cloud.should_receive(:delete_snapshot).with('snap0a')
        BD::Config.cloud.should_receive(:delete_snapshot).with('snap0b')

        expect {
          described_class.delete_snapshots(@disk.snapshots)
        }.to change { BDM::Snapshot.count }.by -2
      end
    end

    describe '#take_snapshot' do

      it 'takes the snapshot' do
        BD::Config.cloud.should_receive(:snapshot_disk).with('disk0').and_return('snap0c')

        expect {
          described_class.take_snapshot(@instance, {})
        }.to change { BDM::Snapshot.count }.by 1
      end

      context 'with the clean option' do
        it 'it sets the clean column to true in the db' do
          BD::Config.cloud.should_receive(:snapshot_disk).with('disk0').and_return('snap0c')
          described_class.take_snapshot(@instance, {:clean => true})

          snapshot = BDM::Snapshot.find(snapshot_cid: 'snap0c')
          expect(snapshot.clean).to be_true
        end
      end
    end
  end

end
