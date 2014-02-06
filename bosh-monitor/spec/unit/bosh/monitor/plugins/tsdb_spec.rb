require 'spec_helper'

describe Bhm::Plugins::Tsdb do

  before :each do
    Bhm.logger = Logging.logger(StringIO.new)

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

    Bhm::Plugins::Tsdb.new(valid_options).validate_options.should be(true)
    Bhm::Plugins::Tsdb.new(invalid_options).validate_options.should be(false)
  end

  it "doesn't start if event loop isn't running" do
    @plugin.run.should be(false)
  end

  it "does not send metrics for Alerts" do
    tsdb = double("tsdb connection")

    alert = make_alert(timestamp: Time.now.to_i)

    EM.run do
      EM.stub(:connect) { tsdb }
      @plugin.run

      tsdb.should_not_receive(:send_metric)

      @plugin.process(alert)

      EM.stop
    end

  end

  it "sends Heartbeat metrics to TSDB" do
    tsdb = double("tsdb connection")

    heartbeat = make_heartbeat(timestamp: Time.now.to_i)

    EM.run do
      EM.should_receive(:connect).with("localhost", 4242, Bhm::TsdbConnection, "localhost", 4242).once.and_return(tsdb)
      @plugin.run

      heartbeat.metrics.each do |metric|
        expected_tags = metric.tags.merge({deployment: "oleg-cloud"})

        tsdb.should_receive(:send_metric).with(metric.name, metric.timestamp, metric.value, expected_tags)
      end

      @plugin.process(heartbeat)

      EM.stop
    end
  end

end
