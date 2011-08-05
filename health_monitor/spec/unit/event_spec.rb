require 'spec_helper'

describe Bhm::Event do

  it "exposes a 'create!' method that raises an exception when event is invalid and returns created event otherwise" do
    lambda {
      Bhm::Event.create!(:summary => "Something happened")
    }.should raise_error(Bhm::InvalidEvent, "Event is invalid: timestamp is missing")

    lambda {
      Bhm::Event.create!(:timestamp => Time.now)
    }.should raise_error(Bhm::InvalidEvent, "Event is invalid: summary is missing, timestamp format is invalid, Unix timestamp expected")

    ts = Time.now

    attrs = { :summary => "Heartbeat received", :timestamp => ts.to_i, :data => { :a => 1, :b => 2 } }

    event = Bhm::Event.create!(attrs)
    event.should be_valid
    event.summary.should   == "Heartbeat received"
    event.timestamp.should == ts.to_i
    event.data.should      == { :a => 1, :b => 2 }

    event = Bhm::Event.create!(attrs.merge(:data => nil))
    event.should be_valid
  end

end
