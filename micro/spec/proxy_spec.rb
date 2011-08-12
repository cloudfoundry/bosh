require 'spec_helper'
require 'micro/proxy'

describe VCAP::Micro::Proxy do

  URL = "http://proxy.vmware.com:3128"

  it "should load a saved proxy from file" do
    p = VCAP::Micro::Proxy.new("spec/assets/proxy.json")
    p.url.should == URL
  end

  it "should default to no proxy when there is no file present" do
    p = VCAP::Micro::Proxy.new
    p.url.should == ""
  end

  it "should validate the url of a new proxy" do
    p = VCAP::Micro::Proxy.new
    p.url = "asd"
    p.url.should be_nil
  end

  it "should accept 'none' for no proxy" do
    p = VCAP::Micro::Proxy.new
    p.url = "none"
    p.url.should == ""
  end

  it "should display 'none' when no proxy is set" do
    p = VCAP::Micro::Proxy.new
    p.url = "none"
    p.name.should == "none"
  end

  it "should accept a correct url as proxy" do
    p = VCAP::Micro::Proxy.new
    p.url = URL
    p.url.should == URL
  end

  it "should display 'none' when no proxy is set" do
    p = VCAP::Micro::Proxy.new
    p.name.should == "none"
  end

  it "should have the proxy url when set" do
    JSON = "tmp/proxy.json"
    p = VCAP::Micro::Proxy.new(JSON)
    p.url = URL
    p.save
    File.exist?(JSON).should be_true
  end
end
