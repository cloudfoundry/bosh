require 'spec_helper'

module Bosh::Director
  describe InstanceDeleter do
    before { allow(App).to receive_message_chain(:instance, :blobstores, :blobstore).and_return(blobstore) }
    let(:blobstore) { instance_double('Bosh::Blobstore::Client') }

    before do
      @cloud = instance_double('Bosh::Cloud')
      allow(Config).to receive(:cloud).and_return(@cloud)
      @deployment_plan = double('deployment_plan')
      @deleter = InstanceDeleter.new(@deployment_plan)
    end

    describe '#delete_instances' do
      let(:event_log_stage) { instance_double('Bosh::Director::EventLog::Stage') }

      it 'should delete the instances with the config max threads option' do
        instances = []
        5.times { instances << double('instance') }

        allow(Config).to receive(:max_threads).and_return(5)
        pool = double('pool')
        allow(ThreadPool).to receive(:new).with(max_threads: 5).and_return(pool)
        allow(pool).to receive(:wrap).and_yield(pool)
        allow(pool).to receive(:process).and_yield

        5.times { |index| expect(@deleter).to receive(:delete_instance).with(instances[index], event_log_stage) }
        @deleter.delete_instances(instances, event_log_stage)
      end

      it 'should delete the instances with the respected max threads option' do
        instances = []
        5.times { instances << double('instance') }

        pool = double('pool')
        allow(ThreadPool).to receive(:new).with(max_threads: 2).and_return(pool)
        allow(pool).to receive(:wrap).and_yield(pool)
        allow(pool).to receive(:process).and_yield

        5.times { |index| expect(@deleter).to receive(:delete_instance).with(instances[index], event_log_stage) }
        @deleter.delete_instances(instances, event_log_stage, max_threads: 2)
      end
    end

    describe '#delete_instance' do
      let(:instance) { Models::Instance.make(vm: vm, job: 'test', index: 5) }
      let(:event_log_stage) { instance_double('Bosh::Director::EventLog::Stage') }
      let(:vm) { Models::Vm.make }

      it 'deletes a single instance' do
        allow(event_log_stage).to receive(:advance_and_track).and_yield

        disk = Models::PersistentDisk.make
        Models::Snapshot.make(persistent_disk: disk)
        persistent_disks = [Models::PersistentDisk.make, disk]
        persistent_disks.each { |disk| instance.persistent_disks << disk }

        expect(@deleter).to receive(:drain).with(vm.agent_id)
        expect(@deleter).to receive(:delete_snapshots).with(instance)
        expect(@deleter).to receive(:delete_persistent_disks).with(persistent_disks)
        allow(Config).to receive(:dns_domain_name).and_return('bosh')
        expect(@deleter).to receive(:delete_dns_records).with('5.test.%.foo.bosh', 0)
        expect(@deployment_plan).to receive(:canonical_name).and_return('foo')
        domain = double('domain', id:  0)
        expect(@deployment_plan).to receive(:dns_domain).and_return(domain)
        expect(@cloud).to receive(:delete_vm).with(vm.cid)

        job_templates_cleaner = instance_double('Bosh::Director::RenderedJobTemplatesCleaner')
        allow(RenderedJobTemplatesCleaner).to receive(:new).with(instance, blobstore, logger).and_return(job_templates_cleaner)
        expect(job_templates_cleaner).to receive(:clean_all).with(no_args)

        @deleter.delete_instance(instance, event_log_stage)

        expect(Models::Vm[vm.id]).to eq(nil)
        expect(Models::Instance[instance.id]).to eq(nil)
      end

      it 'advances event log stage to track deletion of given instance' do
        expect(event_log_stage).to receive(:advance_and_track).with(vm.cid)
        @deleter.delete_instance(instance, event_log_stage)
      end
    end

    describe :drain do
      it 'should drain the VM' do
        agent = double('agent')
        allow(AgentClient).to receive(:with_defaults).with('some_agent_id').and_return(agent)

        expect(agent).to receive(:drain).with('shutdown').and_return(2)
        expect(agent).to receive(:stop)
        expect(@deleter).to receive(:sleep).with(2)

        @deleter.drain('some_agent_id')
      end

      it 'should dynamically drain the VM' do
        agent = double('agent')
        allow(AgentClient).to receive(:with_defaults).with('some_agent_id').and_return(agent)
        allow(Config).to receive(:job_cancelled?).and_return(nil)

        expect(agent).to receive(:drain).with('shutdown').and_return(-2)
        expect(agent).to receive(:drain).with('status').and_return(-3, 1)

        expect(@deleter).to receive(:sleep).with(2)
        expect(@deleter).to receive(:sleep).with(3)
        expect(@deleter).to receive(:sleep).with(1)

        expect(agent).to receive(:stop)
        @deleter.drain('some_agent_id')
      end

      it 'should dynamically drain the VM when drain script returns 0 eventually' do
        agent = double('agent')
        allow(AgentClient).to receive(:with_defaults).with('some_agent_id').and_return(agent)
        allow(Config).to receive(:job_cancelled?).and_return(nil)

        expect(agent).to receive(:drain).with('shutdown').and_return(-2)
        expect(agent).to receive(:drain).with('status').and_return(-3, 0)

        expect(@deleter).to receive(:sleep).with(2)
        expect(@deleter).to receive(:sleep).with(3)
        expect(@deleter).to receive(:sleep).with(0)

        expect(agent).to receive(:stop)
        @deleter.drain('some_agent_id')
      end

      it 'should stop vm-drain if task is cancelled' do
        agent = double('agent')
        allow(AgentClient).to receive(:with_defaults).with('some_agent_id').and_return(agent)
        allow(Config).to receive(:job_cancelled?).and_raise(TaskCancelled.new(1))
        expect(agent).to receive(:drain).with('shutdown').and_return(-2)
        expect { @deleter.drain('some_agent_id') }.to raise_error(TaskCancelled)
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
        domain = Models::Dns::Domain.make
        allow(@deployment_plan).to receive(:canonical_name).and_return('dep')
        allow(@deployment_plan).to receive(:dns_domain).and_return(domain)
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
