# Copyright (c) 2009-2012 VMware, Inc.

require 'spec_helper'

module Bosh::Director
  describe Lock do
    it 'should acquire a lock' do
      redis = double('redis')
      allow(Config).to receive(:redis).and_return(redis)

      started = Time.now.to_f

      stored_value = nil
      expect(redis).to receive(:setnx).with('foo', anything) do |_, value|
        stored_value = value
        timestamp = stored_value.split(':')[0].to_f
        expect(timestamp).to be_within(2.0).of(started + 10)
      end

      allow(redis).to receive(:watch).with('foo')
      allow(redis).to receive(:multi).and_yield

      allow(redis).to receive(:get).with('foo') { stored_value }

      allow(redis).to receive(:set).with('foo', anything()) do |_, value|
        stored_value = value
      end

      expect(redis).to receive(:del).with('foo') do
        stored_value = nil
        nil
      end

      lock = Lock.new('foo')

      ran_once = false
      lock.lock do
        ran_once = true
      end

      expect(ran_once).to be(true)
    end

    it 'should not let two clients to acquire the same lock at the same time' do
      redis = double('redis')
      allow(Config).to receive(:redis).and_return(redis)

      stored_value = nil
      allow(redis).to receive(:setnx).with('foo', anything) do |_, value|
        timestamp = value.split(':')[0].to_f
        expect(timestamp).to be_within(2.0).of(Time.now.to_f + 10)
        if stored_value.nil?
          stored_value = value
          true
        else
          false
        end
      end

      allow(redis).to receive(:watch).with('foo')
      allow(redis).to receive(:get).with('foo') { stored_value }
      allow(redis).to receive(:multi).and_yield

      # set is only called on lock renew, which might not execute
      allow(redis).to receive(:set).with('foo', anything)

      # del is always called to release the lock after the lock block runs
      expect(redis).to receive(:del).with('foo')

      lock_a = Lock.new('foo')
      lock_b = Lock.new('foo', timeout: 0.1)

      lock_a_block_run = false
      lock_b_block_run = false
      lock_a.lock do
        lock_a_block_run = true
        expect do
          lock_b.lock { lock_b_block_run = true }
        end.to raise_exception(Lock::TimeoutError)
      end

      expect(lock_a_block_run).to be(true)
      expect(lock_b_block_run).to be(false)
    end

    it 'should return immediately with lock busy if try lock fails to get lock' do
      redis = double('redis')
      allow(Config).to receive(:redis).and_return(redis)

      stored_value = nil
      allow(redis).to receive(:setnx).with('foo', anything) do |_, value|
        timestamp = value.split(':')[0].to_f
        expect(timestamp).to be_within(2.0).of(Time.now.to_f + 10)
        if stored_value.nil?
          stored_value = value
          true
        else
          false
        end
      end

      allow(redis).to receive(:watch).with('foo')
      allow(redis).to receive(:multi).and_yield

      allow(redis).to receive(:get).with('foo') { stored_value }

      expect(redis).to receive(:del).with('foo')

      lock_a = Lock.new('foo', timeout: 0)
      lock_b = Lock.new('foo', timeout: 0)

      ran_once = false
      lock_a.lock do
        ran_once = true
        expect { lock_b.lock {} }.to raise_exception(Lock::TimeoutError)
      end

      expect(ran_once).to be(true)
    end
  end
end
