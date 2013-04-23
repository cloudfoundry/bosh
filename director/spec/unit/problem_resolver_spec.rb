require 'spec_helper'

describe Bosh::Director::ProblemResolver do
  before(:each) do
    @deployment = BDM::Deployment.make(:name => "mycloud")
    @other_deployment = BDM::Deployment.make(:name => "othercloud")

    @cloud = mock("cloud")
    BD::Config.stub!(:cloud).and_return(@cloud)
  end

  def make_job(deployment_name)
    BD::ProblemResolver.new(deployment_name)
  end

  def inactive_disk(id, deployment_id = nil)
    BDM::DeploymentProblem.
        make(:deployment_id => deployment_id || @deployment.id,
             :resource_id => id,
             :type => "inactive_disk",
             :state => "open")
  end

  it "applies resolutions" do
    disks = []
    problems = []

    agent = mock("agent")
    agent.should_receive(:list_disk).and_return([])

    @cloud.should_receive(:detach_disk).exactly(1).times
    @cloud.should_receive(:delete_disk).exactly(1).times

    BD::AgentClient.stub!(:new).and_return(agent)

    2.times do
      disk = BDM::PersistentDisk.make(:active => false)
      disks << disk
      problems << inactive_disk(disk.id)
    end

    job = make_job("mycloud")

    job.apply_resolutions({problems[0].id.to_s => "delete_disk", problems[1].id.to_s => "ignore"}).should == 2

    BDM::PersistentDisk.find(:id => disks[0].id).should be_nil
    BDM::PersistentDisk.find(:id => disks[1].id).should_not be_nil

    BDM::DeploymentProblem.filter(:state => "open").count.should == 0
  end

  it "whines on missing resolutions" do
    problem = inactive_disk(22)

    job = make_job("mycloud")

    lambda {
      job.apply_resolutions({32 => "delete_disk"})
    }.should raise_error(
                 BD::CloudcheckResolutionNotProvided,
                 "Resolution for problem #{problem.id} (inactive_disk) is not provided")
  end

  it "notices and logs extra resolutions" do
    disks = (1..3).map { |_| BDM::PersistentDisk.make(:active => false) }

    problems = [
        inactive_disk(disks[0].id),
        inactive_disk(disks[1].id),
        inactive_disk(disks[2].id, @other_deployment.id)
    ]

    job1 = make_job("mycloud")
    job1.apply_resolutions({problems[0].id.to_s => "ignore", problems[1].id.to_s => "ignore"}).should == 2

    job2 = make_job("mycloud")

    messages = []
    job2.should_receive(:track_and_log).exactly(5).times.and_return { |message| messages << message }
    job2.apply_resolutions({
                               problems[0].id.to_s => "ignore",
                               problems[1].id.to_s => "ignore",
                               problems[2].id.to_s => "ignore",
                               "foobar" => "ignore",
                               "318" => "do_stuff"
                           })

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
