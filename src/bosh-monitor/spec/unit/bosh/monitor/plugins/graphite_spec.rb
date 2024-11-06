require 'spec_helper'

describe Bosh::Monitor::Plugins::Graphite do
  subject(:plugin) { Bosh::Monitor::Plugins::Graphite.new(options) }

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
      expect(Bosh::Monitor::Plugins::Graphite.new(invalid_port_options).validate_options).to be_falsey
      expect(Bosh::Monitor::Plugins::Graphite.new(invalid_max_retries_options).validate_options).to be_falsey
      expect(Bosh::Monitor::Plugins::Graphite.new(valid_options).validate_options).to be_truthy
      expect(Bosh::Monitor::Plugins::Graphite.new(valid_infinite_retries_options).validate_options).to be_truthy
    end
  end

  describe 'process metrics' do
    let(:connection) { instance_double(Bosh::Monitor::GraphiteConnection, connect: nil) }
    before do
      allow(Bosh::Monitor::GraphiteConnection).to receive(:new)
        .with('fake-graphite-host', 2003, 42)
        .and_return(connection)
    end

    context "when event loop isn't running" do
      it "doesn't start" do
        expect(plugin.run).to be(false)
      end
    end

    context 'when event is of type Alert' do
      include_context Async::RSpec::Reactor

      let(:event) { make_alert(timestamp: Time.now.to_i) }

      it 'does not send metrics' do
        plugin.run
        expect(connection).to_not receive(:send_metric)

        plugin.process(event)
      end
    end

    context 'when event is of type Heartbeat' do
      include_context Async::RSpec::Reactor

      it 'sends metrics to Graphite' do
        event = make_heartbeat(timestamp: Time.now.to_i)

        plugin.run

        event.metrics.each do |metric|
          metric_name = "#{event.deployment}.#{event.job}.#{event.instance_id}.#{event.agent_id}.#{metric.name.gsub('.', '_')}"
          expect(connection).to receive(:send_metric).with(metric_name, metric.value, metric.timestamp)
        end

        plugin.process(event)
      end

      it 'skips sending metrics if instance_id is missing' do
        event = make_heartbeat(timestamp: Time.now.to_i, instance_id: nil)

        plugin.run

        expect(connection).not_to receive(:send_metric)

        plugin.process(event)
      end
    end
  end
end
