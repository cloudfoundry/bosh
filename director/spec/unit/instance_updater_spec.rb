require 'spec_helper'

describe Bosh::Director::InstanceUpdater do

  let(:deployment_model) { BDM::Deployment.make }
  let(:vm_model) { BDM::Vm.make(deployment: deployment_model) }
  let(:persistent_disk_model) { BDM::PersistentDisk.make(instance: instance_model) }
  let(:stemcell_model) { BDM::Stemcell.make }
  let(:instance_model) { BDM::Instance.make(
      deployment: deployment_model,
      vm: vm_model,
  ) }

  let(:deployment_plan) { double(
      BD::DeploymentPlan,
      model: deployment_model
  ) }
  let(:stemcell) { double(
      BD::DeploymentPlan::Stemcell,
      model: stemcell_model)
  }

  let(:resource_pool) { double(
      BD::DeploymentPlan::ResourcePool,
      stemcell: stemcell,
      cloud_properties: double('CloudProperties'),
      env: {})
  }

  let(:update_config) { double(
      BD::DeploymentPlan::UpdateConfig,
      min_update_watch_time: 0.01,
      max_update_watch_time: 0.02,
      min_canary_watch_time: 0.03,
      max_canary_watch_time: 0.04) }
  let(:job) { double(
      BD::DeploymentPlan::Job,
      deployment: deployment_plan,
      resource_pool: resource_pool,
      update: update_config,
      name: 'test-job')
  }
  let(:state) { 'started' }
  let(:changes) { Set.new }
  let(:instance_spec) { Psych.load_file(asset('basic_instance_spec.yml')) }
  let(:job_changed) { false }
  let(:packages_changed) { false }
  let(:disk_currently_attached) { false }
  let(:instance) { double(
      BD::DeploymentPlan::Instance,
      job: job,
      index: 0,
      state: state,
      model: instance_model,
      changes: changes,
      job_changed?: job_changed,
      packages_changed?: packages_changed,
      resource_pool_changed?: false,
      persistent_disk_changed?: false,
      networks_changed?: false,
      dns_changed?: false,
      spec: instance_spec,
      disk_currently_attached?: disk_currently_attached,
      network_settings: double('NetworkSettings'))
  }
  let(:cloud) { double('cloud') }

  let(:agent_client) { double(BD::AgentClient) }

  subject { described_class.new(instance) }

  before do
    Bosh::Director::Config.stub(:cloud).and_return(cloud)
    subject.stub(:agent) { agent_client }
  end

  describe '#report_progress' do

    let(:event_ticker) { double(BD::EventTicker) }

    subject { described_class.new(instance, event_ticker) }

    it 'advances the ticker' do
      subject.stub(update_steps: 200)
      event_ticker.should_receive(:advance).with(0.5)
      subject.report_progress
    end

  end

  describe '#update_steps' do
    context 'when neither the job nor the packages have changed' do
      its(:update_steps) { should == described_class::UPDATE_STEPS }
    end

    context 'when the job has changed' do
      let(:job_changed) { true }
      its(:update_steps) { should == described_class::UPDATE_STEPS + 1 }
    end

    context 'when the packages have changed' do
      let(:packages_changed) { true }
      its(:update_steps) { should == described_class::UPDATE_STEPS + 1 }
    end
  end

  describe '#update' do
    context 'with only a dns change' do
      let(:changes) { [:dns].to_set }

      it 'should only call update_dns' do
        subject.should_receive(:update_dns)
        subject.should_not_receive(:step)

        subject.update
      end
    end

    context 'when the vm need to be stopped' do
      it 'stops the VM' do
        subject.should_receive(:stop)

        subject.stub(:stop)
        subject.stub(:start!)
        subject.stub(:apply_state)
        subject.stub(:wait_until_running)
        subject.stub(current_state: {'job_state' => 'running'})

        subject.update
      end
    end

    context 'when a snapshot is needed' do
      let(:job_changed) { true }
      let(:packages_changed) { true }

      it 'should only call update_dns' do
        subject.should_receive(:take_snapshot)

        subject.stub(:stop)
        subject.stub(:start!)
        subject.stub(:apply_state)
        subject.stub(:wait_until_running)
        subject.stub(current_state: {'job_state' => 'running'})

        subject.update
      end
    end
  end

  describe '#wait_until_running' do
    let(:intervals) { [1000, 2000, 3000, 4000] }
    let(:agent_state) { {'job_state' => 'stopped'} }

    before do
      subject.stub(:watch_schedule) { intervals }
      subject.stub(:sleep)
      agent_client.stub(:get_state) { agent_state }
    end

    it 'sleeps for the correct amount of time' do
      intervals.map { |i| i.to_f/1000 }.each do |wait|
        subject.should_receive(:sleep).with(wait).ordered
      end
      subject.wait_until_running
    end

    context 'when the VM is being started' do

      it 'stops waiting when the VM is running' do
        agent_client.stub(:get_state).and_return(
            {'job_state' => 'stopped'},
            {'job_state' => 'running'}
        )
        subject.should_receive(:sleep).with(1.0).once
        subject.should_receive(:sleep).with(2.0).once
        subject.should_not_receive(:sleep).with(3.0)
        subject.should_not_receive(:sleep).with(4.0)

        subject.wait_until_running
      end
    end

    context 'when the VM is being stopped' do
      let(:state) { 'stopped' }

      it 'stop waiting when the VM is not running' do
        agent_client.stub(:get_state).and_return(
            {'job_state' => 'running'},
            {'job_state' => 'running'},
            {'job_state' => 'stopped'}
        )
        subject.should_receive(:sleep).with(1.0).once
        subject.should_receive(:sleep).with(2.0).once
        subject.should_receive(:sleep).with(3.0).once
        subject.should_not_receive(:sleep).with(4.0)

        subject.wait_until_running
      end
    end

    context 'when the VM never gets to the right state' do
      it 'stops waiting after all the intervals' do
        agent_client.stub(:get_state).and_return(
            {'job_state' => 'stopped'}
        )
        subject.should_receive(:sleep).with(1.0).once
        subject.should_receive(:sleep).with(2.0).once
        subject.should_receive(:sleep).with(3.0).once
        subject.should_receive(:sleep).with(4.0).once

        subject.wait_until_running
      end

    end
  end

  describe '#start!' do

    it 'tells the agent to start' do
      agent_client.should_receive(:start)
      subject.start!
    end

    it 'logs errors' do
      agent_client.stub(:start).and_raise('error')
      BD::Config.logger.should_receive(:warn).with(
          'Agent start raised an exception: #<RuntimeError: error>, ignoring for compatibility')
      subject.start!
    end
  end

  describe '#need_start?' do
    context 'when target state is "started"' do
      it { should be_need_start }
    end

    context 'when target state is not "started"' do
      let(:state) { "stopped" }
      it { should_not be_need_start }
    end
  end

  describe '#dns_change_only?' do
    context 'when there is no DNS change' do
      it { should_not be_dns_change_only }
    end

    context 'when there is only a DNS change' do
      let(:changes) { [:dns].to_set }
      it { should be_dns_change_only }
    end

    context 'when there is a DNS change plus other stuff' do
      let(:changes) { [:dns, :other_stuff].to_set }
      it { should_not be_dns_change_only }
    end
  end

  describe '#need_snapshot?' do
    context 'when the job changed' do
      let(:job_changed) { true }
      it { should be_need_snapshot }
    end

    context 'when the package(s) changed' do
      let(:packages_changed) { true }
      it { should be_need_snapshot }
    end

    context 'when both job and package(s) changed' do
      let(:job_changed) { true }
      let(:packages_changed) { true }

      it { should be_need_snapshot }
    end

    context 'when neither job nor package(s) changed' do
      it { should_not be_need_snapshot }
    end
  end

  describe '#stop' do

    before do
      agent_client.should_receive(:stop)
    end

    let(:drain_time) { 1 }

    context 'when shutting down' do

      before do
        subject.stub(shutting_down?: true)
      end

      context 'with dynamic drain' do
        let(:drain_time) { -1 }

        it 'sends the shutdown message' do
          agent_client.should_receive(:drain).with('shutdown').and_return(drain_time)
          subject.should_receive(:wait_for_dynamic_drain).with(drain_time)
          subject.stop
        end
      end

      context 'with static drain' do
        it 'sends the shutdown message' do
          agent_client.should_receive(:drain).with('shutdown').and_return(drain_time)
          subject.should_receive(:sleep).with(drain_time)
          subject.stop
        end
      end
    end

    context 'when updating' do

      before do
        subject.stub(shutting_down?: false)
      end

      context 'with dynamic drain' do
        let(:drain_time) { -1 }

        it 'sends the shutdown message' do
          agent_client.should_receive(:drain) { |message, spec|
            expect(message).to eq 'update'
            expect(spec).to eq({})
          }.and_return(drain_time)
          subject.should_receive(:wait_for_dynamic_drain).with(drain_time)
          subject.stop
        end
      end

      context 'with static drain' do
        it 'sends the update message' do
          agent_client.should_receive(:drain) { |message, spec|
            expect(message).to eq 'update'
            expect(spec).to eq({})
          }.and_return(drain_time)
          subject.stop
        end
      end
    end
  end

  describe '#wait_for_dynamic_drain' do
    let(:drain_time) { -1 }

    before do
      subject.stub(:sleep)
    end

    it 'can be canceled' do
      BD::Config.should_receive(:task_checkpoint).and_raise(BD::TaskCancelled)
      expect {
        subject.wait_for_dynamic_drain(drain_time)
      }.to raise_error BD::TaskCancelled
    end

    it 'should wait until the agent says it is done draining' do
      agent_client.stub(:drain).with("status").and_return(-2, 0)
      subject.should_receive(:sleep).with(1).ordered
      subject.should_receive(:sleep).with(2).ordered

      subject.wait_for_dynamic_drain(drain_time)
    end

    it 'should wait until the agent says it is done draining' do
      agent_client.stub(:drain).with("status").and_return(-2, 3)
      subject.should_receive(:sleep).with(1).ordered
      subject.should_receive(:sleep).with(2).ordered
      subject.should_receive(:sleep).with(3).ordered

      subject.wait_for_dynamic_drain(drain_time)
    end

  end

  describe '#take_snapshot' do

    it 'tells the snapshot manager to take a snapshot' do
      BD::Api::SnapshotManager.should_receive(:take_snapshot).with(instance_model, clean: true)
      subject.take_snapshot
    end
  end

  describe '#delete_snapshots' do

    let(:snapshots) { [double(BDM::Snapshot), double(BDM::Snapshot)] }
    let(:disk) { double(
        BDM::PersistentDisk,
        snapshots: snapshots
    ) }

    it 'tells the snapshot manager to delete a snapshot' do
      BD::Api::SnapshotManager.should_receive(:delete_snapshots).with(snapshots)
      subject.delete_snapshots(disk)
    end
  end

  describe '#detach_disk' do
    context 'with no disk attached' do
      it 'should do nothing' do
        agent_client.should_not_receive(:umount_disk)
        cloud.should_not_receive(:detach_disk)
      end
    end

    context 'with disk attached' do
      let(:disk_currently_attached) { true }

      context 'when the disk cid is nil' do
        let(:persisent_disk_model) { nil }
        it 'should raise an error' do
          expect {
            subject.detach_disk
          }.to raise_error(BD::AgentUnexpectedDisk,
                           "`#{subject.instance_name}' VM has disk attached but it's not reflected in director DB")
        end
      end

      context 'when the disk cid is not nil' do
        it 'should tell the agent to unmount the disk and tell the cloud provider to detach the disk' do
          agent_client.should_receive(:unmount_disk).with(persistent_disk_model.disk_cid).ordered
          cloud.should_receive(:detach_disk).with(vm_model.cid, persistent_disk_model.disk_cid).ordered
          subject.detach_disk
        end

      end
    end
  end

  describe '#attach_disk' do
    context 'with no disk attached' do
      it 'should do nothing' do
        agent_client.should_not_receive(:mount_disk)
        cloud.should_not_receive(:attach_disk)
      end
    end

    context 'with disk attached' do
      let(:disk_currently_attached) { true }

      it 'should tell the cloud provider to attach the disk and tell the agent to mount the disk ' do
        cloud.should_receive(:attach_disk).with(vm_model.cid, persistent_disk_model.disk_cid).ordered
        agent_client.should_receive(:mount_disk).with(persistent_disk_model.disk_cid).ordered
        subject.attach_disk
      end

    end
  end

  describe '#delete_vm' do
    it 'should delete the VM from the cloud and from the database' do
      cloud.should_receive(:delete_vm).with(vm_model.cid)
      expect {
        subject.delete_vm
      }.to change {
        BDM::Vm.count
      }.by(-1)
    end
  end

  describe '#create_vm' do
    let(:new_disk_id) { 'disk-id' }

    context 'when there is no existing disk' do
      let(:persistent_disk_model) { nil }

      it 'should create a new VM' do
        vm = BDM::Vm.make
        BD::VmCreator.should_receive(:create).with(
            deployment_model, stemcell_model, resource_pool.cloud_properties, instance.network_settings, [new_disk_id],
            resource_pool.env
        ).and_return(vm)
        agent_client.should_receive(:wait_until_ready)
        subject.create_vm(new_disk_id)
        expect(instance_model.vm).to eq vm
      end
    end

    context 'when there is an existing disk' do
      it 'should create a new VM' do
        vm = BDM::Vm.make
        BD::VmCreator.should_receive(:create).with(
            deployment_model, stemcell_model, resource_pool.cloud_properties, instance.network_settings,
            [persistent_disk_model.disk_cid, new_disk_id], resource_pool.env
        ).and_return(vm)
        agent_client.should_receive(:wait_until_ready)
        subject.create_vm(new_disk_id)
        expect(instance_model.vm).to eq vm
      end
    end

    it 'should clean up a VM if creation fails'
  end

  describe '#apply_state' do

    it 'updates the vm' do
      pending
    end
    it 'applies the state to the agent' do
      pending
    end
  end

  describe '#disk_info' do
    context 'when there is a disk list' do
      it 'returns the disk list' do
        pending
      end
    end

    context 'when there is no disk list' do
      it 'gets the list of disks from the agent' do
        pending
      end
    end
  end

  describe '#delete_disk' do

  end

  describe '#update_dns' do

  end

  describe '#update_resource_pool' do

  end

  describe '#attach_missing_disk' do

  end

  describe '#update_networks' do
  end

  describe '#update_persistent_disk' do

  end

  describe '#update_networks' do

  end

  describe '#agent' do

  end

  describe '#watch_schedule' do
    it 'should not sleep for less than 1000 ms' do
      expect(subject.watch_schedule(1000, 5000)).to eq [1000]*5
    end

    it 'should calculate the correct number of sleeps' do
      expect(subject.watch_schedule(1000, 5000, 2)).to eq [1000, 4000]
    end

    it 'should calculate the correct number of sleeps' do
      expect(subject.watch_schedule(1000, 5000, 3)).to eq [1000, 2000, 2000]
    end
  end

  describe '#shutting_down?' do

  end

  describe '#min_watch_time' do
    context 'with a canary' do
      it 'should return min_canary_watch_time' do
        subject.stub(canary?: true)
        expect(subject.min_watch_time).to eq 0.03
      end
    end

    context 'without a canary' do
      it 'should return min_update_watch_time' do
        subject.stub(canary?: false)
        expect(subject.min_watch_time).to eq 0.01
      end
    end
  end

  describe '#max_watch_time' do
    context 'with a canary' do
      it 'should return max_canary_watch_time' do
        subject.stub(canary?: true)
        expect(subject.max_watch_time).to eq 0.04
      end
    end

    context 'without a canary' do
      it 'should return max_update_watch_time' do
        subject.stub(canary?: false)
        expect(subject.max_watch_time).to eq 0.02
      end
    end
  end

  describe '#canary?' do

  end

end
