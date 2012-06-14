# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../../spec_helper", __FILE__)

describe Bosh::Director::Jobs::UpdateDeployment do

  before(:each) do
    @manifest = mock("manifest")
    @deployment_plan = mock("deployment_plan")

    @deployment_plan.stub!(:name).and_return("test_deployment")
    @deployment_plan.should_receive(:parse).once

    pool1 = mock("resource_pool")
    pool2 = mock("resource_pool")
    updater1 = mock("resource_pool_updater")
    updater2 = mock("resource_pool_updater")

    Bosh::Director::ResourcePoolUpdater.stub!(:new).with(pool1).and_return(updater1)
    Bosh::Director::ResourcePoolUpdater.stub!(:new).with(pool2).and_return(updater2)

    @deployment_plan.stub!(:resource_pools).and_return([pool1, pool2])

    @tmpdir = Dir.mktmpdir("base_dir")

    @manifest_file = Tempfile.new("manifest")
    File.open(@manifest_file.path, "w") do |f|
      f.write("manifest")
    end

    YAML.stub!(:load).with("manifest").and_return(@manifest)

    Bosh::Director::DeploymentPlan.stub!(:new).with(@manifest, "recreate" => false, "job_states" => { },
                                                    "job_rename" => { }).and_return(@deployment_plan)
    Bosh::Director::Config.stub!(:base_dir).and_return(@tmpdir)
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
      update_deployment_job = Bosh::Director::Jobs::UpdateDeployment.new(@manifest_file.path)
      Bosh::Director::PackageCompiler.stub!(:new).with(@deployment_plan).and_return(package_compiler)

      deployment_plan_compiler.should_receive(:bind_deployment)
      deployment_plan_compiler.should_receive(:bind_existing_deployment)
      deployment_plan_compiler.should_receive(:bind_resource_pools)
      deployment_plan_compiler.should_receive(:bind_releases)
      deployment_plan_compiler.should_receive(:bind_stemcells)
      deployment_plan_compiler.should_receive(:bind_templates)
      deployment_plan_compiler.should_receive(:bind_unallocated_vms)
      deployment_plan_compiler.should_receive(:bind_instance_networks)
      package_compiler.should_receive(:compile)

      update_deployment_job.prepare

      check_event_log do |events|
        events.size.should == 16
        events.select { |e| e["stage"] == "Preparing deployment" }.size.should == 16
      end
    end

  end

  describe "update" do

    it "should update the deployment" do
      deployment_plan_compiler = mock("deployment_plan_compiler")
      resource_pool = mock("resource_pool")
      resource_pool_updater = mock("resource_pool_updater")
      job = mock("job")
      job_updater = mock("job_updater")

      resource_pool_updater.stub!(:extra_vm_count).and_return(2)
      resource_pool_updater.stub!(:outdated_idle_vm_count).and_return(3)
      resource_pool_updater.stub!(:bound_missing_vm_count).and_return(4)
      resource_pool_updater.stub!(:missing_vm_count).and_return(5)

      Bosh::Director::ResourcePoolUpdater.stub!(:new).with(resource_pool).and_return(resource_pool_updater)
      Bosh::Director::JobUpdater.stub!(:new).with(@deployment_plan, job).and_return(job_updater)

      resource_pool.stub!(:name).and_return("resource_pool_name")

      job.stub!(:name).and_return("job_name")

      @deployment_plan.stub!(:resource_pools).and_return([resource_pool])
      @deployment_plan.stub!(:jobs).and_return([job])

      deployment_plan_compiler.should_receive(:bind_dns).ordered
      deployment_plan_compiler.should_receive(:bind_instance_vms).ordered
      deployment_plan_compiler.should_receive(:bind_configuration).ordered
      deployment_plan_compiler.should_receive(:delete_unneeded_vms).ordered
      deployment_plan_compiler.should_receive(:delete_unneeded_instances).ordered

      resource_pool_updater.should_receive(:delete_extra_vms).ordered
      resource_pool_updater.should_receive(:delete_outdated_idle_vms).ordered

      resource_pool_updater.should_receive(:create_bound_missing_vms).ordered
      resource_pool_updater.should_receive(:reserve_networks).ordered
      resource_pool_updater.should_receive(:create_missing_vms).ordered

      job_updater.should_receive(:update)

      update_deployment_job = Bosh::Director::Jobs::UpdateDeployment.new(@manifest_file.path)

      # TODO: replace with attr_writer to avoid instance_eval
      update_deployment_job.instance_eval do
        @deployment_plan_compiler = deployment_plan_compiler
      end

      update_deployment_job.update

      check_event_log do |events|
        events.select { |e| e["task"] == "Binding configuration" }.size.should == 2
      end
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

      @deployment_plan.stub!(:model).and_return(deployment)
      @deployment_plan.stub!(:resource_pools).and_return([resource_pool_spec])

      Bosh::Director::ResourcePoolUpdater.stub!(:new).with(resource_pool_spec).and_return(mock("updater"))

      resource_pool_spec.stub!(:stemcell).and_return(stemcell_spec)
      stemcell_spec.stub!(:stemcell).and_return(new_stemcell)

      update_deployment_job = Bosh::Director::Jobs::UpdateDeployment.new(@manifest_file.path)
      update_deployment_job.update_stemcell_references

      old_stemcell.deployments.should be_empty
    end

  end

  describe "perform" do

    # TODO: refactor to use less mocks (and a real manifest)
    it "should do a basic update" do
      deployment_lock = mock("deployment_lock")
      foo_release_lock = mock("release_lock")
      bar_release_lock = mock("release_lock")

      deployment = Bosh::Director::Models::Deployment.
        make(:name => "test_deployment")

      foo_release = Bosh::Director::Models::Release.make(:name => "foo_release")
      foo_release_version = Bosh::Director::Models::ReleaseVersion.
        make(:release => foo_release, :version => 17)

      bar_release = Bosh::Director::Models::Release.make(:name => "bar_release")
      bar_release_version = Bosh::Director::Models::ReleaseVersion.
        make(:release => bar_release, :version => 42)

      foo_release_spec = mock("release_spec",
                              :name => "foo",
                              :model => foo_release_version)

      bar_release_spec = mock("release_spec",
                              :name => "bar",
                              :model => bar_release_version)

      release_specs = [foo_release_spec, bar_release_spec]

      @deployment_plan.stub!(:releases).and_return(release_specs)
      @deployment_plan.stub!(:model).and_return(deployment)

      Bosh::Director::Lock.stub!(:new).
        with("lock:deployment:test_deployment").and_return(deployment_lock)

      Bosh::Director::Lock.stub!(:new).
        with("lock:release:foo").and_return(foo_release_lock)
      Bosh::Director::Lock.stub!(:new).
        with("lock:release:bar").and_return(bar_release_lock)

      deployment_lock.should_receive(:lock).ordered.and_yield
      # Note the order of release locks is alphabetical (order is important)
      bar_release_lock.should_receive(:lock).ordered
      foo_release_lock.should_receive(:lock).ordered

      job = Bosh::Director::Jobs::UpdateDeployment.new(@manifest_file.path)
      job.should_receive(:prepare).ordered
      job.should_receive(:update).ordered
      job.should_receive(:update_stemcell_references).ordered

      deployment.should_receive(:add_release_version).
        with(foo_release_version).ordered

      deployment.should_receive(:add_release_version).
        with(bar_release_version).ordered

      foo_release_lock.should_receive(:release).ordered
      bar_release_lock.should_receive(:release).ordered

      job.perform.should == "/deployments/test_deployment"

      deployment.refresh
      deployment.manifest.should == "manifest"
    end

  end

end
