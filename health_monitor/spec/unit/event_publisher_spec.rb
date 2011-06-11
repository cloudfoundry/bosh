require 'spec_helper'

describe Bhm::EventPublisher do

  def make_event(i, ts = Time.now.to_i, data = { })
    Bhm::Event.create!(:summary => "Event #{i}", :data => data, :timestamp => ts)
  end

  before :each do
    Bhm.logger     = Logging.logger(StringIO.new)
    Bhm.event_mbus = OpenStruct.new(:endpoint => "localhost", :user => "zb", :password => "zb")

    @publisher = Bhm::EventPublisher.new
  end

  it "connects to event_mbus and publishes messages" do
    event = make_event(1)
    nats  = mock("nats")

    EM.run do
      EM.add_timer(0.2) { EM.stop }
      NATS.should_receive(:connect).and_return(nats)
      @publisher.connect_to_mbus

      nats.should_receive(:publish).with("bosh.hm.events", event.to_json)
      @publisher.publish_event!(event).should be_true
    end
  end

end
