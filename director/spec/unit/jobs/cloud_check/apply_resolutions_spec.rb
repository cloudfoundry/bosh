require File.expand_path("../../../../spec_helper", __FILE__)

describe Bosh::Director::Jobs::CloudCheck::ApplyResolutions do

  describe "perform scan" do

    before(:each) do
      @deployment = Bosh::Director::Models::Deployment.make(:name => "mycloud")
      @other_deployment = Bosh::Director::Models::Deployment.make(:name => "othercloud")

      @lock = mock("deployment_lock")
      Bosh::Director::Lock.stub!(:new).with("lock:deployment:mycloud").and_return(@lock)
    end

    def make_job(deployment_name, resolutions)
      Bosh::Director::Jobs::CloudCheck::ApplyResolutions.new(deployment_name, resolutions)
    end

    def orphan_disk(id, deployment_id = nil)
      Bosh::Director::Models::DeploymentProblem.
        make(:deployment_id => deployment_id || @deployment.id,
             :resource_id => id,
             :type => "orphan_disk",
             :state => "open")
    end

    it "applies resolutions" do
      disks = []
      problems = [ ]

      2.times do
        disk = Bosh::Director::Models::PersistentDisk.make(:active => false)
        disks << disk
        problems << orphan_disk(disk.id)
      end

      job = make_job("mycloud", { problems[0].id => "delete_disk", problems[1].id => "report" })

      @lock.should_receive(:lock).and_yield

      job.perform

      Bosh::Director::Models::PersistentDisk.find(:id => disks[0].id).should be_nil
      Bosh::Director::Models::PersistentDisk.find(:id => disks[1].id).should_not be_nil

      Bosh::Director::Models::DeploymentProblem.filter(:state => "open").count.should == 0
    end

    it "whines on missing resolutions" do
      problem = orphan_disk(22)

      job = make_job("mycloud", { 32 => "delete_disk" })
      @lock.should_receive(:lock).and_yield

      lambda {
        job.perform
      }.should raise_error(RuntimeError, "Resolution for problem #{problem.id} (orphan_disk) is not provided")
    end

    it "notices and logs extra resolutions" do
      disks = (1..3).map { |i| Bosh::Director::Models::PersistentDisk.make(:active => false) }

      problems = [ orphan_disk(disks[0].id), orphan_disk(disks[1].id), orphan_disk(disks[2].id, @other_deployment.id) ]
      @lock.stub!(:lock).and_yield

      job1 = make_job("mycloud", { problems[0].id => "report", problems[1].id => "report" })
      job1.perform

      job2 = make_job("mycloud", {
                        problems[0].id => "report", problems[1].id => "report",
                        problems[2].id => "report", "foobar" => "ignore", 318 => "do_stuff"
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

  end

end
