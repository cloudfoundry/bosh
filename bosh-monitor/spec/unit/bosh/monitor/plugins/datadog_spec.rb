require 'spec_helper'

describe Bhm::Plugins::DataDog do
  let(:options) { { "api_key" => "api_key", "application_key" => "application_key" } }
  subject { described_class.new(options) }

  let(:dog_client) { double("DataDog Client") }

  before do
    allow(subject).to receive_messages(dog_client: dog_client)
  end

  describe "validating the options" do
    context "when we specify both the api keu and the application key" do
      it "is valid" do
        expect(subject.validate_options).to eq(true)
      end
    end

    context "when we omit the application key " do
      let(:options) { { "api_key" => "api_key" } }

      it "is not valid" do
        expect(subject.validate_options).to eq(false)
      end
    end

    context "when we omit the api key " do
      let(:options) { { "application_key" => "application_key" } }

      it "is not valid" do
        expect(subject.validate_options).to eq(false)
      end
    end
  end

  describe "creating a data dog client" do
    before do
      datadog_plugin.run
    end

    let(:datadog_plugin) { described_class.new(options) }
    let(:client) { datadog_plugin.dog_client }

    context "when we specify the pager duty service name" do
      let(:options) { { "api_key" => "api_key", "application_key" => "application_key", "pagerduty_service_name" => "pdsn" } }

      it "creates a paging client" do
        expect(client).to be_a PagingDatadogClient
      end

      it "has the correct pager duty service name" do
        expect(client.datadog_recipient).to eq("pdsn")
      end
    end

    context "when we do not specify the pager duty service name" do
      it "creates a regular client" do
        expect(client).to be_a Dogapi::Client
      end
    end
  end

  context "processing metrics" do

    it "didn't freak out once timeout sendidng datadog metric" do
      expect(EM).to receive(:defer).and_yield
      heartbeat = make_heartbeat
      allow(dog_client).to receive(:emit_points).and_raise(Timeout::Error)
      expect { subject.process(heartbeat) }.to_not raise_error
    end

    it "didn't freak out with exceptions while sendidng datadog event" do
      expect(EM).to receive(:defer).and_yield
      heartbeat = make_heartbeat
      allow(dog_client).to receive(:emit_points).and_raise
      expect { subject.process(heartbeat) }.to_not raise_error
    end


    it "sends datadog metrics" do
      tags = %w[
          job:mysql_node
          index:0
          deployment:oleg-cloud
          agent:deadbeef
      ]
      time = Time.now
      expect(dog_client).to receive(:emit_points).with("bosh.healthmonitor.system.load.1m", [[Time.at(time.to_i) ,0.2]], tags: tags)

      expect(EM).to receive(:defer).and_yield
      %w[
        cpu.user
        cpu.sys
        cpu.wait
        mem.percent
        mem.kb
        swap.percent
        swap.kb
        disk.system.percent
        disk.system.inode_percent
        disk.ephemeral.percent
        disk.ephemeral.inode_percent
        disk.persistent.percent
        disk.persistent.inode_percent
        healthy
      ].each do |metric|
        expect(dog_client).to receive(:emit_points).with("bosh.healthmonitor.system.#{metric}", anything, anything)
      end

      heartbeat = make_heartbeat(timestamp: time.to_i)
      subject.process(heartbeat)
    end
  end

  context "processing alerts" do

    it "didn't freak out once timeout sendidng datadog event" do
      expect(EM).to receive(:defer).and_yield
      heartbeat = make_heartbeat
      allow(dog_client).to receive(:emit_event).and_raise(Timeout::Error)
      alert = make_alert
      expect { subject.process(alert) }.to_not raise_error
    end

    it "didn't freak out with exceptions while sendidng datadog event" do
      expect(EM).to receive(:defer).and_yield
      heartbeat = make_heartbeat
      allow(dog_client).to receive(:emit_event).and_raise
      alert = make_alert
      expect { subject.process(alert) }.to_not raise_error
    end

    it "sends datadog alerts" do
      expect(EM).to receive(:defer).and_yield

      time = Time.now.to_i - 10
      fake_event = double("Datadog Event")
      expect(Dogapi::Event).to receive(:new) { |msg, options|
        expect(msg).to eq("Everything is down")
        expect(options[:msg_title]).to eq("Test Alert")
        expect(options[:date_happened]).to eq(time)
        expect(options[:tags]).to match_array(["source:mysql_node/0"])
        expect(options[:priority]).to eq("normal")
      }.and_return(fake_event)

      expect(dog_client).to receive(:emit_event).with(fake_event)

      alert = make_alert(created_at: time)
      subject.process(alert)
    end

    it "sends datadog a low priority event for warning alerts" do
      expect(EM).to receive(:defer).and_yield

      expect(Dogapi::Event).to receive(:new) do |_, options|
        expect(options[:priority]).to eq("low")
      end

      allow(dog_client).to receive(:emit_event)

      alert = make_alert(severity: 4)
      subject.process(alert)
    end
  end
end
