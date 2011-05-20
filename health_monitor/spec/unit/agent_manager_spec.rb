require 'spec_helper'

describe Bhm::AgentManager do

  before :each do
    Bhm.logger = Logging.logger(StringIO.new)

    # Just use 2 loggers to test multiple agents without having to care
    # about stubbing delivery operations and providing well formed configs
    Bhm.alert_delivery_agents = [ { "plugin" => "logger" }, { "plugin" => "logger" } ]
  end

  def make_manager
    Bhm::AgentManager.new
  end

  it "can process heartbeats" do
    manager = make_manager
    manager.agents_count.should == 0
    manager.process_heartbeat("agent007", "payload")
    manager.process_heartbeat("agent007", "payload")
    manager.process_heartbeat("agent008", "payload")

    manager.agents_count.should == 2
  end

  it "can process alerts" do
    manager = make_manager

    good_alert_json      = Yajl::Encoder.encode({"id" => "778", "severity" => 2, "title" => "zb", "summary" => "zbb", "created_at" => Time.now.utc.to_i })
    bad_alert_json       = Yajl::Encoder.encode({"id" => "778", "severity" => -2, "title" => nil, "summary" => "zbb", "created_at" => Time.now.utc.to_i })
    malformed_alert_json = Yajl::Encoder.encode("zb")

    manager.process_alert(good_alert_json)
    manager.process_alert(bad_alert_json)
    manager.process_alert(malformed_alert_json)

    manager.alerts_processed.should == 1
  end

  it "can analyze agents" do
    pending
  end

end
