require 'spec_helper'

module Bosh::Director
  describe Lock, truncation: true, :if => ENV.fetch('DB', 'sqlite') != 'sqlite' do
    let!(:task) { Models::Task.make(state: 'processing') }
    before do
      allow(Config).to receive_message_chain(:current_job, :username).and_return('current-user')
      allow(Config).to receive_message_chain(:current_job, :task_id).and_return(task.id)
    end

    it 'should acquire a lock' do
      lock = Lock.new('foo')

      ran_once = false
      lock.lock do
        ran_once = true
      end

      expect(ran_once).to be(true)
    end

    it 'should not let two clients to acquire the same lock at the same time' do
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
      lock_a = Lock.new('foo', timeout: 0)
      lock_b = Lock.new('foo', timeout: 0)

      ran_once = false
      lock_a.lock do
        ran_once = true
        expect { lock_b.lock {} }.to raise_exception(Lock::TimeoutError)
      end

      expect(ran_once).to be(true)
    end

    describe 'event recordings' do
      before do
        allow(Config).to receive(:record_events).and_return(true)
      end

      context 'when a lock is acquired' do
        it 'should record an event' do
          lock = Lock.new('foo', deployment_name: 'my-deployment')

          expect { lock.lock {} }.to change {
            Models::Event.where(
                action: 'acquire', object_type: 'lock', object_name: 'foo', user: 'current-user', task: "#{task.id}", deployment: 'my-deployment'
            ).count
          }.from(0).to(1)
        end
      end

      context 'when a lock is released' do
        it 'should record an event' do
          lock = Lock.new('foo', deployment_name: 'my-deployment')

          expect { lock.lock {} }.to change {
            Models::Event.where(
                action: 'release', object_type: 'lock', object_name: 'foo', user: 'current-user', task: "#{task.id}", deployment: 'my-deployment'
            ).count
          }.from(0).to(1)
        end

        it 'should not update the state of the running task' do
          lock = Lock.new('foo', deployment_name: 'my-deployment')

          expect(Models::Task.where(state: 'processing').count).to eq 1
          expect(Models::Task.where(state: 'cancelling').count).to eq 0

          lock.lock {}

          expect(Models::Task.where(state: 'processing').count).to eq 1
          expect(Models::Task.where(state: 'cancelling').count).to eq 0
        end
      end

      context 'when a lock is lost' do
        it 'should record an event' do
          lock = Lock.new('foo', deployment_name: 'my-deployment', expiration: 1)

          Thread.new do
            until false
              x = Models::Lock.where(name: 'foo').delete
              sleep 0.1
              break if x > 0
            end
          end

          expect(Models::Event.where(action: 'lost').count).to eq 0

          lock.lock { sleep 2 }

          expect(Models::Event.where(
              action: 'lost', object_type: 'lock', object_name: 'foo', user: 'current-user', task: "#{task.id}", deployment: 'my-deployment'
          ).count).to eq 1
        end

        it 'should cancel the running task' do
          lock = Lock.new('foo', deployment_name: 'my-deployment', expiration: 1)

          Thread.new do
            until false
              x = Models::Lock.where(name: 'foo').delete
              sleep 0.1
              break if x > 0
            end
          end

          expect(Models::Task.where(state: 'cancelling').count).to eq 0

          lock.lock { sleep 2 }

          expect(Models::Task.where(state: 'cancelling').count).to eq 1
        end
      end
    end
  end
end