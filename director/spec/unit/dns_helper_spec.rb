# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::Director::DnsHelper do
  include Bosh::Director::ValidationHelper
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

  describe :dns_servers do
    it "should return nil when there are no DNS servers" do
      dns_servers('network', {}).should be_nil
    end

    it "should return an array of DNS servers" do
      dns_servers('network', {"dns" => %w[1.2.3.4 5.6.7.8]}).should ==
          %w[1.2.3.4 5.6.7.8]
    end

    it "should raise an error if a DNS server isn't specified with as an IP" do
      lambda {
        dns_servers('network', {"dns" => %w[1.2.3.4 foo.bar]})
      }.should raise_error
    end
  end
end