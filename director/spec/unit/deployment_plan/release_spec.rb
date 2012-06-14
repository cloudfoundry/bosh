# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../../spec_helper", __FILE__)

describe Bosh::Director::DeploymentPlan::Release do

  def make(plan, spec)
    BD::DeploymentPlan::Release.new(plan, spec)
  end

  def make_plan(deployment)
    double(BD::DeploymentPlan, :model => deployment)
  end

  def find_release(name)
    BD::Models::Release.find(:name => name)
  end

  def make_deployment(name)
    BD::Models::Deployment.make(:name => name)
  end

  def make_release(name)
    BD::Models::Release.make(:name => name)
  end

  def make_version(name, version)
    release = make_release(name)
    BD::Models::ReleaseVersion.make(:release => release, :version => version)
  end

  describe "binding release version model" do
    it "should bind release version model" do
      spec = {"name" => "foo", "version" => "42-dev"}
      deployment = make_deployment("mycloud")
      plan = make_plan(deployment)
      rv1 = make_version("foo", "42-dev")

      release = make(plan, spec)
      release.bind_model

      release.model.should == rv1
      deployment.release_versions.should == [rv1]
    end

    it "should fail if release doesn't exist" do
      deployment = make_deployment("mycloud")
      plan = make_plan(deployment)
      spec = {"name" => "foo", "version" => "42-dev"}

      expect {
        release = make(plan, spec)
        release.bind_model
      }.to raise_error(BD::ReleaseNotFound)
    end

    it "should fail if release version doesn't exist" do
      deployment = make_deployment("mycloud")
      plan = make_plan(deployment)
      spec = {"name" => "foo", "version" => "42-dev"}
      make_version("foo", "55-dev")

      expect {
        release = make(plan, spec)
        release.bind_model
      }.to raise_error(BD::ReleaseVersionNotFound)
    end

    it "binds release versions to the deployment in DB" do
      deployment = make_deployment("mycloud")
      plan = make_plan(deployment)

      rv1 = make_version("foo", "42-dev")
      rv2 = make_version("bar", "55-dev")

      spec1 = {"name" => "foo", "version" => "42-dev"}
      spec2 = {"name" => "bar", "version" => "55-dev"}

      make(plan, spec1).bind_model
      make(plan, spec2).bind_model

      deployment.release_versions.should =~ [rv1, rv2]
    end

    it "doesn't bind model if deployment plan has unbound deployment" do
      plan = make_plan(nil)

      expect {
        release = make(plan, {"name" => "foo", "version" => "42"})
        release.bind_model
      }.to raise_error(BD::DirectorError,
                       "Deployment not bound in deployment plan")
    end
  end
end
