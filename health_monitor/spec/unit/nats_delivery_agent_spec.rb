require 'spec_helper'

describe Bhm::NatsDeliveryAgent do

  def make_alert(i, ts = Time.now)
    Bhm::Alert.create!(:id => i, :severity => i, :title => "Alert #{i}", :summary => "Summary #{i}", :created_at => ts)
  end

  before :each do
    Bhm.event_mbus = OpenStruct.new(:endpoint => "localhost", :user => "zb", :password => "zb")
    @agent = Bhm::NatsDeliveryAgent.new({ })
  end

  it "doesn't start if event loop isn't running" do
    @agent.run.should be_false
  end

  it "publishes alerts to NATS on a dedicated channel" do
    alert = make_alert(1)
    nats  = mock("nats")

    EM.run do
      EM.add_timer(0.2) { EM.stop }
      NATS.should_receive(:connect).and_return(nats)
      @agent.run

      nats.should_receive(:publish).with("bosh.hm.alerts", alert.to_json)
      @agent.deliver(alert).should be_true
    end
  end

end
