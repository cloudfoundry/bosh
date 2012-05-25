# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::Director::Lock do

  it "should acquire a lock" do
    redis = mock("redis")
    Bosh::Director::Config.stub!(:redis).and_return(redis)

    started = Time.now.to_f

    stored_value = nil
    redis.should_receive(:setnx).with("foo", anything).and_return do |_, value|
      stored_value = value
      timestamp = stored_value.split(":")[0].to_f
      timestamp.should be_within(2.0).of(started + 10)
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
      timestamp.should be_within(2.0).of(Time.now.to_f + 10)
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
    lock_b = Bosh::Director::Lock.new("foo", :timeout => 0.1)

    ran_once = false
    lock_a.lock do
      ran_once = true
      lambda {lock_b.lock {}}.should raise_exception(Bosh::Director::Lock::TimeoutError)
    end

    ran_once.should be_true
  end

  it "should return immediately with lock busy if try lock fails to get lock" do
    redis = mock("redis")
    Bosh::Director::Config.stub!(:redis).and_return(redis)

    stored_value = nil
    redis.should_receive(:setnx).with("foo", anything).any_number_of_times.and_return do |_, value|
      timestamp = value.split(":")[0].to_f
      timestamp.should be_within(2.0).of(Time.now.to_f + 10)
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

    redis.should_receive(:del).with("foo").and_return do
      stored_value = nil
      nil
    end

    lock_a = Bosh::Director::Lock.new("foo")
    lock_b = Bosh::Director::Lock.new("foo")

    ran_once = false
    lock_a.try_lock do
      ran_once = true
      lambda {lock_b.try_lock {}}.should raise_exception(Bosh::Director::Lock::LockBusy)
    end

    ran_once.should be_true
  end

end
