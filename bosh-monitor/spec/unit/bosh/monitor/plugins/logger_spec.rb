require 'spec_helper'

describe Bhm::Plugins::Logger do

  before :each do
    @logger = Logging.logger(StringIO.new)
    Bhm.logger = @logger
    @plugin = Bhm::Plugins::Logger.new
  end

  it "validates options" do
    @plugin.validate_options.should be(true)
  end

  it "writes events to log" do
    heartbeat = Bhm::Events::Base.create!(:heartbeat, heartbeat_payload)
    alert = Bhm::Events::Base.create!(:alert, alert_payload)

    @logger.should_receive(:info).with("[HEARTBEAT] #{heartbeat.to_s}")
    @logger.should_receive(:info).with("[ALERT] #{alert.to_s}")

    @plugin.process(heartbeat)
    @plugin.process(alert)
  end

end

