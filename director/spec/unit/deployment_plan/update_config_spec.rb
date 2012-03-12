# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../../spec_helper", __FILE__)

describe Bosh::Director::DeploymentPlan::UpdateConfig do
  describe :initialize do
    it "should create an update configuration from the spec" do
      config = BD::DeploymentPlan::UpdateConfig.new({
        "canaries" => 2,
        "max_in_flight" => 4,
        "canary_watch_time" => 60000,
        "update_watch_time" => 30000
      })

      config.canaries.should == 2
      config.max_in_flight.should == 4
      config.min_canary_watch_time.should == 60000
      config.max_canary_watch_time.should == 60000
      config.min_update_watch_time.should == 30000
      config.max_update_watch_time.should == 30000
    end

    it "should allow ranges for canary watch time" do
      config = BD::DeploymentPlan::UpdateConfig.new({
          "canaries" => 2,
          "max_in_flight" => 4,
          "canary_watch_time" => "60000-120000",
          "update_watch_time" => 30000
      })
      config.min_canary_watch_time.should == 60000
      config.max_canary_watch_time.should == 120000
    end

    it "should allow ranges for canary watch time" do
      config = BD::DeploymentPlan::UpdateConfig.new({
          "canaries" => 2,
          "max_in_flight" => 4,
          "canary_watch_time" => 60000,
          "update_watch_time" => "5000-30000"
      })
      config.min_update_watch_time.should == 5000
      config.max_update_watch_time.should == 30000
    end

    it "should require canaries when there is no default config" do
      lambda {
        BD::DeploymentPlan::UpdateConfig.new({
            "max_in_flight" => 4,
            "canary_watch_time" => 60000,
            "update_watch_time" => 30000
        })
      }.should raise_error(BD::ValidationMissingField)
    end

    it "should require max_in_flight when there is no default config" do
      lambda {
        BD::DeploymentPlan::UpdateConfig.new({
            "canaries" => 2,
            "canary_watch_time" => 60000,
            "update_watch_time" => 30000
        })
      }.should raise_error(BD::ValidationMissingField)
    end

    it "should require update_watch_time when there is no default config" do
      lambda {
        BD::DeploymentPlan::UpdateConfig.new({
            "canaries" => 2,
            "max_in_flight" => 4,
            "canary_watch_time" => 60000
        })
      }.should raise_error(BD::ValidationMissingField)
    end

    it "should require canary_watch_time when there is no default config" do
      lambda {
        BD::DeploymentPlan::UpdateConfig.new({
            "canaries" => 2,
            "max_in_flight" => 4,
            "update_watch_time" => 30000
        })
      }.should raise_error(BD::ValidationMissingField)
    end

    describe "defaults" do
      let(:default_config) {
        BD::DeploymentPlan::UpdateConfig.new({
          "canaries" => 1,
          "max_in_flight" => 2,
          "canary_watch_time" => 10000,
          "update_watch_time" => 5000
        })
      }

      it "should let you override all defaults" do
        config = BD::DeploymentPlan::UpdateConfig.new({
            "canaries" => 2,
            "max_in_flight" => 4,
            "canary_watch_time" => 60000,
            "update_watch_time" => 30000
        }, default_config)
        config.canaries.should == 2
        config.max_in_flight.should == 4
        config.min_canary_watch_time.should == 60000
        config.max_canary_watch_time.should == 60000
        config.min_update_watch_time.should == 30000
        config.max_update_watch_time.should == 30000
      end

      it "should inherit settings from default config" do
        config = BD::DeploymentPlan::UpdateConfig.new({}, default_config)
        config.canaries.should == 1
        config.max_in_flight.should == 2
        config.min_canary_watch_time.should == 10000
        config.max_canary_watch_time.should == 10000
        config.min_update_watch_time.should == 5000
        config.max_update_watch_time.should == 5000
      end
    end
  end

  describe :parse_watch_times do
    let(:basic_config) {
      BD::DeploymentPlan::UpdateConfig.new({
        "canaries" => 1,
        "max_in_flight" => 2,
        "canary_watch_time" => 10000,
        "update_watch_time" => 5000
      })
    }

    it "should parse literals" do
      basic_config.parse_watch_times(1000).should == [1000, 1000]
    end

    it "should parse ranges" do
      basic_config.parse_watch_times("100 - 1000").should == [100, 1000]
    end

    it "should fail parsing garbage" do
      lambda {
        basic_config.parse_watch_times("100 - 1000 - 5000")
      }.should raise_error(/Watch time should be/)
    end

    it "should fail parsing ranges with a higher min than max value" do
      lambda {
        basic_config.parse_watch_times("1001 - 100")
      }.should raise_error(/Min watch time cannot/)
    end
  end
end