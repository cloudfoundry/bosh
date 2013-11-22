require 'spec_helper'

module Bosh::Director
  describe InstanceDeleter do
    before(:each) do
      @cloud = double('cloud')
      Config.stub(:cloud).and_return(@cloud)

      @deployment_plan = double('deployment_plan')
      @deleter = InstanceDeleter.new(@deployment_plan)
    end

    describe :delete_instances do
      it 'should delete the instances with the config max threads option' do
        instances = []
        5.times { instances << double('instance') }

        Config.stub(:max_threads).and_return(5)
        pool = double('pool')
        ThreadPool.stub(:new).with(max_threads: 5).and_return(pool)
        pool.stub(:wrap).and_yield(pool)
        pool.stub(:process).and_yield

        5.times do |index|
          @deleter.should_receive(:delete_instance).with(instances[index])
        end

        @deleter.delete_instances(instances)
      end

      it 'should delete the instances with the respected max threads option' do
        instances = []
        5.times { instances << double('instance') }

        pool = double('pool')
        ThreadPool.stub(:new).with(max_threads: 2).and_return(pool)
        pool.stub(:wrap).and_yield(pool)
        pool.stub(:process).and_yield

        5.times do |index|
          @deleter.should_receive(:delete_instance).with(instances[index])
        end

        @deleter.delete_instances(instances, max_threads: 2)
      end
    end

    describe :delete_instance do
      it 'should delete a single instance' do
        vm = Models::Vm.make
        instance = Models::Instance.make(vm: vm, job: 'test', index: 5)
        disk = Models::PersistentDisk.make
        snapshot = Models::Snapshot.make(persistent_disk: disk)
        persistent_disks = [Models::PersistentDisk.make, disk]
        persistent_disks.each { |disk| instance.persistent_disks << disk }

        @deleter.should_receive(:drain).with(vm.agent_id)
        @deleter.should_receive(:delete_snapshots).with(instance)
        @deleter.should_receive(:delete_persistent_disks).with(persistent_disks)
        Config.stub(:dns_domain_name).and_return('bosh')
        @deleter.should_receive(:delete_dns_records).with('5.test.%.foo.bosh', 0)
        @deployment_plan.should_receive(:canonical_name).and_return('foo')
        domain = double('domain', id:  0)
        @deployment_plan.should_receive(:dns_domain).and_return(domain)
        @cloud.should_receive(:delete_vm).with(vm.cid)

        job_templates_cleaner = instance_double('Bosh::Director::RenderedJobTemplatesCleaner')
        RenderedJobTemplatesCleaner.stub(:new).with(instance).and_return(job_templates_cleaner)
        job_templates_cleaner.should_receive(:clean_all)

        @deleter.delete_instance(instance)

        Models::Vm[vm.id].should == nil
        Models::Instance[instance.id].should == nil
      end
    end

    describe :drain do
      it 'should drain the VM' do
        agent = double('agent')
        AgentClient.stub(:with_defaults).with('some_agent_id').and_return(agent)

        agent.should_receive(:drain).with('shutdown').and_return(2)
        agent.should_receive(:stop)
        @deleter.should_receive(:sleep).with(2)

        @deleter.drain('some_agent_id')
      end

      it 'should dynamically drain the VM' do
        agent = double('agent')
        AgentClient.stub(:with_defaults).with('some_agent_id').and_return(agent)
        Config.stub(:job_cancelled?).and_return(nil)

        agent.should_receive(:drain).with('shutdown').and_return(-2)
        agent.should_receive(:drain).with('status').and_return(1, 0)

        @deleter.should_receive(:sleep).with(2)
        @deleter.should_receive(:sleep).with(1)

        agent.should_receive(:stop)
        @deleter.drain('some_agent_id')
      end

      it 'should stop vm-drain if task is cancelled' do
        agent = double('agent')
        AgentClient.stub(:with_defaults).with('some_agent_id').and_return(agent)
        Config.stub(:job_cancelled?).and_raise(TaskCancelled.new(1))
        agent.should_receive(:drain).with('shutdown').and_return(-2)
        lambda { @deleter.drain('some_agent_id') }.should raise_error(TaskCancelled)
      end

    end

    describe :delete_persistent_disks do
      it 'should delete the persistent disks' do
        persistent_disks = [Models::PersistentDisk.make(active:  true), Models::PersistentDisk.make(active:  false)]

        persistent_disks.each do |disk|
          @cloud.should_receive(:delete_disk).with(disk.disk_cid)
        end

        @deleter.delete_persistent_disks(persistent_disks)

        persistent_disks.each do |disk|
          Models::PersistentDisk[disk.id].should == nil
        end
      end

      it 'should ignore errors to inactive persistent disks' do
        disk = Models::PersistentDisk.make(active:  false)
        @cloud.should_receive(:delete_disk).with(disk.disk_cid).and_raise(Bosh::Clouds::DiskNotFound.new(true))
        @deleter.delete_persistent_disks([disk])
      end

      it 'should not ignore errors to active persistent disks' do
        disk = Models::PersistentDisk.make(active:  true)
        @cloud.should_receive(:delete_disk).with(disk.disk_cid).and_raise(Bosh::Clouds::DiskNotFound.new(true))
        lambda { @deleter.delete_persistent_disks([disk]) }.should raise_error(Bosh::Clouds::DiskNotFound)
      end
    end

    describe :delete_dns do
      it 'should generate a correct SQL query string' do
        domain = Models::Dns::Domain.make
        @deployment_plan.stub(:canonical_name).and_return('dep')
        @deployment_plan.stub(:dns_domain).and_return(domain)
        pattern = '0.foo.%.dep.bosh'
        Config.stub(:dns_domain_name).and_return('bosh')
        @deleter.should_receive(:delete_dns_records).with(pattern, domain.id)
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

          Api::SnapshotManager.should_receive(:delete_snapshots).with(snapshots)

          @deleter.delete_snapshots(instance)
        end
      end

      context 'with three disks' do
        let(:disk2) { Models::PersistentDisk.make(instance: instance) }
        let(:disk3) { Models::PersistentDisk.make(instance: instance) }
        let(:snapshot3) { Models::Snapshot.make(persistent_disk: disk2) }
        it 'should delete all snapshots for an instance' do
          snapshots = [snapshot1, snapshot2, snapshot3]

          Api::SnapshotManager.should_receive(:delete_snapshots).with(snapshots)

          @deleter.delete_snapshots(instance)
        end
      end
    end
  end
end
