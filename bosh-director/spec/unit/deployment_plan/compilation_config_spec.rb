# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../../spec_helper", __FILE__)

describe Bosh::Director::DeploymentPlan::CompilationConfig do
  describe :initialize do
    before(:each) do
      @deployment = instance_double('Bosh::Director::DeploymentPlan::Planner')
      @network = instance_double('Bosh::Director::DeploymentPlan::Network')
      @deployment.stub(:network).with("foo").and_return(@network)
    end

    it "should parse the basic properties" do
      config = BD::DeploymentPlan::CompilationConfig.new(@deployment, {
          "workers" => 2,
          "network" => "foo",
          "cloud_properties" => {
              "foo" => "bar"
          }
      })

      config.workers.should == 2
      config.network.should == @network
      config.cloud_properties.should == {"foo" => "bar"}
      config.env.should == {}
    end

    it "should require workers to be specified" do
      lambda {
        BD::DeploymentPlan::CompilationConfig.new(@deployment, {
            "network" => "foo",
            "cloud_properties" => {
                "foo" => "bar"
            }
        })
      }.should raise_error(BD::ValidationMissingField)
    end

    it "should require there to be at least 1 worker" do
      lambda {
        BD::DeploymentPlan::CompilationConfig.new(@deployment, {
            "workers" => 0,
            "network" => "foo",
            "cloud_properties" => {
                "foo" => "bar"
            }
        })
      }.should raise_error(BD::ValidationViolatedMin)
    end

    it "should require a network to be specified" do
      lambda {
        BD::DeploymentPlan::CompilationConfig.new(@deployment, {
            "workers" => 1,
            "cloud_properties" => {
                "foo" => "bar"
            }
        })
      }.should raise_error(BD::ValidationMissingField)
    end

    it "should require the specified network to exist" do
      @deployment.stub(:network).with("bar").and_return(nil)
      lambda {
        BD::DeploymentPlan::CompilationConfig.new(@deployment, {
            "workers" => 1,
            "network" => "bar",
            "cloud_properties" => {
                "foo" => "bar"
            }
        })
      }.should raise_error(/unknown network `bar'/)
    end

    it "should require resource pool cloud properties" do
      lambda {
        BD::DeploymentPlan::CompilationConfig.new(@deployment, {
            "workers" => 1,
            "network" => "foo"
        })
      }.should raise_error(BD::ValidationMissingField)
    end

    it "should allow an optional environment to be set" do
      config = BD::DeploymentPlan::CompilationConfig.new(@deployment, {
          "workers" => 1,
          "network" => "foo",
          "cloud_properties" => {
              "foo" => "bar"
          },
          "env" => {
              "password" => "password1"
          }
      })
      config.env.should == {"password" => "password1"}
    end

    it "should allow reuse_compilation_vms to be set" do
      config = BD::DeploymentPlan::CompilationConfig.new(@deployment, {
          "workers" => 1,
          "network" => "foo",
          "cloud_properties" => {
              "foo" => "bar"
          },
          "reuse_compilation_vms" => true
      })
      config.reuse_compilation_vms.should == true
    end

    it "should throw an error when a boolean property isnt boolean" do
      lambda {
        config = BD::DeploymentPlan::CompilationConfig.new(@deployment, {
            "workers" => 1,
            "network" => "foo",
            "cloud_properties" => {
                "foo" => "bar"
            },
            # the non-boolean boolean
            "reuse_compilation_vms" => 1
        })
      }.should raise_error(Bosh::Director::ValidationInvalidType)
    end

  end
end
