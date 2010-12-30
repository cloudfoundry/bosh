require File.dirname(__FILE__) + '/../../spec_helper'

describe Bosh::Director::Jobs::UpdateDeployment do

  before(:each) do
    @manifest = mock("manifest")
    @file = mock("file")
    @deployment_plan = mock("deployment_plan")

    @deployment_plan.stub!(:name).and_return("test_deployment")
    @file.stub!(:read).and_return("manifest")

    File.stub!(:open).with("test_file").and_yield(@file)
    YAML.stub!(:load).with("manifest").and_return(@manifest)
    Bosh::Director::DeploymentPlan.stub!(:new).with(@manifest).and_return(@deployment_plan)
    Bosh::Director::Config.stub!(:base_dir).and_return(Dir.mktmpdir("base_dir"))
  end

  describe "prepare" do

    it "should prepare the deployment plan" do
      deployment = mock("deployment")
      deployment_plan_compiler = mock("deployment_plan_compiler")
      package_compiler = mock("package_compiler")

      Bosh::Director::Models::Deployment.stub!(:find).with(:name => "test_deployment").and_return([deployment])
      Bosh::Director::DeploymentPlanCompiler.stub!(:new).with(@deployment_plan).and_return(deployment_plan_compiler)
      Bosh::Director::PackageCompiler.stub!(:new).with(@deployment_plan).and_return(package_compiler)

      @deployment_plan.should_receive(:deployment=).with(deployment)

      deployment_plan_compiler.should_receive(:bind_existing_deployment)
      deployment_plan_compiler.should_receive(:bind_resource_pools)
      deployment_plan_compiler.should_receive(:bind_release)
      deployment_plan_compiler.should_receive(:bind_stemcells)
      deployment_plan_compiler.should_receive(:bind_instance_networks)
      package_compiler.should_receive(:compile)
      deployment_plan_compiler.should_receive(:bind_packages)
      deployment_plan_compiler.should_receive(:bind_configuration)

      update_deployment_job = Bosh::Director::Jobs::UpdateDeployment.new("test_file")
      update_deployment_job.prepare
    end

  end

  describe "update" do

    it "should update the deployment" do
      deployment_plan_compiler = mock("deployment_plan_compiler")
      resource_pool = mock("resource_pool")
      resource_pool_updater = mock("resource_pool_updater")
      job = mock("job")
      job_updater = mock("job_updater")

      Bosh::Director::ResourcePoolUpdater.stub!(:new).with(resource_pool).and_return(resource_pool_updater)
      Bosh::Director::JobUpdater.stub!(:new).with(job).and_return(job_updater)

      resource_pool.stub!(:name).and_return("resource_pool_name")

      job.stub!(:name).and_return("job_name")

      @deployment_plan.stub!(:resource_pools).and_return([resource_pool])
      @deployment_plan.stub!(:jobs).and_return([job])

      deployment_plan_compiler.should_receive(:bind_instance_vms)
      deployment_plan_compiler.should_receive(:delete_unneeded_vms)
      deployment_plan_compiler.should_receive(:delete_unneeded_instances)
      resource_pool_updater.should_receive(:update)
      job_updater.should_receive(:update)

      update_deployment_job = Bosh::Director::Jobs::UpdateDeployment.new("test_file")

      update_deployment_job.instance_eval do
        @deployment_plan_compiler = deployment_plan_compiler
      end

      update_deployment_job.update
    end

  end

  describe "rollback" do

    it "should rollback" do
      deployment = mock("deployment")
      manifest = mock("manifest")
      old_deployment_plan = mock("old_deployment_plan")

      @deployment_plan.stub!(:deployment).and_return(deployment)
      deployment.stub!(:manifest).and_return("old manifest")

      Bosh::Director::DeploymentPlan.stub!(:new).with(manifest).and_return(old_deployment_plan)
      YAML.stub!(:load).with("old manifest").and_return(manifest)

      update_deployment_job = Bosh::Director::Jobs::UpdateDeployment.new("test_file")
      update_deployment_job.should_receive(:prepare)
      update_deployment_job.should_receive(:update)
      update_deployment_job.rollback
      update_deployment_job.instance_eval {@deployment_plan}.should eql(old_deployment_plan)
    end

    it "should not rollback if there was no previous manifest" do
      deployment = mock("deployment")

      @deployment_plan.stub!(:deployment).and_return(deployment)
      deployment.stub!(:manifest).and_return(nil)

      update_deployment_job = Bosh::Director::Jobs::UpdateDeployment.new("test_file")
      update_deployment_job.should_not_receive(:prepare)
      update_deployment_job.should_not_receive(:update)
      update_deployment_job.rollback
      update_deployment_job.instance_eval {@deployment_plan}.should eql(@deployment_plan)
    end

  end

  describe "perform" do

    it "should do a basic update" do
      deployment_lock = mock("deployment_lock")
      release_lock = mock("release_lock")
      deployment = mock("deployment")
      release = mock("release")

      @deployment_plan.stub!(:release).and_return(release)
      @deployment_plan.stub!(:deployment).and_return(deployment)
      release.stub!(:name).and_return("test_release")

      Bosh::Director::Lock.stub!(:new).with("lock:deployment:test_deployment").and_return(deployment_lock)
      Bosh::Director::Lock.stub!(:new).with("lock:release:test_release").and_return(release_lock)

      deployment_lock.should_receive(:lock).and_yield
      release_lock.should_receive(:lock).and_yield

      deployment.should_receive(:manifest=).with("manifest")
      deployment.should_receive(:name).and_return("test_deployment")
      deployment.should_receive(:save!)

      update_deployment_job = Bosh::Director::Jobs::UpdateDeployment.new("test_file")
      update_deployment_job.should_receive(:prepare)
      update_deployment_job.should_receive(:update)
      update_deployment_job.perform.should eql("/deployments/test_deployment")
    end

    it "should rollback if there was an error during the update step" do
      deployment_lock = mock("deployment_lock")
      release_lock = mock("release_lock")
      deployment = mock("deployment")
      release = mock("release")

      @deployment_plan.stub!(:release).and_return(release)
      @deployment_plan.stub!(:deployment).and_return(deployment)
      release.stub!(:name).and_return("test_release")

      Bosh::Director::Lock.stub!(:new).with("lock:deployment:test_deployment").and_return(deployment_lock)
      Bosh::Director::Lock.stub!(:new).with("lock:release:test_release").and_return(release_lock)

      deployment_lock.should_receive(:lock).and_yield
      release_lock.should_receive(:lock).and_yield

      update_deployment_job = Bosh::Director::Jobs::UpdateDeployment.new("test_file")
      update_deployment_job.should_receive(:prepare)
      update_deployment_job.should_receive(:update).and_raise("rollback exception")
      update_deployment_job.should_receive(:rollback)
      update_deployment_job.perform
    end

    it "should not rollback if there was an error during the prepare step" do
      deployment_lock = mock("deployment_lock")
      release_lock = mock("release_lock")
      deployment = mock("deployment")
      release = mock("release")

      @deployment_plan.stub!(:release).and_return(release)
      @deployment_plan.stub!(:deployment).and_return(deployment)
      release.stub!(:name).and_return("test_release")

      Bosh::Director::Lock.stub!(:new).with("lock:deployment:test_deployment").and_return(deployment_lock)
      Bosh::Director::Lock.stub!(:new).with("lock:release:test_release").and_return(release_lock)

      deployment_lock.should_receive(:lock).and_yield
      release_lock.should_receive(:lock).and_yield

      update_deployment_job = Bosh::Director::Jobs::UpdateDeployment.new("test_file")
      update_deployment_job.should_receive(:prepare).and_raise("prepare exception")
      update_deployment_job.should_not_receive(:update)
      update_deployment_job.should_not_receive(:rollback)
      lambda { update_deployment_job.perform }.should raise_exception("prepare exception")
    end

  end

end