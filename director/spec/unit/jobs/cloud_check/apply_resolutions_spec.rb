require File.expand_path("../../../../spec_helper", __FILE__)

describe Bosh::Director::Jobs::CloudCheck::ApplyResolutions do

  describe "perform scan" do

    before(:each) do
      @deployment = Bosh::Director::Models::Deployment.make(:name => "mycloud")

      @lock = mock("deployment_lock")
      Bosh::Director::Lock.stub!(:new).with("lock:deployment:mycloud").and_return(@lock)
    end

    def make_job(deployment_name, resolutions)
      Bosh::Director::Jobs::CloudCheck::ApplyResolutions.new(deployment_name, resolutions)
    end

    it "applies resolutions" do
      disks = []
      problems = [ ]
      # Couple of orphan disks
      2.times do
        disk = Bosh::Director::Models::PersistentDisk.make(:active => false)
        disks << disk
        problems << Bosh::Director::Models::DeploymentProblem.
          make(:deployment_id => @deployment.id, :resource_id => disk.id,
               :type => "orphan_disk", :state => "open")
      end

      job = make_job("mycloud", { problems[0].id => "delete_disk", problems[1].id => "report" })

      @lock.should_receive(:lock).and_yield

      job.perform

      Bosh::Director::Models::PersistentDisk.find(:id => disks[0].id).should be_nil
      Bosh::Director::Models::PersistentDisk.find(:id => disks[1].id).should_not be_nil

      Bosh::Director::Models::DeploymentProblem.filter(:state => "open").count.should == 0
    end

  end

end
