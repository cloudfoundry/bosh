require 'spec_helper'
require 'micro/proxy'
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

  before(:all) do
    @proxy = VCAP::Micro::Proxy.new
  end

  describe "rest resource" do
    it "should not include auth header when config file is missing" do
      VCAP::Micro::Console.stub(:logger)
      i = VCAP::Micro::Identity.new(@proxy, "spec/assets/missing.yml")
      i.resource.headers.should include(:content_type => 'application/json')
      i.resource.headers.should_not include('Auth-Token' => 'foobar')
    end

    it "should include auth header when present in the config file" do
      VCAP::Micro::Console.stub(:logger)
      i = VCAP::Micro::Identity.new(@proxy, "spec/assets/config.json")
      i.resource.headers.should include('Auth-Token' => 'foobar')
    end
  end

  it "should parse result from install" do
    with_constants "VCAP::Micro::Identity::MICRO_CONFIG" => "spec/assets/config.json" do
      VCAP::Micro::Console.stub(:logger)
      i = VCAP::Micro::Identity.new(@proxy)
      resp = fake_response
      i.should_receive(:update_dns).exactly(1).times
      i.install("1.2.3.4")
      i.ip.should == "1.2.3.4"
      i.admins.should include("foo@bar.com")
      i.subdomain.should == "foo.bar.com"
    end
  end

  it "should set a nonce" do
    VCAP::Micro::Console.stub(:logger)
    i = VCAP::Micro::Identity.new(@proxy)
    i.nonce = "foobar"
    i.nonce.should == "foobar"
  end

  it "should generate the correct default url" do
    VCAP::Micro::Console.stub(:logger)
    i = VCAP::Micro::Identity.new(@proxy)
    i.url.should == "https://mcapi.cloudfoundry.com/api/v1/micro"
  end

  it "should have a proxy accessor" do
    VCAP::Micro::Console.stub(:logger)
    i = VCAP::Micro::Identity.new(@proxy)
    i.proxy.should == @proxy
  end

  it "should set correct values for offline mode" do
    logger = double(:logger)
    logger.should_receive(:info)
    logger = VCAP::Micro::Console.should_receive(:logger).and_return(logger)
    i = VCAP::Micro::Identity.new(@proxy)
    i.offline('1.2.3.4', 'foo.bar.com', 'admin@bar.com')
    i.name.should == 'foo'
    i.cloud.should == 'bar.com'
    i.ip.should == '1.2.3.4'
  end
end