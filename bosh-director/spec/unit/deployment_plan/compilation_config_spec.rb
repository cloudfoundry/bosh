# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../../spec_helper", __FILE__)

describe Bosh::Director::DeploymentPlan::CompilationConfig do
  describe :initialize do
    before(:each) do
      @deployment = instance_double('Bosh::Director::DeploymentPlan::Planner')
      @network = instance_double('Bosh::Director::DeploymentPlan::Network')
      allow(@deployment).to receive(:network).with("foo").and_return(@network)
    end

    it "should parse the basic properties" do
      config = BD::DeploymentPlan::CompilationConfig.new(@deployment, {
          "workers" => 2,
          "network" => "foo",
          "cloud_properties" => {
              "foo" => "bar"
          }
      })

      expect(config.workers).to eq(2)
      expect(config.network).to eq(@network)
      expect(config.cloud_properties).to eq({"foo" => "bar"})
      expect(config.env).to eq({})
    end

    it "should require workers to be specified" do
      expect {
        BD::DeploymentPlan::CompilationConfig.new(@deployment, {
            "network" => "foo",
            "cloud_properties" => {
                "foo" => "bar"
            }
        })
      }.to raise_error(BD::ValidationMissingField)
    end

    it "should require there to be at least 1 worker" do
      expect {
        BD::DeploymentPlan::CompilationConfig.new(@deployment, {
            "workers" => 0,
            "network" => "foo",
            "cloud_properties" => {
                "foo" => "bar"
            }
        })
      }.to raise_error(BD::ValidationViolatedMin)
    end

    it "should require a network to be specified" do
      expect {
        BD::DeploymentPlan::CompilationConfig.new(@deployment, {
            "workers" => 1,
            "cloud_properties" => {
                "foo" => "bar"
            }
        })
      }.to raise_error(BD::ValidationMissingField)
    end

    it "should require the specified network to exist" do
      allow(@deployment).to receive(:network).with("bar").and_return(nil)
      expect {
        BD::DeploymentPlan::CompilationConfig.new(@deployment, {
            "workers" => 1,
            "network" => "bar",
            "cloud_properties" => {
                "foo" => "bar"
            }
        })
      }.to raise_error(/unknown network `bar'/)
    end

    it "defaults resource pool cloud properties to empty hash" do
      config = BD::DeploymentPlan::CompilationConfig.new(@deployment, {
            "workers" => 1,
            "network" => "foo"
        })
      expect(config.cloud_properties).to eq({})
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
      expect(config.env).to eq({"password" => "password1"})
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
      expect(config.reuse_compilation_vms).to eq(true)
    end

    it "should throw an error when a boolean property isnt boolean" do
      expect {
        config = BD::DeploymentPlan::CompilationConfig.new(@deployment, {
            "workers" => 1,
            "network" => "foo",
            "cloud_properties" => {
                "foo" => "bar"
            },
            # the non-boolean boolean
            "reuse_compilation_vms" => 1
        })
      }.to raise_error(Bosh::Director::ValidationInvalidType)
    end

  end
end
