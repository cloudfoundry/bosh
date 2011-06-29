require File.expand_path("../../../spec_helper", __FILE__)

describe Bosh::Director::Jobs::UpdateDeployment do

  before(:each) do
    @manifest = mock("manifest")
    @file = mock("file")
    @deployment_plan = mock("deployment_plan")

    @deployment_plan.stub!(:name).and_return("test_deployment")
    @file.stub!(:read).and_return("manifest")

    @tmpdir = Dir.mktmpdir("base_dir")

    File.stub!(:open).with("test_file").and_yield(@file)
    YAML.stub!(:load).with("manifest").and_return(@manifest)
    Bosh::Director::DeploymentPlan.stub!(:new).with(@manifest, false).and_return(@deployment_plan)
    Bosh::Director::Config.stub!(:base_dir).and_return(@tmpdir)

    event_log = Bosh::Director::EventLog.new(1, nil)
    Bosh::Director::Config.stub!(:event_logger).and_return(event_log)
  end

  after(:each) do
    FileUtils.rm_rf(@tmpdir)
  end

  describe "prepare" do

    it "should prepare the deployment plan" do
      deployment = Bosh::Director::Models::Deployment.make(:name => "test_deployment")
      deployment_plan_compiler = mock("deployment_plan_compiler")
      package_compiler = mock("package_compiler")

      Bosh::Director::DeploymentPlanCompiler.stub!(:new).with(@deployment_plan).and_return(deployment_plan_compiler)
      Bosh::Director::PackageCompiler.stub!(:new).with(@deployment_plan).and_return(package_compiler)

      @deployment_plan.should_receive(:deployment=).with(deployment)

      deployment_plan_compiler.should_receive(:bind_existing_deployment)
      deployment_plan_compiler.should_receive(:bind_resource_pools)
      deployment_plan_compiler.should_receive(:bind_release)
      deployment_plan_compiler.should_receive(:bind_stemcells)
      deployment_plan_compiler.should_receive(:bind_templates)
      deployment_plan_compiler.should_receive(:bind_unallocated_vms)
      deployment_plan_compiler.should_receive(:bind_instance_networks)
      package_compiler.should_receive(:compile)
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
      resource_pool_updater.should_receive(:delete_extra_vms)
      resource_pool_updater.should_receive(:delete_outdated_vms)
      resource_pool_updater.should_receive(:create_missing_vms)
      job_updater.should_receive(:update)

      update_deployment_job = Bosh::Director::Jobs::UpdateDeployment.new("test_file")

      update_deployment_job.instance_eval do
        @deployment_plan_compiler = deployment_plan_compiler
      end

      update_deployment_job.update
    end

  end

  describe "update_stemcell_references" do

    it "should delete references to no longer used stemcells" do
      deployment = Bosh::Director::Models::Deployment.make
      resource_pool_spec = stub("resource_pool_spec")
      stemcell_spec = stub("stemcell_spec")
      new_stemcell = Bosh::Director::Models::Stemcell.make
      old_stemcell = Bosh::Director::Models::Stemcell.make
      deployment.add_stemcell(old_stemcell)

      @deployment_plan.stub!(:deployment).and_return(deployment)
      @deployment_plan.stub!(:resource_pools).and_return([resource_pool_spec])

      resource_pool_spec.stub!(:stemcell).and_return(stemcell_spec)
      stemcell_spec.stub!(:stemcell).and_return(new_stemcell)

      update_deployment_job = Bosh::Director::Jobs::UpdateDeployment.new("test_file")
      update_deployment_job.update_stemcell_references

      old_stemcell.deployments.should be_empty
    end

  end

  describe "perform" do

    # TODO: refactor to use less mocks (and a real manifest)
    it "should do a basic update" do
      deployment_lock = mock("deployment_lock")
      release_lock    = mock("release_lock")

      deployment      = Bosh::Director::Models::Deployment.make(:name => "test_deployment")
      release         = Bosh::Director::Models::Release.make(:name => "test_release")
      release_version = Bosh::Director::Models::ReleaseVersion.make(:release => release, :version => 1)

      release_spec = mock("release_spec")
      release_spec.stub!(:release).and_return(release)
      release_spec.stub!(:release_version).and_return(release_version)
      release_spec.stub!(:name).and_return(release.name)

      @deployment_plan.stub!(:release).and_return(release_spec)
      @deployment_plan.stub!(:deployment).and_return(deployment)

      Bosh::Director::Lock.stub!(:new).with("lock:deployment:test_deployment").and_return(deployment_lock)
      Bosh::Director::Lock.stub!(:new).with("lock:release:test_release").and_return(release_lock)

      deployment_lock.should_receive(:lock).and_yield
      release_lock.should_receive(:lock).and_yield

      deployment.should_receive(:add_release_version).with(release_version)

      update_deployment_job = Bosh::Director::Jobs::UpdateDeployment.new("test_file")
      update_deployment_job.should_receive(:prepare)
      update_deployment_job.should_receive(:update)
      update_deployment_job.should_receive(:update_stemcell_references)
      update_deployment_job.perform.should eql("/deployments/test_deployment")

      deployment.refresh
      deployment.manifest.should == "manifest"
    end

  end

end
