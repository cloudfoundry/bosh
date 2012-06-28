# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../../spec_helper", __FILE__)

describe Bosh::Agent::ApplyPlan::Plan do

  before :each do
    @base_dir = Dir.mktmpdir
    Bosh::Agent::Config.base_dir = @base_dir
  end

  def make_plan(*args)
    Bosh::Agent::ApplyPlan::Plan.new(*args)
  end

  let(:valid_spec) do
    {
      "deployment" => "mycloud",
      "configuration_hash" => "deadbeef",
      "job" => {
        "name" => "ccdb",
        "template" => "postgres",
        "version" => "42",
        "sha1" => "deadbeef",
        "blobstore_id" => "deadcafe"
      },
      "packages" => {
        "foo" => {
          "name" => "foo",
          "version" => "5.dev",
          "sha1" => "cadada",
          "blobstore_id" => "deadbad"
        },
        "bar" => {
          "name" => "bar",
          "version" => "15",
          "sha1" => "fafaeda",
          "blobstore_id" => "badeff"
        }
      }
    }
  end

  describe "initialization" do
    it "expects Hash argument" do
      expect {
        make_plan("test")
      }.to raise_error(ArgumentError, "Invalid spec format, " +
                                      "Hash expected, String given")
    end

    it "initializes deployment, job and packages" do
      plan = make_plan(valid_spec)

      plan.deployment.should == "mycloud"
      plan.jobs.length.should == 1
      plan.jobs[0].should be_kind_of Bosh::Agent::ApplyPlan::Job
      plan.packages.size.should == 2
      plan.packages.each do |package|
        package.should be_kind_of Bosh::Agent::ApplyPlan::Package
      end

      plan.has_jobs?.should be_true
      plan.has_packages?.should be_true
      plan.configured?.should be_true
    end
  end

  describe "operations" do

    let(:plan) do
      make_plan(valid_spec)
    end

    it "installs job" do
      plan.jobs.length.should == 1
      plan.jobs[0].should_receive(:install)
      plan.install_jobs
    end

    it "installs packages" do
      plan.packages.each do |package|
        plan.jobs.length.should == 1
        package.should_receive(:install_for_job).with(plan.jobs[0])
      end

      plan.install_packages
    end

    it "configures job" do
      plan.jobs.length.should == 1
      plan.jobs[0].should_receive(:configure)
      plan.configure_jobs
    end

  end

end
