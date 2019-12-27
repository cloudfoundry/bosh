require_relative '../../../../spec_helper'

describe Bhm::Plugins::Tsdb do
  subject(:plugin) { Bhm::Plugins::Tsdb.new(options) }

  let(:options) do
    {
      'host' => 'fake-host',
      'port' => 4242,
    }
  end

  let(:connection) { instance_double('Bosh::Monitor::TsdbConnection') }
  before { allow(EM).to receive(:connect).with('fake-host', 4242, Bhm::TsdbConnection, 'fake-host', 4242).and_return(connection) }

  it 'validates options' do
    valid_options = {
      'host' => 'zb512',
      'port' => 'http://nowhere.com:3128',
    }

    invalid_options = {
      'host' => 'localhost',
    }

    expect(Bhm::Plugins::Tsdb.new(valid_options).validate_options).to be(true)
    expect(Bhm::Plugins::Tsdb.new(invalid_options).validate_options).to be(false)
  end

  it "doesn't start if event loop isn't running" do
    expect(plugin.run).to be(false)
  end

  it 'does not send metrics for alerts' do
    alert = make_alert(timestamp: Time.now.to_i)

    EM.run do
      plugin.run

      expect(connection).not_to receive(:send_metric)

      plugin.process(alert)

      EM.stop
    end
  end

  it 'does not send empty tags to TSDB' do
    heartbeat = make_heartbeat(timestamp: Time.now.to_i, instance_id: '')

    EM.run do
      plugin.run

      heartbeat.metrics.each do |metric|
        expect(connection).to receive(:send_metric)
          .with(metric.name, metric.timestamp, metric.value, hash_excluding('instance_id'))
      end

      plugin.process(heartbeat)

      EM.stop
    end
  end

  it 'sends heartbeat metrics to TSDB' do
    heartbeat = make_heartbeat(timestamp: Time.now.to_i)

    EM.run do
      plugin.run

      heartbeat.metrics.each do |metric|
        expected_tags = metric.tags.merge(deployment: 'oleg-cloud')

        expect(connection).to receive(:send_metric).with(metric.name, metric.timestamp, metric.value, expected_tags)
      end

      plugin.process(heartbeat)

      EM.stop
    end
  end
end
