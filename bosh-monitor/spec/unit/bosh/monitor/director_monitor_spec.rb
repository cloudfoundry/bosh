require 'spec_helper'

describe Bosh::Monitor::DirectorMonitor do
  let(:nats) { double("nats client") }
  let(:event_processor) { double(Bosh::Monitor::EventProcessor) }
  let(:logger) { double(Logging) }
  let(:config) { double('config', nats: nats, event_processor: event_processor, logger: logger) }

  subject(:monitor) { described_class.new(config) }

  let(:payload) { {
      "id" => 'payload-id',
      "severity" => 3,
      "title" => 'payload-title',
      "summary" => 'payload-summary',
      "created_at" => Time.now.to_i
  } }

  describe 'subscribe' do
    it 'subscribes to hm.director.alert over NATS' do
      nats.should_receive(:subscribe).with('hm.director.alert')
      monitor.subscribe
    end

    context 'alert handler' do
      let(:message) { JSON.dump(payload) }

      context 'if we have a valid payload' do
        it 'does not log an error' do
          logger.should_not_receive(:error)
          event_processor.stub(:process)
          nats.should_receive(:subscribe).with('hm.director.alert').and_yield(message)

          monitor.subscribe
        end

        it 'tells the event processor to process the alert' do
          nats.should_receive(:subscribe).with('hm.director.alert').and_yield(message)
          event_processor.should_receive(:process).with(:alert, payload)

          monitor.subscribe
        end
      end

      context 'if we have an invalid payload' do
        %w(id severity title summary created_at).each do |key|
          it "logs an error if the #{key} field is missing" do
            payload.delete(key)
            logger.should_receive(:error).with("Invalid payload from director: the key '#{key}' was missing. #{payload.inspect}")
            nats.should_receive(:subscribe).with('hm.director.alert').and_yield(message)

            monitor.subscribe
          end

          it 'does not create a new director alert' do
            payload.delete(key)
            logger.stub(:error)
            nats.should_receive(:subscribe).with('hm.director.alert').and_yield(message)
            event_processor.should_not_receive(:process)

            monitor.subscribe
          end
        end
      end
    end
  end
end
