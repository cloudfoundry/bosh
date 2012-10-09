# Copyright (c) 2012 VMware, Inc.

require "spec_helper"

describe "property" do
  before(:all) do
    bosh("upload release #{latest_bat_release}")
    bosh("upload stemcell #{stemcell}")
    @deployment = with_deployment(deployment_spec)
    bosh("deployment #{@deployment}")
    bosh("deploy")
  end

  after(:all) do
    bosh("delete deployment bat")
    bosh("delete stemcell bosh-stemcell #{stemcell_version}")
    bosh("delete release bat")
    FileUtils.rm @deployment
  end

  context "with no property" do
    it "should not return a value" do
      expect {
        bosh("get property doesntexist")
      }.to raise_error { |error|
        error.should be_a Bosh::Exec::Error
        error.output.should match /Error 110003/
      }
    end

    it "should set a property" do
      result = bosh("set property newprop something")
      result.output.should match /This will be a new property/
      result.output.should match /Property `newprop' set to `something'/
    end
  end

  context "with existing property" do
    it "should set a property" do
      bosh("set property prop1 value1")
      result = bosh("set property prop1 value2")
      result.output.should match /Current `prop1' value is `value1'/
      result.output.should match /Property `prop1' set to `value2'/
    end

    it "should get a value" do
      bosh("set property prop2 value3")
      bosh("get property prop2").should succeed_with /Property `prop2' value is `value3'/
    end
  end

end
