# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::Director::DeploymentPlan do
  MOCKED_METHODS = [:parse_name, :parse_properties, :parse_releases,
                    :parse_networks, :parse_compilation, :parse_update,
                    :parse_resource_pools, :parse_jobs]

  describe :initialize do
    it "should parse the manifest" do
      MOCKED_METHODS.each do |method_name|
        BD::DeploymentPlan.any_instance.should_receive(method_name)
      end

      plan = BD::DeploymentPlan.new({:some => :manifest})
      plan.parse
    end

    describe :options do
      it "should parse recreate" do
        plan = BD::DeploymentPlan.new({})
        plan.recreate.should == false

        plan = BD::DeploymentPlan.new({}, "recreate" => true)
        plan.recreate.should == true
      end
    end
  end

  describe :parse_name do
    it "should parse the raw and canonical names" do
      plan = BD::DeploymentPlan.new({"name" => "Test Deployment"})
      plan.parse_name
      plan.name.should == "Test Deployment"
      plan.canonical_name.should == "testdeployment"
    end
  end

  describe :parse_properties do
    it "should parse basic properties" do
      plan = BD::DeploymentPlan.new({"properties" => {"foo" => "bar"}})
      plan.parse_properties
      plan.properties.should == {"foo" => "bar"}
    end

    it "should allow not having any properties" do
      plan = BD::DeploymentPlan.new({"name" => "Test Deployment"})
      plan.parse_properties
      plan.properties.should == {}
    end
  end

  describe :parse_releases do
    let(:release_spec) do
      {
        "name" => "foo",
        "version" => "23"
      }
    end

    let(:releases_spec) do
      [
        { "name" => "foo", "version" => "27" },
        { "name" => "bar", "version" => "42" }
      ]
    end

    it "should create a release spec" do
      plan = BD::DeploymentPlan.new({ "release" => release_spec })
      plan.parse_releases
      plan.releases.size.should == 1
      release = plan.releases[0]
      release.should be_kind_of(Bosh::Director::DeploymentPlan::Release)
      release.name.should == "foo"
      release.version.should == "23"
      release.spec.should == release_spec

      plan.release("foo").should == release
    end

    it "should fail when the release section is omitted" do
      lambda {
        plan = BD::DeploymentPlan.new({})
        plan.parse_releases
      }.should raise_error(BD::ValidationMissingField)
    end

    it "support multiple releases per deployment" do
      plan = BD::DeploymentPlan.new({ "releases" => releases_spec })
      plan.parse_releases
      plan.releases.size.should == 2
      plan.releases[0].spec.should == releases_spec[0]
      plan.releases[1].spec.should == releases_spec[1]
      plan.releases.each do |release|
        release.should be_kind_of(Bosh::Director::DeploymentPlan::Release)
      end

      plan.release("foo").should == plan.releases[0]
      plan.release("bar").should == plan.releases[1]
    end

    it "supports either 'releases' or 'release' manifest section, not both" do
      expect {
        plan = BD::DeploymentPlan.new({
                                        "releases" => releases_spec,
                                        "release" => release_spec
                                      })
        plan.parse_releases
      }.to raise_error(/use one of the two/)
    end

    it "should detect duplicate release names" do
      expect {
        plan = BD::DeploymentPlan.new({
                                        "releases" => [release_spec,
                                                       release_spec]
                                      })
        plan.parse_releases
      }.to raise_error(/duplicate release name/i)
    end

  end

  describe :parse_networks do
    it "should create manual network by default" do
      network_spec = mock(:network_spec)
      network_spec.stub(:name).and_return("Bar")
      network_spec.stub(:canonical_name).and_return("bar")
      network_spec

      received_plan = nil
      BD::DeploymentPlan::ManualNetwork.should_receive(:new).
          and_return do |deployment_plan, spec|
        received_plan = deployment_plan
        spec.should == {"foo" => "bar"}
        network_spec
      end
      plan = BD::DeploymentPlan.new({"networks" => [{"foo" => "bar"}]})
      plan.parse_networks
      received_plan.should == plan
    end

    it "should enforce canonical name uniqueness" do
      BD::DeploymentPlan::ManualNetwork.stub(:new).
          and_return do |deployment_plan, spec|
        network_spec = mock(:network_spec)
        network_spec.stub(:name).and_return(spec["name"])
        network_spec.stub(:canonical_name).and_return(spec["cname"])
        network_spec
      end

      lambda {
        plan = BD::DeploymentPlan.new({"networks" => [
          {"name" => "bar", "cname" => "bar"},
          {"name" => "Bar", "cname" => "bar"}
        ]})
        plan.parse_networks
      }.should raise_error(BD::DeploymentCanonicalNetworkNameTaken,
          "Invalid network name `Bar', canonical name already taken")
    end

    it "should require at least one network" do
      lambda {
        plan = BD::DeploymentPlan.new({"networks" => []})
        plan.parse_networks
      }.should raise_error(BD::DeploymentNoNetworks, "No networks specified")

      lambda {
        plan = BD::DeploymentPlan.new({})
        plan.parse_networks
      }.should raise_error(BD::ValidationMissingField)
    end

    it "should create other types of network when specified"
  end

  describe :parse_compilation do
    it "should delegate to CompilationConfig" do
      received_plan = nil
      BD::DeploymentPlan::CompilationConfig.
          should_receive(:new).with do |deployment_plan, spec|
        received_plan = deployment_plan
        spec.should == {"foo" => "bar"}
      end
      plan = BD::DeploymentPlan.new({"compilation" => {"foo" => "bar"}})
      plan.parse_compilation
      received_plan.should == plan
    end

    it "should fail when the compilation section is omitted" do
      lambda {
        plan = BD::DeploymentPlan.new({})
        plan.parse_compilation
      }.should raise_error(BD::ValidationMissingField)
    end
  end

  describe :parse_update do
    it "should delegate to UpdateConfig" do
      BD::DeploymentPlan::UpdateConfig.should_receive(:new).with do |spec|
        spec.should == {"foo" => "bar"}
      end
      plan = BD::DeploymentPlan.new({"update" => {"foo" => "bar"}})
      plan.parse_update
    end

    it "should fail when the update section is omitted" do
      lambda {
        plan = BD::DeploymentPlan.new({})
        plan.parse_update
      }.should raise_error(BD::ValidationMissingField)
    end

  end

  describe :parse_resource_pools do
    it "should delegate to ResourcePool" do
      resource_pool_spec = mock(:resource_pool)
      resource_pool_spec.stub(:name).and_return("foo")

      received_plan = nil
      BD::DeploymentPlan::ResourcePool.should_receive(:new).
          and_return do |deployment_plan, spec|
        received_plan = deployment_plan
        spec.should == {"foo" => "bar"}
        resource_pool_spec
      end

      plan = BD::DeploymentPlan.new({"resource_pools" => [{"foo" => "bar"}]})
      plan.parse_resource_pools
      plan.resource_pools.should == [resource_pool_spec]
      plan.resource_pool("foo").should == resource_pool_spec
      received_plan.should == plan
    end

    it "should enforce name uniqueness" do
      BD::DeploymentPlan::ResourcePool.stub(:new).
          and_return do |_, spec|
        resource_pool_spec = mock(:resource_pool_spec)
        resource_pool_spec.stub(:name).and_return(spec["name"])
        resource_pool_spec
      end
      lambda {
        plan = BD::DeploymentPlan.new(
          {"resource_pools" => [{"name" => "bar"}, {"name" => "bar"}]}
        )
        plan.parse_resource_pools
      }.should raise_error(BD::DeploymentDuplicateResourcePoolName,
                           "Duplicate resource pool name `bar'")
    end

    pending "should require at least one resource pool" do
      lambda {
        plan = BD::DeploymentPlan.new({"resource_pools" => []})
        plan.parse_resource_pools
      }.should raise_error(%q{No resource pools specified.})
    end
  end

  describe :parse_jobs do
    it "should delegate to Job" do
      job_spec = mock(BD::DeploymentPlan::Job)
      job_spec.stub(:name).and_return("Foo")
      job_spec.stub(:canonical_name).and_return("foo")
      job_spec

      received_plan = nil
      BD::DeploymentPlan::Job.should_receive(:new).
          and_return do |deployment_plan, spec|
        received_plan = deployment_plan
        spec.should == {"foo" => "bar"}
        job_spec
      end
      plan = BD::DeploymentPlan.new({"jobs" => [{"foo" => "bar"}]})
      plan.parse_jobs
      received_plan.should == plan
    end

    it "should enforce canonical name uniqueness" do
      BD::DeploymentPlan::Job.stub(:new).
          and_return do |_, spec|
        job_spec = mock(:job_spec)
        job_spec.stub(:name).and_return(spec["name"])
        job_spec.stub(:canonical_name).and_return(spec["cname"])
        job_spec
      end
      lambda {
        plan = BD::DeploymentPlan.new({"jobs" => [
            {"name" => "Bar", "cname" => "bar"},
            {"name" => "bar", "cname" => "bar"}
        ]})
        plan.parse_jobs
      }.should raise_error(BD::DeploymentCanonicalJobNameTaken,
                           "Invalid job name `bar', " +
                           "canonical name already taken")
    end

    it "should raise exception if renamed job is being referenced in deployment" do
      lambda {
        plan = BD::DeploymentPlan.new(
          {"jobs" => [{"name" => "bar"}]},
          {"job_rename" => {"old_name" => "bar", "new_name" => "foo"}}
        )
        plan.parse_jobs
      }.should raise_error(BD::DeploymentRenamedJobNameStillUsed,
                           "Renamed job `bar' is still referenced " +
                           "in deployment manifest")
    end

    it "should allow you to not have any jobs" do
      plan = BD::DeploymentPlan.new({"jobs" => []})
      plan.parse_jobs

      plan.jobs.should be_empty

      plan = BD::DeploymentPlan.new({})
      plan.parse_jobs
      plan.jobs.should be_empty
    end
  end
end
