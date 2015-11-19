# Copyright (c) 2009-2012 VMware, Inc.

require 'spec_helper'

module Bosh::Director
  describe Lock do

    let(:db_lock) { instance_double('Bosh::Director::Models::Lock', name: 'foo', uid: 'fake-uid', expired_at: Time.now + 60) }

    before(:each) do
      allow(Models::Lock).to receive(:for_update).and_return(Models::Lock)
      allow(Models::Lock).to receive(:create).and_return(db_lock)

    end

    it 'should acquire a lock' do
      allow(Models::Lock).to receive(:[]).and_return(nil)
      lock = Lock.new('foo')

      ran_once = false
      lock.lock do
        ran_once = true
      end

      expect(ran_once).to be(true)
    end

    it 'should not let two clients to acquire the same lock at the same time' do
      allow(Models::Lock).to receive(:[]).and_return(nil, db_lock)

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
      allow(Models::Lock).to receive(:[]).and_return(nil, db_lock)

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
