require 'spec_helper'

describe Bosh::Monitor::DirectorMonitor do
  let(:nats) { instance_double('NATS::IO::Client') }
  let(:event_processor) { instance_double('Bosh::Monitor::EventProcessor') }
  let(:logger) { double('Logging::Logger', error: nil, debug: nil) }
  let(:config) { double('config', nats: nats, event_processor: event_processor, logger: logger) }

  subject(:monitor) { described_class.new(config) }

  let(:payload) do
    {
      'id' => 'payload-id',
      'severity' => 3,
      'title' => 'payload-title',
      'summary' => 'payload-summary',
      'created_at' => Time.now.to_i,
    }
  end

  before do
    allow(EventMachine).to receive(:schedule).and_yield
  end

  describe 'subscribe' do
    it 'subscribes to hm.director.alert over NATS' do
      expect(nats).to receive(:subscribe).with('hm.director.alert')
      monitor.subscribe
    end

    context 'alert handler' do
      let(:message) { JSON.dump(payload) }

      context 'if we have a valid payload' do
        it 'does not log an error' do
          expect(logger).to_not receive(:error)
          expect(event_processor).to receive(:process)
          expect(nats).to receive(:subscribe).with('hm.director.alert').and_yield(message, nil, 'hm.director.alert')

          monitor.subscribe
        end

        it 'tells the event processor to process the alert' do
          expect(nats).to receive(:subscribe).with('hm.director.alert').and_yield(message, nil, 'hm.director.alert')
          expect(event_processor).to receive(:process).with(:alert, payload)

          monitor.subscribe
        end
      end

      context 'if we have an invalid payload' do
        %w[id severity title summary created_at].each do |key|
          it "logs an error if the #{key} field is missing" do
            payload.delete(key)
            expect(logger).to receive(:error).with("Invalid payload from director: the key '#{key}' was missing. #{payload.inspect}")
            expect(nats).to receive(:subscribe).with('hm.director.alert').and_yield(message, nil, 'hm.director.alert')

            monitor.subscribe
          end

          it 'does not create a new director alert' do
            payload.delete(key)
            expect(nats).to receive(:subscribe).with('hm.director.alert').and_yield(message, nil, 'hm.director.alert')
            expect(event_processor).to_not receive(:process)

            monitor.subscribe
          end
        end
      end
    end
  end
end
