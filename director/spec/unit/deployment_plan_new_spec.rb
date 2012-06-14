# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::Director::DeploymentPlan do

  def make_plan(manifest)
    BD::DeploymentPlan.new(manifest)
  end

  def find_deployment(name)
    BD::Models::Deployment.find(:name => name)
  end

  def make_deployment(name)
    BD::Models::Deployment.make(:name => name)
  end

  describe "binding deployment model" do
    it "creates new deployment in DB using name from the manifest" do
      plan = make_plan({"name" => "mycloud"})
      plan.parse_name

      find_deployment("mycloud").should be_nil
      plan.bind_model

      plan.model.should == find_deployment("mycloud")
      BD::Models::Deployment.count.should == 1
    end

    it "uses an existing deployment model if found in DB" do
      plan = make_plan({"name" => "mycloud"})
      plan.parse_name

      deployment = make_deployment("mycloud")
      plan.bind_model
      plan.model.should == deployment
      BD::Models::Deployment.count.should == 1
    end

    it "enforces canonical name uniqueness" do
      make_deployment("my-cloud")
      plan = make_plan("name" => "my_cloud")
      plan.parse_name

      expect {
        plan.bind_model
      }.to raise_error(BD::DeploymentCanonicalNameTaken)

      plan.model.should be_nil
      BD::Models::Deployment.count.should == 1
    end

    it "only works when name and canonical name are known" do
      plan = make_plan("name" => "my_cloud")
      expect {
        plan.bind_model
      }.to raise_error(BD::DirectorError)

      plan.parse_name
      lambda { plan.bind_model }.should_not raise_error
    end
  end
end