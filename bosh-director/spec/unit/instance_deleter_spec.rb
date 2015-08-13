require 'spec_helper'

module Bosh::Director
  describe InstanceDeleter do
    before { allow(App).to receive_message_chain(:instance, :blobstores, :blobstore).and_return(blobstore) }
    let(:blobstore) { instance_double('Bosh::Blobstore::Client') }
    let(:domain) { Models::Dns::Domain.make }

    before do
      @cloud = instance_double('Bosh::Cloud')
      allow(Config).to receive(:cloud).and_return(@cloud)
      @deployment_plan = instance_double(DeploymentPlan::Planner, canonical_name: 'dep', dns_domain: domain)
      @deleter = InstanceDeleter.new(@deployment_plan)
    end

    describe '#delete_instances' do
      let(:event_log_stage) { instance_double('Bosh::Director::EventLog::Stage') }
      let(:instances_to_delete) do
        instances = []
        5.times { instances << double('instance') }
        instances
      end

      before do
        allow(event_log_stage).to receive(:advance_and_track).and_yield
      end

      let(:vm) do
        vm = DeploymentPlan::Vm.new
        vm.model = Models::Vm.make(cid: 'fake-vm-cid')
        vm
      end

      let(:instance) do
        instance_double(
          DeploymentPlan::ExistingInstance,
          model: Models::Instance.make(vm: vm.model),
          vm: vm,
          job_name: 'fake-job-name',
          index: 5,
          name: 'fake-job-name/5',
          release_original_network_reservations: nil
        )
      end

      it 'should delete the instances with the config max threads option' do
        allow(Config).to receive(:max_threads).and_return(5)
        pool = double('pool')
        allow(ThreadPool).to receive(:new).with(max_threads: 5).and_return(pool)
        allow(pool).to receive(:wrap).and_yield(pool)
        allow(pool).to receive(:process).and_yield

        5.times do |index|
          expect(@deleter).to receive(:delete_instance).with(
            instances_to_delete[index], event_log_stage
          )
        end
        @deleter.delete_instances(instances_to_delete, event_log_stage)
      end

      it 'should delete the instances with the respected max threads option' do
        pool = double('pool')
        allow(ThreadPool).to receive(:new).with(max_threads: 2).and_return(pool)
        allow(pool).to receive(:wrap).and_yield(pool)
        allow(pool).to receive(:process).and_yield

        5.times do |index|
          expect(@deleter).to receive(:delete_instance).with(
            instances_to_delete[index], event_log_stage)
        end
        @deleter.delete_instances(instances_to_delete, event_log_stage, max_threads: 2)
      end

      it 'drains, deletes snapshots, persistent disk, releases old reservations' do
        disk = Models::PersistentDisk.make(disk_cid: 'fake-disk-cid-1')
        Models::Snapshot.make(persistent_disk: disk)
        persistent_disks = [Models::PersistentDisk.make(disk_cid: 'instance-disk-cid'), disk]
        persistent_disks.each { |disk| instance.model.persistent_disks << disk }

        expect(@deleter).to receive(:drain).with(vm.model)
        expect(@deleter).to receive(:delete_snapshots).with(instance.model)
        expect(@deleter).to receive(:delete_persistent_disks).with(persistent_disks)
        allow(Config).to receive(:dns_domain_name).and_return('bosh')
        expect(@deleter).to receive(:delete_dns_records).with('5.fake-job-name.%.dep.bosh', domain.id)
        expect(@cloud).to receive(:delete_vm).with(vm.model.cid)
        expect(instance).to receive(:delete)
        expect(instance).to receive(:release_original_network_reservations)

        expect(event_log_stage).to receive(:advance_and_track).with('fake-job-name/5')

        job_templates_cleaner = instance_double('Bosh::Director::RenderedJobTemplatesCleaner')
        allow(RenderedJobTemplatesCleaner).to receive(:new).with(instance.model, blobstore).and_return(job_templates_cleaner)
        expect(job_templates_cleaner).to receive(:clean_all).with(no_args)

        @deleter.delete_instances([instance], event_log_stage)

        expect(Models::Vm.find(cid: 'fake-vm-cid')).to eq(nil)
      end

      context 'when instance does not have vm' do
        it 'skips drain' do
          instance.model.vm = instance.vm.model = nil
          expect(@deleter).to_not receive(:drain)
          expect(instance).to receive(:delete)
          @deleter.delete_instances([instance], event_log_stage)
        end
      end
    end

    describe :drain do
      let(:vm) { Models::Vm.make }
      let(:agent) { double('agent') }
      before do
        allow(AgentClient).to receive(:with_vm).with(vm).and_return(agent)
      end

      it 'should drain the VM' do
        expect(agent).to receive(:drain).with('shutdown').and_return(2)
        expect(agent).to receive(:stop)
        expect(@deleter).to receive(:sleep).with(2)

        @deleter.drain(vm)
      end

      it 'should dynamically drain the VM' do
        allow(Config).to receive(:job_cancelled?).and_return(nil)

        expect(agent).to receive(:drain).with('shutdown').and_return(-2)
        expect(agent).to receive(:drain).with('status').and_return(-3, 1)

        expect(@deleter).to receive(:sleep).with(2)
        expect(@deleter).to receive(:sleep).with(3)
        expect(@deleter).to receive(:sleep).with(1)

        expect(agent).to receive(:stop)
        @deleter.drain(vm)
      end

      it 'should dynamically drain the VM when drain script returns 0 eventually' do
        allow(Config).to receive(:job_cancelled?).and_return(nil)

        expect(agent).to receive(:drain).with('shutdown').and_return(-2)
        expect(agent).to receive(:drain).with('status').and_return(-3, 0)

        expect(@deleter).to receive(:sleep).with(2)
        expect(@deleter).to receive(:sleep).with(3)
        expect(@deleter).to receive(:sleep).with(0)

        expect(agent).to receive(:stop)
        @deleter.drain(vm)
      end

      it 'should stop vm-drain if task is cancelled' do
        allow(Config).to receive(:job_cancelled?).and_raise(TaskCancelled.new(1))
        expect(agent).to receive(:drain).with('shutdown').and_return(-2)
        expect { @deleter.drain(vm) }.to raise_error(TaskCancelled)
      end
    end

    describe :delete_persistent_disks do
      it 'should delete the persistent disks' do
        persistent_disks = [Models::PersistentDisk.make(active:  true), Models::PersistentDisk.make(active:  false)]
        persistent_disks.each { |disk| expect(@cloud).to receive(:delete_disk).with(disk.disk_cid) }
        @deleter.delete_persistent_disks(persistent_disks)
        persistent_disks.each { |disk| expect(Models::PersistentDisk[disk.id]).to eq(nil) }
      end

      it 'should ignore errors to inactive persistent disks' do
        disk = Models::PersistentDisk.make(active:  false)
        expect(@cloud).to receive(:delete_disk).with(disk.disk_cid).and_raise(Bosh::Clouds::DiskNotFound.new(true))
        @deleter.delete_persistent_disks([disk])
      end

      it 'should not ignore errors to active persistent disks' do
        disk = Models::PersistentDisk.make(active:  true)
        expect(@cloud).to receive(:delete_disk).with(disk.disk_cid).and_raise(Bosh::Clouds::DiskNotFound.new(true))
        expect { @deleter.delete_persistent_disks([disk]) }.to raise_error(Bosh::Clouds::DiskNotFound)
      end
    end

    describe :delete_dns do
      it 'should generate a correct SQL query string' do
        pattern = '0.foo.%.dep.bosh'
        allow(Config).to receive(:dns_domain_name).and_return('bosh')
        expect(@deleter).to receive(:delete_dns_records).with(pattern, domain.id)
        @deleter.delete_dns('foo', 0)
      end
    end

    describe :delete_snapshots do
      let(:vm) { Models::Vm.make }
      let(:instance) { Models::Instance.make(vm: vm, job: 'test', index: 5) }
      let(:disk) { Models::PersistentDisk.make(instance: instance) }
      let(:snapshot1) { Models::Snapshot.make(persistent_disk: disk) }
      let(:snapshot2) { Models::Snapshot.make(persistent_disk: disk) }

      context 'with one disk' do
        it 'should delete all snapshots for an instance' do
          snapshots = [snapshot1, snapshot2]
          expect(Api::SnapshotManager).to receive(:delete_snapshots).with(snapshots)
          @deleter.delete_snapshots(instance)
        end
      end

      context 'with three disks' do
        let(:disk2) { Models::PersistentDisk.make(instance: instance) }
        let(:disk3) { Models::PersistentDisk.make(instance: instance) }
        let(:snapshot3) { Models::Snapshot.make(persistent_disk: disk2) }

        it 'should delete all snapshots for an instance' do
          snapshots = [snapshot1, snapshot2, snapshot3]
          expect(Api::SnapshotManager).to receive(:delete_snapshots).with(snapshots)
          @deleter.delete_snapshots(instance)
        end
      end
    end
  end
end
