require 'spec_helper'

describe Bhm::Alert do

  it "exposes a 'create!' method that raises an exception when Alert is invalid and creates an alert otherwise" do
    lambda {
      Bhm::Alert.create!(:severity => 2)
    }.should raise_error(Bhm::InvalidAlert, "Alert is invalid: id is missing, title is missing, timestamp is missing")

    lambda {
      Bhm::Alert.create!(:id => "2321.nats.down", :severity => 2, :title => "NATS down on nats#0")
    }.should raise_error(Bhm::InvalidAlert, "Alert is invalid: timestamp is missing")

    ts = Time.now

    alert = Bhm::Alert.create!(:id => "nats.down", :severity => 2, :title => "NATS is down", :created_at => ts, :summary => "NATS is really down")
    alert.id.should         == "nats.down"
    alert.severity.should   == 2
    alert.title.should      == "NATS is down"
    alert.created_at.should == ts
    alert.summary.should    == "NATS is really down"
  end

end
