require File.dirname(__FILE__) + '/../../spec_helper'

describe Bosh::Director::Jobs::DeleteDeployment do

  def make_instance(job, index, vm, disk_cid)
    instance = stub("instance-#{job}/#{index}")
    instance.stub!(:job).and_return(job)
    instance.stub!(:index).and_return(index)
    instance.stub!(:vm).and_return(vm)
    instance.stub!(:disk_cid).and_return(disk_cid)
    instance
  end

  def make_vm(agent_id, cid)
    vm = stub("vm-#{cid}")
    vm.stub!(:agent_id).and_return(agent_id)
    vm.stub!(:cid).and_return(cid)
    vm
  end

  describe "delete_instance" do

    before(:each) do
      @cloud = mock("cloud")
      Bosh::Director::Config.stub!(:cloud).and_return(@cloud)
      @job = Bosh::Director::Jobs::DeleteDeployment.new("test_deployment")
    end

    it "should delete the disk if it's not attached to the VM" do
      instance = stub("instance")
      instance.stub!(:job).and_return("foo")
      instance.stub!(:index).and_return("1")
      instance.stub!(:vm).and_return(nil)
      instance.stub!(:disk_cid).and_return("disk-cid")

      @cloud.should_receive(:delete_disk).with("disk-cid")

      instance.should_receive(:delete)

      @job.delete_instance(instance)
    end

    it "should detach and delete disk if there is a disk" do
      vm = stub("vm")
      vm.stub!(:cid).and_return("vm-cid")

      instance = stub("instance")
      instance.stub!(:job).and_return("foo")
      instance.stub!(:index).and_return("1")
      instance.stub!(:vm).and_return(vm)
      instance.stub!(:disk_cid).and_return("disk-cid")

      @cloud.should_receive(:detach_disk).with("vm-cid", "disk-cid")
      @cloud.should_receive(:delete_disk).with("disk-cid")

      @job.should_receive(:delete_vm).with(vm)

      instance.should_receive(:delete)

      @job.delete_instance(instance)
    end

    it "should only delete the VM if there is no disk" do
      vm = stub("vm")
      vm.stub!(:cid).and_return("vm-cid")

      instance = stub("instance")
      instance.stub!(:job).and_return("foo")
      instance.stub!(:index).and_return("1")
      instance.stub!(:vm).and_return(vm)
      instance.stub!(:disk_cid).and_return(nil)

      @job.should_receive(:delete_vm).with(vm)

      instance.should_receive(:delete)

      @job.delete_instance(instance)
    end

    it "should only delete the model if there is no VM" do
      instance = stub("instance")
      instance.stub!(:job).and_return("foo")
      instance.stub!(:index).and_return("1")
      instance.stub!(:vm).and_return(nil)
      instance.stub!(:disk_cid).and_return(nil)

      instance.should_receive(:delete)

      @job.delete_instance(instance)
    end

  end

  describe "delete_vm" do

    before(:each) do
      @cloud = mock("cloud")
      Bosh::Director::Config.stub!(:cloud).and_return(@cloud)
      @job = Bosh::Director::Jobs::DeleteDeployment.new("test_deployment")
    end

    it "should delete the VM and the model" do
      vm = stub("vm")
      vm.stub!(:cid).and_return("vm-cid")

      @cloud.should_receive(:delete_vm).with("vm-cid")
      vm.should_receive(:delete)

      @job.delete_vm(vm)
    end
  end

  describe "perform" do

    before(:each) do
      @cloud = mock("cloud")
      Bosh::Director::Config.stub!(:cloud).and_return(@cloud)
      @job = Bosh::Director::Jobs::DeleteDeployment.new("test_deployment")
    end

    it "should delete all the associated instances, VMs, and disks" do
      deployment = mock("deployment")
      deployment.stub!(:name).and_return("test_deployment")
      deployment.stub!(:id).and_return(76)

      Bosh::Director::Models::Deployment.stub!(:find).with(:name => "test_deployment").twice.and_return([deployment])

      lock = mock("lock")
      Bosh::Director::Lock.stub!(:new).with("lock:deployment:test_deployment").and_return(lock)

      lock.should_receive(:lock).and_yield

      vm_a = make_vm("a", "a-cid")
      vm_b = make_vm("b", "b-cid")

      instance_a = make_instance("test_a", "1", nil, nil)
      instance_b = make_instance("test_b", "1", vm_b, "disk-cid")

      Bosh::Director::Models::Instance.stub!(:find).with(:deployment_id => 76).and_return([instance_a, instance_b])
      Bosh::Director::Models::Vm.stub!(:find).with(:deployment_id => 76).and_return([vm_a])

      @job.should_receive(:delete_instance).with(instance_a)
      @job.should_receive(:delete_instance).with(instance_b)

      @job.should_receive(:delete_vm).with(vm_a)

      deployment.should_receive(:delete)

      stemcell = stub("stemcell")
      stemcell_deployments = stub("stemcell_deployments")
      stemcell.stub!(:deployments).and_return(stemcell_deployments)

      deployment.stub!(:stemcells).and_return([stemcell])
      stemcell_deployments.should_receive(:delete).with(deployment)

      @job.perform
    end

    it "should fail if the deployment is not found" do
      deployment = mock("deployment")
      deployment.stub!(:name).and_return("test_deployment")
      deployment.stub!(:id).and_return(76)

      Bosh::Director::Models::Deployment.stub!(:find).with(:name => "test_deployment").and_return([])

      lambda { @job.perform }.should raise_exception Bosh::Director::DeploymentNotFound
    end

  end

end