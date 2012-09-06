# Copyright (c) 2012 VMware, Inc.

require "spec_helper"
require "common/properties"

describe Bosh::Common::PropertyHelper do

  before(:each) do
    @helper = Object.new
    @helper.extend(Bosh::Common::PropertyHelper)
  end

  it "can copy named property from one collection to another" do
    dst = {}
    src = {"foo" => {"bar" => "baz", "secret" => "zazzle"}}

    @helper.copy_property(dst, src, "foo.bar")
    dst.should == {"foo" => {"bar" => "baz"}}

    @helper.copy_property(dst, src, "no.such.prop", "default")
    dst.should == {
      "foo" => {"bar" => "baz"},
      "no" => {
        "such" => {"prop" => "default"}
      }
    }
  end

  it "can lookup the property in a Hash using dot-syntax" do
    properties = {
      "foo" => {"bar" => "baz"},
      "router" => {"token" => "foo"}
    }

    @helper.lookup_property(properties, "foo.bar").should == "baz"
    @helper.lookup_property(properties, "router").should == {"token" => "foo"}
    @helper.lookup_property(properties, "no.prop").should be_nil
  end
end
