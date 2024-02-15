require 'spec_helper'

describe Bhm::Plugins::Graphite do
  subject(:plugin) { Bhm::Plugins::Graphite.new(options) }

  let(:options) do
    {
      'host' => 'fake-graphite-host',
      'port' => 2003,
      'max_retries' => 42,
    }
  end

  describe 'validates options' do
    invalid_port_options = {
      'host' => 'localhost',
    }

    invalid_max_retries_options = {
      'host' => 'localhost',
      'port' => 1337,
      'max_retries' => -1337,
    }

    valid_options = {
      'host' => 'fake-graphite-host',
      'port' => 2003,
      'max_retries' => 42,
    }

    valid_infinite_retries_options = {
      'host' => 'fake-graphite-host',
      'port' => 2003,
      'max_retries' => -1,
    }

    it 'validates options' do
      expect(Bhm::Plugins::Graphite.new(invalid_port_options).validate_options).to be_falsey
      expect(Bhm::Plugins::Graphite.new(invalid_max_retries_options).validate_options).to be_falsey
      expect(Bhm::Plugins::Graphite.new(valid_options).validate_options).to be_truthy
      expect(Bhm::Plugins::Graphite.new(valid_infinite_retries_options).validate_options).to be_truthy
    end
  end

  describe 'process metrics' do
    let(:connection) { instance_double('Bosh::Monitor::GraphiteConnection') }
    before do
      allow(EventMachine).to receive(:connect)
        .with('fake-graphite-host', 2003, Bhm::GraphiteConnection, 'fake-graphite-host', 2003, 42)
        .and_return(connection)
    end

    context "when event loop isn't running" do
      it "doesn't start" do
        expect(plugin.run).to be(false)
      end
    end

    context 'when event is of type Alert' do
      let(:event) { make_alert(timestamp: Time.now.to_i) }

      it 'does not send metrics' do
        EventMachine.run do
          plugin.run
          expect(connection).to_not receive(:send_metric)

          plugin.process(event)

          EventMachine.stop
        end
      end
    end

    context 'when event is of type Heartbeat' do
      it 'sends metrics to Graphite' do
        event = make_heartbeat(timestamp: Time.now.to_i)
        EventMachine.run do
          plugin.run

          event.metrics.each do |metric|
            metric_name = "#{event.deployment}.#{event.job}.#{event.instance_id}.#{event.agent_id}.#{metric.name.gsub('.', '_')}"
            expect(connection).to receive(:send_metric).with(metric_name, metric.value, metric.timestamp)
          end

          plugin.process(event)

          EventMachine.stop
        end
      end

      it 'skips sending metrics if instance_id is missing' do
        event = make_heartbeat(timestamp: Time.now.to_i, instance_id: nil)
        EventMachine.run do
          plugin.run

          expect(connection).not_to receive(:send_metric)

          plugin.process(event)

          EventMachine.stop
        end
      end
    end
  end
end
