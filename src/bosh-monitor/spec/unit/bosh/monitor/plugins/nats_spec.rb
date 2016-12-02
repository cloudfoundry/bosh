require 'spec_helper'

describe Bhm::Plugins::Nats do

  before do
    @nats_options = {
      "endpoint" => "localhost",
      "user" => "zb",
      "password" => "zb"
    }

    @plugin = Bhm::Plugins::Nats.new(@nats_options)
  end

  it "doesn't start if event loop isn't running" do
    expect(@plugin.run).to be(false)
  end

  it "publishes events to NATS" do
    alert = Bhm::Events::Base.create!(:alert, alert_payload)
    heartbeat = Bhm::Events::Base.create!(:heartbeat, heartbeat_payload)
    nats = double("nats")

    EM.run do
      expect(NATS).to receive(:connect).and_return(nats)
      @plugin.run

      expect(nats).to receive(:publish).with("bosh.hm.events", alert.to_json)
      expect(nats).to receive(:publish).with("bosh.hm.events", heartbeat.to_json)

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
    nats = double("nats")

    EM.run do
      expect(NATS).to receive(:connect).and_return(nats)
      @plugin.run

      expect(nats).to receive(:publish).with("test.hm.events", alert.to_json)
      expect(nats).to receive(:publish).with("test.hm.events", heartbeat.to_json)

      @plugin.process(alert)
      @plugin.process(heartbeat)

      EM.stop
    end
  end

end
