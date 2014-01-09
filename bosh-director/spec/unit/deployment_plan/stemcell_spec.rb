# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../../spec_helper", __FILE__)

describe Bosh::Director::DeploymentPlan::Stemcell do

  def make(resource_pool, spec)
    BD::DeploymentPlan::Stemcell.new(resource_pool, spec)
  end

  def make_resource_pool(plan)
    instance_double('Bosh::Director::DeploymentPlan::ResourcePool', :deployment_plan => plan)
  end

  def make_plan(deployment = nil)
    instance_double('Bosh::Director::DeploymentPlan::Planner', :model => deployment)
  end

  def make_deployment(name)
    BD::Models::Deployment.make(:name => name)
  end

  def make_stemcell(name, version)
    BD::Models::Stemcell.make(:name => name, :version => version)
  end

  let(:valid_spec) do
    {
      "name" => "stemcell-name",
      "version" => "0.5.2"
    }
  end

  describe "creating" do
    it "parses name and version" do
      resource_pool = make_resource_pool(make_plan)

      sc = make(resource_pool, valid_spec)
      sc.name.should == "stemcell-name"
      sc.version.should == "0.5.2"
    end

    it "requires name and version" do
      %w(name version).each do |key|
        spec = valid_spec.dup
        spec.delete(key)
        resource_pool = make_resource_pool(make_plan)

        expect {
          make(resource_pool, spec)
        }.to raise_error(BD::ValidationMissingField)
      end
    end
  end

  it "returns stemcell spec as Hash" do
    resource_pool = make_resource_pool(make_plan)
    sc = make(resource_pool, valid_spec)
    sc.spec.should == valid_spec
  end

  describe "binding stemcell model" do
    it "should bind stemcell model" do
      deployment = make_deployment("mycloud")
      plan = make_plan(deployment)
      resource_pool = make_resource_pool(plan)
      stemcell = make_stemcell("stemcell-name", "0.5.2")

      sc = make(resource_pool, valid_spec)
      sc.bind_model

      sc.model.should == stemcell
      stemcell.deployments.should == [deployment]
    end

    it "should fail if stemcell doesn't exist" do
      deployment = make_deployment("mycloud")
      plan = make_plan(deployment)
      resource_pool = make_resource_pool(plan)

      sc = make(resource_pool, valid_spec)
      expect {
        sc.bind_model
      }.to raise_error(BD::StemcellNotFound)
    end

    it "binds stemcells to the deployment DB" do
      deployment = make_deployment("mycloud")
      plan = make_plan(deployment)
      resource_pool = make_resource_pool(plan)

      sc1 = make_stemcell("foo", "42-dev")
      sc2 = make_stemcell("bar", "55-dev")

      spec1 = {"name" => "foo", "version" => "42-dev"}
      spec2 = {"name" => "bar", "version" => "55-dev"}

      make(resource_pool, spec1).bind_model
      make(resource_pool, spec2).bind_model

      deployment.stemcells.should =~ [sc1, sc2]
    end

    it "doesn't bind model if deployment plan has unbound deployment" do
      resource_pool = make_resource_pool(make_plan)

      expect {
        sc = make(resource_pool, {"name" => "foo", "version" => "42"})
        sc.bind_model
      }.to raise_error(BD::DirectorError,
                       "Deployment not bound in the deployment plan")
    end
  end
end
