require 'spec_helper'
require 'timecop'

describe Bosh::Director::Api::EventManager do
  let(:manager) { described_class.new(true) }

  describe '#store_event' do
    it 'should create a new event model' do
      expect {
        manager.create_event({:user => 'user', :action => 'action', :object_type => 'deployment', :object_name => 'dep'})
      }.to change {
        Bosh::Director::Models::Event.count
      }.from(0).to(1)
    end

    it 'should take care about duplicates' do
      expect {
        Timecop.freeze do
          2.times do
            manager.create_event({:user => 'user', :action => 'action', :object_type => 'deployment', :object_name => 'dep'})
          end
        end
      }.not_to raise_error
      expect(Bosh::Director::Models::Event.count).to eq(2)
    end

    it 'should not be deadlocked' do
      expect {
        Timecop.freeze do
          3.times do
            manager.create_event({:user => 'user', :action => 'action', :object_type => 'deployment', :object_name => 'dep'})
          end
        end
      }.to raise_error
    end
  end

  describe '#event_to_hash' do
    it 'should not pass values are equal to nil' do
      Bosh::Director::Models::Event.make(
          'user' => 'test',
          'action' => 'create',
          'object_type' => 'deployment',
          'object_name' => 'depl1',
          'error' => nil,
          'task' => nil,
          'deployment' => nil,
          'instance' => nil,
          'parent_id' => nil
      )
      expect(manager.event_to_hash(Bosh::Director::Models::Event.first)).not_to include('error', 'task', 'deployment', 'instance', 'parent_id')
    end

    it 'should pass ids as String' do
      Bosh::Director::Models::Event.make(
          'parent_id' => Time.new,
          'user' => 'test',
          'action' => 'create',
          'object_type' => 'deployment',
          'object_name' => 'depl1',
      )
      expect(manager.event_to_hash(Bosh::Director::Models::Event.first)).to include('id' => String, 'parent_id' => String)
    end
  end

  describe '#remove_old_events' do
    def make_n_events(num_events)
      num_events.times do |i|
        Bosh::Director::Models::Event.make
      end
    end

    context 'when there are fewer than `max_events` events in the database' do
      before {
        make_n_events(2)
      }

      it 'keeps all events in the database' do
        expect {
          manager.remove_old_events
        }.not_to change {
          Bosh::Director::Models::Event.count
        }
      end
    end

    context 'when there are exactly `max_events` events in the database' do
      before {
        make_n_events(3)
      }

      it 'keeps all events in the database' do
        expect {
          manager.remove_old_events(3)
        }.not_to change {
          Bosh::Director::Models::Event.count
        }
      end
    end

    context 'when there is one more than `max_events` events in the database' do
      before {
        make_n_events(4)
      }

      it 'keeps the latest `max_events` events in the database' do
        expect {
          manager.remove_old_events(3)
        }.to change {
          Bosh::Director::Models::Event.filter.count
        }.from(4).to(3)
      end
    end

    context 'when there are 10 more than `max_events` events in the database' do
      before {
        make_n_events(13)
      }

      it 'keeps the latest `max_events` events in the database' do
        expect {
          manager.remove_old_events(3)
        }.to change {
          Bosh::Director::Models::Event.filter.count
        }.from(13).to(3)
      end
    end

    context 'when there is `parent_id` from dataset to remove' do
      before {
        make_n_events(10)
        Bosh::Director::Models::Event.make(parent_id: Time.at(Bosh::Director::Models::Event.all[5].id), action: 'action', object_type: 'type')
        Bosh::Director::Models::Event.make(parent_id: Time.at(Bosh::Director::Models::Event.all[3].id), action: 'action', object_type: 'type')
        make_n_events(2)
      }

      it 'keeps the events started from `parent_id` in the database' do
        first_id = Bosh::Director::Models::Event.all[3].id
        expect {
          manager.remove_old_events(4)
        }.to change {
          Bosh::Director::Models::Event.count
        }.from(14).to(11)
        expect(Bosh::Director::Models::Event.order { Sequel.asc(:id) }.first.id).to eq(first_id)
      end
    end
  end
end
