require 'spec_helper'

describe Bhm::Plugins::Varz do

  before :each do
    Bhm.logger = Logging.logger(StringIO.new)
    @plugin = Bhm::Plugins::Varz.new
  end

  it "validates options" do
    @plugin.validate_options.should be_true
  end

  it "sends event metrics to varz" do
    alert = Bhm::Events::Base.create!(:alert, alert_payload)
    heartbeat = Bhm::Events::Base.create!(:heartbeat, heartbeat_payload)

    @plugin.run

    Bhm.should_receive(:set_varz).with("last_agents_alert",
                                       {"" => alert.to_hash})
    Bhm.should_receive(:set_varz).with("last_agents_heartbeat",
                                       {"" => heartbeat.to_hash})

    @plugin.process(alert)
    @plugin.process(heartbeat)
  end

end