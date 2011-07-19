require 'spec_helper'
require 'micro/identity'

describe VCAP::Micro::Identity do

  def fake_response
    resp = {}
    resp["email"] = "foo@bar.com"
    resp["name"] = "foo"
    resp["cloud"] = "bar.com"
    resp["token"] = "foobar"
    resp
  end

  describe "rest resource" do
    it "should not include auth header when config file is missing" do
      i = VCAP::Micro::Identity.new("spec/assets/missing.yml")
      i.resource.headers.should include(:content_type => 'application/json')
      i.resource.headers.should_not include('Auth-Token' => 'foobar')
    end

    it "should include auth header when present in the config file" do
      i = VCAP::Micro::Identity.new("spec/assets/config.json")
      i.resource.headers.should include('Auth-Token' => 'foobar')
    end
  end

  it "should parse result from install" do
    i = VCAP::Micro::Identity.new
    i.proxy = ""
    resp = fake_response
    i.should_receive(:auth).exactly(1).times.and_return(resp)
    i.should_receive(:update_dns).exactly(1).times
    i.install("1.2.3.4")
    i.ip.should == "1.2.3.4"
    i.admins.should include("foo@bar.com")
    i.subdomain.should == "foo.bar.com"
  end

  it "should set a nonce" do
    i = VCAP::Micro::Identity.new
    i.nonce = "foobar"
    i.nonce.should == "foobar"
  end
end