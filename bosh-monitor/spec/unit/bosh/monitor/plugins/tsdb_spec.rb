require 'spec_helper'

describe Bhm::Plugins::Tsdb do

  before do
    @options = {
      "host" => "localhost",
      "port" => 4242
    }

    @plugin = Bhm::Plugins::Tsdb.new(@options)
  end

  it "validates options" do
    valid_options = {
      "host" => "zb512",
      "port"  => "http://nowhere.com:3128"
    }

    invalid_options = {
      "host" => "localhost"
    }

    expect(Bhm::Plugins::Tsdb.new(valid_options).validate_options).to be(true)
    expect(Bhm::Plugins::Tsdb.new(invalid_options).validate_options).to be(false)
  end

  it "doesn't start if event loop isn't running" do
    expect(@plugin.run).to be(false)
  end

  it "does not send metrics for Alerts" do
    tsdb = double("tsdb connection")

    alert = make_alert(timestamp: Time.now.to_i)

    EM.run do
      allow(EM).to receive(:connect) { tsdb }
      @plugin.run

      expect(tsdb).not_to receive(:send_metric)

      @plugin.process(alert)

      EM.stop
    end

  end

  it "sends Heartbeat metrics to TSDB" do
    tsdb = double("tsdb connection")

    heartbeat = make_heartbeat(timestamp: Time.now.to_i)

    EM.run do
      expect(EM).to receive(:connect).with("localhost", 4242, Bhm::TsdbConnection, "localhost", 4242).once.and_return(tsdb)
      @plugin.run

      heartbeat.metrics.each do |metric|
        expected_tags = metric.tags.merge({deployment: "oleg-cloud"})

        expect(tsdb).to receive(:send_metric).with(metric.name, metric.timestamp, metric.value, expected_tags)
      end

      @plugin.process(heartbeat)

      EM.stop
    end
  end

end
