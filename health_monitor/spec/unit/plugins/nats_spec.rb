require 'spec_helper'

describe Bhm::Plugins::Nats do

  before :each do
    Bhm.logger = Logging.logger(StringIO.new)

    @nats_options = {
      "endpoint" => "localhost",
      "user" => "zb",
      "password" => "zb"
    }

    @plugin = Bhm::Plugins::Nats.new(@nats_options)
  end

  it "doesn't start if event loop isn't running" do
    @plugin.run.should be_false
  end

  it "publishes events to NATS" do
    alert = Bhm::Events::Base.create!(:alert, alert_payload)
    heartbeat = Bhm::Events::Base.create!(:heartbeat, heartbeat_payload)
    nats = mock("nats")

    EM.run do
      NATS.should_receive(:connect).and_return(nats)
      @plugin.run

      nats.should_receive(:publish).with("bosh.hm.events", alert.to_json)
      nats.should_receive(:publish).with("bosh.hm.events", heartbeat.to_json)

      @plugin.process(alert)
      @plugin.process(heartbeat)

      EM.stop
    end
  end

  it "publishes events to a custom NATS subject" do
    @nats_options["subject"] = "test.hm.events"
    @plugin = Bhm::Plugins::Nats.new(@nats_options)
    alert = Bhm::Events::Base.create!(:alert, alert_payload)
    heartbeat = Bhm::Events::Base.create!(:heartbeat, heartbeat_payload)
    nats = mock("nats")

    EM.run do
      NATS.should_receive(:connect).and_return(nats)
      @plugin.run

      nats.should_receive(:publish).with("test.hm.events", alert.to_json)
      nats.should_receive(:publish).with("test.hm.events", heartbeat.to_json)

      @plugin.process(alert)
      @plugin.process(heartbeat)

      EM.stop
    end
  end

end
