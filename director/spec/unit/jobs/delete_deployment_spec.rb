require File.expand_path("../../../spec_helper", __FILE__)

describe Bosh::Director::Jobs::DeleteDeployment do

  describe "delete_instance" do

    before(:each) do
      @cloud = mock("cloud")
      Bosh::Director::Config.stub!(:cloud).and_return(@cloud)
      @job = Bosh::Director::Jobs::DeleteDeployment.new("test_deployment")
    end

    it "should delete the disk if it's not attached to the VM" do
      instance = Bosh::Director::Models::Instance.make(:vm => nil)
      Bosh::Director::Models::PersistentDisk.make(:disk_cid => "disk-cid", :instance_id => instance.id)

      @cloud.should_receive(:delete_disk).with("disk-cid")

      @job.delete_instance(instance)

      Bosh::Director::Models::Instance[instance.id].should be_nil
    end

    it "should detach and delete disk if there is a disk" do
      vm = Bosh::Director::Models::Vm.make(:cid => "vm-cid")
      instance = Bosh::Director::Models::Instance.make(:vm => vm)
      Bosh::Director::Models::PersistentDisk.make(:disk_cid => "disk-cid", :instance_id => instance.id)

      @cloud.should_receive(:detach_disk).with("vm-cid", "disk-cid")
      @cloud.should_receive(:delete_disk).with("disk-cid")

      @job.should_receive(:delete_vm).with(vm)

      @job.delete_instance(instance)

      Bosh::Director::Models::Instance[instance.id].should be_nil
    end

    it "should only delete the VM if there is no disk" do
      vm = Bosh::Director::Models::Vm.make(:cid => "vm-cid")
      instance = Bosh::Director::Models::Instance.make(:vm => vm)

      @job.should_receive(:delete_vm).with(vm)

      @job.delete_instance(instance)

      Bosh::Director::Models::Instance[instance.id].should be_nil
    end

    it "should only delete the model if there is no VM" do
      instance = Bosh::Director::Models::Instance.make(:vm => nil)

      @job.delete_instance(instance)

      Bosh::Director::Models::Instance[instance.id].should be_nil
    end

  end

  describe "delete_vm" do

    before(:each) do
      @cloud = mock("cloud")
      Bosh::Director::Config.stub!(:cloud).and_return(@cloud)
      @job = Bosh::Director::Jobs::DeleteDeployment.new("test_deployment")
    end

    it "should delete the VM and the model" do
      vm = Bosh::Director::Models::Vm.make(:cid => "vm-cid")

      @cloud.should_receive(:delete_vm).with("vm-cid")

      @job.delete_vm(vm)

      Bosh::Director::Models::Vm[vm.id].should be_nil
    end
  end

  describe "perform" do

    before(:each) do
      @cloud = mock("cloud")
      Bosh::Director::Config.stub!(:cloud).and_return(@cloud)
      @job = Bosh::Director::Jobs::DeleteDeployment.new("test_deployment")
    end

    it "should delete all the associated instances, VMs, and disks" do
      lock = mock("lock")
      Bosh::Director::Lock.stub!(:new).with("lock:deployment:test_deployment").and_return(lock)

      lock.should_receive(:lock).and_yield

      stemcell = Bosh::Director::Models::Stemcell.make
      deployment = Bosh::Director::Models::Deployment.make(:name => "test_deployment")
      deployment.stemcells << stemcell

      vm = Bosh::Director::Models::Vm.make(:deployment => deployment)
      instance = Bosh::Director::Models::Instance.make(:deployment => deployment, :vm => vm)

      @cloud.stub!(:delete_vm)
      @cloud.stub!(:delete_disk)
      @cloud.stub!(:detach_disk)

      @job.perform

      deployment = Bosh::Director::Models::Deployment[deployment.id]
      deployment.should be_nil

      stemcell.refresh
      stemcell.deployments.should be_empty

      Bosh::Director::Models::Vm[vm.id].should be_nil
      Bosh::Director::Models::Instance[instance.id].should be_nil
    end

    it "should fail if the deployment is not found" do
      lambda { @job.perform }.should raise_exception Bosh::Director::DeploymentNotFound
    end

  end

end
