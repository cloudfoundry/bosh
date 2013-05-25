require 'spec_helper'

describe Bhm::Plugins::DataDog do
  subject { described_class.new("api_key" => "api_key",
    "application_key" => "application_key",
    "pagerduty_service_name" => "service_name")
  }
  let(:dog_client) { double("DataDog Client") }
  before do
    subject.stub(dog_client: dog_client)
  end

  context "processing metrics" do
    it "sends datadog metrics" do
      tags = %w[
          job:mysql_node
          index:0
          deployment:oleg-cloud
          agent:deadbeef
      ]
      time = Time.now
      dog_client.should_receive(:emit_points).with("bosh.healthmonitor.system.load.1m", [[Time.at(time.to_i) ,0.2]], tags: tags)

      EM.should_receive(:defer).and_yield
      %w[
        cpu.user
        cpu.sys
        cpu.wait
        mem.percent
        mem.kb
        swap.percent
        swap.kb
        disk.system.percent
        disk.ephemeral.percent
        disk.persistent.percent
        healthy
      ].each do |metric|
        dog_client.should_receive(:emit_points).with("bosh.healthmonitor.system.#{metric}", anything, anything)
      end

      heartbeat = make_heartbeat(timestamp: time.to_i)
      subject.process(heartbeat)
    end
  end

  context "processing alerts" do
    it "sends datadog alerts" do
      EM.should_receive(:defer).and_yield

      time = Time.now.to_i - 10
      fake_event = double("Datadog Event")
      Dogapi::Event.should_receive(:new).with do |msg, options|
        msg.should == "Everything is down"
        options[:msg_title].should == "Test Alert"
        options[:date_happened].should == time
        options[:tags].should =~ ["source:mysql_node/0"]
        options[:priority].should == "normal"
      end.and_return(fake_event)

      dog_client.should_receive(:emit_event).with(fake_event)

      alert = make_alert(created_at: time)
      subject.process(alert)
    end

    it "sends datadog a low priority event for warning alerts" do
      EM.should_receive(:defer).and_yield

      Dogapi::Event.should_receive(:new).with do |_, options|
        options[:priority].should == "low"
      end

      dog_client.stub(:emit_event)

      alert = make_alert(severity: 4)
      subject.process(alert)
    end
  end
end
