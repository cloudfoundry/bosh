# Copyright (c) 2012 VMware, Inc.

require "spec_helper"

describe "property" do

  before(:all) do
    requirement stemcell
    requirement release
  end

  after(:all) do
    cleanup release
    cleanup stemcell
  end

  before(:each) do
    load_deployment_spec
  end

  describe "managed properties" do
    context "with no property" do

      it "should not return a value" do
        with_deployment do
          expect {
            bosh("get property doesntexist")
          }.to raise_error { |error|
            error.should be_a Bosh::Exec::Error
            error.output.should match /Error 110003/
          }
        end
      end

      it "should set a property" do
        with_deployment do
          result = bosh("set property newprop something")
          result.output.should match /This will be a new property/
          result.output.should match /Property `newprop' set to `something'/
        end
      end

    end

    context "with existing property" do

      it "should set a property" do
        with_deployment do
          bosh("set property prop1 value1")
          result = bosh("set property prop1 value2")
          result.output.should match /Current `prop1' value is `value1'/
          result.output.should match /Property `prop1' set to `value2'/
        end
      end

      it "should get a value" do
        with_deployment do
          bosh("set property prop2 value3")
          bosh("get property prop2").should succeed_with /Property `prop2' value is `value3'/
        end
      end

    end
  end

  describe "template properties" do
    it "should fail to deploy when a property isn't set" do
      use_missing_property
      with_deployment do |deployment|
        bosh("deployment #{deployment.to_path}").should succeed
        result = bosh("deploy", :on_error => :return)
        result.should_not succeed
        result.output.should match(/Error 80006:.*batlight.missing/)
      end
    end

    it "should render correct properties", :focus => true do
      use_static_ip
      with_deployment do
        props = "/var/vcap/jobs/batlight/config/properties"
        expected = "required\ntrue\n\nboth\n\nnope\n"
        ssh(static_ip, "vcap", password, "cat #{props}").should == expected
      end
    end
  end
end
