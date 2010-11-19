require File.dirname(__FILE__) + '/../spec_helper'

describe Bosh::Director::Lock do

  it "should acquire a lock" do
    redis = mock("redis")
    Bosh::Director::Config.stub!(:redis).and_return(redis)

    started = Time.now.to_f

    stored_value = nil
    redis.should_receive(:setnx).with("foo", anything).and_return do |_, value|
      stored_value = value
      timestamp = stored_value.split(":")[0].to_f
      timestamp.should be_within(started + 10).of(2.0)
    end

    redis.should_receive(:watch).with("foo").any_number_of_times
    redis.should_receive(:multi).any_number_of_times.and_yield

    redis.stub!(:get).with("foo").and_return do
      stored_value
    end

    redis.stub!(:set).with("foo", anything()) do |_, value|
      stored_value = value
    end

    redis.should_receive(:del).with("foo").and_return do
      stored_value = nil
      nil
    end

    lock = Bosh::Director::Lock.new("foo")

    ran_once = false
    lock.lock do
      ran_once = true
    end

    ran_once.should be_true
  end

  it "should not let two clients to acquire the same lock at the same time" do
    redis = mock("redis")
    Bosh::Director::Config.stub!(:redis).and_return(redis)

    stored_value = nil
    redis.should_receive(:setnx).with("foo", anything).any_number_of_times.and_return do |_, value|
      timestamp = value.split(":")[0].to_f
      timestamp.should be_within(Time.now.to_f + 10).of(2.0)
      if stored_value.nil?
        stored_value = value
        true
      else
        false
      end
    end

    redis.should_receive(:watch).with("foo").any_number_of_times
    redis.should_receive(:multi).any_number_of_times.and_yield

    redis.should_receive(:get).with("foo").any_number_of_times.and_return do
      stored_value
    end

    redis.should_receive(:set).with("foo", anything()) do |_, value|
      stored_value = value
    end
    
    redis.should_receive(:del).with("foo").and_return do
      stored_value = nil
      nil
    end

    lock_a = Bosh::Director::Lock.new("foo")
    lock_b = Bosh::Director::Lock.new("foo")

    ran_once = false
    lock_a.lock do
      ran_once = true
      lambda {lock_b.lock {}}.should raise_exception(Bosh::Director::Lock::TimeoutError)
    end

    ran_once.should be_true
  end

end
