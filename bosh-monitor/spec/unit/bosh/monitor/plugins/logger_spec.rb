require 'spec_helper'

describe Bhm::Plugins::Logger do

  before do
    Bhm.logger = logger
    @plugin = Bhm::Plugins::Logger.new
  end

  it "validates options" do
    expect(@plugin.validate_options).to be(true)
  end

  it "writes events to log" do
    heartbeat = Bhm::Events::Base.create!(:heartbeat, heartbeat_payload)
    alert = Bhm::Events::Base.create!(:alert, alert_payload)

    expect(logger).to receive(:info).with("[HEARTBEAT] #{heartbeat.to_s}")
    expect(logger).to receive(:info).with("[ALERT] #{alert.to_s}")

    @plugin.process(heartbeat)
    @plugin.process(alert)
  end

end

