require "spec_helper"

describe Bhm::Events::Base do

  it "can act as events factory" do
    alert = Bhm::Events::Base.create(:alert, alert_payload)
    alert.should be_instance_of Bhm::Events::Alert
    alert.kind.should == :alert

    heartbeat = Bhm::Events::Base.create(:heartbeat, heartbeat_payload)
    heartbeat.should be_instance_of Bhm::Events::Heartbeat
    heartbeat.kind.should == :heartbeat
  end

  it "whines on attempt to create event from unsupported types" do
    lambda {
      Bhm::Events::Base.create!(:alert, "foo")
    }.should raise_error(Bhm::InvalidEvent, "Cannot create event from String")
  end

  it "whines on invalid events (when using create!)" do
    incomplete_payload = alert_payload(:severity => nil)

    alert = Bhm::Events::Base.create(:alert, incomplete_payload)
    alert.should_not be_valid

    lambda {
      Bhm::Events::Base.create!(:alert, incomplete_payload)
    }.should raise_error(Bhm::InvalidEvent, "severity is missing")
  end

  it "whines on unknown event kinds" do
    lambda {
      Bhm::Events::Base.create!(:foobar, { })
    }.should raise_error(Bhm::InvalidEvent, "Cannot find `foobar' event handler")
  end

  it "normalizes attributes" do
    event = Bhm::Events::Base.new(:a => 1, :b => 2)
    event.attributes.should == { "a" => 1, "b" => 2 }
  end

  it "provides stubs for format representations" do
    event = Bhm::Events::Base.new

    [:validate, :to_plain_text, :to_hash, :to_json, :metrics].each do |method|
      lambda {
        event.send(method)
      }.should raise_error(Bhm::FatalError, "`#{method}' is not implemented by Bosh::HealthMonitor::Events::Base")
    end
  end

end
