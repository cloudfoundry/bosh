require 'spec_helper'

describe Bhm::Plugins::Varz do

  before :each do
    Bhm.logger = Logging.logger(StringIO.new)
    @plugin = Bhm::Plugins::Varz.new
  end

  it "validates options" do
    @plugin.validate_options.should be(true)
  end

  it "sends event metrics to varz" do
    alert = Bhm::Events::Base.create!(:alert,
                                      alert_payload(:agent_id => "a-id"))
    heartbeat = Bhm::Events::Base.create!(:heartbeat,
                                         heartbeat_payload(:agent_id => "a-id"))

    @plugin.run

    Bhm.should_receive(:set_varz).with("last_agents_alert",
                                       {"a-id" => alert.to_hash})
    Bhm.should_receive(:set_varz).with("last_agents_heartbeat",
                                       {"a-id" => heartbeat.to_hash})

    @plugin.process(alert)
    @plugin.process(heartbeat)
  end

  it "sends event metrics to varz from unknown agents " do
    alert = Bhm::Events::Base.create!(:alert, alert_payload)
    heartbeat = Bhm::Events::Base.create!(:heartbeat, heartbeat_payload)

    @plugin.run

    Bhm.should_receive(:set_varz).with("last_agents_alert",
                                       {"unknown" => alert.to_hash})
    Bhm.should_receive(:set_varz).with("last_agents_heartbeat",
                                       {"unknown" => heartbeat.to_hash})

    @plugin.process(alert)
    @plugin.process(heartbeat)
  end

end
