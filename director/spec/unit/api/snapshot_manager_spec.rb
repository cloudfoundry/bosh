require 'spec_helper'

describe Bosh::Director::Api::SnapshotManager do
  let(:cloud) { double(Bosh::Cloud) }
  let(:manager) { described_class.new }
  let(:user) { BD::Models::User.make }
  let(:time) { Time.now.to_s }

  let(:deployment) { BD::Models::Deployment.make(name: 'deployment') }
  before(:each) do
    BD::Config.stub(cloud: cloud)

    # instance 1: one disk with two snapshots
    vm = BD::Models::Vm.make(cid: 'vm-cid0', agent_id: 'agent0', deployment: deployment)
    @instance = BD::Models::Instance.make(vm: vm, deployment: deployment, job: 'job', index: 0)

    @disk = BD::Models::PersistentDisk.make(disk_cid: 'disk0', instance: @instance, active: true)
    BD::Models::Snapshot.make(persistent_disk: @disk, snapshot_cid: 'snap0a', created_at: time, clean: true)
    BD::Models::Snapshot.make(persistent_disk: @disk, snapshot_cid: 'snap0b', created_at: time)

    # instance 2: 1 disk
    vm = BD::Models::Vm.make(cid: 'vm-cid1', agent_id: 'agent1', deployment: deployment)
    instance = BD::Models::Instance.make(vm: vm, deployment: deployment, job: 'job', index: 1)

    disk = BD::Models::PersistentDisk.make(disk_cid: 'disk1', instance: instance, active: true)
    BD::Models::Snapshot.make(persistent_disk: disk, snapshot_cid: 'snap1a', created_at: time)

    # instance 3: no disks
    vm = BD::Models::Vm.make(cid: 'vm-cid2', agent_id: 'agent2', deployment: deployment)
    @instance2 = BD::Models::Instance.make(vm: vm, deployment: deployment, job: 'job2', index: 0)

    # snapshot from another deployment
    BD::Models::Snapshot.make
  end

  let(:task) { double(BDM::Task, id: 'task_id') }

  describe 'create_deployment_snapshot_task' do
    it 'should take snapshots of all instances with persistent disks' do
      manager.should_receive(:create_task).with(user.username, :snapshot_deployment, 'snapshot deployment').and_return(task)
      Resque.should_receive(:enqueue).with(BD::Jobs::SnapshotDeployment, task.id, deployment.name, {})

      expect(manager.create_deployment_snapshot_task(user.username, deployment)).to eq task

    end
  end

  describe 'create_snapshot_task' do
    let(:instance) { double(BDM::Instance, id: 0) }
    let(:options) { {} }

    it 'should enqueue a CreateSnapshot job' do
      manager.should_receive(:create_task).with(user.username, :create_snapshot, "create snapshot").and_return(task)
      Resque.should_receive(:enqueue).with(BD::Jobs::CreateSnapshot, task.id, instance.id, options)

      expect(manager.create_snapshot_task(user.username, instance, options)).to eq task
    end
  end

  describe 'delete_deployment_snapshots' do
    it 'should enqueue a DeleteDeploymentSnapshots job' do
      manager.should_receive(:create_task).with(user.username, :delete_deployment_napshots, "delete deployment snapshots").and_return(task)
      Resque.should_receive(:enqueue).with(BD::Jobs::DeleteDeploymentSnapshots, task.id, deployment.name)

      expect(manager.delete_deployment_snapshots_task(user.username, deployment)).to eq task
    end
  end

  describe 'delete_snapshots_task' do
    let(:snapshot_cids) { %w[snap0 snap1] }

    it 'should enqueue a DeleteSnapshot job' do
      manager.should_receive(:create_task).with(user.username, :delete_snapshot, "delete snapshot").and_return(task)
      Resque.should_receive(:enqueue).with(BD::Jobs::DeleteSnapshots, task.id, snapshot_cids)

      expect(manager.delete_snapshots_task(user.username, snapshot_cids)).to eq task
    end
  end

  describe '#find_by_cid' do
    it 'should return the snapshot with the given id' do
      expect(manager.find_by_cid(deployment, 'snap0a').snapshot_cid).to eq 'snap0a'
    end
  end

  describe '#snapshots' do
    it 'should list all snapshots for a given deployment' do
      response = [
          { 'job' => 'job', 'index' => 0, 'snapshot_cid' => 'snap0a', 'created_at' => time, 'clean' => true },
          { 'job' => 'job', 'index' => 0, 'snapshot_cid' => 'snap0b', 'created_at' => time, 'clean' => false },
          { 'job' => 'job', 'index' => 1, 'snapshot_cid' => 'snap1a', 'created_at' => time, 'clean' => false },
      ]
      expect(manager.snapshots(deployment)).to eq response
    end

    it 'should list all snapshots for a given instance' do
      response = [
          { 'job' => 'job', 'index' => 0, 'snapshot_cid' => 'snap0a', 'created_at' => time, 'clean' => true },
          { 'job' => 'job', 'index' => 0, 'snapshot_cid' => 'snap0b', 'created_at' => time, 'clean' => false },
      ]
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

      let(:metadata) {
        {
            agent_id: 'agent0',
            instance_id: 1,
            director_name: 'Test Director',
            director_uuid: BD::Config.uuid,
            deployment: 'deployment',
            job: 'job',
            index: 0
        }
      }

      context 'when there is no persistent disk' do
        it 'does not take a snapshot' do
          BD::Config.cloud.should_not_receive(:snapshot_disk)

          expect {
            described_class.take_snapshot(@instance2, {})
          }.to_not change { BDM::Snapshot.count }
        end
      end

      it 'takes the snapshot' do
        BD::Config.cloud.should_receive(:snapshot_disk).with('disk0', metadata).and_return('snap0c')

        expect {
          expect(described_class.take_snapshot(@instance, {})).to eq %w[snap0c]
        }.to change { BDM::Snapshot.count }.by 1
      end

      context 'with the clean option' do
        it 'it sets the clean column to true in the db' do
          BD::Config.cloud.should_receive(:snapshot_disk).with('disk0', metadata).and_return('snap0c')
          expect(described_class.take_snapshot(@instance, {:clean => true})).to eq %w[snap0c]

          snapshot = BDM::Snapshot.find(snapshot_cid: 'snap0c')
          expect(snapshot.clean).to be_true
        end
      end
    end
  end

end
