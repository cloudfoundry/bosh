require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::Director::JobUpdater do

  before(:each) do
    @job_spec = mock("job_spec")
    @update_spec = mock("update_spec")
    @job_spec.stub!(:update).and_return(@update_spec)
    @job_spec.stub!(:name).and_return("job_name")
    @update_spec.stub!(:max_in_flight).and_return(5)
    @update_spec.stub!(:canaries).and_return(1)
    Bosh::Director::Config.stub!(:cloud).and_return(nil)
  end

  it "should do nothing when the job is up to date" do
    instance_1 = mock("instance-1")
    instance_1.stub!(:index).and_return(1)
    instance_2 = mock("instance-1")
    instance_2.stub!(:index).and_return(2)

    instances = [instance_1, instance_2]

    @job_spec.should_receive(:instances).and_return(instances)
    @job_spec.should_receive(:unneeded_instances).and_return([])
    instance_1.should_receive(:changed?).and_return(false)
    instance_2.should_receive(:changed?).and_return(false)

    job_updater = Bosh::Director::JobUpdater.new(@job_spec)
    job_updater.update
  end

  it "should update the job with canaries" do
    instance_1 = mock("instance-1")
    instance_1.stub!(:index).and_return(1)
    instance_2 = mock("instance-1")
    instance_2.stub!(:index).and_return(2)
    instances = [instance_1, instance_2]

    instance_updater_1 = mock("instance_updater_1")
    instance_updater_2 = mock("instance_updater_2")

    @job_spec.should_receive(:instances).and_return(instances)
    @job_spec.should_receive(:unneeded_instances).and_return([])
    @job_spec.stub!(:should_rollback?).and_return(false)

    instance_1.should_receive(:changed?).and_return(true)
    instance_2.should_receive(:changed?).and_return(true)

    instance_updater_1.should_receive(:update).with(:canary => true)
    instance_updater_2.should_receive(:update).with(no_args)

    Bosh::Director::InstanceUpdater.stub!(:new).and_return do |instance, ticker|
      case instance
        when instance_1
          instance_updater_1
        when instance_2
          instance_updater_2
        else
          raise "unknown instance"
      end
    end

    job_updater = Bosh::Director::JobUpdater.new(@job_spec)
    job_updater.update

    check_event_log do |events|
      events.size.should == 4
      events.map { |e| e["stage"] }.uniq.should == ["Updating job"]
      events.map { |e| e["tags"] }.uniq.should == [ ["job_name"] ]
      events.map { |e| e["total"] }.uniq.should == [2]
      events.map { |e| e["task"] }.should == ["job_name/1 (canary)", "job_name/1 (canary)", "job_name/2", "job_name/2"]
    end
  end

  it "should rollback the job if the canaries failed" do
    instance_1 = mock("instance-1")
    instance_1.stub!(:index).and_return(1)
    instance_2 = mock("instance-1")
    instance_2.stub!(:index).and_return(2)
    instances = [instance_1, instance_2]

    instance_updater_1 = mock("instance_updater_1")
    instance_updater_2 = mock("instance_updater_2")

    @job_spec.stub!(:should_rollback?).and_return(false, true)
    @job_spec.should_receive(:instances).and_return(instances)
    @job_spec.should_receive(:record_update_error).with(anything, :canary => true)
    @job_spec.should_receive(:unneeded_instances).and_return([])

    instance_1.should_receive(:changed?).and_return(true)
    instance_2.should_receive(:changed?).and_return(true)

    instance_updater_1.should_receive(:update).with(:canary => true).and_throw("bad update")
    instance_updater_2.should_not_receive(:update).with(no_args)

    Bosh::Director::InstanceUpdater.stub!(:new).and_return do |instance, ticker|
      case instance
        when instance_1
          instance_updater_1
        when instance_2
          instance_updater_2
        else
          raise "unknown instance"
      end
    end

    job_updater = Bosh::Director::JobUpdater.new(@job_spec)
    lambda {job_updater.update}.should raise_exception(Bosh::Director::JobUpdater::RollbackException)
  end

  it "should rollback the job if it exceeded max number of errors" do
    instance_1 = mock("instance-1")
    instance_1.stub!(:index).and_return(1)
    instance_2 = mock("instance-1")
    instance_2.stub!(:index).and_return(2)
    instances = [instance_1, instance_2]

    instance_updater_1 = mock("instance_updater_1")
    instance_updater_2 = mock("instance_updater_2")

    @job_spec.stub!(:should_rollback?).and_return(false, false, false, true)
    @job_spec.should_receive(:unneeded_instances).and_return([])
    @job_spec.should_receive(:instances).and_return(instances)
    @job_spec.should_receive(:record_update_error).with(anything)

    instance_1.should_receive(:changed?).and_return(true)
    instance_2.should_receive(:changed?).and_return(true)

    instance_updater_1.should_receive(:update).with(:canary => true)
    instance_updater_2.should_receive(:update).with(no_args).and_throw("bad update")

    Bosh::Director::InstanceUpdater.stub!(:new).and_return do |instance, ticker|
      case instance
        when instance_1
          instance_updater_1
        when instance_2
          instance_updater_2
        else
          raise "unknown instance"
      end
    end

    job_updater = Bosh::Director::JobUpdater.new(@job_spec)
    lambda {job_updater.update}.should raise_exception(Bosh::Director::JobUpdater::RollbackException)
  end

  it "should delete the unneeded instances" do
    vm = Bosh::Director::Models::Vm.make(:cid => "vm-cid", :agent_id => "agent-id")
    instance = Bosh::Director::Models::Instance.make(:vm => vm, :disk_cid => "disk-cid")

    agent = mock("agent")
    cloud = mock("cloud")

    Bosh::Director::Config.stub!(:cloud).and_return(cloud)

    agent.should_receive(:drain).and_return(0.01)
    agent.should_receive(:stop)

    cloud.should_receive(:delete_vm).with("vm-cid")
    cloud.should_receive(:delete_disk).with("disk-cid")

    Bosh::Director::AgentClient.stub!(:new).and_return(agent, nil)

    @job_spec.stub!(:instances).and_return([])
    @job_spec.stub!(:unneeded_instances).and_return([instance])

    job_updater = Bosh::Director::JobUpdater.new(@job_spec)
    job_updater.update

    check_event_log do |events|
      events.size.should == 2
      events.map { |e| e["stage"] }.uniq.should == ["Deleting unneeded instances"]
      events.map { |e| e["tags"] }.uniq.should == [ ["job_name"] ]
      events.map { |e| e["total"] }.uniq.should == [1]
      events.map { |e| e["task"] }.uniq.should == ["vm-cid"]
    end
  end

end
