# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../../spec_helper", __FILE__)

describe Bosh::Director::DeploymentPlan::Stemcell do

  def make(plan, spec)
    BD::DeploymentPlan::Stemcell.new(plan, spec)
  end

  def make_plan(deployment)
    mock(BD::DeploymentPlan, :model => deployment)
  end

  def make_deployment(name)
    BD::Models::Deployment.make(:name => name)
  end

  def make_stemcell(name, version)
    BD::Models::Stemcell.make(:name => name, :version => version)
  end

  let :valid_spec do
    {
      "name" => "bosh-stemcell",
      "version" => "0.5.2"
    }
  end

  describe "creating" do
    it "parses name and version" do
      plan = mock(BD::DeploymentPlan)

      sc = make(plan, valid_spec)
      sc.name.should == "bosh-stemcell"
      sc.version.should == "0.5.2"
    end

    it "requires name and version" do
      %w(name version).each do |key|
        spec = valid_spec.dup
        spec.delete(key)
        plan = mock(BD::DeploymentPlan)

        expect {
          make(plan, spec)
        }.to raise_error(BD::ValidationMissingField)
      end
    end
  end

  it "returns stemcell spec as Hash" do
    plan = mock(BD::DeploymentPlan)
    sc = make(plan, valid_spec)
    sc.spec.should == valid_spec
  end

  describe "binding stemcell model" do
    it "should bind stemcell model" do
      deployment = make_deployment("mycloud")
      plan = make_plan(deployment)
      stemcell = make_stemcell("bosh-stemcell", "0.5.2")

      sc = make(plan, valid_spec)
      sc.bind_model

      sc.model.should == stemcell
      stemcell.deployments.should == [deployment]
    end

    it "should fail if stemcell doesn't exist" do
      deployment = make_deployment("mycloud")
      plan = make_plan(deployment)

      sc = make(plan, valid_spec)
      expect {
        sc.bind_model
      }.to raise_error(BD::StemcellNotFound)
    end

    it "binds stemcells to the deployment DB" do
      deployment = make_deployment("mycloud")
      plan = make_plan(deployment)

      sc1 = make_stemcell("foo", "42-dev")
      sc2 = make_stemcell("bar", "55-dev")

      spec1 = {"name" => "foo", "version" => "42-dev"}
      spec2 = {"name" => "bar", "version" => "55-dev"}

      make(plan, spec1).bind_model
      make(plan, spec2).bind_model

      deployment.stemcells.should =~ [sc1, sc2]
    end

    it "doesn't bind model if deployment plan has unbound deployment" do
      plan = make_plan(nil)

      expect {
        sc = make(plan, {"name" => "foo", "version" => "42"})
        sc.bind_model
      }.to raise_error(BD::DirectorError,
                       "Deployment not bound in the deployment plan")
    end
  end

end