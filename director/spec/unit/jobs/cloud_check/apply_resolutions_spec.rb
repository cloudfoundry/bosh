# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../../../spec_helper", __FILE__)

describe Bosh::Director::Jobs::CloudCheck::ApplyResolutions do

  before(:each) do
    @deployment = Bosh::Director::Models::Deployment.make(:name => "mycloud")
    @other_deployment = Bosh::Director::Models::Deployment.make(:name => "othercloud")

    @cloud = mock("cloud")
    Bosh::Director::Config.stub!(:cloud).and_return(@cloud)

    @lock = mock("deployment_lock")
    Bosh::Director::Lock.stub!(:new).with("lock:deployment:mycloud").and_return(@lock)
  end

  def make_job(deployment_name, resolutions)
    Bosh::Director::Jobs::CloudCheck::ApplyResolutions.new(deployment_name, resolutions)
  end

  def inactive_disk(id, deployment_id = nil)
    Bosh::Director::Models::DeploymentProblem.
      make(:deployment_id => deployment_id || @deployment.id,
           :resource_id => id,
           :type => "inactive_disk",
           :state => "open")
  end

  it "applies resolutions" do
    disks = []
    problems = [ ]

    agent = mock("agent")
    agent.should_receive(:list_disk).and_return([])

    @cloud.should_receive(:detach_disk).exactly(1).times
    @cloud.should_receive(:delete_disk).exactly(1).times

    Bosh::Director::AgentClient.stub!(:new).and_return(agent)

    2.times do
      disk = Bosh::Director::Models::PersistentDisk.make(:active => false)
      disks << disk
      problems << inactive_disk(disk.id)
    end

    job = make_job("mycloud", { problems[0].id => "delete_disk", problems[1].id => "ignore" })

    @lock.should_receive(:lock).and_yield

    job.perform

    Bosh::Director::Models::PersistentDisk.find(:id => disks[0].id).should be_nil
    Bosh::Director::Models::PersistentDisk.find(:id => disks[1].id).should_not be_nil

    Bosh::Director::Models::DeploymentProblem.filter(:state => "open").count.should == 0
  end

  it "whines on missing resolutions" do
    problem = inactive_disk(22)

    job = make_job("mycloud", { 32 => "delete_disk" })
    @lock.should_receive(:lock).and_yield

    lambda {
      job.perform
    }.should raise_error(
               BD::CloudcheckResolutionNotProvided,
               "Resolution for problem #{problem.id} (inactive_disk) is not provided")
  end

  it "notices and logs extra resolutions" do
    disks = (1..3).map { |i| Bosh::Director::Models::PersistentDisk.make(:active => false) }

    problems = [ inactive_disk(disks[0].id), inactive_disk(disks[1].id), inactive_disk(disks[2].id, @other_deployment.id) ]
    @lock.stub!(:lock).and_yield

    job1 = make_job("mycloud", { problems[0].id => "ignore", problems[1].id => "ignore" })
    job1.perform

    job2 = make_job("mycloud", {
                      problems[0].id => "ignore", problems[1].id => "ignore",
                      problems[2].id => "ignore", "foobar" => "ignore", 318 => "do_stuff"
                    })

    messages = []
    job2.should_receive(:track_and_log).exactly(5).times.and_return { |message| messages << message }
    job2.perform

    messages.should =~ [
      "Ignoring problem #{problems[0].id} (state is 'resolved')",
      "Ignoring problem #{problems[1].id} (state is 'resolved')",
      "Ignoring problem 318 (not found)",
      "Ignoring problem #{problems[2].id} (not a part of this deployment)",
      "Ignoring problem foobar (malformed id)"
    ]
  end

  it "continues despite erroneous resolutions" do
    pending
  end

end
