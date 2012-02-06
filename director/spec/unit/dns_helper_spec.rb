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

    it "should reject strings that don't start with a letter or end with a letter/number" do
      canonical("hello_world").should == "hello-world"
      canonical("hello_world").should == "hello-world"
    end

  end

end