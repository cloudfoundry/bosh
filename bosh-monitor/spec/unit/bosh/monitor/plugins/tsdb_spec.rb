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

  it "sends event metrics to TSDB" do
    tsdb = double("tsdb connection")

    alert = Bhm::Events::Base.create!(:alert, alert_payload)
    heartbeat = Bhm::Events::Base.create!(:heartbeat, heartbeat_payload)

    EM.run do
      EM.should_receive(:connect).with("localhost", 4242, Bhm::TsdbConnection, "localhost", 4242).once.and_return(tsdb)
      @plugin.run

      (alert.metrics + heartbeat.metrics).each do |metric|
        tsdb.should_receive(:send_metric).with(metric.name, metric.timestamp, metric.value, metric.tags)
      end

      @plugin.process(alert)
      @plugin.process(heartbeat)

      EM.stop
    end
  end

end
