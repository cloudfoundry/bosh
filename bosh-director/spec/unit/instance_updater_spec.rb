require 'spec_helper'

module Bosh::Director
  describe InstanceUpdater do
    subject { described_class.new(instance, ticker, job_renderer) }

    let(:ticker) { double('ticker', advance: nil) }
    let(:job_renderer) { instance_double('Bosh::Director::JobRenderer') }

    before { allow(App).to receive_message_chain(:instance, :blobstores, :blobstore).and_return(blobstore) }
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
             spec: 'resource_pool_spec',
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
    let(:trusted_certs_changed) { false }
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
             trusted_certs_changed?: trusted_certs_changed,
             spec: instance_spec,
             disk_currently_attached?: disk_currently_attached,
             network_settings: double('NetworkSettings'),
             disk_size: disk_size)
    end
    let(:cloud) { instance_double('Bosh::Cloud') }

    let(:agent_client) { instance_double('Bosh::Director::AgentClient', id: vm_model.agent_id) }

    before do
      allow(AgentClient).to receive(:with_defaults).and_return(agent_client)
      allow(Bosh::Director::Config).to receive(:cloud).and_return(cloud)

      allow(agent_client).to receive(:run_script)
      allow(instance). to receive(:spec).and_return(
                              {
                                  'deployment' => 'simple',
                                  'job' => {
                                      'name' => 'job_with_templates_having_pre_start_scripts',
                                      'templates' => [{'name' => 'job_with_pre_start'}]
                                  }
                              }
                          )

    end

    describe '#report_progress' do
      subject { described_class.new(instance, event_log_task, job_renderer) }
      let(:event_log_task) { instance_double('Bosh::Director::EventLog::Task') }

      it 'advances the ticker' do
        allow(subject).to receive(:update_steps).and_return(['dummy_step'] * 200)
        expect(event_log_task).to receive(:advance).with(0.5)
        subject.report_progress(200)
      end
    end

    describe '#update' do
      def self.it_updates_vm_metadata
        it 'updates vm metadata' do
          vm_metadata_updater = instance_double('Bosh::Director::VmMetadataUpdater')
          expect(Bosh::Director::VmMetadataUpdater).to receive(:build).and_return(vm_metadata_updater)
          expect(vm_metadata_updater).to receive(:update).with(vm_model, {})
          subject.update
        end
      end

      before { allow(InstanceUpdater::Preparer).to receive(:new).with(instance, agent_client, Config.logger).and_return(preparer) }
      let(:preparer) { instance_double('Bosh::Director::InstanceUpdater::Preparer', prepare: nil) }

      before { allow(RenderedJobTemplatesCleaner).to receive(:new).with(instance_model, blobstore).and_return(templates_cleaner) }
      let(:templates_cleaner) { instance_double('Bosh::Director::RenderedJobTemplatesCleaner', clean: nil) }

      context 'when instance is not detached' do
        before do
          allow(subject).to receive(:stop)
          allow(subject).to receive(:start!)
          allow(subject).to receive(:apply_state)
          allow(subject).to receive(:wait_until_running)
          allow(subject).to receive(:current_state).and_return({'job_state' => 'running'})
        end

        it 'cleans up rendered job templates after apply' do
          expect(subject).to receive(:apply_state).ordered
          expect(templates_cleaner).to receive(:clean).ordered
          subject.update
        end
      end

      context 'with only a dns change' do
        let(:changes) { [:dns].to_set }

        before do
          allow(subject).to receive(:current_state).and_return({'job_state' => 'running'})
        end

        it 'should only call update_dns' do
          steps = subject.update_steps
          expect(steps.length).to eq 1

          expect(subject).to receive(:update_dns)
          steps[0].call
        end

        it 'does not prepare instance' do
          expect(InstanceUpdater::Preparer).to_not receive(:new)
          subject.update
        end

        it 'does not update vm metadata' do
          expect(Bosh::Director::VmMetadataUpdater).to_not receive(:new)
          subject.update
        end
      end

      context 'when the job instance needs to be stopped' do
        before do
          allow(subject).to receive(:stop)
          allow(subject).to receive(:start!)
          allow(subject).to receive(:apply_state)
          allow(subject).to receive(:wait_until_running)
          allow(subject).to receive(:current_state).and_return({'job_state' => 'running'})
        end

        it 'prepares the job before stopping it to minimize downtime' do
          expect(preparer).to receive(:prepare).ordered
          expect(subject).to receive(:stop).ordered
          subject.update
        end

        it 'stops the job' do
          expect(subject).to receive(:stop)
          subject.update
        end

        it_updates_vm_metadata
      end

      context 'when a snapshot is needed' do
        let(:job_changed) { true }
        let(:packages_changed) { true }

        before do
          allow(subject).to receive(:stop)
          allow(subject).to receive(:start!)
          allow(subject).to receive(:apply_state)
          allow(subject).to receive(:wait_until_running)
          allow(subject).to receive(:current_state).and_return({'job_state' => 'running'})
        end

        it 'should take snapshot' do
          expect(subject).to receive(:take_snapshot)
          subject.update
        end

        it_updates_vm_metadata
      end

      context 'when there is a network change' do
        let(:networks_changed) { true }

        before do
          allow(cloud).to receive(:configure_networks)
          allow(agent_client).to receive(:prepare_configure_networks)
          allow(agent_client).to receive(:configure_networks)
          allow(agent_client).to receive(:wait_until_ready)
          allow(subject).to receive(:stop)
          allow(subject).to receive(:update_resource_pool)
          allow(subject).to receive(:start!)
          allow(subject).to receive(:apply_state)
          allow(subject).to receive(:wait_until_running)
          allow(subject).to receive(:current_state).and_return({'job_state' => 'running'})
        end

        context 'when a vm does not need to be recreated' do
          it 'should prepare network change' do
            expect(cloud).to receive(:configure_networks)
            expect(agent_client).to receive(:configure_networks)
            expect(agent_client).to receive(:wait_until_ready)

            subject.update
          end
        end

        context 'when a vm needs to be recreated' do
          context 'without persistent disk' do
            let(:persistent_disk_changed) { false }

            it 'should recreate vm' do
              expect(agent_client).to_not receive(:configure_networks)
              expect(cloud).to receive(:configure_networks).and_raise(Bosh::Clouds::NotSupported)
              expect(instance).to receive(:recreate=)

              subject.update
            end
          end

          context 'with persistent disk' do
            let(:persistent_disk_changed) { true }
            let(:disk_cloud_properties) do
              {
                'fake-disk-key' => 'fake-disk-value',
              }
            end

            let(:disk_pool) do
              instance_double(
                'Bosh::Director::DeploymentPlan::DiskPool',
                disk_size: 1024,
                cloud_properties: disk_cloud_properties,
              )
            end

            before do
              allow(job).to receive(:persistent_disk_pool).and_return(disk_pool)
              allow(cloud).to receive(:create_disk).and_return('disk-cid')
              allow(cloud).to receive(:attach_disk)
              allow(agent_client).to receive(:mount_disk)
            end

            it 'creates new disk record' do
              subject.update
              persistent_disk = Bosh::Director::Models::PersistentDisk.first
              expect(persistent_disk.size).to eq(1024)
              expect(persistent_disk.instance_id).to eq(instance_model.id)
              expect(persistent_disk.active).to eq(true)
              expect(persistent_disk.cloud_properties).to eq(disk_cloud_properties)
            end

            it 'should recreate vm and attach disk' do
              expect(agent_client).to_not receive(:configure_networks)
              expect(cloud).to receive(:configure_networks).and_raise(Bosh::Clouds::NotSupported)
              expect(instance).to receive(:recreate=)
              expect(cloud).to receive(:create_disk).and_return('disk-cid')
              expect(cloud).to receive(:attach_disk)
              expect(agent_client).to receive(:mount_disk)

              subject.update
            end

            it_updates_vm_metadata
          end
        end
      end

      describe 'canary' do
        before do
          allow(subject).to receive(:stop)
          allow(subject).to receive(:start!)
          allow(subject).to receive(:apply_state)
          allow(subject).to receive(:wait_until_running)
          allow(subject).to receive(:current_state).and_return({'job_state' => 'running'})
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
        allow(subject).to receive(:watch_schedule) { intervals }
        allow(subject).to receive(:sleep)
        allow(agent_client).to receive(:get_state) { agent_state }
      end

      it 'sleeps for the correct amount of time' do
        intervals.map { |i| i.to_f/1000 }.each do |wait|
          expect(subject).to receive(:sleep).with(wait).ordered
        end
        subject.wait_until_running
      end

      context 'when the VM is being started' do
        it 'stops waiting when the VM is running' do
          allow(agent_client).to receive(:get_state).and_return(
            {'job_state' => 'stopped'},
            {'job_state' => 'running'}
          )
          expect(subject).to receive(:sleep).with(1.0).once
          expect(subject).to receive(:sleep).with(2.0).once
          expect(subject).to_not receive(:sleep).with(3.0)
          expect(subject).to_not receive(:sleep).with(4.0)

          subject.wait_until_running
        end
      end

      context 'when the VM is being stopped' do
        let(:state) { 'stopped' }

        it 'stop waiting when the VM is not running' do
          allow(agent_client).to receive(:get_state).and_return(
            {'job_state' => 'running'},
            {'job_state' => 'running'},
            {'job_state' => 'stopped'}
          )
          expect(subject).to receive(:sleep).with(1.0).once
          expect(subject).to receive(:sleep).with(2.0).once
          expect(subject).to receive(:sleep).with(3.0).once
          expect(subject).to_not receive(:sleep).with(4.0)

          subject.wait_until_running
        end
      end

      context 'when the VM never gets to the right state' do
        it 'stops waiting after all the intervals' do
          allow(agent_client).to receive(:get_state).and_return(
            {'job_state' => 'stopped'}
          )
          expect(subject).to receive(:sleep).with(1.0).once
          expect(subject).to receive(:sleep).with(2.0).once
          expect(subject).to receive(:sleep).with(3.0).once
          expect(subject).to receive(:sleep).with(4.0).once

          subject.wait_until_running
        end
      end
    end

    describe '#start!' do
      it 'tells the agent to start' do
        expect(agent_client).to receive(:start)
        subject.start!
      end

      it 'logs errors' do
        allow(agent_client).to receive(:start).and_raise('error')
        expect(Config.logger).to receive(:warn).
          with('Agent start raised an exception: #<RuntimeError: error>, ignoring for compatibility')
        subject.start!
      end
    end

    describe '#run_pre_start_scripts' do
      it 'tells the agent to run_pre_start_scripts' do
        expect(agent_client).to receive(:run_script)
        subject.run_pre_start_scripts
      end

      it 'send an array of scripts to the agent to run' do
        expect(agent_client).to receive(:run_script).with("pre-start", {})
        subject.run_pre_start_scripts
      end
    end

    describe '#need_start?' do
      context 'when target state is "started"' do
        it { is_expected.to be_need_start }
      end

      context 'when target state is not "started"' do
        let(:state) { 'stopped' }
        it { is_expected.not_to be_need_start }
      end
    end

    describe '#dns_change_only?' do
      context 'when there is no DNS change' do
        it { is_expected.not_to be_dns_change_only }
      end

      context 'when there is only a DNS change' do
        let(:changes) { [:dns].to_set }
        it { is_expected.to be_dns_change_only }
      end

      context 'when there is a DNS change plus other stuff' do
        let(:changes) { [:dns, :other_stuff].to_set }
        it { is_expected.not_to be_dns_change_only }
      end
    end

    describe '#stop' do
      let(:state) { 'fake-target-state' }
      before { allow(deployment_plan).to receive(:skip_drain_for_job?).with('test-job').and_return(false) }

      it 'stop an instance' do
        stopper = instance_double('Bosh::Director::InstanceUpdater::Stopper')
        expect(InstanceUpdater::Stopper).to receive(:new).
          with(instance, agent_client, 'fake-target-state', false, Config, Config.logger).
          and_return(stopper)

        expect(stopper).to receive(:stop).with(no_args)

        subject.stop
      end
    end

    describe '#take_snapshot' do
      it 'tells the snapshot manager to take a snapshot' do
        expect(Api::SnapshotManager).to receive(:take_snapshot).with(instance_model, clean: true)
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
        expect(Api::SnapshotManager).to receive(:delete_snapshots).with(snapshots)
        subject.delete_snapshots(disk)
      end
    end

    describe '#apply_state' do
      it 'updates the vm' do
        expect(instance.model.vm).to receive(:update).with(apply_spec: 'newstate')
        expect(agent_client).to receive(:apply).with('newstate')
        subject.apply_state('newstate')
      end
    end

    describe '#disk_info' do
      context 'when there is a disk list' do
        it 'caches the disk list' do
          allow(agent_client).to receive(:list_disk).once.and_return []
          expect(subject.disk_info).to eq []
          expect(subject.disk_info).to eq []
        end
      end

      context 'when there is no disk list' do
        it 'gets the list of disks from the agent' do
          expect(agent_client).to receive(:list_disk).and_return []
          expect(subject.disk_info).to eq []
        end
      end

      context 'when the agent does not support list_disk' do
        it 'returns the persistent disk cid of the instance' do
          allow(agent_client).to receive(:list_disk).and_raise RuntimeError
          expect(instance).to receive(:persistent_disk_cid).and_return('disk_cid')
          expect(subject.disk_info).to eq ['disk_cid']
        end
      end
    end

    describe '#delete_mounted_disk' do
      let(:disk) { instance_double('Bosh::Director::Models::PersistentDisk', disk_cid: 'disk_cid') }

      it 'deletes the disk and destroys the disk model' do
        expect(cloud).to receive(:delete_disk).with(disk.disk_cid)
        expect(disk).to receive(:destroy)

        subject.delete_unused_disk(disk)
      end
    end

    describe '#delete_mounted_disk' do
      let(:disk) { instance_double('Bosh::Director::Models::PersistentDisk', disk_cid: 'disk_cid') }
      let(:vm_model) { Models::Vm.make(deployment: deployment_model, cid: 'vm_cid') }

      before do
        allow(subject).to receive(:disk_info).and_return([disk.disk_cid])
        allow(agent_client).to receive(:unmount_disk)
        allow(subject).to receive(:delete_snapshots)
        allow(cloud).to receive(:detach_disk)
        allow(cloud).to receive(:delete_disk)
        allow(disk).to receive(:destroy)
        allow(disk).to receive(:active).and_return(true)
      end

      context 'when the disk is known by the agent' do
        it 'umounts the disk' do
          expect(agent_client).to receive(:unmount_disk).with(disk.disk_cid)

          subject.delete_mounted_disk(disk)
        end
      end

      context 'when the disk is attached' do
        it 'detaches the disk' do
          expect(cloud).to receive(:detach_disk).with(vm_model.cid, disk.disk_cid)

          subject.delete_mounted_disk(disk)
        end
      end

      context 'when the disk is not attached' do
        it 'raises an exception' do
          allow(cloud).to receive(:detach_disk).with(vm_model.cid, disk.disk_cid).and_raise(CloudDiskNotAttached)

          expect { subject.delete_mounted_disk(disk) }.to raise_exception(CloudDiskNotAttached)
        end
      end

      it 'deletes the snapshots' do
        expect(subject).to receive(:delete_snapshots).with(disk)

        subject.delete_mounted_disk(disk)
      end

      it 'deletes the disk' do
        expect(cloud).to receive(:delete_disk).with(disk.disk_cid)

        subject.delete_mounted_disk(disk)
      end

      context 'when the disk is not found' do
        it 'raises an exception' do
          expect(cloud).to receive(:delete_disk).with(disk.disk_cid).and_raise(Bosh::Clouds::DiskNotFound.new(false))

          expect { subject.delete_mounted_disk(disk) }.to raise_exception(CloudDiskMissing)
        end
      end

      it 'destroys the disk' do
        expect(disk).to receive(:destroy)

        subject.delete_mounted_disk(disk)
      end
    end

    describe '#update_dns' do
      context 'when DNS is not being changed' do
        it { expect(subject).to_not receive(:update_dns_a_record) }
        it { expect(subject).to_not receive(:update_dns_ptr_record) }
        it { expect(subject).to_not receive(:flush_dns_cache) }
      end

      context 'when DNS is being changed' do
        let(:dns_changed) { true }

        it 'updates the A and PTR records' do
          allow(instance).to receive(:dns_record_info).and_return([
                                                       ['record 1', '1.1.1.1'],
                                                       ['record 2', '2.2.2.2'],
                                                     ])

          expect(subject).to receive(:update_dns_a_record).with(domain, 'record 1', '1.1.1.1')
          expect(subject).to receive(:update_dns_ptr_record).with('record 1', '1.1.1.1')
          expect(subject).to receive(:update_dns_a_record).with(domain, 'record 2', '2.2.2.2')
          expect(subject).to receive(:update_dns_ptr_record).with('record 2', '2.2.2.2')
          expect(subject).to receive(:flush_dns_cache).once
          subject.update_dns
        end
      end
    end

    describe '#recreate_vm' do
      it 'updates the VM' do
        vm_updater = instance_double('Bosh::Director::InstanceUpdater::VmUpdater')
        expect(InstanceUpdater::VmUpdater).to receive(:new).
          with(instance, vm_model, agent_client, job_renderer, cloud, 3, Config.logger).
          and_return(vm_updater)

        expect(vm_updater).to receive(:update).with('new-disk-cid')

        subject.recreate_vm('new-disk-cid')
      end
    end

    describe '#update_networks' do
      it 'updates networks' do
        vm_updater = instance_double('Bosh::Director::InstanceUpdater::VmUpdater')
        expect(InstanceUpdater::VmUpdater).to receive(:new).
          with(instance, vm_model, agent_client, job_renderer, cloud, 3, Config.logger).
          and_return(vm_updater)

        network_updater = instance_double('Bosh::Director::InstanceUpdater::NetworkUpdater')
        expect(InstanceUpdater::NetworkUpdater).to receive(:new).
          with(instance, vm_model, agent_client, vm_updater, cloud, Config.logger).
          and_return(network_updater)

        expect(network_updater).to receive(:update).with(no_args)

        subject.update_networks
      end
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

    describe '#min_watch_time' do
      context 'with a canary' do
        it 'should return min_canary_watch_time' do
          allow(subject).to receive(:canary?).and_return(true)
          expect(subject.min_watch_time).to eq 0.03
        end
      end

      context 'without a canary' do
        it 'should return min_update_watch_time' do
          allow(subject).to receive(:canary?).and_return(false)
          expect(subject.min_watch_time).to eq 0.01
        end
      end
    end

    describe '#max_watch_time' do
      context 'with a canary' do
        it 'should return max_canary_watch_time' do
          allow(subject).to receive(:canary?).and_return(true)
          expect(subject.max_watch_time).to eq 0.04
        end
      end

      context 'without a canary' do
        it 'should return max_update_watch_time' do
          allow(subject).to receive(:canary?).and_return(false)
          expect(subject.max_watch_time).to eq 0.02
        end
      end
    end
  end
end
