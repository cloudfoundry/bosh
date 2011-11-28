require File.expand_path("../../../../spec_helper", __FILE__)

describe Bosh::Director::Jobs::CloudCheck::Scan do

  describe "perform scan" do

    before(:each) do
      @mycloud = Bosh::Director::Models::Deployment.make(:name => "mycloud")
      @job = Bosh::Director::Jobs::CloudCheck::Scan.new("mycloud")

      @lock = mock("deployment_lock")
      Bosh::Director::Lock.stub!(:new).with("lock:deployment:mycloud").and_return(@lock)
    end

    it "scans for problems (using inactive disks as an example of a problem)" do
      # Couple of inactive disks
      2.times do
        Bosh::Director::Models::PersistentDisk.make(:active => false)
      end

      Bosh::Director::Models::DeploymentProblem.count.should == 0
      @lock.should_receive(:lock).and_yield
      @job.perform
      Bosh::Director::Models::DeploymentProblem.count.should == 2

      Bosh::Director::Models::DeploymentProblem.all.each do |problem|
        problem.counter.should == 1
        problem.type.should == "inactive_disk"
        problem.deployment.should == @mycloud
        problem.state.should == "open"
      end

      @lock.should_receive(:lock).and_yield
      @job.perform

      Bosh::Director::Models::DeploymentProblem.all.each do |problem|
        problem.counter.should == 2
        problem.last_seen_at.should >= problem.created_at
        problem.type.should == "inactive_disk"
        problem.deployment.should == @mycloud
        problem.state.should == "open"
      end
    end

  end

end
