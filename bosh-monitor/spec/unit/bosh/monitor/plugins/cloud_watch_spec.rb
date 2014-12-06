require 'spec_helper'

describe Bhm::Plugins::CloudWatch do
  let(:aws_cloud_watch) { double('AWS CloudWatch') }
  subject { described_class.new }

  before do
    allow(subject).to receive_messages(aws_cloud_watch: aws_cloud_watch)
  end

  context "processing metrics" do
    it "sends CloudWatch metrics" do
      time = Time.now
      expected_dimensions = [
          {name: "job", value: "mysql_node"},
          {name: "index", value: "0"},
          {name: "name", value: "mysql_node/0"},
          {name: "deployment", value: "oleg-cloud"},
          {name: "agent_id", value: "deadbeef"}
      ]

      expect(aws_cloud_watch).to receive(:put_metric_data) do |data|
        expect(data[:namespace]).to eq("BOSH/HealthMonitor")
        expect(data[:metric_data]).to include({
                                              metric_name: "system.load.1m",
                                              value: "0.2",
                                              timestamp: time.utc.iso8601,
                                              dimensions: expected_dimensions
                                          })

        expect(data[:metric_data]).to include({
                                              metric_name: "system.cpu.user",
                                              value: "22.3",
                                              timestamp: time.utc.iso8601,
                                              dimensions: expected_dimensions
                                          })

        metrics = data[:metric_data].map { |data| data[:metric_name] }
        expect(metrics).to match_array([
            "system.load.1m",
            "system.cpu.user",
            "system.cpu.sys",
            "system.cpu.wait",
            "system.mem.percent",
            "system.mem.kb",
            "system.swap.percent",
            "system.swap.kb",
            "system.disk.system.percent",
            "system.disk.system.inode_percent",
            "system.disk.ephemeral.percent",
            "system.disk.ephemeral.inode_percent",
            "system.disk.persistent.percent",
            "system.disk.persistent.inode_percent",
            "system.healthy"
        ])
      end

      heartbeat = make_heartbeat(timestamp: time)
      subject.process(heartbeat)
    end
  end

  context "processing alarms" do
    it "does nothing" do
      expect(aws_cloud_watch).not_to receive(:put_metric_data)
      alert = make_alert
      subject.process(alert)
    end
  end
end