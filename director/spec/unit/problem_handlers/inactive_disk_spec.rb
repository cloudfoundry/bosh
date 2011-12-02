require File.expand_path("../../../spec_helper", __FILE__)

describe Bosh::Director::ProblemHandlers::InactiveDisk do
  before(:each) do
    @cloud = mock("cloud")
    @agent = mock("agent")
    Bosh::Director::AgentClient.stub!(:new).and_return(@agent)
    @disk = Bosh::Director::Models::PersistentDisk.make(:disk_cid => "disk-cid",
                                                        :instance_id => 1,
                                                        :size => 1024,
                                                        :active => false)
    @handler = Bosh::Director::ProblemHandlers::Base.create_by_type(:inactive_disk, @disk.id, {})
    @handler.stub(:cloud).and_return(@cloud)
  end

  it "should detect if problem still exists" do
    @handler.problem_still_exists?.should be_true
    @disk.update(:active => true)
    @handler.problem_still_exists?.should be_false
  end

  it "should delete inactive disk" do
    @agent.stub(:list_disk).and_return([])
    @cloud.should_receive(:detach_disk)
    @cloud.should_receive(:delete_disk).with("disk-cid")
    @handler.delete_disk
    Bosh::Director::Models::PersistentDisk[@disk.id].should be_nil
  end

  it "should refuse to delete if the invalid disk is currently mounted" do
    @agent.stub(:list_disk).and_return(["disk-cid"])
    @cloud.should_not_receive(:detach_disk)
    @cloud.should_not_receive(:delete_disk)
    lambda {@handler.delete_disk}.should raise_error Bosh::Director::ProblemHandlers::HandlerError
    Bosh::Director::Models::PersistentDisk[@disk.id].should_not be_nil
  end

  it "should activate disk" do
    @agent.stub(:list_disk).and_return(["disk-cid"])
    @handler.activate_disk
    Bosh::Director::Models::PersistentDisk[@disk.id].active.should be_true
  end

  it "should refuse to activate disk if not mounted" do
    @agent.stub(:list_disk).and_return([])
    lambda {@handler.activate_disk}.should raise_error Bosh::Director::ProblemHandlers::HandlerError
    Bosh::Director::Models::PersistentDisk[@disk.id].active.should be_false
  end

  it "should refuse to activate disk if the instance already has a persistent disk" do
    disk_1 = Bosh::Director::Models::PersistentDisk.make(:disk_cid => "disk-cid-1",
                                                         :instance_id => 1,
                                                         :size => 1024,
                                                         :active => true)
    @agent.stub(:list_disk).and_return(["disk-cid"])
    lambda {@handler.activate_disk}.should raise_error Bosh::Director::ProblemHandlers::HandlerError
    Bosh::Director::Models::PersistentDisk[@disk.id].active.should be_false
  end
end
