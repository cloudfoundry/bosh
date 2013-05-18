require 'spec_helper'

describe Bhm::Plugins::DataDog do
  subject { described_class.new("api_key" => "api_key", "application_key" => "application_key") }
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
    let(:creation_time) { Time.now.to_i - 10 }

    before do
      EM.should_receive(:defer).and_yield
    end

    it "sends datadog alerts" do
      fake_event = double("Datadog Event")
      Dogapi::Event.should_receive(:new).with do |msg, options|
        msg.should == "Everything is down"
        options[:msg_title].should == "Test Alert"
        options[:date_happened].should == creation_time
        options[:tags].should =~ ["source:mysql_node/0"]
        options[:priority].should == "normal"
      end.and_return(fake_event)

      dog_client.stub(:emit_points)
      dog_client.should_receive(:emit_event).with(fake_event)

      alert = make_alert(created_at: creation_time)
      subject.process(alert)
    end

    describe "sending metrics to datadog" do
      it "sends datadog a metric so that we can set up alerts on it" do
        alert = make_alert(created_at: creation_time)
        metric_id = "bosh.healthmonitor.alerts.test_alert"

        datapoints = [[Time.at(creation_time), 10],
                      [Time.at(creation_time)+1*60, 10],
                      [Time.at(creation_time)+4*60, 0],
                      [Time.at(creation_time)+5*60, 0],
                      [Time.at(creation_time)+6*60, 0],
                      [Time.at(creation_time)+7*60, 0],
                      [Time.at(creation_time)+8*60, 0],
                      [Time.at(creation_time)+9*60, 0]]

        tags = ["source:mysql_node/0"]

        dog_client.stub(:emit_event)
        dog_client.should_receive(:emit_points).with(metric_id, datapoints, tags: tags)

        subject.process(alert)
      end

      it "sanitizes strange characters in the title" do
        alert = make_alert(title: "!!!TEST -  aler@t")
        metric_id = "bosh.healthmonitor.alerts.test_alert"

        dog_client.stub(:emit_event)
        dog_client.should_receive(:emit_points).with(metric_id, anything, anything)

        subject.process(alert)
      end
    end

    it "sends datadog a low priority event for warning alerts" do
      Dogapi::Event.should_receive(:new).with do |_, options|
        options[:priority].should == "low"
      end

      dog_client.stub(:emit_event)
      dog_client.stub(:emit_points)

      alert = make_alert(severity: 4)
      subject.process(alert)
    end
  end
end
