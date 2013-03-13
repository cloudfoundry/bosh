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

  it "should return the default value if the value not found in src" do
    dst = {}
    src = {}
    @helper.copy_property(dst, src, "foo.bar", "foobar")
    dst.should == {"foo" => {"bar" => "foobar"}}
  end

  it "should return the 'false' value when parsing a boolean false value" do
    dst = {}
    src = {"foo" => {"bar" => false}}
    @helper.copy_property(dst, src, "foo.bar", true)
    dst.should == {"foo" => {"bar" => false}}
  end

  it "should get a nil when value not found in src and no default value specified " do
    dst = {}
    src = {}
    @helper.copy_property(dst, src, "foo.bar")
    dst.should == {"foo" => {"bar" => nil}}
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
