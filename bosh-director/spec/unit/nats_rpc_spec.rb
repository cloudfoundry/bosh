# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::Director::NatsRpc do

  before(:each) do
    @nats = double("nats")
    Bosh::Director::Config.stub(:nats).and_return(@nats)
    Bosh::Director::Config.stub(:process_uuid).and_return(123)
    EM.stub(:next_tick).and_yield
  end

  describe "send_request" do

    it "should publish a message to the client" do
      @nats.should_receive(:subscribe).with("director.123.>")
      @nats.should_receive(:publish) do |subject, payload|
        subject.should eql("test_client")
        Yajl::Parser.parse(payload).
            should eql({"method" => "a", "arguments" => [5],
                        "reply_to" => "director.123.req1"})
      end

      nats_rpc = Bosh::Director::NatsRpc.new
      nats_rpc.stub(:generate_request_id).and_return("req1")
      nats_rpc.send_request("test_client",
                            {"method" => "a", "arguments" => [5]}).
          should eql("req1")
    end

    it "should fire callback when message is received" do
      subscribe_callback = nil
      @nats.should_receive(:subscribe).with("director.123.>").
          and_return do |&block|
        subscribe_callback = block
      end
      @nats.should_receive(:publish).and_return do
        subscribe_callback.call("", nil, "director.123.req1")
      end

      nats_rpc = Bosh::Director::NatsRpc.new
      nats_rpc.stub(:generate_request_id).and_return("req1")

      called = false
      nats_rpc.send_request("test_client",
                            {"method" => "a", "arguments" => [5]}) do
        called = true
      end

      called.should be(true)
    end

    it "should fire once even if two messages were received" do
      subscribe_callback = nil
      @nats.should_receive(:subscribe).with("director.123.>").
          and_return do |&block|
        subscribe_callback = block
      end
      @nats.should_receive(:publish).and_return do
        subscribe_callback.call("", nil, "director.123.req1")
        subscribe_callback.call("", nil, "director.123.req1")
      end

      nats_rpc = Bosh::Director::NatsRpc.new
      nats_rpc.stub(:generate_request_id).and_return("req1")

      called_times = 0
      nats_rpc.send_request("test_client",
                            {"method" => "a", "arguments" => [5]}) do
        called_times += 1
      end
      called_times.should eql(1)
    end

  end

  describe "cancel_request" do

    it "should not fire after cancel was called" do
      subscribe_callback = nil
      @nats.should_receive(:subscribe).with("director.123.>").
          and_return do |&block|
        subscribe_callback = block
      end
      @nats.should_receive(:publish)

      nats_rpc = Bosh::Director::NatsRpc.new
      nats_rpc.stub(:generate_request_id).and_return("req1")

      called = false
      request_id = nats_rpc.send_request("test_client",
                                         {"method" => "a",
                                          "arguments" => [5]}) do
        called = true
      end

      request_id.should eql("req1")
      nats_rpc.cancel_request("req1")
      subscribe_callback.call("", nil, "director.123.req1")
      called.should be(false)
    end

  end

end
