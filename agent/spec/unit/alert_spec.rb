require File.dirname(__FILE__) + '/../spec_helper'

describe Bosh::Agent::Alert do

  before(:each) do
    @logger   = Logger.new(StringIO.new)
    @nats     = mock()
    @agent_id = "zb-agent"

    Bosh::Agent::Config.logger   = @logger
    Bosh::Agent::Config.nats     = @nats
    Bosh::Agent::Config.agent_id = @agent_id
  end

  def make_alert(attrs = { })
    default_attrs = {
      :id          => "id",
      :service     => "service",
      :event       => "event",
      :action      => "action",
      :date        => "date",
      :description => "description"
    }
    Bosh::Agent::Alert.new(default_attrs.merge(attrs))
  end

  it "has a utc unix timestamp" do
    t = Time.now.utc.to_i
    date = Time.at(t).rfc822

    alert = make_alert(:date => date)
    alert.timestamp.should == t
  end

  it "can lookup severity by monit event names" do
    alert = make_alert(:event => "does not exist")
    alert.calculate_severity.should == 1

    alert = make_alert(:event => "pid changed")
    alert.calculate_severity.should == 4

    alert = make_alert(:event => "size failed")
    alert.calculate_severity.should == 3
  end

  it "uses default severity for unknown event names" do
    alert = make_alert(:event => "something bad")
    alert.calculate_severity.should == 2

    alert = make_alert(:event => "something really good")
    alert.calculate_severity.should == 2
  end

  it "converts data for sending it via mbus" do
    attrs = {
      :id          => "1304319946.0",
      :service     => "nats",
      :event       => "does not exist",
      :action      => "restart",
      :date        => "Sun, 22 May 2011 20:07:41 +0500",
      :description => "process is not running"
    }
    alert = make_alert(attrs)

    alert.converted_alert_data.should == {
      "id"         => "1304319946.0",
      "severity"   => 1,
      "title"      => "nats - does not exist - restart",
      "summary"    => "process is not running",
      "created_at" => 1306076861
    }
  end

  it "registers an alert by sending it via mbus 3 times (respecting a one second interval)" do
    alert = make_alert
    EM.should_receive(:add_timer).with(0).and_yield
    EM.should_receive(:add_timer).with(1).and_yield
    EM.should_receive(:add_timer).with(2).and_yield

    alert.should_receive(:send_via_mbus).exactly(3).times
    alert.register
  end

  it "doesn't register alerts with severity >= 5" do
    alert = make_alert

    3.times do |i|
      alert.stub!(:severity).and_return(5 + i)

      EM.should_not_receive(:add_timer)
      alert.should_not_receive(:send_via_mbus)
      alert.register
    end
  end

  it "sends JSON payload over NATS" do
    attrs = {
      :id          => "1304319946.0",
      :service     => "nats",
      :event       => "does not exist",
      :action      => "restart",
      :date        => "Sun, 22 May 2011 20:07:41 +0500",
      :description => "process is not running"
    }
    alert = make_alert(attrs)

    payload = {
      "id"         => "1304319946.0",
      "severity"   => 1,
      "title"      => "nats - does not exist - restart",
      "summary"    => "process is not running",
      "created_at" => 1306076861
    }

    @nats.should_receive(:publish).with("hm.agent.alert.zb-agent", Yajl::Encoder.encode(payload))
    alert.send_via_mbus
  end

end
