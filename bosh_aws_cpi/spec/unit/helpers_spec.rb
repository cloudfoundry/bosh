# Copyright (c) 2009-2012 VMware, Inc.

require "spec_helper"

describe Bosh::AwsCloud::Helpers do


  describe "#extract_security_groups" do
    let(:networks_spec) do
      {
          "vip" => {"cloud_properties" => {}},
          "default" => {"cloud_properties" => {"security_groups" => ["two to tango", "numero uno"]}},
          "other" => {"cloud_properties" => {"security_groups" => "numero uno"}}
      }
    end

    it "should return a sorted list of unique security_group_names" do
      class HelpersTester
        include Bosh::AwsCloud::Helpers
      end

      helpers_tester = HelpersTester.new
      expect(helpers_tester.extract_security_groups(networks_spec)).to match_array(["numero uno", "two to tango"])
    end
  end
end