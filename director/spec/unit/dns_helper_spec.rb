# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::Director::DnsHelper do
  include Bosh::Director::DnsHelper

  describe :canonical do

    it "should be lowercase" do
      canonical("HelloWorld").should == "helloworld"
    end

    it "should convert underscores to hyphens" do
      canonical("hello_world").should == "hello-world"
    end

    it "should strip any non alpha numeric characters" do
      canonical("hello^world").should == "helloworld"
    end

    it "should reject strings that don't start with a letter " +
       "or end with a letter/number" do
      lambda {
        canonical("-helloworld")
      }.should raise_error(
                 BD::DnsInvalidCanonicalName,
                 "Invalid DNS canonical name `-helloworld', " +
                 "must begin with a letter")

      lambda {
        canonical("helloworld-")
      }.should raise_error(
                 BD::DnsInvalidCanonicalName,
                 "Invalid DNS canonical name `helloworld-', " +
                 "can't end with a hyphen")
    end

  end

end