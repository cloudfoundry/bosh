require File.dirname(__FILE__) + '/../spec_helper'

describe Bosh::Director::Client do

  it "should send messages and return values" do
    nats_rpc = mock("nats_rpc")

    Bosh::Director::Config.stub!(:nats_rpc).and_return(nats_rpc)

    nats_rpc.should_receive(:send).with("test_service.test_service_id",
        {:arguments=>["arg 1", 2, {:test=>"blah"}], :method=>:test_method}
    ).and_return { |*args|
      callback = args[2]
      callback.call({"value" => 5})
      "3"
    }

    @client = Bosh::Director::Client.new("test_service", "test_service_id")
    @client.test_method("arg 1", 2, {:test =>"blah"}).should eql(5)
  end

  it "should handle exceptions" do
    nats_rpc = mock("nats_rpc")

    Bosh::Director::Config.stub!(:nats_rpc).and_return(nats_rpc)

    nats_rpc.should_receive(:send).with("test_service.test_service_id",
        {:arguments=>["arg 1", 2, {:test=>"blah"}], :method=>:test_method}
    ).and_return { |*args|
      callback = args[2]
      callback.call({"exception" => "test"})
      "3"
    }

    @client = Bosh::Director::Client.new("test_service", "test_service_id")
    lambda {@client.test_method("arg 1", 2, {:test =>"blah"})}.should raise_exception(RuntimeError, "test")
  end

  it "should handle timeouts" do
    nats_rpc = mock("nats_rpc")

    Bosh::Director::Config.stub!(:nats_rpc).and_return(nats_rpc)

    nats_rpc.should_receive(:send).with("test_service.test_service_id",
        {:arguments=>["arg 1", 2, {:test=>"blah"}], :method=>:test_method}
    ).and_return("4")

    nats_rpc.should_receive(:cancel).with("4")

    @client = Bosh::Director::Client.new("test_service", "test_service_id", :timeout => 0.1)
    lambda {
      @client.test_method("arg 1", 2, {:test =>"blah"})
    }.should raise_exception(Bosh::Director::Client::TimeoutException)
  end

  it "should let you wait for the server to be ready" do
    nats_rpc = mock("nats_rpc")

    Bosh::Director::Config.stub!(:nats_rpc).and_return(nats_rpc)

    @client = Bosh::Director::Client.new("test_service", "test_service_id", :timeout => 0.1)
    @client.should_receive(:ping).and_raise(Bosh::Director::Client::TimeoutException)
    @client.should_receive(:ping).and_raise(Bosh::Director::Client::TimeoutException)
    @client.should_receive(:ping).and_raise(Bosh::Director::Client::TimeoutException)
    @client.should_receive(:ping).and_return(true)
    @client.wait_until_ready
  end

end
