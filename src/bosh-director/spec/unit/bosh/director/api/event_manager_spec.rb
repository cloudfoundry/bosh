require 'spec_helper'

describe Bosh::Director::Api::EventManager do
  let(:manager) { described_class.new(true) }

  describe '#create_event' do
    let(:audit_logger) { instance_double(Bosh::Director::AuditLogger) }

    before do
      allow(Bosh::Director::AuditLogger).to receive(:instance).and_return(audit_logger)
      allow(audit_logger).to receive(:info)
    end

    context 'record_events is true' do
      it 'should create a new event model' do
        expect do
          manager.create_event(user: 'user', action: 'action', object_type: 'deployment', object_name: 'dep')
        end.to change { Bosh::Director::Models::Event.count }.from(0).to(1)
      end

      it 'allows to save specified timestamp' do
        manager.create_event(
          user: 'user',
          action: 'action',
          object_type: 'deployment',
          object_name: 'dep',
          timestamp: Time.at(1479673560),
        )
        expect(Bosh::Director::Models::Event.first.timestamp.to_i).to eq(1479673560)
      end

      it 'should write event to audit logger' do
        event = manager.create_event(user: 'user', action: 'action', object_type: 'deployment')

        expect(audit_logger).to have_received(:info).with(JSON.generate(event.to_hash))
      end
    end

    context 'record_events is false' do
      let(:manager) { described_class.new(false) }

      it 'should not create a new event model' do
        expect do
          manager.create_event(user: 'user', action: 'action', object_type: 'deployment', object_name: 'dep')
        end.to_not change { Bosh::Director::Models::Event.count }
      end

      it 'should not write event to audit logger' do
        manager.create_event(user: 'user', action: 'action', object_type: 'deployment')

        expect(audit_logger).to_not have_received(:info)
      end

      it 'returns an empty event' do
        event = manager.create_event(user: 'user', action: 'action', object_type: 'deployment')

        expect(event).to eq(Bosh::Director::Models::Event.new)
      end
    end
  end

  describe '#event_to_hash' do
    it 'should not pass values are equal to nil' do
      FactoryBot.create(:models_event,
        'user' => 'test',
        'action' => 'create',
        'object_type' => 'deployment',
        'object_name' => 'depl1',
        'error' => nil,
        'task' => nil,
        'deployment' => nil,
        'instance' => nil,
        'parent_id' => nil,
      )
      expect(manager.event_to_hash(Bosh::Director::Models::Event.first))
        .not_to include('error', 'task', 'deployment', 'instance', 'parent_id')
    end

    it 'should pass ids as String' do
      event = FactoryBot.create(:models_event,
        'parent_id' => 2,
        'user' => 'test',
        'action' => 'create',
        'object_type' => 'deployment',
        'object_name' => 'depl1',
      )
      expect(manager.event_to_hash(Bosh::Director::Models::Event.first)).to include('id' => event.id.to_s, 'parent_id' => '2')
    end
  end

  describe '#remove_old_events' do
    def make_n_events(num_events)
      num_events.times do |_i|
        FactoryBot.create(:models_event)
      end
    end

    context 'when there are fewer than `max_events` events in the database' do
      before do
        make_n_events(2)
      end

      it 'keeps all events in the database' do
        expect do
          manager.remove_old_events
        end.not_to change { Bosh::Director::Models::Event.count }
      end
    end

    context 'when there are exactly `max_events` events in the database' do
      before do
        make_n_events(3)
      end

      it 'keeps all events in the database' do
        expect do
          manager.remove_old_events(3)
        end.not_to change { Bosh::Director::Models::Event.count }
      end
    end

    context 'when there is one more than `max_events` events in the database' do
      before do
        make_n_events(4)
      end

      it 'keeps the latest `max_events` events in the database' do
        expect do
          manager.remove_old_events(3)
        end.to change {
          Bosh::Director::Models::Event.count
        }.from(4).to(3)
      end
    end

    context 'when there are 10 more than `max_events` events in the database' do
      before do
        make_n_events(13)
      end

      it 'keeps the latest `max_events` events in the database' do
        expect do
          manager.remove_old_events(3)
        end.to change {
          Bosh::Director::Models::Event.count
        }.from(13).to(3)
      end

      it 'does not duplicate ids (no reuse of deleted ids)' do
        manager.remove_old_events(3)
        previous_id = Bosh::Director::Models::Event.order { Sequel.asc(:id) }.last.id
        manager.create_event(user: 'user', action: 'action', object_type: 'deployment', object_name: 'dep')
        expect(Bosh::Director::Models::Event.order { Sequel.asc(:id) }.last.id).to be > previous_id
      end
    end

    context 'when there is `parent_id` from dataset to remove' do
      let(:parent_id) { Bosh::Director::Models::Event.last.id - 5 }
      before do
        make_n_events(10)
        FactoryBot.create(:models_event, parent_id: parent_id, action: 'action', object_type: 'type')
        make_n_events(2)
      end

      it 'keeps the events started from `parent_id` in the database' do
        expect do
          manager.remove_old_events(3)
        end.to change {
          Bosh::Director::Models::Event.count
        }.from(13).to(9)
        expect(Bosh::Director::Models::Event.order { Sequel.desc(:id) }.last.id).to eq(parent_id)
      end
    end
  end
end
