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

  describe "version matcher" do
    it "should return false for 1.0.0 and 1.0.0" do
      with_constants "VCAP::Micro::VERSION" => "1.0.0" do
        i = VCAP::Micro::Identity.new
        i.should_update?("1.0.0").should be_false
      end
    end

    it "should return false for 1.2 and 1.2.3" do
      with_constants "VCAP::Micro::VERSION" => "1.2" do
        i = VCAP::Micro::Identity.new
        i.should_update?("1.2.3").should be_false
      end
    end

    it "should return true for 1.3 and 1.2.4" do
      with_constants "VCAP::Micro::VERSION" => "1.3" do
        i = VCAP::Micro::Identity.new
        i.should_update?("1.2.4").should be_true
      end
    end

    it "should return false for 1.4 and 1.5.3_rc1" do
      with_constants "VCAP::Micro::VERSION" => "1.4" do
        i = VCAP::Micro::Identity.new
        i.should_update?("1.5.3_rc1").should be_false
      end
    end

    it "should return true for 1.2.6 and 1.2.5" do
      with_constants "VCAP::Micro::VERSION" => "1.2.6" do
        i = VCAP::Micro::Identity.new
        i.should_update?("1.2.5").should be_true
      end
    end

    it "should return true for 2.7 and 1.7.4" do
      with_constants "VCAP::Micro::VERSION" => "2.7" do
        i = VCAP::Micro::Identity.new
        i.should_update?("1.7.4").should be_true
      end
    end

  end
end