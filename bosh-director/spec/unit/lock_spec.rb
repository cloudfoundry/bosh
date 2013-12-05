# Copyright (c) 2009-2012 VMware, Inc.

require 'spec_helper'

module Bosh::Director
  describe Lock do
    it 'should acquire a lock' do
      redis = double('redis')
      Config.stub(:redis).and_return(redis)

      started = Time.now.to_f

      stored_value = nil
      redis.should_receive(:setnx).with('foo', anything).and_return do |_, value|
        stored_value = value
        timestamp = stored_value.split(':')[0].to_f
        timestamp.should be_within(2.0).of(started + 10)
      end

      redis.stub(:watch).with('foo')
      redis.stub(:multi).and_yield

      redis.stub(:get).with('foo').and_return do
        stored_value
      end

      redis.stub(:set).with('foo', anything()) do |_, value|
        stored_value = value
      end

      redis.should_receive(:del).with('foo').and_return do
        stored_value = nil
        nil
      end

      lock = Lock.new('foo')

      ran_once = false
      lock.lock do
        ran_once = true
      end

      ran_once.should be(true)
    end

    it 'should not let two clients to acquire the same lock at the same time' do
      redis = double('redis')
      Config.stub(:redis).and_return(redis)

      stored_value = nil
      redis.stub(:setnx).with('foo', anything).
        and_return do |_, value|
        timestamp = value.split(':')[0].to_f
        timestamp.should be_within(2.0).of(Time.now.to_f + 10)
        if stored_value.nil?
          stored_value = value
          true
        else
          false
        end
      end

      redis.stub(:watch).with('foo')
      redis.stub(:multi).and_yield

      redis.stub(:get).with('foo').and_return { stored_value }

      redis.should_receive(:set).with('foo', anything()) do |_, value|
        stored_value = value
      end

      redis.should_receive(:del).with('foo').and_return do
        stored_value = nil
        nil
      end

      lock_a = Lock.new('foo')
      lock_b = Lock.new('foo', timeout: 0.1)

      ran_once = false
      lock_a.lock do
        ran_once = true
        lambda { lock_b.lock {} }.should raise_exception(Lock::TimeoutError)
      end

      ran_once.should be(true)
    end

    it 'should return immediately with lock busy if try lock fails to get lock' do
      redis = double('redis')
      Config.stub(:redis).and_return(redis)

      stored_value = nil
      redis.stub(:setnx).with('foo', anything).
        and_return do |_, value|
        timestamp = value.split(':')[0].to_f
        timestamp.should be_within(2.0).of(Time.now.to_f + 10)
        if stored_value.nil?
          stored_value = value
          true
        else
          false
        end
      end

      redis.stub(:watch).with('foo')
      redis.stub(:multi).and_yield

      redis.stub(:get).with('foo').and_return do
        stored_value
      end

      redis.should_receive(:del).with('foo').and_return do
        stored_value = nil
        nil
      end

      lock_a = Lock.new('foo', timeout: 0)
      lock_b = Lock.new('foo', timeout: 0)

      ran_once = false
      lock_a.lock do
        ran_once = true
        lambda { lock_b.lock {} }.should raise_exception(Lock::TimeoutError)
      end

      ran_once.should be(true)
    end
  end
end
