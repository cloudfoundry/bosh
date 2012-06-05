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

      BD::DeploymentPlan.new({:some => :manifest})
    end

    describe :options do
      before(:each) do
        MOCKED_METHODS.each do |method_name|
          BD::DeploymentPlan.any_instance.stub(method_name)
        end
      end

      it "should parse recreate" do
        plan = BD::DeploymentPlan.new({})
        plan.recreate.should == false

        plan = BD::DeploymentPlan.new({}, "recreate" => true)
        plan.recreate.should == true
      end
    end
  end

  describe :parse_name do
    before(:each) do
      (MOCKED_METHODS - [:parse_name]).each do |method_name|
        BD::DeploymentPlan.any_instance.stub(method_name)
      end
    end

    it "should parse the raw and canonical names" do
      plan = BD::DeploymentPlan.new({"name" => "Test Deployment"})
      plan.name.should == "Test Deployment"
      plan.canonical_name.should == "testdeployment"
    end
  end

  describe :parse_properties do
    before(:each) do
      (MOCKED_METHODS - [:parse_properties]).each do |method_name|
        BD::DeploymentPlan.any_instance.stub(method_name)
      end
    end

    it "should parse basic properties" do
      plan = BD::DeploymentPlan.new({"properties" => {"foo" => "bar"}})
      plan.properties.should == {"foo" => "bar"}
    end

    it "should allow not having any properties" do
      plan = BD::DeploymentPlan.new({"name" => "Test Deployment"})
      plan.properties.should == {}
    end
  end

  describe :parse_releases do
    before(:each) do
      (MOCKED_METHODS - [:parse_releases]).each do |method_name|
        BD::DeploymentPlan.any_instance.stub(method_name)
      end
    end

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
      plan.releases.size.should == 1
      release = plan.releases[0]
      release.should be_kind_of(Bosh::Director::DeploymentPlan::ReleaseSpec)
      release.name.should == "foo"
      release.version.should == "23"
      release.spec.should == release_spec

      plan.release("foo").should == release
    end

    it "should fail when the release section is omitted" do
      lambda {
        BD::DeploymentPlan.new({})
      }.should raise_error(BD::ValidationMissingField)
    end

    it "support multiple releases per deployment" do
      plan = BD::DeploymentPlan.new({ "releases" => releases_spec })
      plan.releases.size.should == 2
      plan.releases[0].spec.should == releases_spec[0]
      plan.releases[1].spec.should == releases_spec[1]
      plan.releases.each do |release|
        release.should be_kind_of(Bosh::Director::DeploymentPlan::ReleaseSpec)
      end

      plan.release("foo").should == plan.releases[0]
      plan.release("bar").should == plan.releases[1]
    end

    it "supports either 'releases' or 'release' manifest section, not both" do
      expect {
        BD::DeploymentPlan.new({
                                 "releases" => releases_spec,
                                 "release" => release_spec
                               })
      }.to raise_error(/use one of the two/)
    end

    it "should detect duplicate release names" do
      expect {
        BD::DeploymentPlan.new({
                                 "releases" => [release_spec, release_spec]
                               })
      }.to raise_error(/duplicate release name/i)
    end

  end

  describe :parse_networks do
    before(:each) do
      (MOCKED_METHODS - [:parse_networks]).each do |method_name|
        BD::DeploymentPlan.any_instance.stub(method_name)
      end
    end

    it "should create manual network by default" do
      network_spec = mock(:network_spec)
      network_spec.stub(:name).and_return("Bar")
      network_spec.stub(:canonical_name).and_return("bar")
      network_spec

      received_plan = nil
      BD::DeploymentPlan::ManualNetworkSpec.should_receive(:new).
          and_return do |deployment_plan, spec|
        received_plan = deployment_plan
        spec.should == {"foo" => "bar"}
        network_spec
      end
      plan = BD::DeploymentPlan.new({"networks" => [{"foo" => "bar"}]})
      received_plan.should == plan
    end

    it "should enforce canonical name uniqueness" do
      BD::DeploymentPlan::ManualNetworkSpec.stub(:new).
          and_return do |deployment_plan, spec|
        network_spec = mock(:network_spec)
        network_spec.stub(:name).and_return(spec["name"])
        network_spec.stub(:canonical_name).and_return(spec["cname"])
        network_spec
      end

      lambda {
        BD::DeploymentPlan.new({"networks" => [
            {"name" => "bar", "cname" => "bar"},
            {"name" => "Bar", "cname" => "bar"}
        ]})
      }.should raise_error(BD::DeploymentCanonicalNetworkNameTaken,
          "Invalid network name `Bar', canonical name already taken")
    end

    it "should require at least one network" do
      lambda {
        BD::DeploymentPlan.new({"networks" => []})
      }.should raise_error(BD::DeploymentNoNetworks, "No networks specified")

      lambda {
        BD::DeploymentPlan.new({})
      }.should raise_error(BD::ValidationMissingField)
    end

    it "should create other types of network when specified"
  end

  describe :parse_compilation do
    before(:each) do
      (MOCKED_METHODS - [:parse_compilation]).each do |method_name|
        BD::DeploymentPlan.any_instance.stub(method_name)
      end
    end

    it "should delegate to CompilationConfig" do
      received_plan = nil
      BD::DeploymentPlan::CompilationConfig.
          should_receive(:new).with do |deployment_plan, spec|
        received_plan = deployment_plan
        spec.should == {"foo" => "bar"}
      end
      plan = BD::DeploymentPlan.new({"compilation" => {"foo" => "bar"}})
      received_plan.should == plan
    end

    it "should fail when the compilation section is omitted" do
      lambda {
        BD::DeploymentPlan.new({})
      }.should raise_error(BD::ValidationMissingField)
    end
  end

  describe :parse_update do
    before(:each) do
      (MOCKED_METHODS - [:parse_update]).each do |method_name|
        BD::DeploymentPlan.any_instance.stub(method_name)
      end
    end

    it "should delegate to UpdateConfig" do
      BD::DeploymentPlan::UpdateConfig.should_receive(:new).with do |spec|
        spec.should == {"foo" => "bar"}
      end
      BD::DeploymentPlan.new({"update" => {"foo" => "bar"}})
    end

    it "should fail when the update section is omitted" do
      lambda {
        BD::DeploymentPlan.new({})
      }.should raise_error(BD::ValidationMissingField)
    end

  end

  describe :parse_resource_pools do
    before(:each) do
      (MOCKED_METHODS - [:parse_resource_pools]).each do |method_name|
        BD::DeploymentPlan.any_instance.stub(method_name)
      end
    end

    it "should delegate to ResourcePoolSpec" do
      resource_pool_spec = mock(:resource_pool_spec)
      resource_pool_spec.stub(:name).and_return("foo")

      received_plan = nil
      BD::DeploymentPlan::ResourcePoolSpec.should_receive(:new).
          and_return do |deployment_plan, spec|
        received_plan = deployment_plan
        spec.should == {"foo" => "bar"}
        resource_pool_spec
      end

      plan = BD::DeploymentPlan.new({"resource_pools" => [{"foo" => "bar"}]})
      plan.resource_pools.should == [resource_pool_spec]
      plan.resource_pool("foo").should == resource_pool_spec
      received_plan.should == plan
    end

    it "should enforce name uniqueness" do
      BD::DeploymentPlan::ResourcePoolSpec.stub(:new).
          and_return do |_, spec|
        resource_pool_spec = mock(:resource_pool_spec)
        resource_pool_spec.stub(:name).and_return(spec["name"])
        resource_pool_spec
      end
      lambda {
        BD::DeploymentPlan.new(
          {"resource_pools" => [{"name" => "bar"}, {"name" => "bar"}]}
        )
      }.should raise_error(BD::DeploymentDuplicateResourcePoolName,
                           "Duplicate resource pool name `bar'")
    end

    pending "should require at least one resource pool" do
      lambda {
        BD::DeploymentPlan.new({"resource_pools" => []})
      }.should raise_error(%q{No resource pools specified.})
    end
  end

  describe :parse_jobs do
    before(:each) do
      (MOCKED_METHODS - [:parse_jobs]).each do |method_name|
        BD::DeploymentPlan.any_instance.stub(method_name)
      end
    end

    it "should delegate to JobSpec" do
      job_spec = mock(:job_spec)
      job_spec.stub(:name).and_return("Foo")
      job_spec.stub(:canonical_name).and_return("foo")
      job_spec

      received_plan = nil
      BD::DeploymentPlan::JobSpec.should_receive(:new).
          and_return do |deployment_plan, spec|
        received_plan = deployment_plan
        spec.should == {"foo" => "bar"}
        job_spec
      end
      plan = BD::DeploymentPlan.new({"jobs" => [{"foo" => "bar"}]})
      received_plan.should == plan
    end

    it "should enforce canonical name uniqueness" do
      BD::DeploymentPlan::JobSpec.stub(:new).
          and_return do |_, spec|
        job_spec = mock(:job_spec)
        job_spec.stub(:name).and_return(spec["name"])
        job_spec.stub(:canonical_name).and_return(spec["cname"])
        job_spec
      end
      lambda {
        BD::DeploymentPlan.new({"jobs" => [
            {"name" => "Bar", "cname" => "bar"},
            {"name" => "bar", "cname" => "bar"}
        ]})
      }.should raise_error(BD::DeploymentCanonicalJobNameTaken,
                           "Invalid job name `bar', " +
                           "canonical name already taken")
    end

    it "should raise exception if renamed job is being referenced in deployment" do
      lambda {
        BD::DeploymentPlan.new(
          {"jobs" => [{"name" => "bar"}]},
          {"job_rename" => {"old_name" => "bar", "new_name" => "foo"}}
        )
      }.should raise_error(BD::DeploymentRenamedJobNameStillUsed,
                           "Renamed job `bar' is still referenced " +
                           "in deployment manifest")
    end

    it "should allow you to not have any jobs" do
      BD::DeploymentPlan.new({"jobs" => []}).jobs.should be_empty
      BD::DeploymentPlan.new({}).jobs.should be_empty
    end
  end
end
