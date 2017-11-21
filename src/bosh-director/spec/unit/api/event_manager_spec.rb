require 'spec_helper'

describe Bosh::Director::Api::EventManager do
  let(:manager) { described_class.new(true) }

  describe '#create_event' do

    context 'record_events is true' do
      it 'should create a new event model' do
        expect {
          manager.create_event({:user => 'user', :action => 'action', :object_type => 'deployment', :object_name => 'dep'})
        }.to change {
          Bosh::Director::Models::Event.count
        }.from(0).to(1)
      end

      it 'allows to save specified timestamp' do
        manager.create_event({:user => 'user', :action => 'action', :object_type => 'deployment', :object_name => 'dep', :timestamp => Time.at(1479673560)})
        expect( Bosh::Director::Models::Event.first.timestamp.to_i).to eq(1479673560)
      end

      it 'should write event to syslog' do
        pending("Syslog::Logger does not exist in ruby version '#{RUBY_VERSION}'") if RUBY_VERSION.to_i < 2

        syslog = instance_double(Syslog::Logger)
        allow(Syslog::Logger).to receive(:new).with('vcap.bosh.director').and_return(syslog)
        allow(syslog).to receive(:info)

        event = manager.create_event({:user => 'user', :action => 'action', :object_type => 'deployment'})

        expect(syslog).to have_received(:info).with(JSON.generate(event.to_hash))
      end
    end

    context 'record_events is false' do
      let(:manager) { described_class.new(false) }

      it 'should not create a new event model' do
        expect {
          manager.create_event({:user => 'user', :action => 'action', :object_type => 'deployment', :object_name => 'dep'})
        }.to_not change {
          Bosh::Director::Models::Event.count
        }
      end

      it 'should not write event to syslog' do
        pending("Syslog::Logger does not exist in ruby version '#{RUBY_VERSION}'") if RUBY_VERSION.to_i < 2

        syslog = instance_double(Syslog::Logger)
        allow(Syslog::Logger).to receive(:new).with('vcap.bosh.director').and_return(syslog)
        allow(syslog).to receive(:info)

        manager.create_event({:user => 'user', :action => 'action', :object_type => 'deployment'})

        expect(syslog).to_not have_received(:info)
      end

      it 'returns an empty event' do
        event = manager.create_event({:user => 'user', :action => 'action', :object_type => 'deployment'})

        expect(event).to eq(Bosh::Director::Models::Event.new)
      end
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
          'parent_id' => 2,
          'user' => 'test',
          'action' => 'create',
          'object_type' => 'deployment',
          'object_name' => 'depl1',
      )
      expect(manager.event_to_hash(Bosh::Director::Models::Event.first)).to include('id' => '1', 'parent_id' => '2')
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
          Bosh::Director::Models::Event.count
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
          Bosh::Director::Models::Event.count
        }.from(13).to(3)
      end

      it 'does not duplicate ids (no reuse of deleted ids)' do
        manager.remove_old_events(3)
        manager.create_event({:user => 'user', :action => 'action', :object_type => 'deployment', :object_name => 'dep'})
        expect(Bosh::Director::Models::Event.order{Sequel.asc(:id)}.last.id).to eq(14)
      end
    end

    context 'when there is `parent_id` from dataset to remove' do
      before {
        make_n_events(10)
        Bosh::Director::Models::Event.make(parent_id: 5, action: 'action', object_type: 'type')
        make_n_events(2)
      }

      it 'keeps the events started from `parent_id` in the database' do
        expect {
          manager.remove_old_events(3)
        }.to change {
          Bosh::Director::Models::Event.count
        }.from(13).to(9)
        expect(Bosh::Director::Models::Event.order{Sequel.desc(:id)}.last.id).to eq(5)
      end
    end
  end
end
