# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../../spec_helper", __FILE__)

describe Bosh::Director::Jobs::DeleteDeployment do

  describe "delete_instance" do

    before(:each) do
      @cloud = mock("cloud")
      BD::Config.stub!(:cloud).and_return(@cloud)
      @job = BD::Jobs::DeleteDeployment.new("test_deployment")
    end

    it "should delete the disk if it's not attached to the VM" do
      instance = BDM::Instance.make(:vm => nil)
      BDM::PersistentDisk.
        make(:disk_cid => "disk-cid", :instance_id => instance.id)

      @cloud.should_receive(:delete_disk).with("disk-cid")

      @job.delete_instance(instance)

      BDM::Instance[instance.id].should be_nil
    end

    it "should detach and delete disk if there is a disk" do
      agent = mock("agent")

      BD::AgentClient.stub(:new).with("agent-1").
        and_return(agent)

      vm = BDM::Vm.make(:cid => "vm-cid",
                                           :agent_id => "agent-1")

      instance = BDM::Instance.make(:vm => vm)

      BDM::PersistentDisk.
        make(:disk_cid => "disk-cid", :instance_id => instance.id)

      agent.should_receive(:stop)
      agent.should_receive(:unmount_disk).with("disk-cid")

      @cloud.should_receive(:detach_disk).with("vm-cid", "disk-cid")
      @cloud.should_receive(:delete_disk).with("disk-cid")

      @job.should_receive(:delete_vm).with(vm)

      @job.delete_instance(instance)

      BDM::Instance[instance.id].should be_nil
    end

    it "should only delete the VM if there is no disk" do
      agent = mock("agent")

      BD::AgentClient.stub(:new).with("agent-1").
        and_return(agent)

      vm = BDM::Vm.make(:cid => "vm-cid", :agent_id => "agent-1")
      instance = BDM::Instance.make(:vm => vm)

      agent.should_receive(:stop)

      @job.should_receive(:delete_vm).with(vm)

      @job.delete_instance(instance)

      BDM::Instance[instance.id].should be_nil
    end

    it "should only delete the model if there is no VM" do
      instance = BDM::Instance.make(:vm => nil)

      @job.delete_instance(instance)

      BDM::Instance[instance.id].should be_nil
    end

    it "should ignore cpi errors if forced" do
      vm = BDM::Vm.make(:cid => "vm-cid")
      instance = BDM::Instance.make(:vm => vm)
      BDM::PersistentDisk.
        make(:disk_cid => "disk-cid", :instance_id => instance.id)

      @cloud.should_receive(:detach_disk).
        with("vm-cid", "disk-cid").and_raise("ERROR")
      @cloud.should_receive(:delete_disk).with("disk-cid").and_raise("ERROR")

      job = BD::Jobs::DeleteDeployment.new("test_deployment", "force" => true)
      job.should_receive(:delete_vm).with(vm)
      job.delete_instance(instance)

      BDM::Instance[instance.id].should be_nil
    end

  end

  describe "delete_vm" do

    before(:each) do
      @cloud = mock("cloud")
      BD::Config.stub!(:cloud).and_return(@cloud)
      @job = BD::Jobs::DeleteDeployment.new("test_deployment")
    end

    it "should delete the VM and the model" do
      vm = BDM::Vm.make(:cid => "vm-cid")

      @cloud.should_receive(:delete_vm).with("vm-cid")

      @job.delete_vm(vm)

      BDM::Vm[vm.id].should be_nil
    end
  end

  describe "perform" do

    before(:each) do
      @cloud = mock("cloud")
      BD::Config.stub!(:cloud).and_return(@cloud)
      @job = BD::Jobs::DeleteDeployment.new("test_deployment")
    end

    it "should delete all the associated instances, VMs, disks and problems" do
      agent = mock("agent")

      BD::AgentClient.stub(:new).with("agent-1").
        and_return(agent)

      stemcell = BDM::Stemcell.make
      deployment = BDM::Deployment.
        make(:name => "test_deployment")

      deployment.stemcells << stemcell

      vm = BDM::Vm.
        make(:deployment => deployment, :agent_id => "agent-1")

      instance = BDM::Instance.
        make(:deployment => deployment, :vm => vm)
      problem = BDM::DeploymentProblem.
        make(:deployment => deployment)
      disk = BDM::PersistentDisk.
        make(:instance => instance, :disk_cid => "disk-cid")

      @cloud.stub!(:delete_vm)
      @cloud.stub!(:delete_disk)
      @cloud.stub!(:detach_disk)

      agent.should_receive(:stop)
      agent.should_receive(:unmount_disk).with("disk-cid")

      @job.should_receive(:with_deployment_lock).with("test_deployment").
          and_yield
      @job.perform

      BDM::Deployment[deployment.id].should be_nil

      stemcell.refresh
      stemcell.deployments.should be_empty

      BDM::Vm[vm.id].should be_nil
      BDM::Instance[instance.id].should be_nil
      BDM::DeploymentProblem[problem.id].should be_nil
      BDM::PersistentDisk[disk.id].should be_nil
    end

    it "should fail if the deployment is not found" do
      lambda { @job.perform }.should raise_exception BD::DeploymentNotFound
    end

  end

end
