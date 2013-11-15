# Copyright (c) 2009-2012 VMware, Inc.

require 'spec_helper'

module Bosh::Director
  describe Jobs::DeleteDeployment do
    describe 'Resque job class expectations' do
      let(:job_type) { :delete_deployment }
      it_behaves_like 'a Resque job'
    end

    describe 'delete_instance' do
      before do
        @cloud = double('cloud')
        Config.stub(:cloud).and_return(@cloud)
        @job = Jobs::DeleteDeployment.new('test_deployment')
      end

      it "should delete the disk if it's not attached to the VM" do
        instance = Models::Instance.make(vm: nil)
        Models::PersistentDisk.make(disk_cid: 'disk-cid', instance_id: instance.id)

        @cloud.should_receive(:delete_disk).with('disk-cid')

        @job.delete_instance(instance)

        Models::Instance[instance.id].should be_nil
      end

      it 'should detach and delete disk if there is a disk' do
        agent = double('agent')

        AgentClient.stub(:with_defaults).with('agent-1').and_return(agent)

        vm = Models::Vm.make(cid: 'vm-cid', agent_id: 'agent-1')

        instance = Models::Instance.make(vm: vm)

        Models::PersistentDisk.make(disk_cid: 'disk-cid', instance_id: instance.id)

        agent.should_receive(:stop)
        agent.should_receive(:unmount_disk).with('disk-cid')

        @cloud.should_receive(:detach_disk).with('vm-cid', 'disk-cid')
        @cloud.should_receive(:delete_disk).with('disk-cid')

        @job.should_receive(:delete_vm).with(vm)

        @job.delete_instance(instance)

        Models::Instance[instance.id].should be_nil
      end

      it 'should only delete the VM if there is no disk' do
        agent = double('agent')

        AgentClient.stub(:with_defaults).with('agent-1').and_return(agent)

        vm = Models::Vm.make(cid: 'vm-cid', agent_id: 'agent-1')
        instance = Models::Instance.make(vm: vm)

        agent.should_receive(:stop)

        @job.should_receive(:delete_vm).with(vm)

        @job.delete_instance(instance)

        Models::Instance[instance.id].should be_nil
      end

      it 'should only delete the model if there is no VM' do
        instance = Models::Instance.make(vm: nil)

        @job.delete_instance(instance)

        Models::Instance[instance.id].should be_nil
      end

      it 'should ignore cpi errors if forced' do
        vm = Models::Vm.make(cid: 'vm-cid')
        instance = Models::Instance.make(vm: vm)
        Models::PersistentDisk.make(disk_cid: 'disk-cid', instance_id: instance.id)

        @cloud.should_receive(:detach_disk).with('vm-cid', 'disk-cid').and_raise('ERROR')
        @cloud.should_receive(:delete_disk).with('disk-cid').and_raise('ERROR')

        job = Jobs::DeleteDeployment.new('test_deployment', 'force' => true)
        job.should_receive(:delete_vm).with(vm)
        job.delete_instance(instance)

        Models::Instance[instance.id].should be_nil
      end

      it 'should delete the snapshots' do
        instance = Models::Instance.make(vm: nil)
        disk = Models::PersistentDisk.make(disk_cid: 'disk-cid', instance_id: instance.id)
        Models::Snapshot.make(snapshot_cid: 'snap1a', persistent_disk_id: disk.id)

        @cloud.should_receive(:delete_snapshot).with('snap1a')
        @cloud.should_receive(:delete_disk).with('disk-cid')

        @job.delete_instance(instance)

        Models::Instance[instance.id].should be_nil
      end

      it 'should not delete the snapshots if keep_snapshots is set' do
        instance = Models::Instance.make(vm: nil)
        disk = Models::PersistentDisk.make(disk_cid: 'disk-cid', instance_id: instance.id)
        Models::Snapshot.make(snapshot_cid: 'snap1a', persistent_disk_id: disk.id)

        @cloud.should_not_receive(:delete_snapshot)
        @cloud.should_receive(:delete_disk).with('disk-cid')

        job = Jobs::DeleteDeployment.new('test_deployment', 'keep_snapshots' => true)
        job.delete_instance(instance)

        Models::Instance[instance.id].should be_nil
      end
    end

    describe 'delete_vm' do
      before do
        @cloud = double('cloud')
        Config.stub(:cloud).and_return(@cloud)
        @job = Jobs::DeleteDeployment.new('test_deployment')
      end

      it 'should delete the VM and the model' do
        vm = Models::Vm.make(cid: 'vm-cid')

        @cloud.should_receive(:delete_vm).with('vm-cid')

        @job.delete_vm(vm)

        Models::Vm[vm.id].should be_nil
      end
    end

    describe 'perform' do
      before do
        @cloud = double('cloud')
        Config.stub(:cloud).and_return(@cloud)
        @job = Jobs::DeleteDeployment.new('test_deployment')
      end

      it 'should delete all the associated instances, VMs, disks and problems' do
        agent = double('agent')

        AgentClient.stub(:with_defaults).with('agent-1').and_return(agent)

        stemcell = Models::Stemcell.make
        deployment = Models::Deployment.make(name: 'test_deployment')

        deployment.stemcells << stemcell

        vm = Models::Vm.make(deployment: deployment, agent_id: 'agent-1')

        instance = Models::Instance.make(deployment: deployment, vm: vm)
        problem = Models::DeploymentProblem.make(deployment: deployment)
        disk = Models::PersistentDisk.make(instance: instance, disk_cid: 'disk-cid')

        @cloud.stub(:delete_vm)
        @cloud.stub(:delete_disk)
        @cloud.stub(:detach_disk)

        agent.should_receive(:stop)
        agent.should_receive(:unmount_disk).with('disk-cid')

        @job.should_receive(:with_deployment_lock).with('test_deployment').and_yield
        @job.perform

        Models::Deployment[deployment.id].should be_nil

        stemcell.refresh
        stemcell.deployments.should be_empty

        Models::Vm[vm.id].should be_nil
        Models::Instance[instance.id].should be_nil
        Models::DeploymentProblem[problem.id].should be_nil
        Models::PersistentDisk[disk.id].should be_nil
      end

      it 'should fail if the deployment is not found' do
        lambda { @job.perform }.should raise_exception DeploymentNotFound
      end
    end
  end
end
