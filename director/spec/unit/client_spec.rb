require File.dirname(__FILE__) + '/../spec_helper'

describe Bosh::Director::Client do

  it "should send messages and return values" do
    redis = mock("redis")
    pubsub_redis = mock("pubsub_redis")

    Bosh::Director::Config.stub!(:redis).and_return(redis)
    Bosh::Director::Config.stub!(:pubsub_redis).and_return(pubsub_redis)

    pubsub_callback = nil
    pubsub_redis.should_receive(:subscribe).and_return do |*args|
      pubsub_callback = args[1]
      Thread.new {pubsub_callback.call(:subscribe)}
    end

    pubsub_redis.should_receive(:unsubscribe)

    redis.should_receive(:publish).and_return do
      Thread.new {pubsub_callback.call(:message, Yajl::Encoder.encode({:value => 5}))}
    end

    @client = Bosh::Director::Client.new("test_service", "test_service_id")
    @client.test_method("arg 1", 2, {:test =>"blah"}).should eql(5)
  end

  it "should handle exceptions" do
    redis = mock("redis")
    pubsub_redis = mock("pubsub_redis")

    Bosh::Director::Config.stub!(:redis).and_return(redis)
    Bosh::Director::Config.stub!(:pubsub_redis).and_return(pubsub_redis)

    pubsub_callback = nil
    pubsub_redis.should_receive(:subscribe).and_return do |*args|
      pubsub_callback = args[1]
      Thread.new {pubsub_callback.call(:subscribe)}
    end

    pubsub_redis.should_receive(:unsubscribe)

    redis.should_receive(:publish).and_return do
      Thread.new {pubsub_callback.call(:message, Yajl::Encoder.encode({:exception => "test"}))}
    end

    @client = Bosh::Director::Client.new("test_service", "test_service_id")
    lambda {@client.test_method("arg 1", 2, {:test =>"blah"})}.should raise_exception(RuntimeError, "test")
  end

  it "should handle timeouts" do
    redis = mock("redis")
    pubsub_redis = mock("pubsub_redis")

    Bosh::Director::Config.stub!(:redis).and_return(redis)
    Bosh::Director::Config.stub!(:pubsub_redis).and_return(pubsub_redis)

    pubsub_redis.should_receive(:subscribe).and_return do |*args|
      pubsub_callback = args[1]
      Thread.new {pubsub_callback.call(:subscribe)}
    end

    pubsub_redis.should_receive(:unsubscribe)

    redis.should_receive(:publish)

    @client = Bosh::Director::Client.new("test_service", "test_service_id", :timeout => 0.1)
    lambda {
      @client.test_method("arg 1", 2, {:test =>"blah"})
    }.should raise_exception(Bosh::Director::Client::TimeoutException)
  end

end
