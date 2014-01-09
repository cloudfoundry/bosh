require 'spec_helper'

module Bosh::Director
  describe InstanceUpdater do
    subject do
      ticker = double('ticker', advance: nil)
      described_class.new(instance, ticker)
    end

    before { App.stub_chain(:instance, :blobstores, :blobstore).and_return(blobstore) }
    let(:blobstore) { instance_double('Bosh::Blobstore::Client') }

    let(:deployment_model) { Models::Deployment.make }
    let(:vm_model) { Models::Vm.make(deployment: deployment_model) }
    let(:persistent_disk_model) { Models::PersistentDisk.make(instance: instance_model) }
    let(:stemcell_model) { Models::Stemcell.make }
    let(:instance_model) { Models::Instance.make(deployment: deployment_model, vm: vm_model) }

    let(:domain) { 'somedomain.com' }
    let(:deployment_plan) { double('Bosh::Director::DeploymentPlan', model: deployment_model, dns_domain: domain, name: 'deployment') }
    let(:stemcell) { instance_double('Bosh::Director::DeploymentPlan::Stemcell', model: stemcell_model) }

    let(:release) { instance_double('Bosh::Director::DeploymentPlan::ReleaseVersion', spec: 'release-spec') }
    let(:resource_pool) do
      double('Bosh::Director::DeploymentPlan::ResourcePool',
             stemcell: stemcell,
             cloud_properties: double('CloudProperties'),
             env: {},
             spec: 'deployment-plan-spec',
             release: release)
    end

    let(:update_config) do
      instance_double('Bosh::Director::DeploymentPlan::UpdateConfig',
                      min_update_watch_time: 0.01,
                      max_update_watch_time: 0.02,
                      min_canary_watch_time: 0.03,
                      max_canary_watch_time: 0.04)
    end

    let(:job) do
      instance_double('Bosh::Director::DeploymentPlan::Job',
                      deployment: deployment_plan,
                      resource_pool: resource_pool,
                      update: update_config,
                      name: 'test-job',
                      spec: 'job-spec',
                      release: release)
    end
    let(:state) { 'started' }
    let(:changes) { Set.new }
    let(:instance_spec) { Psych.load_file(asset('basic_instance_spec.yml')) }
    let(:job_changed) { false }
    let(:packages_changed) { false }
    let(:resource_pool_changed) { false }
    let(:persistent_disk_changed) { false }
    let(:networks_changed) { false }
    let(:dns_changed) { false }
    let(:disk_currently_attached) { false }
    let(:disk_size) { 0 }
    let(:instance) do
      double('Bosh::Director::DeploymentPlan::Instance',
             job: job,
             index: 0,
             state: state,
             model: instance_model,
             changes: changes,
             job_changed?: job_changed,
             packages_changed?: packages_changed,
             resource_pool_changed?: resource_pool_changed,
             persistent_disk_changed?: persistent_disk_changed,
             networks_changed?: networks_changed,
             dns_changed?: dns_changed,
             spec: instance_spec,
             disk_currently_attached?: disk_currently_attached,
             network_settings: double('NetworkSettings'),
             disk_size: disk_size)
    end
    let(:cloud) { instance_double('Bosh::Cloud') }

    let(:agent_client) { double('Bosh::Director::AgentClient') }

    before do
      Bosh::Director::Config.stub(:cloud).and_return(cloud)
      subject.stub(:agent) { agent_client }
    end

    describe '#report_progress' do
      subject { described_class.new(instance, event_log_task) }
      let(:event_log_task) { instance_double('Bosh::Director::EventLog::Task') }

      it 'advances the ticker' do
        subject.stub(update_steps: 200)
        event_log_task.should_receive(:advance).with(0.5)
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
      def self.it_updates_vm_metadata
        it 'updates vm metadata' do
          vm_metadata_updater = instance_double('Bosh::Director::VmMetadataUpdater')
          Bosh::Director::VmMetadataUpdater.should_receive(:build).and_return(vm_metadata_updater)
          vm_metadata_updater.should_receive(:update).with(vm_model, {})
          subject.update
        end
      end

      before { allow(InstancePreparer).to receive(:new).with(instance, agent_client).and_return(preparer) }
      let(:preparer) { instance_double('Bosh::Director::InstancePreparer', prepare: nil) }

      before { allow(RenderedJobTemplatesCleaner).to receive(:new).with(instance_model, blobstore).and_return(templates_cleaner) }
      let(:templates_cleaner) { instance_double('Bosh::Director::RenderedJobTemplatesCleaner', clean: nil) }

      context 'when instance is not detached' do
        before do
          subject.stub(:stop)
          subject.stub(:start!)
          subject.stub(:apply_state)
          subject.stub(:wait_until_running)
          subject.stub(current_state: {'job_state' => 'running'})
        end

        it 'cleans up rendered job templates after apply' do
          subject.should_receive(:apply_state).ordered
          templates_cleaner.should_receive(:clean).ordered
          subject.update
        end
      end

      context 'with only a dns change' do
        let(:changes) { [:dns].to_set }

        it 'should only call update_dns' do
          subject.should_receive(:update_dns)
          subject.should_not_receive(:step)
          subject.update
        end

        it 'does not prepare instance' do
          Bosh::Director::InstancePreparer.should_not_receive(:new)
          subject.update
        end

        it 'does not update vm metadata' do
          Bosh::Director::VmMetadataUpdater.should_not_receive(:new)
          subject.update
        end
      end

      context 'when the job instance needs to be stopped' do
        before do
          subject.stub(:stop)
          subject.stub(:start!)
          subject.stub(:apply_state)
          subject.stub(:wait_until_running)
          subject.stub(current_state: {'job_state' => 'running'})
        end

        it 'prepares the job before stopping it to minimize downtime' do
          preparer.should_receive(:prepare).ordered
          subject.should_receive(:stop).ordered
          subject.update
        end

        it 'stops the job' do
          subject.should_receive(:stop)
          subject.update
        end

        it_updates_vm_metadata
      end

      context 'when a snapshot is needed' do
        let(:job_changed) { true }
        let(:packages_changed) { true }

        before do
          subject.stub(:stop)
          subject.stub(:start!)
          subject.stub(:apply_state)
          subject.stub(:wait_until_running)
          subject.stub(current_state: {'job_state' => 'running'})
        end

        it 'should take snapshot' do
          subject.should_receive(:take_snapshot)
          subject.update
        end

        it_updates_vm_metadata
      end

      context 'when there is a network change' do
        let(:networks_changed) { true }

        before do
          cloud.stub(:configure_networks)
          agent_client.stub(:prepare_network_change)
          agent_client.stub(:wait_until_ready)
          subject.stub(:sleep)
          subject.stub(:stop)
          subject.stub(:update_resource_pool)
          subject.stub(:start!)
          subject.stub(:apply_state)
          subject.stub(:wait_until_running)
          subject.stub(current_state: {'job_state' => 'running'})
        end

        context 'when a vm does not need to be recreated' do
          it 'should prepare network change' do
            cloud.should_receive(:configure_networks)
            agent_client.should_receive(:prepare_network_change)
            agent_client.should_receive(:wait_until_ready)

            subject.update
          end
        end

        context 'when a vm needs to be recreated' do
          context 'without persistent disk' do
            let(:persistent_disk_changed) { false }

            it 'should recreate vm' do
              agent_client.should_not_receive(:prepare_network_change)
              cloud.should_receive(:configure_networks).and_raise(Bosh::Clouds::NotSupported)
              instance.should_receive(:recreate=)

              subject.update
            end
          end

          context 'without persistent disk' do
            let(:persistent_disk_changed) { true }

            before do
              job.stub(persistent_disk: 1)
              cloud.stub(create_disk: 'disk-cid')
              cloud.stub(:attach_disk)
              agent_client.stub(:mount_disk)
            end

            it 'should recreate vm and attach disk' do
              agent_client.should_not_receive(:prepare_network_change)
              cloud.should_receive(:configure_networks).and_raise(Bosh::Clouds::NotSupported)
              instance.should_receive(:recreate=)
              job.should_receive(:persistent_disk).exactly(3).times.and_return(1024)
              cloud.should_receive(:create_disk).and_return('disk-cid')
              cloud.should_receive(:attach_disk)
              agent_client.should_receive(:mount_disk)

              subject.update
            end

            it_updates_vm_metadata
          end
        end
      end

      describe 'canary' do
        before do
          subject.stub(:stop)
          subject.stub(:start!)
          subject.stub(:apply_state)
          subject.stub(:wait_until_running)
          subject.stub(current_state: {'job_state' => 'running'})
        end

        context 'when canary is set to true' do
          it 'updates the instance to be a canary' do
            subject.update(:canary => true)
            expect(subject.canary?).to be(true)
          end

          it_updates_vm_metadata
        end

        context 'when canary is not passed in' do
          it 'defaults the instance to not be a canary' do
            subject.update
            expect(subject.canary?).to be(false)
          end

          it_updates_vm_metadata
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
        Config.logger.should_receive(:warn).
          with('Agent start raised an exception: #<RuntimeError: error>, ignoring for compatibility')
        subject.start!
      end
    end

    describe '#need_start?' do
      context 'when target state is "started"' do
        it { should be_need_start }
      end

      context 'when target state is not "started"' do
        let(:state) { 'stopped' }
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
        Config.should_receive(:task_checkpoint).and_raise(TaskCancelled)
        expect {
          subject.wait_for_dynamic_drain(drain_time)
        }.to raise_error TaskCancelled
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
        Api::SnapshotManager.should_receive(:take_snapshot).with(instance_model, clean: true)
        subject.take_snapshot
      end
    end

    describe '#delete_snapshots' do

      let(:snapshots) {
        [
          instance_double('Bosh::Director::Models::Snapshot'),
          instance_double('Bosh::Director::Models::Snapshot')
        ]
      }
      let(:disk) { instance_double('Bosh::Director::Models::PersistentDisk', snapshots: snapshots) }

      it 'tells the snapshot manager to delete a snapshot' do
        Api::SnapshotManager.should_receive(:delete_snapshots).with(snapshots)
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
            }.to raise_error(AgentUnexpectedDisk,
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
          Models::Vm.count
        }.by(-1)
      end
    end

    describe '#create_vm' do
      let(:new_disk_id) { 'disk-id' }

      context 'when there is no existing disk' do
        let(:persistent_disk_model) { nil }

        it 'should create a new VM' do
          vm = Models::Vm.make
          VmCreator.should_receive(:create).
            with(deployment_model,
                 stemcell_model,
                 resource_pool.cloud_properties,
                 instance.network_settings,
                 [new_disk_id],
                 resource_pool.env).
            and_return(vm)

          agent_client.should_receive(:wait_until_ready)
          subject.create_vm(new_disk_id)
          expect(instance_model.vm).to eq vm
        end
      end

      context 'when there is an existing disk' do
        it 'should create a new VM' do
          vm = Models::Vm.make
          VmCreator.should_receive(:create).
            with(deployment_model,
                 stemcell_model,
                 resource_pool.cloud_properties,
                 instance.network_settings,
                 [persistent_disk_model.disk_cid, new_disk_id],
                 resource_pool.env).
            and_return(vm)
          agent_client.should_receive(:wait_until_ready)
          subject.create_vm(new_disk_id)
          expect(instance_model.vm).to eq vm
        end
      end

      it 'should clean up a VM if agent fails to respond' do
        agent_client.stub(:wait_until_ready).with(no_args).and_raise(RuntimeError)
        new_vm = Models::Vm.make(cid: 'new vm cid')
        VmCreator.stub(:create).and_return(new_vm)
        cloud.should_receive(:delete_vm).with('new vm cid')
        new_vm.should_receive(:destroy).with(no_args)

        expect {
          subject.create_vm(new_disk_id)
        }.to raise_error(RuntimeError)

        expect(instance.model.vm).to be_nil
      end

      it 'should clean up a VM if instance model fails to save' do
        # too bad "allow-to" doesn't work yet: the second stub would override the first
        expect(instance.model).to receive(:save).once.and_raise(RuntimeError)
        expect(instance.model).to receive(:save).once

        new_vm = Models::Vm.make(cid: 'new vm cid')
        VmCreator.stub(:create).and_return(new_vm)
        cloud.should_receive(:delete_vm).with('new vm cid')
        new_vm.should_receive(:destroy).with(no_args)

        expect {
          subject.create_vm(new_disk_id)
        }.to raise_error(RuntimeError)

        expect(instance.model.vm).to be_nil
      end
    end

    describe '#apply_state' do

      it 'updates the vm' do
        instance.model.vm.should_receive(:update).with(apply_spec: 'newstate')
        agent_client.should_receive(:apply).with('newstate')

        subject.apply_state('newstate')
      end
    end

    describe '#disk_info' do
      context 'when there is a disk list' do
        it 'caches the disk list' do
          agent_client.stub(:list_disk).once.and_return []
          expect(subject.disk_info).to eq []
          expect(subject.disk_info).to eq []
        end
      end

      context 'when there is no disk list' do
        it 'gets the list of disks from the agent' do
          agent_client.should_receive(:list_disk).and_return []
          expect(subject.disk_info).to eq []
        end
      end

      context "when the agent doesn't support list_disk" do

        it "returns the instance's persistent disk cid" do
          agent_client.stub(:list_disk).and_raise RuntimeError

          instance.should_receive(:persistent_disk_cid).and_return('disk_cid')
          expect(subject.disk_info).to eq ['disk_cid']
        end

      end
    end

    describe '#delete_disk' do
      let(:disk) { instance_double('Bosh::Director::Models::PersistentDisk', disk_cid: 'disk_cid') }
      let(:vm_cid) { 'vm_cid' }

      before do
        subject.stub(:disk_info).and_return [disk.disk_cid]
        agent_client.stub(:unmount_disk)
        subject.stub(:delete_snapshots)
        cloud.stub(:detach_disk)
        cloud.stub(:delete_disk)
        disk.stub(:destroy)
        disk.stub(active: true)
      end

      context 'when the disk is known by the agent' do
        it 'umounts the disk' do
          agent_client.should_receive(:unmount_disk).with(disk.disk_cid)

          subject.delete_disk(disk, vm_cid)
        end
      end

      context 'when the disk is attached' do
        it 'detaches the disk' do
          cloud.should_receive(:detach_disk).with(vm_cid, disk.disk_cid)

          subject.delete_disk(disk, vm_cid)
        end
      end

      context 'when the disk is not attached' do
        it 'raises an exception' do
          cloud.stub(:detach_disk).with(vm_cid, disk.disk_cid).and_raise(CloudDiskNotAttached)

          expect { subject.delete_disk(disk, vm_cid) }.to raise_exception(CloudDiskNotAttached)
        end
      end

      it 'deletes the snapshots' do
        subject.should_receive(:delete_snapshots).with(disk)

        subject.delete_disk(disk, vm_cid)
      end

      it 'deletes the disk' do
        cloud.should_receive(:delete_disk).with(disk.disk_cid)

        subject.delete_disk(disk, vm_cid)
      end

      context 'when the disk is not found' do
        it 'raises an exception' do
          cloud.should_receive(:delete_disk).with(disk.disk_cid).and_raise(Bosh::Clouds::DiskNotFound.new(false))

          expect { subject.delete_disk(disk, vm_cid) }.to raise_exception(CloudDiskMissing)
        end
      end

      it 'destroys the disk' do
        disk.should_receive(:destroy)

        subject.delete_disk(disk, vm_cid)
      end
    end

    describe '#update_dns' do
      context 'when DNS is not being changed' do
        it { should_not_receive(:update_dns_a_record) }
        it { should_not_receive(:update_dns_ptr_record) }
      end

      context 'when DNS is being changed' do
        let(:dns_changed) { true }

        it 'updates the A and PTR records' do
          instance.stub(:dns_record_info).and_return([
                                                       ['record 1', '1.1.1.1'],
                                                       ['record 2', '2.2.2.2'],
                                                     ])

          subject.should_receive(:update_dns_a_record).with(domain, 'record 1', '1.1.1.1')
          subject.should_receive(:update_dns_ptr_record).with('record 1', '1.1.1.1')
          subject.should_receive(:update_dns_a_record).with(domain, 'record 2', '2.2.2.2')
          subject.should_receive(:update_dns_ptr_record).with('record 2', '2.2.2.2')

          subject.update_dns
        end
      end
    end

    describe '#update_resource_pool' do

      context 'when the resource pool has not changed' do

      end

      context 'when the resource pool has changed' do
        let(:resource_pool_changed) { true }
        let(:new_disk_cid) { 'new-disk-cid' }
        let(:instance_state) { {'job_state' => 'running'} }

        it 'recreates the vm' do
          agent_client.stub(:get_state).and_return(instance_state)

          subject.should_receive(:delete_vm)
          subject.should_receive(:create_vm).with(new_disk_cid)
          subject.should_receive(:attach_disk)
          subject.should_receive(:apply_state)
          instance.should_receive(:current_state=).with(instance_state)

          subject.update_resource_pool(new_disk_cid)
        end

        context 'when new vm creation fails' do
          it 'does not try to delete the original vm multiple times' do
            agent_client.stub(:get_state).and_return(instance_state)

            expect(cloud).to receive(:delete_vm).exactly(1).times
            cloud.stub(:create_vm).and_raise('create vm failure')

            expect {
              subject.update_resource_pool(new_disk_cid)
            }.to raise_error(/create vm failure/)
          end
        end
      end

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

    describe 'shutting_down?' do

      context 'when the resource pool has changed' do
        let(:resource_pool_changed) { true }

        its(:shutting_down?) { should be(true) }
      end
      context 'when the persistent disks have changed' do
        let(:persistent_disk_changed) { true }

        its(:shutting_down?) { should be(true) }
      end

      context 'when the networks have changed' do
        let(:networks_changed) { true }

        its(:shutting_down?) { should be(true) }
      end

      context 'when the target state is detached' do
        let(:state) { 'detached' }

        its(:shutting_down?) { should be(true) }
      end

      context 'when the target state is stopped' do
        let(:state) { 'stopped' }

        its(:shutting_down?) { should be(true) }
      end

      context 'when the target state is started' do
        let(:state) { 'started' }

        its(:shutting_down?) { should be(false) }
      end
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
  end
end
